import SwiftUI
import Supabase

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

struct HabitDetailView: View {
    let habit: Habit

    @Environment(AuthManager.self) private var auth

    @State private var logs: [HabitLog] = []
    @State private var plan: HabitPlan?
    @State private var isLoading = true
    @State private var isLoadingPlan = false
    @State private var isGeneratingPlan = false
    @State private var alertMessage: String?
    @State private var logsErrorMessage: String?
    @State private var planErrorMessage: String?
    @State private var planLoadingTitle = ""
    @State private var planLoadingSubtitle = ""
    @State private var planLoadingMode: PlanLoadingMode = .generating
    @State private var displayedMonth: Date = Date()
    @State private var showAlhamdulillah = false
    @State private var alhamdulillahTask: Task<Void, Never>?
    @State private var isTogglingToday = false

    private static let ymdFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var todayDateString: String { Self.ymdFormatter.string(from: Date()) }

    private func isCompleted(dateString: String) -> Bool {
        logs.first { $0.date == dateString }?.completed ?? false
    }

    private var isCompletedToday: Bool { isCompleted(dateString: todayDateString) }

    private var habitStreak: Int {
        let completed = Set(logs.filter(\.completed).map(\.date))
        let calendar = Calendar.current
        var count = 0
        var cursor = Date()

        if !completed.contains(Self.ymdFormatter.string(from: cursor)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        while completed.contains(Self.ymdFormatter.string(from: cursor)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return count
    }

    private var longestStreak: Int {
        let completedDates: [Date] = logs
            .filter(\.completed)
            .compactMap { Self.ymdFormatter.date(from: $0.date) }
            .sorted()
        guard !completedDates.isEmpty else { return 0 }

        let calendar = Calendar.current
        var longest = 1
        var current = 1

        for index in 1..<completedDates.count {
            let previous = completedDates[index - 1]
            let next = completedDates[index]
            if let gap = calendar.dateComponents([.day], from: previous, to: next).day, gap == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    private var completionRate: Double {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let totalDays = calendar.dateComponents([.day], from: interval.start, to: interval.end).day
        else { return 0 }

        let today = Date()
        let isCurrentMonth = calendar.isDate(displayedMonth, equalTo: today, toGranularity: .month)
        let denominator = isCurrentMonth ? calendar.component(.day, from: today) : totalDays
        guard denominator > 0 else { return 0 }

        let completedInMonth = logs.filter { log in
            guard log.completed, let date = Self.ymdFormatter.date(from: log.date) else { return false }
            return calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        }.count

        return Double(completedInMonth) / Double(denominator)
    }

    private var todayMilestone: HabitMilestone? {
        guard let plan else { return nil }
        let currentDay = plan.currentCycleMilestoneDay()
        return plan.milestones.first { $0.day == currentDay }
    }

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    detailHeader
                    todaysFocusCard
                    HabitMonthCalendar(
                        displayedMonth: $displayedMonth,
                        logs: logs,
                        todayString: todayDateString
                    )
                    .padding(.horizontal, 16)

                    statsRow
                        .padding(.horizontal, 16)

                    if isLoading && logs.isEmpty {
                        ProgressView()
                            .tint(Color.msGold)
                            .padding(.top, 8)
                    } else if let logsErrorMessage, logs.isEmpty {
                        inlineStatusCard(
                            title: "Couldn't load check-ins",
                            message: logsErrorMessage,
                            buttonTitle: "Retry"
                        ) {
                            Task { await fetchLogs() }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }

            if showAlhamdulillah {
                HamdulillahOverlay()
                    .allowsHitTesting(false)
            }

            if isGeneratingPlan {
                planLoadingOverlay
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if !isCompletedToday {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await toggleTodayCompletion() }
                    }
                    label: {
                        if isTogglingToday {
                            ProgressView()
                                .tint(Color.msGold)
                        } else {
                            Text("Check in")
                                .foregroundStyle(Color.msGold)
                        }
                    }
                    .disabled(isTogglingToday)
                }
            }
        }
        .task {
            await fetchLogs()
            await loadPlan()
        }
        .alert("Error", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var detailHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                SwiftUI.Circle()
                    .fill(Color.msGold.opacity(0.10))
                    .frame(width: 78, height: 78)

                Image(systemName: habit.icon)
                    .font(.system(size: 34))
                    .foregroundStyle(Color.msGold)
                    .shadow(color: Color.msGold.opacity(0.45), radius: 10)
            }

            Text(habit.name)
                .font(.system(size: 26, weight: .regular, design: .serif))
                .foregroundStyle(Color.msTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("Make today count.")
                .font(.system(size: 15, weight: .regular, design: .serif).italic())
                .foregroundStyle(Color.msTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .padding(.horizontal, 16)
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
        } else if let planErrorMessage {
            inlineStatusCard(
                title: "Couldn't load your roadmap",
                message: planErrorMessage,
                buttonTitle: "Retry"
            ) {
                Task { await loadPlan() }
            }
            .padding(.horizontal, 16)
        } else {
            buildPlanCTA
                .padding(.horizontal, 16)
        }
    }

    private func todaysFocusCardLabel(plan: HabitPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today’s Focus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.msGold)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.msGold.opacity(0.7))
            }

            if let milestone = todayMilestone {
                Text(milestone.title)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                    .multilineTextAlignment(.leading)
                Text(milestone.description)
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

    private func playCompletionFeedback() {
        showAlhamdulillah = true
        alhamdulillahTask?.cancel()
        alhamdulillahTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            showAlhamdulillah = false
        }
    }

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

    private func inlineStatusCard(
        title: String,
        message: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(Color.msTextPrimary)
            Text(message)
                .font(.appSubheadline)
                .foregroundStyle(Color.msTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button(buttonTitle, action: action)
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(Color.msBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.msGold, in: Capsule())
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.msBorder, lineWidth: 1))
    }

    private func loadPlan() async {
        guard let userId = auth.session?.user.id else { return }
        isLoadingPlan = true
        planErrorMessage = nil
        defer { isLoadingPlan = false }
        do {
            plan = try await HabitPlanService.shared.fetchPlan(habitId: habit.id, userId: userId)
        } catch {
            plan = nil
            planErrorMessage = HabitPlanService.userFacingMessage(from: error)
        }
    }

    private func generatePlan() async {
        guard let userId = auth.session?.user.id else { return }
        planLoadingMode = .generating
        planLoadingTitle = "Generating your roadmap..."
        planLoadingSubtitle = "Building a gentle 28-day path for this habit."
        isGeneratingPlan = true
        alertMessage = nil
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
            planErrorMessage = nil
        } catch {
            alertMessage = HabitPlanService.userFacingMessage(from: error)
        }
    }

    private func fetchLogs() async {
        isLoading = true
        logsErrorMessage = nil
        do {
            let fetched: [HabitLog] = try await SupabaseService.shared.client
                .from("habit_logs")
                .select()
                .eq("habit_id", value: habit.id.uuidString)
                .execute()
                .value
            logs = fetched
        } catch {
            logs = []
            logsErrorMessage = "Check your connection and try again."
        }
        isLoading = false
    }

    private func toggleTodayCompletion() async {
        guard let userId = auth.session?.user.id, !isTogglingToday else { return }

        let wasCompleted = isCompletedToday
        let createdOptimisticLog: Bool
        isTogglingToday = true

        if let existingIndex = logs.firstIndex(where: { $0.date == todayDateString }) {
            logs[existingIndex].completed.toggle()
            createdOptimisticLog = false
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
            createdOptimisticLog = true
        }

        if !wasCompleted {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            playCompletionFeedback()
        }

        do {
            _ = try await HabitToggleService.shared.toggleToday(
                habit: habit,
                userId: userId,
                date: todayDateString,
                alreadyCompleted: wasCompleted
            )
        } catch {
            if createdOptimisticLog {
                logs.removeAll { $0.date == todayDateString }
            } else if let existingIndex = logs.firstIndex(where: { $0.date == todayDateString }) {
                logs[existingIndex].completed = wasCompleted
            }
            if !wasCompleted {
                showAlhamdulillah = false
            }
            alertMessage = "Couldn't save today's check-in. Try again."
        }

        isTogglingToday = false
    }
}

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
                                .fill(index == activeIndex ? Color.msGold : Color.msGold.opacity(index < activeIndex ? 0.45 : 0.18))
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
