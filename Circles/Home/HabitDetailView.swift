import SwiftUI
import Supabase

struct HabitDetailView: View {
    let habit: Habit

    @Environment(AuthManager.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    @State private var logs: [HabitLog] = []
    @State private var plan: HabitPlan?
    @State private var isLoading = true
    @State private var isLoadingPlan = false
    @State private var isGeneratingPlan = false
    @State private var errorMessage: String?
    @State private var showRefineSheet = false

    private var colors: AppColors { AppColors.resolve(colorScheme) }

    private var last28Days: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        return (0..<28).reversed().map { daysAgo -> String in
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            return formatter.string(from: date)
        }
    }

    private var twentyEightDaysAgoString: String {
        last28Days.first ?? ""
    }

    private func isCompleted(dateString: String) -> Bool {
        logs.first { $0.date == dateString }?.completed ?? false
    }

    private var totalCompletions: Int {
        logs.filter { $0.completed }.count
    }

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 24) {
                    heroCard

                    roadmapSection

                    historySection
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchLogs()
            await loadPlan()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showRefineSheet) {
            RefinePlanSheet(
                isRefining: $isGeneratingPlan,
                onRefine: { userNote in
                    await refineWithAI(userNote: userNote)
                }
            )
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 8) {
            Image(systemName: habit.icon)
                .font(.system(size: 56))
                .foregroundStyle(Color.accent)
            Text(habit.name)
                .font(.appTitle)
                .foregroundStyle(colors.textPrimary)
            if let goal = habit.acceptedAmount, !goal.isEmpty {
                Label(goal, systemImage: "target")
                    .font(.appSubheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            HStack(spacing: 16) {
                StatBadge(label: "Completions", value: "\(totalCompletions)")
                StatBadge(label: "Last 28 days", value: "\(totalCompletions)/28")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppCardBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    // MARK: - Roadmap

    private var roadmapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("28-Day Roadmap")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                if plan != nil {
                    Button("Refine plan") {
                        if plan?.isRefinementLimitReached == true {
                            errorMessage = HabitPlanServiceError.refinementLimitReached.errorDescription
                        } else {
                            showRefineSheet = true
                        }
                    }
                    .font(.appCaptionMedium)
                    .foregroundStyle(plan?.isRefinementLimitReached == true ? Color.textSecondary : Color.accent)
                    .disabled(isGeneratingPlan)
                }
            }
            .padding(.horizontal, 16)

            if isLoadingPlan {
                HStack { Spacer(); ProgressView().tint(Color.accent); Spacer() }
                    .padding(.vertical, 8)
            } else if let plan {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(1 ... 4, id: \.self) { week in
                        let days = plan.milestones.filter { plan.displayWeek(forMilestoneDay: $0.day) == week }
                        if !days.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Week \(week)")
                                    .font(.appCaptionMedium)
                                    .foregroundStyle(Color.accent)
                                ForEach(days) { m in
                                    milestoneRow(plan: plan, milestone: m)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text("Get a gentle, personalized 28-day path for this habit.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                    PrimaryButton(title: isGeneratingPlan ? "Generating…" : "Generate 28-day plan") {
                        Task { await generatePlan() }
                    }
                    .disabled(isGeneratingPlan)
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    private func milestoneRow(plan: HabitPlan, milestone: HabitMilestone) -> some View {
        let today = plan.isMilestoneToday(day: milestone.day)
        let dateLabel: String = {
            guard let s = plan.calendarDateString(forMilestoneDay: milestone.day) else { return "" }
            let parts = s.split(separator: "-")
            guard parts.count == 3 else { return s }
            return "\(parts[1])/\(parts[2])"
        }()

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Day \(milestone.day)")
                    .font(.appCaptionMedium)
                    .foregroundStyle(Color.textSecondary)
                Text(dateLabel)
                    .font(.appCaption)
                    .foregroundStyle(Color.textSecondary.opacity(0.85))
                if today {
                    Text("Today")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accent, in: Capsule())
                }
                Spacer()
            }
            Text(milestone.title)
                .font(.appSubheadline)
                .foregroundStyle(colors.textPrimary)
            Text(milestone.description)
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(today ? Color.accent.opacity(0.12) : Color.white.opacity(colorScheme == .dark ? 0.06 : 0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(today ? Color.accent.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - History grid

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("28-Day History")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(colors.textPrimary)
                .padding(.horizontal, 16)

            if isLoading {
                HStack { Spacer(); ProgressView().tint(Color.accent); Spacer() }
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(last28Days, id: \.self) { dateStr in
                        VStack(spacing: 2) {
                            SwiftUI.Circle()
                                .fill(isCompleted(dateString: dateStr) ? Color.accent : Color.white.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Text(dayNumber(from: dateStr))
                                .font(.system(size: 9))
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Actions

    private func loadPlan() async {
        guard let userId = auth.session?.user.id else { return }
        isLoadingPlan = true
        defer { isLoadingPlan = false }
        plan = try? await HabitPlanService.shared.fetchPlan(habitId: habit.id, userId: userId)
    }

    private func generatePlan() async {
        guard let userId = auth.session?.user.id else { return }
        isGeneratingPlan = true
        errorMessage = nil
        defer { isGeneratingPlan = false }
        do {
            let milestones = try await GeminiService.shared.generate28DayRoadmap(
                habitName: habit.name,
                planNotes: habit.planNotes,
                userRefinementRequest: nil
            )
            plan = try await HabitPlanService.shared.upsertInitialPlan(
                habitId: habit.id,
                userId: userId,
                milestones: milestones
            )
        } catch {
            errorMessage = HabitPlanService.userFacingMessage(from: error)
        }
    }

    private func refineWithAI(userNote: String?) async {
        guard let userId = auth.session?.user.id, let existing = plan else { return }
        isGeneratingPlan = true
        errorMessage = nil
        defer { isGeneratingPlan = false }
        do {
            let milestones = try await GeminiService.shared.generate28DayRoadmap(
                habitName: habit.name,
                planNotes: habit.planNotes,
                userRefinementRequest: userNote
            )
            plan = try await HabitPlanService.shared.applyRefinement(habitId: habit.id, milestones: milestones)
            showRefineSheet = false
        } catch let e as HabitPlanServiceError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = HabitPlanService.userFacingMessage(from: error)
        }
    }

    private func fetchLogs() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched: [HabitLog] = try await SupabaseService.shared.client
                .from("habit_logs")
                .select()
                .eq("habit_id", value: habit.id.uuidString)
                .gte("date", value: twentyEightDaysAgoString)
                .execute()
                .value
            logs = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func dayNumber(from dateString: String) -> String {
        let day = String(dateString.suffix(2))
        return day.hasPrefix("0") ? String(day.dropFirst()) : day
    }
}

// MARK: - Refine sheet

private struct RefinePlanSheet: View {
    @Binding var isRefining: Bool
    var onRefine: (String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.darkBackground : Color.lightBackground)
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tell the coach what to change (optional). We’ll regenerate all 28 days.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.textSecondary)
                    TextField("e.g. I can only practice on weekdays…", text: $note, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .textFieldStyle(.roundedBorder)
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Refine plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isRefining)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Refine with AI") {
                        Task {
                            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                            await onRefine(trimmed.isEmpty ? nil : trimmed)
                        }
                    }
                    .disabled(isRefining)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Small views

private struct StatBadge: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct AppCardBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.75)
    }
}
