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

private enum DetailTab: String, CaseIterable {
    case path       = "Path"
    case roadmap    = "Roadmap"
    case reflection = "Reflection"
}

// MARK: - HabitDetailView

struct HabitDetailView: View {
    let habit: Habit

    @Environment(AuthManager.self) private var auth

    @State private var logs: [HabitLog] = []
    @State private var plan: HabitPlan?
    @State private var isLoading = true
    @State private var isLoadingPlan = false
    @State private var isGeneratingPlan = false
    @State private var errorMessage: String?
    @State private var planLoadingTitle = ""
    @State private var planLoadingSubtitle = ""
    @State private var planLoadingMode: PlanLoadingMode = .generating
    @State private var showRefineSheet = false
    @State private var showReflectionSheet = false
    @State private var editingReflectionDate: String? = nil
    @State private var todayReflection = ""
    @State private var allReflections: [(date: String, note: String)] = []
    @State private var expandedWeeks: Set<Int> = []
    @State private var editingMilestone: HabitMilestone?
    @State private var revealedGlow: Set<Int> = []
    @State private var showFullRoadmapSheet = false
    @State private var selectedTab: DetailTab = .path

    // MARK: - Computed helpers

    private var last28Days: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        return (0..<28).reversed().map { daysAgo -> String in
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            return formatter.string(from: date)
        }
    }

    private var twentyEightDaysAgoString: String { last28Days.first ?? "" }

    private func isCompleted(dateString: String) -> Bool {
        logs.first { $0.date == dateString }?.completed ?? false
    }

    private var totalCompletions: Int { logs.filter { $0.completed }.count }
    private var todayDateString: String { last28Days.last ?? "" }
    private var isCompletedToday: Bool { isCompleted(dateString: todayDateString) }

    /// Consecutive days this habit has been completed, counting backwards from today.
    /// If today isn't done yet, starts counting from yesterday so an in-progress streak
    /// isn't zeroed out mid-day.
    private var habitStreak: Int {
        var count = 0
        for dateStr in last28Days.reversed() {
            if isCompleted(dateString: dateStr) {
                count += 1
            } else if dateStr == todayDateString {
                continue   // today not done yet — skip, don't break
            } else {
                break
            }
        }
        return count
    }

    private var currentPlanWeek: Int? {
        guard let plan else { return nil }
        return plan.milestones.first { plan.isMilestoneToday(day: $0.day) }
            .map { plan.displayWeek(forMilestoneDay: $0.day) }
    }

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                    tabBar
                    tabContent
                        .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }

            if isGeneratingPlan {
                planLoadingOverlay
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await fetchLogs()
            await loadPlan()
            loadTodayReflection()
            loadAllReflections()
            await triggerConstellationReveal()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showRefineSheet) {
            RefinePlanSheet(
                isRefining: $isGeneratingPlan,
                onRefine: { userNote in await refineWithAI(userNote: userNote) }
            )
        }
        .sheet(isPresented: $showReflectionSheet) {
            let date = editingReflectionDate ?? todayDateString
            let initial = ReflectionLogStore.load(habitId: habit.id, date: date)
            let label = formatReflectionDate(date, style: .full)
            ReflectionLogSheet(
                dateLabel: label,
                initialNote: initial,
                onSave: { note in saveReflection(note, for: date) }
            )
        }
        .sheet(item: $editingMilestone) { milestone in
            EditMilestoneSheet(milestone: milestone) { updated in applyMilestoneEdit(updated) }
        }
        .sheet(isPresented: $showFullRoadmapSheet) {
            fullRoadmapSheet
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium))
                        .foregroundStyle(selectedTab == tab ? Color.msGold : Color.msTextMuted)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 18)
                        .background(
                            selectedTab == tab
                                ? Color.msGold.opacity(0.14)
                                : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.msCardShared, in: Capsule())
        .overlay(Capsule().stroke(Color.msBorder, lineWidth: 1))
    }

    // MARK: - Tab content router

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .path:
            constellationSection
        case .roadmap:
            roadmapCard
        case .reflection:
            reflectionTabContent
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 18) {
            ZStack {
                RadialGradient(
                    colors: [
                        Color.msGold.opacity(isCompletedToday ? 0.22 : 0.10),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: 72
                )
                .frame(width: 144, height: 144)
                .animation(.easeInOut(duration: 0.7), value: isCompletedToday)

                if isCompletedToday {
                    SwiftUI.Circle()
                        .stroke(Color.msGold.opacity(0.08), lineWidth: 10)
                        .frame(width: 116, height: 116)

                    SwiftUI.Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.msGold.opacity(0.65), Color.msGold.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: Color.msGold.opacity(0.55), radius: 14)
                }

                Image(systemName: habit.icon)
                    .font(.system(size: 54))
                    .foregroundStyle(Color.msGold)
                    .shadow(
                        color: Color.msGold.opacity(isCompletedToday ? 0.70 : 0.28),
                        radius: isCompletedToday ? 20 : 8
                    )
            }
            .animation(.easeInOut(duration: 0.7), value: isCompletedToday)

            if let niyyah = habit.niyyah?.trimmingCharacters(in: .whitespacesAndNewlines),
               !niyyah.isEmpty {
                Text("“\(niyyah)”")
                    .font(.system(size: 15, weight: .regular, design: .serif).italic())
                    .foregroundStyle(Color.msTextPrimary.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
            }

            if let goal = habit.acceptedAmount, !goal.isEmpty {
                Label(goal, systemImage: "target")
                    .font(.appCaption)
                    .foregroundStyle(Color.msTextMuted)
            }

            HStack(spacing: 10) {
                StatPill(text: habitStreak > 0 ? "\(habitStreak) Day Streak" : "Start a Streak")
                StatPill(text: "\(totalCompletions)/28 Completions")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 4)
        .padding(.horizontal, 16)
    }

    // MARK: - Path tab

    private var constellationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isLoading {
                HStack { Spacer(); ProgressView().tint(Color.msGold); Spacer() }
                    .padding(.vertical, 20)
            } else if totalCompletions == 0 {
                VStack(spacing: 8) {
                    Text("Your path begins today.")
                        .font(.system(size: 15, weight: .regular, design: .serif).italic())
                        .foregroundStyle(Color.msTextMuted.opacity(0.7))
                    Text("Each check-in lights a node on your constellation.")
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { row in
                        HStack(spacing: 0) {
                            Text(shortDateLabel(last28Days[row * 7]))
                                .font(.system(size: 9, weight: .regular))
                                .foregroundStyle(Color.msTextMuted.opacity(0.4))
                                .frame(width: 30, alignment: .leading)

                            ForEach(0..<7, id: \.self) { col in
                                let index = row * 7 + col
                                let dateStr = last28Days[index]
                                let done = isCompleted(dateString: dateStr)
                                let glowing = revealedGlow.contains(index)
                                let isToday = dateStr == todayDateString

                                ZStack {
                                    SwiftUI.Circle()
                                        .fill(done ? Color.msGold : Color.clear)
                                        .shadow(color: glowing ? Color.msGold.opacity(0.75) : .clear,
                                                radius: glowing ? 9 : 0)

                                    SwiftUI.Circle()
                                        .stroke(
                                            isToday
                                                ? Color.msTextPrimary.opacity(0.55)
                                                : (done ? Color.clear : Color.msTextMuted.opacity(0.22)),
                                            lineWidth: isToday ? 2 : 1
                                        )

                                    if isToday && !done {
                                        SwiftUI.Circle()
                                            .fill(Color.msTextPrimary.opacity(0.25))
                                            .frame(width: 5, height: 5)
                                    }
                                }
                                .frame(width: 30, height: 30)
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Reflection tab

    private var reflectionTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Today's card — tappable to write/edit
            todayReflectionCard

            // Past entries
            let past = allReflections.filter { $0.date != todayDateString }
            if !past.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Past Reflections")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.msTextMuted)
                        .padding(.horizontal, 20)

                    ForEach(past, id: \.date) { entry in
                        pastReflectionCard(date: entry.date, note: entry.note)
                    }
                }
            }
        }
    }

    private var todayReflectionCard: some View {
        Button {
            editingReflectionDate = todayDateString
            showReflectionSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Reflection")
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.msTextPrimary)
                        Text(formatReflectionDate(todayDateString, style: .long))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.msTextMuted.opacity(0.65))
                    }
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.msGold.opacity(0.7))
                }

                if todayReflection.isEmpty {
                    Text("What did your heart hear today?")
                        .font(.system(size: 14, weight: .regular, design: .serif).italic())
                        .foregroundStyle(Color.msTextMuted.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                } else {
                    Text(todayReflection)
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(5)
                }
            }
            .padding(20)
            .background(Color.msCardDeep, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.msBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func pastReflectionCard(date: String, note: String) -> some View {
        Button {
            editingReflectionDate = date
            showReflectionSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(formatReflectionDate(date, style: .medium))
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(Color.msGold.opacity(0.75))
                Text(note)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.msTextPrimary.opacity(0.8))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.msCardDeep, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.msBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Roadmap tab

    private var roadmapCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("28-Day Roadmap")
                    .font(.system(size: 17, weight: .semibold, design: .serif))
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

            if isLoadingPlan {
                HStack { Spacer(); ProgressView().tint(Color.msGold); Spacer() }
                    .padding(.vertical, 8)
            } else if let plan {
                let week = currentPlanWeek ?? 1
                let weekMilestones = plan.milestones.filter {
                    plan.displayWeek(forMilestoneDay: $0.day) == week
                }
                let todayMilestone = weekMilestones.first { plan.isMilestoneToday(day: $0.day) }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Week \(week)")
                            .font(.appCaptionMedium)
                            .foregroundStyle(Color.msGold)
                        Text("Current")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.msBackground)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.msGold, in: Capsule())
                    }

                    if let m = todayMilestone {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Day \(m.day) · Today")
                                .font(.appCaption)
                                .foregroundStyle(Color.msGold.opacity(0.85))
                            Text(m.title)
                                .font(.appSubheadline)
                                .foregroundStyle(Color.msTextPrimary)
                            Text(m.description)
                                .font(.appCaption)
                                .foregroundStyle(Color.msTextMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.msGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.msGold.opacity(0.25), lineWidth: 1)
                        )
                    }

                    Button {
                        showFullRoadmapSheet = true
                    } label: {
                        HStack {
                            Text("View Full Roadmap")
                                .font(.appCaptionMedium)
                                .foregroundStyle(Color.msGold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.msGold.opacity(0.7))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.msCardDeep, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.msBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
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
        .padding(20)
        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.msBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Full roadmap sheet (bug fix: expandedWeeks set in .onAppear)

    private var fullRoadmapSheet: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let plan {
                            ForEach(1...4, id: \.self) { week in
                                let days = plan.milestones.filter {
                                    plan.displayWeek(forMilestoneDay: $0.day) == week
                                }
                                if !days.isEmpty {
                                    weekSection(week: week, days: days, plan: plan)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .onAppear { expandedWeeks = Set(1...4) }  // fix: initialize after sheet renders
            .navigationTitle("28-Day Roadmap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showFullRoadmapSheet = false }
                        .foregroundStyle(Color.msGold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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

    // MARK: - Week / Milestone rows

    private func weekSection(week: Int, days: [HabitMilestone], plan: HabitPlan) -> some View {
        let isExpanded = expandedWeeks.contains(week)
        let hasToday = days.contains { plan.isMilestoneToday(day: $0.day) }

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                if isExpanded { expandedWeeks.remove(week) } else { expandedWeeks.insert(week) }
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
                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(hasToday ? Color.msGold.opacity(0.4) : Color.msBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(days) { m in milestoneRow(plan: plan, milestone: m) }
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

    // MARK: - Constellation animation

    private func triggerConstellationReveal() async {
        let completedIndices = last28Days.enumerated()
            .filter { isCompleted(dateString: $0.element) }
            .map { $0.offset }
        for (i, idx) in completedIndices.enumerated() {
            try? await Task.sleep(nanoseconds: UInt64(i * 80_000_000))
            withAnimation(.easeOut(duration: 0.35)) {
                revealedGlow.insert(idx)
            }
        }
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
            expandedWeeks = [1]
        } catch {
            errorMessage = HabitPlanService.userFacingMessage(from: error)
        }
    }

    private func refineWithAI(userNote: String?) async {
        guard plan != nil else { return }
        planLoadingMode = .refining
        planLoadingTitle = "Updating your roadmap..."
        planLoadingSubtitle = "Applying your feedback and regenerating all 28 days."
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

    // MARK: - Reflection helpers

    private func loadTodayReflection() {
        todayReflection = ReflectionLogStore.load(habitId: habit.id, date: todayDateString)
    }

    private func loadAllReflections() {
        // Newest first; includes today so the list stays in sync
        allReflections = last28Days.reversed().compactMap { dateStr in
            let note = ReflectionLogStore.load(habitId: habit.id, date: dateStr)
            return note.isEmpty ? nil : (date: dateStr, note: note)
        }
    }

    private func saveReflection(_ note: String, for date: String) {
        ReflectionLogStore.save(note, habitId: habit.id, date: date)
        if date == todayDateString {
            todayReflection = ReflectionLogStore.load(habitId: habit.id, date: date)
        }
        loadAllReflections()
    }

    private func shortDateLabel(_ dateString: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dateString) else { return "" }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return display.string(from: date)
    }

    private func formatReflectionDate(_ dateString: String, style: DateFormatter.Style) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dateString) else { return dateString }
        let display = DateFormatter()
        display.dateStyle = style
        display.timeStyle = .none
        return display.string(from: date)
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.msTextMuted)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.msCardShared, in: Capsule())
            .overlay(Capsule().stroke(Color.msBorder, lineWidth: 1))
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
                        .lineLimit(3...6)
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
                            dismiss()
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

// MARK: - Reflection log sheet

private struct ReflectionLogSheet: View {
    let dateLabel: String
    let initialNote: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note: String

    init(dateLabel: String, initialNote: String, onSave: @escaping (String) -> Void) {
        self.dateLabel = dateLabel
        self.initialNote = initialNote
        self.onSave = onSave
        _note = State(initialValue: initialNote)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text(dateLabel)
                        .font(.appCaptionMedium)
                        .foregroundStyle(Color.msGold)
                    Text("Private reflection for today")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                    TextField(
                        "Write about your consistency, intention, or spiritual state today…",
                        text: $note,
                        axis: .vertical
                    )
                    .lineLimit(8...16)
                    .foregroundStyle(Color.msTextPrimary)
                    .padding(14)
                    .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                    .tint(Color.msGold)
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Reflection Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.msGold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(note); dismiss() }
                        .foregroundStyle(Color.msGold)
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
                            .lineLimit(3...8)
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

// MARK: - Roadmap loading indicator

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
