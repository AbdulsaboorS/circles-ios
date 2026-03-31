import SwiftUI
import Supabase

// MARK: - Midnight Sanctuary tokens

private extension Color {
    static let msBackground  = Color(hex: "1A2E1E")
    static let msCardShared  = Color(hex: "243828")
    static let msCardDeep    = Color(hex: "1E3122")
    static let msGold        = Color(hex: "D4A240")
    static let msTextPrimary = Color(hex: "F0EAD6")
    static let msTextMuted   = Color(hex: "8FAF94")
    static let msBorder      = Color(hex: "D4A240").opacity(0.18)
}

struct HabitDetailView: View {
    let habit: Habit

    @Environment(AuthManager.self) private var auth

    @State private var logs: [HabitLog] = []
    @State private var plan: HabitPlan?
    @State private var isLoading = true
    @State private var isLoadingPlan = false
    @State private var isGeneratingPlan = false
    @State private var errorMessage: String?
    @State private var showRefineSheet = false
    // Collapsible weeks: default all collapsed; week 1 opens after plan generates
    @State private var expandedWeeks: Set<Int> = []
    // Editing
    @State private var editingMilestone: HabitMilestone?

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
            Color.msBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    heroCard

                    historySection   // heatmap first

                    roadmapSection
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
        .sheet(item: $editingMilestone) { milestone in
            EditMilestoneSheet(milestone: milestone) { updated in
                applyMilestoneEdit(updated)
            }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 8) {
            Image(systemName: habit.icon)
                .font(.system(size: 56))
                .foregroundStyle(Color.msGold)
            Text(habit.name)
                .font(.appTitle)
                .foregroundStyle(Color.msTextPrimary)
            if let goal = habit.acceptedAmount, !goal.isEmpty {
                Label(goal, systemImage: "target")
                    .font(.appSubheadline)
                    .foregroundStyle(Color.msTextMuted)
            }
            HStack(spacing: 16) {
                StatBadge(label: "Completions", value: "\(totalCompletions)")
                StatBadge(label: "Last 28 days", value: "\(totalCompletions)/28")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.msCardShared)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.msBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Roadmap

    private var roadmapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("28-Day Roadmap")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                Spacer()
                if plan != nil {
                    Button("Refine") {
                        if plan?.isRefinementLimitReached == true {
                            errorMessage = HabitPlanServiceError.refinementLimitReached.errorDescription
                        } else {
                            showRefineSheet = true
                        }
                    }
                    .font(.appCaptionMedium)
                    .foregroundStyle(plan?.isRefinementLimitReached == true ? Color.msTextMuted : Color.msGold)
                    .disabled(isGeneratingPlan)
                }
            }
            .padding(.horizontal, 16)

            if isLoadingPlan {
                HStack { Spacer(); ProgressView().tint(Color.msGold); Spacer() }
                    .padding(.vertical, 8)
            } else if let plan {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(1 ... 4, id: \.self) { week in
                        let days = plan.milestones.filter { plan.displayWeek(forMilestoneDay: $0.day) == week }
                        if !days.isEmpty {
                            weekSection(week: week, days: days, plan: plan)
                        }
                    }
                }
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 12) {
                    Text("Get a gentle, personalized 28-day path for this habit.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)

                    Button {
                        Task { await generatePlan() }
                    } label: {
                        ZStack {
                            if isGeneratingPlan {
                                ProgressView().tint(Color.msBackground)
                            } else {
                                Text("Generate 28-day plan")
                                    .font(.appSubheadline.weight(.semibold))
                                    .foregroundStyle(Color.msBackground)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(isGeneratingPlan ? Color.msGold.opacity(0.4) : Color.msGold)
                        .clipShape(Capsule())
                    }
                    .disabled(isGeneratingPlan)
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    private func weekSection(week: Int, days: [HabitMilestone], plan: HabitPlan) -> some View {
        let isExpanded = expandedWeeks.contains(week)
        let hasToday = days.contains { plan.isMilestoneToday(day: $0.day) }

        return VStack(alignment: .leading, spacing: 0) {
            // Week header — tappable to collapse/expand
            Button {
                if isExpanded {
                    expandedWeeks.remove(week)
                } else {
                    expandedWeeks.insert(week)
                }
            } label: {
                HStack {
                    Text("Week \(week)")
                        .font(.appCaptionMedium)
                        .foregroundStyle(hasToday ? Color.msGold : Color.msTextMuted)
                    if hasToday {
                        Text("Current")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.msBackground)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.msGold, in: Capsule())
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.msTextMuted)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: isExpanded ? 14 : 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(hasToday ? Color.msGold.opacity(0.4) : Color.msBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(days) { m in
                        milestoneRow(plan: plan, milestone: m)
                    }
                }
                .padding(.top, 8)
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
                    .foregroundStyle(Color.msTextMuted)
                Text(dateLabel)
                    .font(.appCaption)
                    .foregroundStyle(Color.msTextMuted.opacity(0.7))
                if today {
                    Text("Today")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.msBackground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.msGold, in: Capsule())
                }
                Spacer()
                Button {
                    editingMilestone = milestone
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.msTextMuted.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            Text(milestone.title)
                .font(.appSubheadline)
                .foregroundStyle(Color.msTextPrimary)
            Text(milestone.description)
                .font(.appCaption)
                .foregroundStyle(Color.msTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(today ? Color.msGold.opacity(0.10) : Color.msCardDeep)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(today ? Color.msGold.opacity(0.35) : Color.msBorder, lineWidth: 1)
        )
    }

    // MARK: - Apply milestone edit

    private func applyMilestoneEdit(_ updated: HabitMilestone) {
        guard var currentPlan = plan,
              let idx = currentPlan.milestones.firstIndex(where: { $0.day == updated.day }) else { return }
        currentPlan.milestones[idx] = updated
        plan = currentPlan
        Task {
            try? await HabitPlanService.shared.updateMilestones(
                planId: currentPlan.id,
                milestones: currentPlan.milestones
            )
        }
    }

    // MARK: - History grid

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("28-Day History")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Color.msTextPrimary)
                .padding(.horizontal, 16)

            if isLoading {
                HStack { Spacer(); ProgressView().tint(Color.msGold); Spacer() }
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(last28Days, id: \.self) { dateStr in
                        VStack(spacing: 2) {
                            SwiftUI.Circle()
                                .fill(isCompleted(dateString: dateStr) ? Color.msGold : Color.msCardShared)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    SwiftUI.Circle()
                                        .stroke(Color.msBorder, lineWidth: isCompleted(dateString: dateStr) ? 0 : 1)
                                )
                            Text(dayNumber(from: dateStr))
                                .font(.system(size: 9))
                                .foregroundStyle(Color.msTextMuted)
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
            expandedWeeks = [1]  // reveal week 1 so user sees it generated
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
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tell the coach what to change (optional). We'll regenerate all 28 days.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                    TextField("e.g. I can only practice on weekdays…", text: $note, axis: .vertical)
                        .lineLimit(3 ... 6)
                        .foregroundStyle(Color.msTextPrimary)
                        .padding(12)
                        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 10))
                        .tint(Color.msGold)
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Refine plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.msGold)
                        .disabled(isRefining)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Refine with AI") {
                        Task {
                            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                            await onRefine(trimmed.isEmpty ? nil : trimmed)
                        }
                    }
                    .foregroundStyle(Color.msGold)
                    .disabled(isRefining)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Edit milestone sheet

private struct EditMilestoneSheet: View {
    let milestone: HabitMilestone
    var onSave: (HabitMilestone) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var desc: String

    init(milestone: HabitMilestone, onSave: @escaping (HabitMilestone) -> Void) {
        self.milestone = milestone
        self.onSave = onSave
        _title = State(initialValue: milestone.title)
        _desc = State(initialValue: milestone.description)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text("Day \(milestone.day)")
                        .font(.appCaptionMedium)
                        .foregroundStyle(Color.msGold)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.appCaption)
                            .foregroundStyle(Color.msTextMuted)
                        TextField("Title", text: $title)
                            .foregroundStyle(Color.msTextPrimary)
                            .padding(12)
                            .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 10))
                            .tint(Color.msGold)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.appCaption)
                            .foregroundStyle(Color.msTextMuted)
                        TextField("Description", text: $desc, axis: .vertical)
                            .lineLimit(3 ... 8)
                            .foregroundStyle(Color.msTextPrimary)
                            .padding(12)
                            .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 10))
                            .tint(Color.msGold)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Edit Day \(milestone.day)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.msGold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = milestone
                        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.description = desc.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(updated)
                        dismiss()
                    }
                    .foregroundStyle(Color.msGold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Color.msTextPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.msTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.msCardDeep, in: RoundedRectangle(cornerRadius: 10))
    }
}
