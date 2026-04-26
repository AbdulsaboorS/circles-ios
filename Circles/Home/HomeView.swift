import SwiftUI
import Supabase

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct GrainTexture: View {
    private static let grainPoints: [(CGFloat, CGFloat)] = {
        var rng = SystemRandomNumberGenerator()
        return (0 ..< 900).map { _ in
            (CGFloat.random(in: 0 ..< 1, using: &rng),
             CGFloat.random(in: 0 ..< 1, using: &rng))
        }
    }()

    var body: some View {
        Canvas { ctx, size in
            for (nx, ny) in Self.grainPoints {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: nx * size.width, y: ny * size.height, width: 1, height: 1)),
                    with: .color(.white.opacity(0.028))
                )
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

private struct CardGrain: View {
    private static let points: [(CGFloat, CGFloat)] = {
        var rng = SystemRandomNumberGenerator()
        return (0 ..< 300).map { _ in
            (CGFloat.random(in: 0 ..< 1, using: &rng),
             CGFloat.random(in: 0 ..< 1, using: &rng))
        }
    }()

    var body: some View {
        Canvas { ctx, size in
            for (nx, ny) in Self.points {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: nx * size.width, y: ny * size.height, width: 1, height: 1)),
                    with: .color(.white.opacity(0.032))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

struct HomeView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = HomeViewModel()
    @State private var notificationService = NotificationService.shared
    @State private var preferredName = "Friend"
    @State private var showAddIntention = false
    @State private var navigationPath = NavigationPath()
    @State private var showRoadmapBanner = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showNoorInfo = false
    @State private var showEditLayout = false
    @State private var sharedHabits: [Habit] = []
    @State private var personalHabits: [Habit] = []
    @State private var fabGlow = false
    @State private var pendingUndo: PendingUndo?
    @State private var undoDismissTask: Task<Void, Never>?

    private struct PendingUndo: Equatable {
        let habit: Habit
    }

    private let islamicQuotes = [
        "\"Verily, in the remembrance of Allah do hearts find rest.\"",
        "\"Verily, with hardship comes ease.\"",
        "\"Allah is with the patient.\"",
        "\"The best of deeds are those done consistently.\"",
        "\"Whoever fears Allah, He will make a way out for him.\""
    ]

    private var todayFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private var hijriDateFormatted: String {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = Locale(identifier: "en_US")
        let components = calendar.dateComponents([.day, .month, .year], from: Date())
        let months = [
            "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
            "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
            "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"
        ]
        let monthIndex = (components.month ?? 1) - 1
        let monthName = (0 ..< months.count).contains(monthIndex) ? months[monthIndex] : ""
        return "\(components.day ?? 1) \(monthName) \(components.year ?? 1446)"
    }

    private var islamicQuote: String {
        islamicQuotes[viewModel.computedStreak % islamicQuotes.count]
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottomTrailing) {
                background

                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 24)

                        heartSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                            .offset(y: reduceMotion ? 0 : max(0, -scrollOffset) * 0.35)

                        if showRoadmapBanner {
                            roadmapGeneratingBanner
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                                .transition(.opacity)
                        }

                        habitsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 120)
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ScrollOffsetKey.self,
                                value: geo.frame(in: .named("homeScroll")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "homeScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }
                .scrollIndicators(.hidden)

                fabButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 16)
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Habit.self) { HabitDetailView(habit: $0) }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    fabGlow = true
                }
            }
            .refreshable { await reloadHome() }
            .task { await reloadHome() }
            .onChange(of: viewModel.habits) { _, newHabits in
                updateOrderedHabits(from: newHabits)
                applyPendingNotificationRouteIfNeeded()
            }
            .onChange(of: notificationService.pendingRoute) { _, _ in
                applyPendingNotificationRouteIfNeeded()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showNoorInfo) {
                NoorInfoSheet(streakDays: viewModel.computedStreak)
            }
            .sheet(isPresented: $showAddIntention) {
                AddPrivateIntentionSheet { newHabit, destination in
                    if let uid = auth.session?.user.id {
                        Task { await viewModel.loadAll(userId: uid) }
                    }
                    if destination == .detail {
                        navigationPath.append(newHabit)
                    }
                }
                .environment(auth)
            }
            .sheet(isPresented: $showEditLayout) {
                EditLayoutSheet(
                    shared: sharedHabits,
                    personal: personalHabits,
                    onSave: { newShared, newPersonal in
                        sharedHabits = newShared
                        personalHabits = newPersonal
                        saveSharedOrder()
                        savePersonalOrder()
                    },
                    onDelete: { habit in
                        await viewModel.deleteHabit(habit)
                        updateOrderedHabits(from: viewModel.habits)
                    }
                )
                .environment(auth)
            }
        }
        .overlay(alignment: .bottom) {
            if let undo = pendingUndo {
                HomeUndoToast(
                    habitName: undo.habit.name,
                    onUndo: { undoRecentCheckIn(undo.habit) }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 110)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: pendingUndo)
        .onDisappear { undoDismissTask?.cancel() }
    }

    private var background: some View {
        ZStack {
            Color.msBackgroundDeep.ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "253A28"), Color(hex: "1B261B"), Color.msBackgroundDeep.opacity(0)],
                center: UnitPoint(x: 0.5, y: 0.28),
                startRadius: 0,
                endRadius: 340
            )
            .ignoresSafeArea()
            GrainTexture()
        }
        .ignoresSafeArea()
    }

    private var headerSection: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("Assalamu Alaikum,")
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundStyle(Color.msTextMuted)

            Text(preferredName)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(Color.msTextPrimary)

            Text(todayFormatted)
                .font(.appCaption)
                .foregroundStyle(Color.msTextMuted.opacity(0.7))

            Text(hijriDateFormatted)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(Color.msGold.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var heartSection: some View {
        let days = viewModel.computedStreak
        let milestone = StreakMilestone.tier(for: days)
        let nextHint = StreakMilestone.nextTierHint(forDays: days)

        return VStack(spacing: 14) {
            Button { showNoorInfo = true } label: {
                StreakBeadView(
                    streakDays: days,
                    todayComplete: viewModel.allHabitsCompleted,
                    igniteTrigger: viewModel.beadIgniteCounter
                )
            }
            .buttonStyle(.plain)

            Text("\(days) Day Streak")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Color.msTextPrimary)

            Button { showNoorInfo = true } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 5) {
                        Text(milestone.caption)
                            .font(.system(size: 14, weight: .regular, design: .serif).italic())
                            .foregroundStyle(Color.msTextPrimary.opacity(0.70))
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.msTextMuted.opacity(0.55))
                    }

                    if let nextHint {
                        Text(nextHint)
                            .font(.system(size: 12, weight: .regular, design: .serif).italic())
                            .foregroundStyle(Color.msTextPrimary.opacity(0.55))
                    }
                }
            }
            .buttonStyle(.plain)

            Text(islamicQuote)
                .font(.system(size: 13, weight: .regular, design: .serif).italic())
                .foregroundStyle(Color.msTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 26) {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(Color.msGold)
                    Spacer()
                }
                .padding(.vertical, 32)
            } else if sharedHabits.isEmpty && personalHabits.isEmpty {
                emptyState
            } else {
                if !sharedHabits.isEmpty {
                    intentionsSection(
                        title: "Shared Intentions",
                        habits: sharedHabits,
                        showsEditButton: true
                    )
                }
                if !personalHabits.isEmpty {
                    intentionsSection(
                        title: "Personal Intentions",
                        habits: personalHabits,
                        showsEditButton: sharedHabits.isEmpty
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.msGold.opacity(0.55))
            Text("No intentions yet.")
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(Color.msTextPrimary)
            Text("Tap the gold button to add your first personal intention.")
                .font(.appCaption)
                .foregroundStyle(Color.msTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func intentionsSection(title: String, habits: [Habit], showsEditButton: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: title, showsEditButton: showsEditButton)

            VStack(spacing: 10) {
                ForEach(displayHabits(for: habits)) { habit in
                    IntentionCard(
                        habit: habit,
                        subtitle: subtitle(for: habit),
                        isCompleted: viewModel.isCompleted(habitId: habit.id),
                        onOpen: { navigationPath.append(habit) },
                        onCheckIn: { checkInHabit(habit) }
                    )
                }
            }
        }
    }

    private func sectionHeader(title: String, showsEditButton: Bool) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(Color.msTextPrimary)

            Spacer()

            if showsEditButton {
                Button { showEditLayout = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.msGold)
                        .frame(width: 32, height: 32)
                        .background(
                            SwiftUI.Circle()
                                .fill(Color.msGold.opacity(0.10))
                                .overlay(
                                    SwiftUI.Circle()
                                        .stroke(Color.msGold.opacity(0.28), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func displayHabits(for habits: [Habit]) -> [Habit] {
        let incomplete = habits.filter { !viewModel.isCompleted(habitId: $0.id) }
        let completed = habits.filter { viewModel.isCompleted(habitId: $0.id) }
        return incomplete + completed
    }

    private func subtitle(for habit: Habit) -> String {
        if let niyyah = habit.niyyah?.trimmingCharacters(in: .whitespacesAndNewlines), !niyyah.isEmpty {
            return niyyah
        }
        return viewModel.isCompleted(habitId: habit.id) ? "Completed today" : "Tap the check circle to mark it done"
    }

    private func updateOrderedHabits(from habits: [Habit]) {
        let shared = habits.filter { $0.isAccountable && $0.circleId != nil }
        let personal = habits.filter(\.isPersonal)
        sharedHabits = applyStoredOrder(shared, key: "circles_shared_order")
        personalHabits = applyStoredOrder(personal, key: "circles_personal_order")
    }

    private func applyStoredOrder(_ habits: [Habit], key: String) -> [Habit] {
        let saved = (UserDefaults.standard.array(forKey: key) as? [String])?
            .compactMap { UUID(uuidString: $0) } ?? []
        guard !saved.isEmpty else { return habits }

        let mapped = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
        let ordered = saved.compactMap { mapped[$0] }
        let unsaved = habits.filter { !saved.contains($0.id) }
        return ordered + unsaved
    }

    private func saveSharedOrder() {
        UserDefaults.standard.set(sharedHabits.map { $0.id.uuidString }, forKey: "circles_shared_order")
    }

    private func savePersonalOrder() {
        UserDefaults.standard.set(personalHabits.map { $0.id.uuidString }, forKey: "circles_personal_order")
    }

    private var fabButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            showAddIntention = true
        } label: {
            ZStack {
                SwiftUI.Circle()
                    .fill(Color.msGold.opacity(fabGlow ? 0.22 : 0.08))
                    .frame(width: 72, height: 72)
                    .blur(radius: fabGlow ? 12 : 5)

                SwiftUI.Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "F0CC6A"), Color(hex: "C08A1A")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.msGold.opacity(fabGlow ? 0.60 : 0.30), radius: fabGlow ? 22 : 10, x: 0, y: 4)

                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.msBackgroundDeep)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a personal intention")
    }

    private func reloadHome() async {
        guard let uid = auth.session?.user.id else { return }
        await viewModel.loadAll(userId: uid)
        await loadPreferredName(userId: uid)
        updateOrderedHabits(from: viewModel.habits)
        showRoadmapBanner = HabitPlanService.isRoadmapGenerating(userId: uid)
        applyPendingNotificationRouteIfNeeded()
    }

    private func loadPreferredName(userId: UUID) async {
        struct ProfileName: Decodable { let preferred_name: String? }

        let rows: [ProfileName] = (try? await SupabaseService.shared.client
            .from("profiles")
            .select("preferred_name")
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value) ?? []

        if let name = rows.first?.preferred_name, !name.isEmpty {
            preferredName = name
        }
    }

    private func checkInHabit(_ habit: Habit) {
        guard let userId = auth.session?.user.id else { return }
        guard !viewModel.isCompleted(habitId: habit.id) else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showUndoToast(for: habit)

        Task {
            await viewModel.toggleHabit(habit, userId: userId)
            if !viewModel.isCompleted(habitId: habit.id) {
                dismissUndoToast(ifMatches: habit.id)
            }
        }
    }

    private func undoRecentCheckIn(_ habit: Habit) {
        guard let userId = auth.session?.user.id else { return }
        dismissUndoToast(ifMatches: habit.id)

        Task {
            await viewModel.toggleHabit(habit, userId: userId)
        }
    }

    private func showUndoToast(for habit: Habit) {
        undoDismissTask?.cancel()
        pendingUndo = PendingUndo(habit: habit)
        undoDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                pendingUndo = nil
            }
        }
    }

    private func dismissUndoToast(ifMatches habitId: UUID? = nil) {
        undoDismissTask?.cancel()
        undoDismissTask = nil
        if habitId == nil || pendingUndo?.habit.id == habitId {
            pendingUndo = nil
        }
    }

    private func applyPendingNotificationRouteIfNeeded() {
        guard let route = notificationService.pendingRoute, route.tab == .home else { return }

        switch route.homeDestination {
        case .root:
            notificationService.updateCurrentRoute(.home)
            notificationService.consumePendingRoute()
        case .habitDetail:
            guard let habitId = route.habitId,
                  let habit = viewModel.habits.first(where: { $0.id == habitId }) else { return }

            navigationPath.append(habit)
            notificationService.updateCurrentRoute(route)
            notificationService.consumePendingRoute()
        }
    }

    private var roadmapGeneratingBanner: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Color.msGold).scaleEffect(0.85)
            VStack(alignment: .leading, spacing: 3) {
                Text("Building your 28-day roadmaps")
                    .font(.appCaptionMedium)
                    .foregroundStyle(Color.msTextPrimary)
                Text("Your personalized plans are generating in the background.")
                    .font(.appCaption)
                    .foregroundStyle(Color.msTextMuted)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.msCardShared)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.msGold.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

private struct HomeUndoToast: View {
    let habitName: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Checked in")
                    .font(.appCaptionMedium)
                    .foregroundStyle(Color.msGold)
                Text(habitName)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.msTextPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button("Undo", action: onUndo)
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(Color.msBackgroundDeep)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.msGold, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.msCardShared)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.msGold.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
    }
}

private struct IntentionCard: View {
    let habit: Habit
    let subtitle: String
    let isCompleted: Bool
    let onOpen: () -> Void
    let onCheckIn: () -> Void

    @State private var shimmerPhase: CGFloat = -0.5
    @State private var bloomOpacity: Double = 0
    @State private var bloomScale: CGFloat = 0.78

    private var iconName: String {
        habit.icon.isEmpty ? habitSymbol(for: habit.name) : habit.icon
    }

    private var surfaceColor: Color {
        if habit.isPersonal {
            return isCompleted ? Color.msCardWarmDone : Color.msCardWarm
        }
        return isCompleted ? Color.msCardDone : Color.msCardShared
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    iconBadge

                    VStack(alignment: .leading, spacing: 5) {
                        Text(habit.name)
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.msTextPrimary.opacity(isCompleted ? 0.95 : 1))
                            .lineLimit(2)

                        Text(subtitle)
                            .font(.appCaption)
                            .foregroundStyle(Color.msTextMuted.opacity(isCompleted ? 0.88 : 1))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.leading, 18)
                .padding(.vertical, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onCheckIn) {
                completionControl
            }
            .buttonStyle(.plain)
            .disabled(isCompleted)
            .padding(.horizontal, 18)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(isCompleted ? Color.msGold.opacity(0.48) : Color.msGold.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 16, x: 0, y: 8)
        .shadow(color: Color.msGold.opacity(isCompleted ? 0.16 : 0.05), radius: 18, x: 0, y: 8)
        .scaleEffect(isCompleted ? 0.985 : 1.0)
        .opacity(isCompleted ? 0.92 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: isCompleted)
        .onChange(of: isCompleted) { _, newValue in
            guard newValue else { return }
            shimmerPhase = -0.5
            bloomOpacity = 0.62
            bloomScale = 0.78
            withAnimation(.easeOut(duration: 1.25)) { shimmerPhase = 1.6 }
            withAnimation(.easeOut(duration: 0.9)) {
                bloomOpacity = 0
                bloomScale = 1.45
            }
        }
    }

    private var iconBadge: some View {
        ZStack {
            SwiftUI.Circle()
                .fill(Color.msGold.opacity(isCompleted ? 0.18 : 0.10))
                .frame(width: 52, height: 52)
            Image(systemName: iconName)
                .font(.system(size: 22))
                .foregroundStyle(Color.msGold.opacity(isCompleted ? 0.92 : 0.82))
                .shadow(color: Color.msGold.opacity(isCompleted ? 0.45 : 0.24), radius: 6)
        }
    }

    private var completionControl: some View {
        ZStack {
            SwiftUI.Circle()
                .fill(isCompleted ? Color.msGold : Color.clear)
                .frame(width: 52, height: 52)
                .overlay(
                    SwiftUI.Circle()
                        .stroke(isCompleted ? Color.msGold : Color.msGold.opacity(0.70), lineWidth: 2)
                )

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.msBackgroundDeep)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.msGold.opacity(0.90))
            }
        }
        .shadow(color: Color.msGold.opacity(isCompleted ? 0.32 : 0.12), radius: 10)
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 28)
                .fill(surfaceColor.opacity(0.92))

            LinearGradient(
                colors: [Color.msGold.opacity(0.10), .clear, .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))

            if isCompleted {
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: shimmerPhase - 0.22),
                                .init(color: .white.opacity(0.10), location: shimmerPhase),
                                .init(color: .clear, location: shimmerPhase + 0.22)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            RoundedRectangle(cornerRadius: 28)
                .fill(
                    RadialGradient(
                        colors: [Color.msGold.opacity(0.36), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 110
                    )
                )
                .scaleEffect(bloomScale)
                .opacity(bloomOpacity)
                .allowsHitTesting(false)

            CardGrain()
                .clipShape(RoundedRectangle(cornerRadius: 28))
        }
    }
}

private struct EditLayoutSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var shared: [Habit]
    @State private var personal: [Habit]

    let onSave: ([Habit], [Habit]) -> Void
    let onDelete: (Habit) async -> Void

    init(
        shared: [Habit],
        personal: [Habit],
        onSave: @escaping ([Habit], [Habit]) -> Void,
        onDelete: @escaping (Habit) async -> Void
    ) {
        _shared = State(initialValue: shared)
        _personal = State(initialValue: personal)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            List {
                if !shared.isEmpty {
                    Section {
                        ForEach(shared) { habit in
                            HStack(spacing: 12) {
                                if habit.id == shared.first?.id {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.msGold)
                                        .frame(width: 16)
                                } else {
                                    Color.clear.frame(width: 16)
                                }

                                Image(systemName: habitSymbol(for: habit.name))
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.msGold)
                                    .frame(width: 24)

                                Text(habit.name)
                                    .font(.system(size: 15, design: .serif))
                                    .foregroundStyle(Color.msTextPrimary)
                            }
                            .padding(.vertical, 4)
                        }
                        .onMove { shared.move(fromOffsets: $0, toOffset: $1) }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Shared Intentions")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.msTextMuted)
                            Text("Drag to reorder · first stays on top")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.msTextMuted.opacity(0.55))
                        }
                        .textCase(nil)
                    }
                }

                if !personal.isEmpty {
                    Section {
                        ForEach(personal) { habit in
                            HStack(spacing: 12) {
                                Image(systemName: habitSymbol(for: habit.name))
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.msTextMuted.opacity(0.65))
                                    .frame(width: 24)

                                Text(habit.name)
                                    .font(.system(size: 15, design: .serif))
                                    .foregroundStyle(Color.msTextPrimary)
                            }
                            .padding(.vertical, 4)
                        }
                        .onMove { personal.move(fromOffsets: $0, toOffset: $1) }
                        .onDelete { offsets in
                            let toRemove = offsets.map { personal[$0] }
                            personal.remove(atOffsets: offsets)
                            Task {
                                for habit in toRemove {
                                    await onDelete(habit)
                                }
                            }
                        }
                    } header: {
                        Text("Personal Intentions")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.msTextMuted)
                            .textCase(nil)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Color.msBackgroundDeep)
            .listStyle(.insetGrouped)
            .navigationTitle("Edit Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.msTextMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(shared, personal)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.msGold)
                }
            }
        }
        .background(Color.msBackgroundDeep)
    }
}

private func habitSymbol(for name: String) -> String {
    let normalized = name.lowercased()
    if normalized.contains("quran") || normalized.contains("qur") { return "book.fill" }
    if normalized.contains("salah") || normalized.contains("salat") || normalized.contains("prayer") { return "building.columns.fill" }
    if normalized.contains("dhikr") || normalized.contains("zikr") { return "circle.grid.3x3.fill" }
    if normalized.contains("fast") || normalized.contains("sawm") { return "moon.stars.fill" }
    if normalized.contains("sadaqah") || normalized.contains("charity") { return "hands.sparkles.fill" }
    if normalized.contains("tahajjud") || normalized.contains("night") { return "moon.fill" }
    return "leaf.fill"
}

#Preview {
    HomeView()
        .environment(AuthManager())
}
