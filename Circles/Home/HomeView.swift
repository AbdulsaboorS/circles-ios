import SwiftUI
import Supabase

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Grain Texture (global background noise)

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

// MARK: - Card Grain (per-card sacred parchment texture)

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

// MARK: - Delete Confirmation Modal

private struct DeleteConfirmationModal: View {
    let habitName: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                ZStack {
                    SwiftUI.Circle()
                        .fill(Color.msGold.opacity(0.10))
                        .frame(width: 64, height: 64)
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.msGold.opacity(0.75))
                }
                .padding(.top, 28)
                .padding(.bottom, 16)

                Text("Remove Intention?")
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                    .padding(.bottom, 10)

                Text("Are you sure you want to remove\n\"\(habitName)\"\nfrom your sacred intentions?")
                    .font(.system(size: 14, design: .serif).italic())
                    .foregroundStyle(Color.msTextMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)

                Rectangle()
                    .fill(Color.msGold.opacity(0.15))
                    .frame(height: 0.5)

                HStack(spacing: 0) {
                    Button(action: onCancel) {
                        Text("Keep It")
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(Color.msTextMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(Color.msGold.opacity(0.15))
                        .frame(width: 0.5)

                    Button(action: onConfirm) {
                        Text("Remove")
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(Color(hex: "E05555"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.msCardShared)
                    .overlay(RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.msGold.opacity(0.30), lineWidth: 1))
            )
            .shadow(color: Color.black.opacity(0.55), radius: 40, x: 0, y: 20)
            .padding(.horizontal, 36)
        }
    }
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(AuthManager.self)                    private var auth
    @Environment(\.accessibilityReduceMotion)         private var reduceMotion

    @State private var viewModel          = HomeViewModel()
    @State private var preferredName      = "Friend"
    @State private var showAddIntention   = false
    @State private var navigationPath     = NavigationPath()
    @State private var showInviteNudge    = false
    @State private var showNudgeShare     = false
    @State private var nudgeInviteURL     = URL(string: "https://joinlegacy.app")!
    @State private var showRoadmapBanner  = false
    @State private var scrollOffset: CGFloat = 0

    // Edit layout sheet
    @State private var showEditLayout = false

    // Ordering
    @State private var sharedHabits: [Habit]   = []
    @State private var personalHabits: [Habit] = []

    // Toast
    @State private var toastVisible = false
    @State private var displayedToastMessage: String? = nil

    // Nudge
    @State private var nudgedIds: Set<UUID>    = []
    @State private var showMembersSheet        = false

    @State private var celebratingHabitId: UUID? = nil
    @State private var celebrationTask: Task<Void, Never>? = nil

    // FAB pulse
    @State private var fabGlow = false

    // Generic loading placeholders (no real names)
    private static let fallbackPresence: [HomeViewModel.MemberPresence] = [
        HomeViewModel.MemberPresence(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            circleId: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Member", initials: "M1",
            avatarColor: Color(hex: "4A7C59"), checkedInToday: false),
        HomeViewModel.MemberPresence(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            circleId: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            name: "Member", initials: "M2",
            avatarColor: Color(hex: "5E9E72"), checkedInToday: false),
        HomeViewModel.MemberPresence(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            circleId: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
            name: "Member", initials: "M3",
            avatarColor: Color(hex: "3D6B4F"), checkedInToday: false),
    ]

    private let islamicQuotes = [
        "\"Verily, in the remembrance of Allah do hearts find rest.\"",
        "\"Verily, with hardship comes ease.\"",
        "\"Allah is with the patient.\"",
        "\"The best of deeds are those done consistently.\"",
        "\"Whoever fears Allah, He will make a way out for him.\""
    ]

    private var todayFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    private var hijriDateFormatted: String {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.locale = Locale(identifier: "en_US")
        let c = cal.dateComponents([.day, .month, .year], from: Date())
        let months = ["Muharram","Safar","Rabi' al-Awwal","Rabi' al-Thani",
                      "Jumada al-Awwal","Jumada al-Thani","Rajab","Sha'ban",
                      "Ramadan","Shawwal","Dhu al-Qi'dah","Dhu al-Hijjah"]
        let idx  = (c.month ?? 1) - 1
        let name = (0 ..< months.count).contains(idx) ? months[idx] : ""
        return "\(c.day ?? 1) \(name) \(c.year ?? 1446)"
    }

    private var islamicQuote: String {
        islamicQuotes[viewModel.computedStreak % islamicQuotes.count]
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottomTrailing) {

                // ── Living Background ─────────────────────────────────────
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

                // ── Scrollable Content ────────────────────────────────────
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
                                .padding(.bottom, 12)
                                .transition(.opacity)
                        }

                        if showInviteNudge {
                            inviteNudgeBanner
                                .padding(.bottom, 20)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        habitsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
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
            .refreshable {
                guard let uid = auth.session?.user.id else { return }
                await viewModel.loadAll(userId: uid)
                await loadPreferredName(userId: uid)
                updateOrderedHabits(from: viewModel.habits)
                showRoadmapBanner = HabitPlanService.isRoadmapGenerating(userId: uid)
            }
            .task {
                guard let uid = auth.session?.user.id else { return }
                await viewModel.loadAll(userId: uid)
                await loadPreferredName(userId: uid)
                await loadNudgeState(userId: uid)
                updateOrderedHabits(from: viewModel.habits)
                showRoadmapBanner = HabitPlanService.isRoadmapGenerating(userId: uid)
            }
            .onChange(of: viewModel.habits) { _, newHabits in
                updateOrderedHabits(from: newHabits)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onChange(of: viewModel.toastMessage) { _, newMsg in
                guard let msg = newMsg else { return }
                displayedToastMessage = msg
                viewModel.toastMessage = nil
                withAnimation(.spring(response: 0.4)) { toastVisible = true }
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation(.easeOut(duration: 0.3)) { toastVisible = false }
                }
            }
            .sheet(isPresented: $showAddIntention) {
                AddPrivateIntentionSheet { newHabit in
                    if let uid = auth.session?.user.id {
                        Task { await viewModel.loadAll(userId: uid) }
                    }
                    navigationPath.append(newHabit)
                }
                .environment(auth)
            }
            .sheet(isPresented: $showMembersSheet) {
                let presenceData = viewModel.circlePresence.isEmpty
                    ? Self.fallbackPresence : viewModel.circlePresence
                MembersSheet(
                    presence: presenceData,
                    nudgedIds: $nudgedIds,
                    onNudge: sendPresenceNudge
                )
            }
            .sheet(isPresented: $showEditLayout) {
                EditLayoutSheet(
                    shared: sharedHabits,
                    personal: personalHabits,
                    onSave: { newShared, newPersonal in
                        sharedHabits   = newShared
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
            if toastVisible, let msg = displayedToastMessage {
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.msTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.msCardShared)
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.msGold.opacity(0.40), lineWidth: 1))
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 6)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 110)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.4), value: toastVisible)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("Assalamu Alaikum,")
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundStyle(Color.msTextMuted)

            Text(preferredName)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(Color.msTextPrimary)

            Text(todayFormatted)
                .font(.system(size: 13))
                .foregroundStyle(Color.msTextMuted.opacity(0.7))

            Text(hijriDateFormatted)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(Color.msGold.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    // MARK: - Noor Bead (Spiritual Centerpiece)

    private var heartSection: some View {
        let days = viewModel.computedStreak
        let milestone = StreakMilestone.tier(for: days)
        let nextHint = StreakMilestone.nextTierHint(forDays: days)

        return VStack(spacing: 14) {
            StreakBeadView(
                streakDays: days,
                todayComplete: viewModel.allHabitsCompleted,
                igniteTrigger: viewModel.beadIgniteCounter
            )

            Text("\(days) Day Streak")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Color.msTextPrimary)

            VStack(spacing: 4) {
                Text(milestone.caption)
                    .font(.system(size: 14, weight: .regular, design: .serif).italic())
                    .foregroundStyle(Color.msTextPrimary.opacity(0.70))

                if let nextHint {
                    Text(nextHint)
                        .font(.system(size: 12, weight: .regular, design: .serif).italic())
                        .foregroundStyle(Color.msTextPrimary.opacity(0.55))
                }
            }

            Text(islamicQuote)
                .font(.system(size: 13, weight: .regular, design: .serif).italic())
                .foregroundStyle(Color.msTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Habits

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            if viewModel.isLoading {
                HStack { Spacer(); ProgressView().tint(Color.msGold); Spacer() }
                    .padding(.vertical, 32)
            } else if sharedHabits.isEmpty && personalHabits.isEmpty {
                emptyState
            } else {
                if !sharedHabits.isEmpty   { sharedSection(habits: sharedHabits) }
                if !personalHabits.isEmpty { personalSection(habits: personalHabits) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.msGold.opacity(0.55))
            Text("No intentions yet.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.msTextPrimary)
            Text("Tap + to add your first intention.")
                .font(.system(size: 13))
                .foregroundStyle(Color.msTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    // MARK: - Shared Section (hero + presence + grid)

    private func sharedSection(habits: [Habit]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Shared Intentions")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.msTextPrimary)
                Spacer()
                Button { showEditLayout = true } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.msGold.opacity(0.75))
                        .frame(width: 30, height: 30)
                        .background(
                            SwiftUI.Circle()
                                .fill(Color.msGold.opacity(0.10))
                                .overlay(SwiftUI.Circle().stroke(Color.msGold.opacity(0.28), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }

            let presenceData = viewModel.circlePresence.isEmpty
                ? Self.fallbackPresence
                : viewModel.circlePresence
            let checkedIn = viewModel.circlePresence.isEmpty ? 0 : viewModel.circleCheckedInCount

            CirclePresenceRow(
                presence: presenceData,
                checkedInCount: checkedIn,
                nudgedIds: $nudgedIds,
                onNudge: sendPresenceNudge,
                onOpenSheet: { showMembersSheet = true }
            )

            if let hero = habits.first {
                NavigationLink(value: hero) {
                    HeroHabitCard(
                        habit: hero,
                        isCompleted: viewModel.isCompleted(habitId: hero.id),
                        onToggle: { handleHabitToggle(hero) }
                    )
                    .overlay {
                        if celebratingHabitId == hero.id {
                            HamdulillahOverlay()
                        }
                    }
                }
                .buttonStyle(.plain)

                let remaining = Array(habits.dropFirst())
                if !remaining.isEmpty { habitGrid(remaining) }
            }
        }
    }

    @ViewBuilder
    private func habitGrid(_ habits: [Habit]) -> some View {
        // Pending first, completed last — gives "UI clears up" reward as day progresses
        let sorted = habits.sorted { a, b in
            let aDone = viewModel.isCompleted(habitId: a.id)
            let bDone = viewModel.isCompleted(habitId: b.id)
            if aDone == bDone { return false }
            return !aDone
        }
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(sorted) { habit in
                SharedHabitCard(
                    habit: habit,
                    isCompleted: viewModel.isCompleted(habitId: habit.id),
                    onToggle: { handleHabitToggle(habit) }
                )
                .overlay {
                    if celebratingHabitId == habit.id {
                        HamdulillahOverlay()
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { navigationPath.append(habit) }
            }
        }
    }

    // MARK: - Personal Section

    private func personalSection(habits: [Habit]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Rectangle()
                    .fill(Color.msGold.opacity(0.08))
                    .frame(height: 0.5)
                Text("Personal Intentions")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.msTextMuted.opacity(0.50))
                    .fixedSize()
                Rectangle()
                    .fill(Color.msGold.opacity(0.08))
                    .frame(height: 0.5)
            }
            .padding(.bottom, 2)

            VStack(spacing: 8) {
                ForEach(habits) { habit in
                    PersonalHabitCard(
                        habit: habit,
                        isCompleted: viewModel.isCompleted(habitId: habit.id),
                        onToggle: { handleHabitToggle(habit) }
                    )
                    .overlay {
                        if celebratingHabitId == habit.id {
                            HamdulillahOverlay()
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { navigationPath.append(habit) }
                }
            }
        }
    }

    // MARK: - Check-off Micro-moment

    /// Drives the Hamdulillah overlay + subtle haptic only on the
    /// incomplete → complete transition. Undo (complete → incomplete)
    /// runs the toggle plainly, no animation, no haptic.
    private func handleHabitToggle(_ habit: Habit) {
        guard let uid = auth.session?.user.id else { return }
        let wasCompleted = viewModel.isCompleted(habitId: habit.id)

        if !wasCompleted {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            celebrationTask?.cancel()
            celebratingHabitId = habit.id
            celebrationTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1500))
                guard !Task.isCancelled else { return }
                if celebratingHabitId == habit.id {
                    celebratingHabitId = nil
                }
            }
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        Task { await viewModel.toggleHabit(habit, userId: uid) }
    }

    // MARK: - Habit Ordering

    private func updateOrderedHabits(from habits: [Habit]) {
        let shared   = habits.filter { $0.isAccountable && $0.circleId != nil }
        let personal = habits.filter { !$0.isAccountable || $0.circleId == nil }
        sharedHabits   = applyStoredOrder(shared,   key: "circles_shared_order")
        personalHabits = applyStoredOrder(personal, key: "circles_personal_order")
    }

    private func applyStoredOrder(_ habits: [Habit], key: String) -> [Habit] {
        let saved = (UserDefaults.standard.array(forKey: key) as? [String])?
            .compactMap { UUID(uuidString: $0) } ?? []
        guard !saved.isEmpty else { return habits }
        let mapped  = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
        let ordered = saved.compactMap { mapped[$0] }
        let unsaved = habits.filter { !saved.contains($0.id) }
        return ordered + unsaved
    }

    private func saveSharedOrder() {
        UserDefaults.standard.set(sharedHabits.map { $0.id.uuidString },
                                  forKey: "circles_shared_order")
    }

    private func savePersonalOrder() {
        UserDefaults.standard.set(personalHabits.map { $0.id.uuidString },
                                  forKey: "circles_personal_order")
    }

    // MARK: - FAB

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
                    .fill(LinearGradient(
                        colors: [Color(hex: "F0CC6A"), Color(hex: "C08A1A")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.msGold.opacity(fabGlow ? 0.60 : 0.30),
                            radius: fabGlow ? 22 : 10, x: 0, y: 4)

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.msBackgroundDeep)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data loading

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

    private func loadNudgeState(userId: UUID) async {
        let shouldShow  = UserDefaults.standard.bool(forKey: "should_show_invite_nudge_\(userId.uuidString)")
        let isDismissed = UserDefaults.standard.bool(forKey: "invite_nudge_dismissed_\(userId.uuidString)")
        guard shouldShow && !isDismissed else { return }
        showInviteNudge = true
        if let circles = try? await CircleService.shared.fetchMyCircles(userId: userId),
           let owned = circles.first, let code = owned.inviteCode {
            nudgeInviteURL = URL(string: "circles://join/\(code)") ?? URL(string: "https://joinlegacy.app")!
        }
    }

    private func sendPresenceNudge(_ member: HomeViewModel.MemberPresence) {
        guard let senderId = auth.session?.user.id else { return }
        guard !nudgedIds.contains(member.id) else { return }

        Task {
            do {
                let sentCount = try await NudgeService.shared.sendDirectNudge(
                    circleId: member.circleId,
                    senderId: senderId,
                    targetUserId: member.id,
                    nudgeType: "habit_reminder"
                )
                guard sentCount > 0 else { return }
                _ = withAnimation(.easeInOut(duration: 0.2)) {
                    nudgedIds.insert(member.id)
                }
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Invite Nudge Banner

    private var inviteNudgeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 20))
                .foregroundStyle(Color.msGold)

            VStack(alignment: .leading, spacing: 4) {
                Text("Activate your group streak")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.msTextPrimary)
                Text("Invite your circle to activate the group streak.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.msTextMuted)
            }
            Spacer()

            Button { showNudgeShare = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.msBackgroundDeep)
                    .frame(width: 34, height: 34)
                    .background(Color.msGold, in: SwiftUI.Circle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showNudgeShare) {
                ShareSheet(url: nudgeInviteURL)
                    .presentationDetents([.medium, .large])
            }

            Button {
                withAnimation { showInviteNudge = false }
                if let uid = auth.session?.user.id {
                    UserDefaults.standard.set(true, forKey: "invite_nudge_dismissed_\(uid.uuidString)")
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.msTextMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.msCardShared)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.msGold.opacity(0.4), lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Roadmap Generating Banner

    private var roadmapGeneratingBanner: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Color.msGold).scaleEffect(0.85)
            VStack(alignment: .leading, spacing: 3) {
                Text("Building your 28-day roadmaps")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.msTextPrimary)
                Text("Your personalized plans are generating in the background.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.msTextMuted)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.msCardShared)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.msGold.opacity(0.25), lineWidth: 1))
        )
    }
}

// MARK: - Circle Presence Row

private struct CirclePresenceRow: View {
    let presence: [HomeViewModel.MemberPresence]
    let checkedInCount: Int
    @Binding var nudgedIds: Set<UUID>
    let onNudge: (HomeViewModel.MemberPresence) -> Void
    let onOpenSheet: () -> Void

    private var usesSheet: Bool { presence.count >= 4 }
    private var displayedMembers: [HomeViewModel.MemberPresence] {
        usesSheet ? Array(presence.prefix(3)) : Array(presence.prefix(5))
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                ForEach(displayedMembers) { member in
                    Button {
                        guard !usesSheet else { return }
                        guard !nudgedIds.contains(member.id) else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onNudge(member)
                    } label: {
                        VStack(spacing: 5) {
                            ZStack {
                                SwiftUI.Circle().fill(member.avatarColor)
                                Text(member.initials)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                if nudgedIds.contains(member.id) {
                                    SwiftUI.Circle()
                                        .fill(Color.msGold)
                                        .frame(width: 10, height: 10)
                                        .overlay(
                                            Text("✓")
                                                .font(.system(size: 6, weight: .bold))
                                                .foregroundStyle(Color.msBackgroundDeep)
                                        )
                                        .offset(x: 12, y: -12)
                                }
                            }
                            .frame(width: 36, height: 36)
                            .overlay(
                                SwiftUI.Circle()
                                    .strokeBorder(
                                        member.checkedInToday ? Color.msGold : Color.msTextMuted.opacity(0.28),
                                        style: StrokeStyle(
                                            lineWidth: member.checkedInToday ? 2 : 1,
                                            dash: member.checkedInToday ? [] : [3, 2]
                                        )
                                    )
                            )
                            .shadow(color: member.checkedInToday ? Color.msGold.opacity(0.40) : .clear, radius: 6)

                            Text(member.name.split(separator: " ").first.map(String.init) ?? member.name)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.msTextMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }

                if usesSheet {
                    let extra = presence.count - 3
                    Button(action: onOpenSheet) {
                        VStack(spacing: 5) {
                            ZStack {
                                SwiftUI.Circle().fill(Color.msCardShared)
                                Text("+\(extra)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.msGold)
                            }
                            .frame(width: 36, height: 36)
                            .overlay(SwiftUI.Circle().strokeBorder(Color.msGold.opacity(0.35),
                                                                   style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                            Text("more")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.msTextMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("\(checkedInCount) of \(presence.count) members checked in")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.msTextMuted)
                Spacer()
                if usesSheet {
                    Button(action: onOpenSheet) {
                        Text("Nudge")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.msGold.opacity(0.75))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(
                                Capsule().fill(Color.msGold.opacity(0.10))
                                    .overlay(Capsule().stroke(Color.msGold.opacity(0.40), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                } else if checkedInCount < presence.count {
                    Text("Tap a name to nudge")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.msGold.opacity(0.50))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.msCardShared.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.msBorder, lineWidth: 1))
        )
    }
}

// MARK: - Hero Habit Card

private struct HeroHabitCard: View {
    let habit: Habit
    let isCompleted: Bool
    let onToggle: () -> Void

    @State private var borderGlow: Double = 0.45
    @State private var shimmerPhase: CGFloat = -0.5
    @State private var bloomOpacity: Double = 0
    @State private var bloomScale: CGFloat = 0.8

    private var symbol: String { habitSymbol(for: habit.name) }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    SwiftUI.Circle()
                        .fill(Color.msGold.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: symbol)
                        .font(.system(size: 24))
                        .foregroundStyle(Color.msGold)
                        .shadow(color: Color.msGold.opacity(0.55), radius: 8)
                }

                Text(habit.name)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                    .lineLimit(2)
            }

            Spacer()

            // Check-in / done CTA — checkmark IS the undo trigger
            Button(action: onToggle) {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(Color.msGold.opacity(0.80))
                        .frame(width: 58, height: 58)
                        .shadow(color: Color.msGold.opacity(0.45), radius: 10)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "circle")
                            .font(.system(size: 22))
                        Text("Check\nIn")
                            .font(.system(size: 9, weight: .semibold))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Color.msGold)
                    .frame(width: 58, height: 58)
                    .background(
                        SwiftUI.Circle()
                            .fill(Color.msGold.opacity(0.14))
                            .overlay(SwiftUI.Circle().stroke(Color.msGold.opacity(0.50), lineWidth: 1.5))
                    )
                }
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.35), value: isCompleted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 28).fill(Color(hex: "243828").opacity(0.72))
                // Noor source — gold radial from top-leading
                RadialGradient(
                    colors: [Color.msGold.opacity(0.13), Color.clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 180
                )
                .clipShape(RoundedRectangle(cornerRadius: 28))
                // One-shot completion shimmer
                if isCompleted {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear,               location: shimmerPhase - 0.25),
                                .init(color: .white.opacity(0.11), location: shimmerPhase),
                                .init(color: .clear,               location: shimmerPhase + 0.25)
                            ]),
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                // Gold bloom pulse
                RoundedRectangle(cornerRadius: 28)
                    .fill(RadialGradient(
                        colors: [Color.msGold.opacity(0.42), Color.clear],
                        center: .center, startRadius: 0, endRadius: 130
                    ))
                    .scaleEffect(bloomScale)
                    .opacity(bloomOpacity)
                    .allowsHitTesting(false)
                // Grain texture
                CardGrain().clipShape(RoundedRectangle(cornerRadius: 28))
                // Inner shadow
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.black.opacity(0.40), lineWidth: 10)
                    .blur(radius: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .allowsHitTesting(false)
                // Breathing border
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.msGold.opacity(borderGlow), lineWidth: 1.5)
            }
        )
        .shadow(color: Color.msGold.opacity(borderGlow * 0.3), radius: 20, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                borderGlow = 0.88
            }
        }
        .onChange(of: isCompleted) { _, newValue in
            guard newValue else { return }
            shimmerPhase = -0.5
            bloomOpacity = 0.65
            bloomScale   = 0.75
            withAnimation(.easeOut(duration: 1.5)) { shimmerPhase = 1.7 }
            withAnimation(.easeOut(duration: 0.9)) {
                bloomOpacity = 0
                bloomScale   = 1.55
            }
        }
    }
}

// MARK: - Shared Habit Card (grid)

private struct SharedHabitCard: View {
    let habit: Habit
    let isCompleted: Bool
    let onToggle: () -> Void

    @State private var shimmerPhase: CGFloat = -0.5
    @State private var bloomOpacity: Double  = 0
    @State private var bloomScale: CGFloat   = 0.8

    private var symbol: String { habitSymbol(for: habit.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    SwiftUI.Circle()
                        .fill(Color.msGold.opacity(0.10))
                        .frame(width: 34, height: 34)
                    Image(systemName: symbol)
                        .font(.system(size: 16))
                        .foregroundStyle(isCompleted ? Color.msGold : Color.msGold.opacity(0.75))
                        .shadow(color: Color.msGold.opacity(isCompleted ? 0.55 : 0.30), radius: 5)
                }
                Spacer()
                // Checkmark IS the undo trigger when completed
                if isCompleted {
                    Button(action: onToggle) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.msGold.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.msTextMuted)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.35), value: isCompleted)

            Text(habit.name)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(Color.msTextPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            // Check In button only when pending — completed state is clean
            if !isCompleted {
                HStack {
                    Spacer(minLength: 0)
                    Button(action: onToggle) {
                        Text("Check In")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.msBackgroundDeep)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(Capsule().fill(Color.msGold))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35), value: isCompleted)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24)
                    .fill((isCompleted ? Color.msCardDone : Color.msCardShared).opacity(0.78))
                if isCompleted {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(RadialGradient(
                            colors: [Color.msGold.opacity(0.12), Color.clear],
                            center: .center,
                            startRadius: 0, endRadius: 80
                        ))
                }
                // One-shot shimmer on completion
                if isCompleted {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear,               location: shimmerPhase - 0.25),
                                .init(color: .white.opacity(0.09), location: shimmerPhase),
                                .init(color: .clear,               location: shimmerPhase + 0.25)
                            ]),
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                // Gold bloom pulse
                RoundedRectangle(cornerRadius: 24)
                    .fill(RadialGradient(
                        colors: [Color.msGold.opacity(0.38), Color.clear],
                        center: .center, startRadius: 0, endRadius: 90
                    ))
                    .scaleEffect(bloomScale)
                    .opacity(bloomOpacity)
                    .allowsHitTesting(false)
                // Grain — sacred parchment
                CardGrain().clipShape(RoundedRectangle(cornerRadius: 24))
                // Inner shadow — carved depth
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.black.opacity(0.35), lineWidth: 8)
                    .blur(radius: 6)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .allowsHitTesting(false)
                // Border
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isCompleted ? Color.msGold.opacity(0.55) : Color.msGold.opacity(0.22), lineWidth: 0.5)
            }
        )
        .shadow(color: Color.black.opacity(0.38), radius: 14, x: 0, y: 7)
        .onChange(of: isCompleted) { _, newValue in
            guard newValue else { return }
            shimmerPhase = -0.5
            bloomOpacity  = 0.65
            bloomScale    = 0.75
            withAnimation(.easeOut(duration: 1.4)) { shimmerPhase = 1.6 }
            withAnimation(.easeOut(duration: 0.85)) {
                bloomOpacity = 0
                bloomScale   = 1.45
            }
        }
    }
}

// MARK: - Personal Habit Card (sanctuary row)

private struct PersonalHabitCard: View {
    let habit: Habit
    let isCompleted: Bool
    let onToggle: () -> Void

    @State private var shimmerPhase: CGFloat = -0.5

    private var symbol: String { habitSymbol(for: habit.name) }

    var body: some View {
        HStack(spacing: 12) {
                ZStack {
                    SwiftUI.Circle()
                        .fill(isCompleted ? Color.msGold.opacity(0.08) : Color.msTextMuted.opacity(0.06))
                        .frame(width: 34, height: 34)
                    Image(systemName: symbol)
                        .font(.system(size: 17))
                        .foregroundStyle(isCompleted ? Color.msGold.opacity(0.70) : Color.msTextMuted.opacity(0.45))
                }
                .frame(width: 34)

                Text(habit.name)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.msTextPrimary.opacity(isCompleted ? 1.0 : 0.85))
                    .lineLimit(2)

                Spacer()

                // Checkmark IS the undo trigger when completed
                Button(action: onToggle) {
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.msGold.opacity(0.70))
                    } else {
                        Text("Check in")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.msTextMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(Color.clear)
                                    .overlay(Capsule().stroke(Color.msTextMuted.opacity(0.25), lineWidth: 1))
                            )
                    }
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.35), value: isCompleted)
            }
            .padding(.horizontal, 16)
            .frame(height: 58)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isCompleted ? Color.msCardWarmDone : Color.msCardWarm)
                        .overlay(RoundedRectangle(cornerRadius: 20)
                            .stroke(isCompleted ? Color.msGold.opacity(0.22) : Color.msGold.opacity(0.06), lineWidth: 0.5))
                    // Grain
                    CardGrain().clipShape(RoundedRectangle(cornerRadius: 20))
                    // Inner shadow
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.30), lineWidth: 6)
                        .blur(radius: 5)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .allowsHitTesting(false)
                    // Completion shimmer
                    if isCompleted {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear,               location: shimmerPhase - 0.30),
                                    .init(color: .white.opacity(0.07), location: shimmerPhase),
                                    .init(color: .clear,               location: shimmerPhase + 0.30)
                                ]),
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
            )
            .shadow(color: Color.black.opacity(0.18), radius: 5, x: 0, y: 2)
        .onChange(of: isCompleted) { _, newValue in
            guard newValue else { return }
            shimmerPhase = -0.5
            withAnimation(.easeOut(duration: 1.2)) { shimmerPhase = 1.7 }
        }
    }
}


// MARK: - Edit Layout Sheet

private struct EditLayoutSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var shared:   [Habit]
    @State private var personal: [Habit]

    let onSave:   ([Habit], [Habit]) -> Void
    let onDelete: (Habit) async -> Void

    init(
        shared: [Habit],
        personal: [Habit],
        onSave: @escaping ([Habit], [Habit]) -> Void,
        onDelete: @escaping (Habit) async -> Void
    ) {
        _shared   = State(initialValue: shared)
        _personal = State(initialValue: personal)
        self.onSave   = onSave
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
                            Text("Drag to reorder · first becomes lead")
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
                                for h in toRemove { await onDelete(h) }
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

// MARK: - Members Sheet

private struct MembersSheet: View {
    let presence: [HomeViewModel.MemberPresence]
    @Binding var nudgedIds: Set<UUID>
    let onNudge: (HomeViewModel.MemberPresence) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackgroundDeep.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(presence) { member in
                            HStack(spacing: 14) {
                                ZStack {
                                    SwiftUI.Circle().fill(member.avatarColor)
                                    Text(member.initials)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 44, height: 44)
                                .overlay(
                                    SwiftUI.Circle().strokeBorder(
                                        member.checkedInToday ? Color.msGold : Color.msTextMuted.opacity(0.3),
                                        lineWidth: member.checkedInToday ? 2 : 1
                                    )
                                )
                                .shadow(color: member.checkedInToday ? Color.msGold.opacity(0.35) : .clear, radius: 6)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(member.name)
                                        .font(.system(size: 15, weight: .semibold, design: .serif))
                                        .foregroundStyle(Color.msTextPrimary)
                                    Text(member.checkedInToday ? "Checked in today ✓" : "Not yet checked in")
                                        .font(.system(size: 12))
                                        .foregroundStyle(member.checkedInToday
                                            ? Color.msGold.opacity(0.80) : Color.msTextMuted)
                                }

                                Spacer()

                                Button {
                                    guard !nudgedIds.contains(member.id) else { return }
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    onNudge(member)
                                } label: {
                                    Text(nudgedIds.contains(member.id) ? "Sent ✓" : "Nudge")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(nudgedIds.contains(member.id)
                                            ? Color.msGold : Color.msGold.opacity(0.80))
                                        .padding(.horizontal, 14).padding(.vertical, 7)
                                        .background(
                                            Capsule()
                                                .fill(Color.msGold.opacity(nudgedIds.contains(member.id) ? 0.20 : 0.10))
                                                .overlay(Capsule().stroke(Color.msGold.opacity(0.40), lineWidth: 1))
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(nudgedIds.contains(member.id))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)

                            if member.id != presence.last?.id {
                                Rectangle()
                                    .fill(Color.msGold.opacity(0.08))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Your Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.msBackgroundDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.msGold)
                }
            }
        }
    }
}

// MARK: - Habit symbol helper

private func habitSymbol(for name: String) -> String {
    let n = name.lowercased()
    if n.contains("quran")   || n.contains("qur")                           { return "book.fill" }
    if n.contains("salah")   || n.contains("salat") || n.contains("prayer") { return "building.columns.fill" }
    if n.contains("dhikr")   || n.contains("zikr")                          { return "circle.grid.3x3.fill" }
    if n.contains("fast")    || n.contains("sawm")                          { return "moon.stars.fill" }
    if n.contains("sadaqah") || n.contains("charity")                       { return "hands.sparkles.fill" }
    if n.contains("tahajjud") || n.contains("night")                        { return "moon.fill" }
    return "leaf.fill"
}

// MARK: - Preview

#Preview {
    HomeView()
        .environment(AuthManager())
}
