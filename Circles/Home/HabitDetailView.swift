import SwiftUI
import Supabase

// MARK: - Enums

private enum PlanLoadingMode {
    case generating
    case refining

    var steps: [String] {
        switch self {
        case .generating:
            ["Shaping the plan", "Balancing the 28 days", "Saving your roadmap"]
        case .refining:
            ["Reading your feedback", "Reworking the 28 days", "Saving the update"]
        }
    }
}

// MARK: - HabitDetailView
//
// Two-state layout (post-redesign):
//  - State 1 — pre-check-in: hold-to-confirm orb + contextual text.
//  - State 2 — post-check-in: monthly calendar heatmap, today's focus card
//    (pushes `FullRoadmapView`), and stats row.
//
// Toggle happens here (the card taps on Home now navigate straight to this
// screen instead of toggling inline). Ownership of the Alhamdulillah beat
// moved here too — Home no longer mounts the overlay.

struct HabitDetailView: View {
    let habit: Habit

    @Environment(AuthManager.self) private var auth

    // Logs + plan
    @State private var logs: [HabitLog] = []
    @State private var plan: HabitPlan?
    @State private var isLoading = true
    @State private var isLoadingPlan = false
    @State private var isGeneratingPlan = false
    @State private var errorMessage: String?
    @State private var planLoadingTitle = ""
    @State private var planLoadingSubtitle = ""
    @State private var planLoadingMode: PlanLoadingMode = .generating

    // Calendar paging
    @State private var displayedMonth: Date = Date()

    // Celebration (moved from HomeView)
    @State private var showAlhamdulillah: Bool = false
    @State private var alhamdulillahTask: Task<Void, Never>?
    @State private var isTogglingToday = false

    // MARK: - Computed helpers

    private static let ymdFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var todayDateString: String { Self.ymdFormatter.string(from: Date()) }

    private func isCompleted(dateString: String) -> Bool {
        logs.first { $0.date == dateString }?.completed ?? false
    }

    private var isCompletedToday: Bool { isCompleted(dateString: todayDateString) }

    private var totalCompletions: Int { logs.filter(\.completed).count }

    /// Current streak counting backwards from today. Skips today when today
    /// isn't done yet so an in-progress streak isn't zeroed mid-day.
    private var habitStreak: Int {
        let completed = Set(logs.filter(\.completed).map(\.date))
        let calendar = Calendar.current
        var count = 0
        var cursor = Date()
        // If today isn't done, start from yesterday.
        if !completed.contains(Self.ymdFormatter.string(from: cursor)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        while completed.contains(Self.ymdFormatter.string(from: cursor)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// Longest run of consecutive completed days anywhere in `logs`.
    private var longestStreak: Int {
        let completedDates: [Date] = logs
            .filter(\.completed)
            .compactMap { Self.ymdFormatter.date(from: $0.date) }
            .sorted()
        guard !completedDates.isEmpty else { return 0 }
        let calendar = Calendar.current
        var longest = 1
        var current = 1
        for i in 1..<completedDates.count {
            let prev = completedDates[i - 1]
            let this = completedDates[i]
            if let gap = calendar.dateComponents([.day], from: prev, to: this).day, gap == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    /// Completion rate within `displayedMonth`. Past months divide by total
    /// days in the month; the current month divides by days up to today.
    private var completionRate: Double {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let totalDays = calendar.dateComponents([.day], from: interval.start, to: interval.end).day
        else { return 0 }
        let today = Date()
        let isCurrentMonth = calendar.isDate(displayedMonth, equalTo: today, toGranularity: .month)
        let denominator: Int = {
            if isCurrentMonth {
                return calendar.component(.day, from: today)
            } else if interval.end <= today {
                return totalDays
            } else {
                // Future month — shouldn't be reachable via UI but cap safely.
                return totalDays
            }
        }()
        guard denominator > 0 else { return 0 }
        let completedInMonth = logs.filter { log in
            guard log.completed, let d = Self.ymdFormatter.date(from: log.date) else { return false }
            return calendar.isDate(d, equalTo: displayedMonth, toGranularity: .month)
        }.count
        return Double(completedInMonth) / Double(denominator)
    }

    private var todayMilestone: HabitMilestone? {
        guard let plan else { return nil }
        return plan.milestones.first { plan.isMilestoneToday(day: $0.day) }
    }

    private var contextualText: String {
        if let m = todayMilestone, !m.description.isEmpty { return m.description }
        if let niyyah = habit.niyyah?.trimmingCharacters(in: .whitespacesAndNewlines), !niyyah.isEmpty {
            return "“\(niyyah)”"
        }
        return "Make today count."
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            Group {
                if isCompletedToday {
                    completedState
                } else {
                    preCheckInState
                }
            }
            .animation(.easeInOut(duration: 0.35), value: isCompletedToday)

            if showAlhamdulillah {
                HamdulillahOverlay()
                    .allowsHitTesting(false)
            }

            if isGeneratingPlan {
                planLoadingOverlay
            }
        }
        .navigationTitle(isCompletedToday ? habit.name : "Today's Check-In")
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
    }

    // MARK: - State 1 — Pre-check-in

    private var preCheckInState: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 24)

                habitBadgePill

                Text(habit.name)
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(contextualText)
                    .font(.system(size: 15, weight: .regular, design: .serif).italic())
                    .foregroundStyle(Color.msTextMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)

                CheckInOrb(onComplete: handleOrbComplete)
                    .padding(.vertical, 24)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var habitBadgePill: some View {
        HStack(spacing: 8) {
            Image(systemName: habit.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.msGold)
            Text(habit.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.msTextPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.msCardShared, in: Capsule())
        .overlay(Capsule().stroke(Color.msGold.opacity(0.3), lineWidth: 1))
    }

    // MARK: - State 2 — Post-check-in

    private var completedState: some View {
        ScrollView {
            VStack(spacing: 24) {
                completedHeader
                todayActionCard
                todaysFocusCard
                HabitMonthCalendar(
                    displayedMonth: $displayedMonth,
                    logs: logs,
                    todayString: todayDateString
                )
                .padding(.horizontal, 16)
                statsRow
                    .padding(.horizontal, 16)
                Spacer(minLength: 0)
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    private var completedHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: habit.icon)
                .font(.system(size: 36))
                .foregroundStyle(Color.msGold)
                .shadow(color: Color.msGold.opacity(0.5), radius: 10)

            Text(habit.name)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .foregroundStyle(Color.msTextPrimary)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Completed today")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(Color.msGold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.msGold.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Color.msGold.opacity(0.35), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var todaysFocusCard: some View {
        if let plan {
            NavigationLink {
                FullRoadmapView(habit: habit, plan: plan, onPlanChanged: { updated in
                    self.plan = updated
                })
            } label: {
                todaysFocusCardLabel(plan: plan)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        } else if isLoadingPlan {
            HStack {
                Spacer()
                ProgressView().tint(Color.msGold)
                Spacer()
            }
            .padding(.vertical, 20)
        } else {
            buildPlanCTA
                .padding(.horizontal, 16)
        }
    }

    private var todayActionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(.appCaptionMedium)
                .foregroundStyle(Color.msGold.opacity(0.9))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isCompletedToday ? "Completed for today" : "Still waiting for today's check-in")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextPrimary)

                    Text(isCompletedToday ? "You can undo if this needs to be corrected." : "Reminder taps land here so you can check in without hunting through Home.")
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)
                }

                Spacer(minLength: 12)

                Button {
                    Task { await toggleTodayCompletion() }
                } label: {
                    Group {
                        if isTogglingToday {
                            ProgressView()
                                .tint(Color.msBackground)
                                .frame(width: 124, height: 44)
                        } else {
                            Text(isCompletedToday ? "Undo" : "Check In")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.msBackground)
                                .frame(width: 124, height: 44)
                        }
                    }
                    .background(Color.msGold, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isTogglingToday)
            }
        }
        .padding(18)
        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.msBorder, lineWidth: 1)
        )
    }

    private func todaysFocusCardLabel(plan: HabitPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's Focus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.msGold)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.msGold.opacity(0.7))
            }

            if let m = todayMilestone {
                Text(m.title)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                    .multilineTextAlignment(.leading)
                Text(m.description)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.msTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            } else {
                Text("View your 28-day roadmap")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.msTextPrimary)
                Text("Tap to review the full plan week by week.")
                    .font(.appSubheadline)
                    .foregroundStyle(Color.msTextMuted)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.msGold.opacity(0.25), lineWidth: 1)
        )
    }

    private var buildPlanCTA: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Build your 28-day plan")
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(Color.msTextPrimary)
            Text("A gentle, personalized roadmap for this habit.")
                .font(.appSubheadline)
                .foregroundStyle(Color.msTextMuted)
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
                .frame(height: 48)
                .background(isGeneratingPlan ? Color.msGold.opacity(0.4) : Color.msGold)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isGeneratingPlan)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.msBorder, lineWidth: 1))
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatPill(
                title: "Current",
                value: "\(habitStreak)",
                subtitle: habitStreak == 1 ? "day" : "days"
            )
            StatPill(
                title: "This Month",
                value: "\(Int((completionRate * 100).rounded()))%",
                subtitle: "complete"
            )
            StatPill(
                title: "Longest",
                value: "\(longestStreak)",
                subtitle: longestStreak == 1 ? "day" : "days"
            )
        }
    }

    // MARK: - Orb completion

    private func handleOrbComplete() {
        guard let userId = auth.session?.user.id, !isTogglingToday else { return }

        // Optimistic local log so isCompletedToday flips immediately and the
        // view animates into State 2 behind the Alhamdulillah beat.
        let todayStr = todayDateString
        isTogglingToday = true
        if let idx = logs.firstIndex(where: { $0.date == todayStr }) {
            logs[idx].completed = true
        } else {
            logs.append(HabitLog(
                id: UUID(),
                habitId: habit.id,
                userId: userId,
                date: todayStr,
                completed: true,
                notes: nil,
                createdAt: Date()
            ))
        }

        showAlhamdulillah = true
        alhamdulillahTask?.cancel()
        alhamdulillahTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            showAlhamdulillah = false
        }

        // Fire-and-forget persistence + cross-circle side effects.
        Task {
            do {
                _ = try await HabitToggleService.shared.toggleToday(
                    habit: habit,
                    userId: userId,
                    date: todayStr,
                    alreadyCompleted: false
                )
            } catch {
                errorMessage = error.localizedDescription
                // Roll back optimistic log so the view reverts to State 1.
                if let idx = logs.firstIndex(where: { $0.date == todayStr }) {
                    logs[idx].completed = false
                }
            }
            isTogglingToday = false
        }
    }

    // MARK: - Plan loading overlay

    private var planLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(planLoadingTitle)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                Text(planLoadingSubtitle)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.msTextMuted)
                    .multilineTextAlignment(.center)
                RoadmapLoadingIndicator(mode: planLoadingMode)
                ProgressView()
                    .tint(Color.msGold)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
            .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.msBorder, lineWidth: 1))
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
    }
    // MARK: - Data actions

    private func loadPlan() async {
        guard let userId = auth.session?.user.id else { return }
        isLoadingPlan = true
        defer { isLoadingPlan = false }
        plan = try? await HabitPlanService.shared.fetchPlan(habitId: habit.id, userId: userId)
    }

    private func generatePlan() async {
        guard let userId = auth.session?.user.id else { return }
        planLoadingMode = .generating
        planLoadingTitle = "Generating your roadmap..."
        planLoadingSubtitle = "Building a gentle 28-day path for this habit."
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

    private func fetchLogs() async {
        isLoading = true
        errorMessage = nil
        do {
            // Pull the full log history — calendar needs months past the 28-day
            // window, and longestStreak must see every completion.
            let fetched: [HabitLog] = try await SupabaseService.shared.client
                .from("habit_logs")
                .select()
                .eq("habit_id", value: habit.id.uuidString)
                .execute()
                .value
            logs = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleTodayCompletion() async {
        guard let userId = auth.session?.user.id, !isTogglingToday else { return }

        let wasCompleted = isCompletedToday
        isTogglingToday = true

        if let existingIndex = logs.firstIndex(where: { $0.date == todayDateString }) {
            logs[existingIndex].completed.toggle()
        } else {
            logs.append(
                HabitLog(
                    id: UUID(),
                    habitId: habit.id,
                    userId: userId,
                    date: todayDateString,
                    completed: true,
                    notes: nil,
                    createdAt: Date()
                )
            )
        }

        do {
            _ = try await HabitToggleService.shared.toggleToday(
                habit: habit,
                userId: userId,
                date: todayDateString,
                alreadyCompleted: wasCompleted
            )
        } catch {
            if let existingIndex = logs.firstIndex(where: { $0.date == todayDateString }) {
                logs[existingIndex].completed = wasCompleted
            }
            errorMessage = error.localizedDescription
        }

        isTogglingToday = false
    }
}

// MARK: - Stat Pill (redesigned — title / value / subtitle stack)

private struct StatPill: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.msTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Color.msGold)
            Text(subtitle)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Color.msTextMuted.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.msBorder, lineWidth: 1))
    }
}

// MARK: - Roadmap loading indicator (unchanged)

private struct RoadmapLoadingIndicator: View {
    let mode: PlanLoadingMode

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.9, paused: false)) { context in
            let steps = mode.steps
            let activeIndex = Int(context.date.timeIntervalSinceReferenceDate / 1.2) % steps.count

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.msGold)
                    Text(steps[activeIndex])
                        .font(.appCaptionMedium)
                        .foregroundStyle(Color.msTextPrimary)
                        .animation(.easeInOut(duration: 0.25), value: activeIndex)
                }

                HStack(spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        VStack(alignment: .leading, spacing: 6) {
                            Capsule()
                                .fill(index == activeIndex
                                      ? Color.msGold
                                      : Color.msGold.opacity(index < activeIndex ? 0.45 : 0.18))
                                .frame(height: 6)
                            Text(step)
                                .font(.system(size: 10, weight: index == activeIndex ? .semibold : .regular))
                                .foregroundStyle(index == activeIndex ? Color.msTextPrimary : Color.msTextMuted)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}
