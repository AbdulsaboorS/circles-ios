import SwiftUI
import Supabase
import UniformTypeIdentifiers

// MARK: - Midnight Sanctuary Color Tokens (HomeView scoped)

private extension Color {
    static let msBackgroundDeep = Color(hex: "131C14")   // layered base
    static let msBackground     = Color(hex: "1A2E1E")   // legacy compat
    static let msCardShared     = Color(hex: "243828")
    static let msCardPersonal   = Color(hex: "1E3122")
    static let msCardDone       = Color(hex: "2A4A30")   // shared done warmth
    static let msCardWarm       = Color(hex: "201C14")   // personal sanctuary
    static let msCardWarmDone   = Color(hex: "2E2410")   // personal done warmth
    static let msGold           = Color(hex: "D4A240")
    static let msTextPrimary    = Color(hex: "F0EAD6")
    static let msTextMuted      = Color(hex: "8FAF94")
    static let msBorder         = Color(hex: "D4A240").opacity(0.28)
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Islamic 8-Pointed Star (geometric border ring)

private struct IslamicStar: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * 0.44
        var path   = Path()
        for i in 0 ..< 16 {
            let angle = Double(i) * .pi / 8 - .pi / 2
            let r     = i.isMultiple(of: 2) ? outerR : innerR
            let pt    = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Grain Texture (tactile noise overlay)

private struct GrainTexture: View {
    // Pre-computed once — stable across redraws, no flickering
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

    // Drag-to-reorder — ordered habit arrays (sourced from viewModel + UserDefaults)
    @State private var sharedHabits: [Habit]   = []
    @State private var personalHabits: [Habit] = []
    @State private var draggingId: UUID?       = nil

    // Nudge
    @State private var nudgedIds: Set<UUID>    = []
    @State private var showMembersSheet        = false

    // Multi-layer heart animations (each on independent timing)
    @State private var bloomOpacity: Double  = 0.10
    @State private var bloomScale: CGFloat   = 1.0
    @State private var heartScale: CGFloat   = 1.0
    @State private var starAngle: Double     = 0

    // FAB pulse
    @State private var fabGlow = false

    // Placeholder presence shown while real data loads
    private static let fallbackPresence: [HomeViewModel.MemberPresence] = [
        HomeViewModel.MemberPresence(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Omar", initials: "OI",
            avatarColor: Color(hex: "4A7C59"), checkedInToday: false),
        HomeViewModel.MemberPresence(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Amir", initials: "AA",
            avatarColor: Color(hex: "5E9E72"), checkedInToday: false),
        HomeViewModel.MemberPresence(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "Khalid", initials: "KA",
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
        let streak = viewModel.streak?.currentStreak ?? 0
        return islamicQuotes[streak % islamicQuotes.count]
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottomTrailing) {

                // ── Living Background ─────────────────────────────────────
                ZStack {
                    Color.msBackgroundDeep.ignoresSafeArea()
                    // Radial warmth centered where the heart sits (~28% from top)
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
                            // Parallax: heart moves at 35% scroll speed
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
                // Outer bloom — 4s, independent timing
                withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                    bloomOpacity = 0.20
                    bloomScale   = 1.12
                }
                // Medallion — 3.5s, 0.4s offset for organic feel
                withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true).delay(0.4)) {
                    heartScale = 1.06
                }
                // Star — imperceptibly slow full rotation (2 min cycle)
                withAnimation(.linear(duration: 120).repeatForever(autoreverses: false)) {
                    starAngle = 360
                }
                // FAB glow
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
                MembersSheet(presence: presenceData, nudgedIds: $nudgedIds)
            }
        }
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

    // MARK: - Heart (Spiritual Centerpiece)

    private var heartSection: some View {
        VStack(spacing: 14) {
            ZStack {
                // Layer A — outer ambient bloom (own timing: 4s)
                SwiftUI.Circle()
                    .fill(Color.msGold.opacity(bloomOpacity))
                    .frame(width: 200, height: 200)
                    .blur(radius: 36)
                    .scaleEffect(bloomScale)

                // Layer B — Islamic star ring (slow rotation: 120s)
                IslamicStar()
                    .stroke(Color.msGold.opacity(0.20), lineWidth: 1)
                    .frame(width: 154, height: 154)
                    .rotationEffect(.degrees(starAngle))

                // Layer C — soft mid ring
                SwiftUI.Circle()
                    .fill(Color.msGold.opacity(0.07))
                    .frame(width: 132, height: 132)

                // Layer D — inner halo glow
                SwiftUI.Circle()
                    .fill(Color(hex: "EEC050").opacity(0.18))
                    .frame(width: 112, height: 112)
                    .blur(radius: 12)

                // Layer E — gold medallion (own timing: 3.5s, 0.4s delay)
                ZStack {
                    SwiftUI.Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "F5D080"), Color(hex: "D4A240"), Color(hex: "A8781A")],
                                center: UnitPoint(x: 0.35, y: 0.30),
                                startRadius: 0,
                                endRadius: 52
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: Color.msGold.opacity(0.60), radius: 26, x: 0, y: 8)
                        .shadow(color: Color.msGold.opacity(0.25), radius: 8,  x: 0, y: 2)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(.white.opacity(0.95))
                        .shadow(color: .white.opacity(0.30), radius: 6)
                }
                .scaleEffect(heartScale)
            }

            Text("\(viewModel.streak?.currentStreak ?? 0) Day Streak")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Color.msTextPrimary)

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
            Text("Complete onboarding to begin your journey.")
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
            Text("Shared Intentions")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.msTextPrimary)

            // Circle presence — real data or fallback placeholder
            let presenceData = viewModel.circlePresence.isEmpty
                ? Self.fallbackPresence
                : viewModel.circlePresence
            let checkedIn = viewModel.circlePresence.isEmpty ? 0 : viewModel.circleCheckedInCount

            CirclePresenceRow(
                presence: presenceData,
                checkedInCount: checkedIn,
                nudgedIds: $nudgedIds,
                onOpenSheet: { showMembersSheet = true }
            )

            // Hero = first habit in user's drag order
            if let hero = habits.first {
                HeroHabitCard(
                    habit: hero,
                    isCompleted: viewModel.isCompleted(habitId: hero.id),
                    onToggle: {
                        guard let uid = auth.session?.user.id else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task { await viewModel.toggleHabit(hero, userId: uid) }
                    }
                )
                let remaining = Array(habits.dropFirst())
                if !remaining.isEmpty { habitGrid(remaining) }
            }
        }
    }

    @ViewBuilder
    private func habitGrid(_ habits: [Habit]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(habits) { habit in
                NavigationLink(value: habit) {
                    SharedHabitCard(
                        habit: habit,
                        isCompleted: viewModel.isCompleted(habitId: habit.id),
                        onToggle: {
                            guard let uid = auth.session?.user.id else { return }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task { await viewModel.toggleHabit(habit, userId: uid) }
                        }
                    )
                }
                .buttonStyle(.plain)
                .opacity(draggingId == habit.id ? 0.5 : 1.0)
                .scaleEffect(draggingId == habit.id ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.18), value: draggingId)
                .onDrag {
                    draggingId = habit.id
                    return NSItemProvider(object: habit.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: HabitDropDelegate(
                    habit: habit,
                    habits: $sharedHabits,
                    draggingId: $draggingId,
                    onReorder: saveSharedOrder
                ))
            }
        }
    }

    // MARK: - Personal Section (sanctuary layout)

    private func personalSection(habits: [Habit]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Quiet label — whisper, not a title
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

            // Single-column list — intimate, not cramped grid
            VStack(spacing: 8) {
                ForEach(habits) { habit in
                    NavigationLink(value: habit) {
                        PersonalHabitCard(
                            habit: habit,
                            isCompleted: viewModel.isCompleted(habitId: habit.id),
                            onToggle: {
                                guard let uid = auth.session?.user.id else { return }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                Task { await viewModel.toggleHabit(habit, userId: uid) }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(draggingId == habit.id ? 0.5 : 1.0)
                    .scaleEffect(draggingId == habit.id ? 0.97 : 1.0)
                    .animation(.easeInOut(duration: 0.18), value: draggingId)
                    .onDrag {
                        draggingId = habit.id
                        return NSItemProvider(object: habit.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: HabitDropDelegate(
                        habit: habit,
                        habits: $personalHabits,
                        draggingId: $draggingId,
                        onReorder: savePersonalOrder
                    ))
                }
            }
        }
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
        let mapped   = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
        let ordered  = saved.compactMap { mapped[$0] }
        let unsaved  = habits.filter { !saved.contains($0.id) }
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
                Text("Invite 2 brothers/sisters to begin.")
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
    let onOpenSheet: () -> Void

    // Threshold: 4+ members → open sheet instead of inline tap
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            nudgedIds.insert(member.id)
                        }
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

                // "+N more" pill for large circles
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
                Text("\(checkedInCount) of \(presence.count) brothers checked in")
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

// MARK: - Hero Habit Card (prayer-time anchor)

private struct HeroHabitCard: View {
    let habit: Habit
    let isCompleted: Bool
    let onToggle: () -> Void

    @State private var borderGlow: Double = 0.45

    private var symbol: String { habitSymbol(for: habit.name) }

    var body: some View {
        HStack(spacing: 16) {
            // Left: layered icon + name + elegant "Now" beacon
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    // Bespoke layered icon: backing glow + symbol + inner shadow
                    ZStack {
                        SwiftUI.Circle()
                            .fill(Color.msGold.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: symbol)
                            .font(.system(size: 24))
                            .foregroundStyle(Color.msGold)
                            .shadow(color: Color.msGold.opacity(0.55), radius: 8)
                    }

                    Spacer()

                    // Crescent "Now" — elegant, not a blinking dot
                    HStack(spacing: 5) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.msGold)
                        Text("Now")
                            .font(.system(size: 11, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.msGold)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.msGold.opacity(0.10))
                            .overlay(Capsule().stroke(Color.msGold.opacity(borderGlow * 0.6), lineWidth: 0.5))
                    )
                }

                Text(habit.name)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                    .lineLimit(2)
            }

            // Right: check-in CTA
            Button(action: onToggle) {
                VStack(spacing: 4) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                    Text(isCompleted ? "Done" : "Check\nIn")
                        .font(.system(size: 9, weight: .semibold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(isCompleted ? Color.msBackgroundDeep : Color.msGold)
                .frame(width: 58, height: 58)
                .background(
                    SwiftUI.Circle()
                        .fill(isCompleted ? Color.msGold : Color.msGold.opacity(0.14))
                        .overlay(SwiftUI.Circle().stroke(Color.msGold.opacity(0.50), lineWidth: 1.5))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(
            ZStack {
                // Glass base — lets living background show through
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
                // Breathing border — the whole card is the beacon
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
    }
}

// MARK: - Shared Habit Card (grid)

private struct SharedHabitCard: View {
    let habit: Habit
    let isCompleted: Bool
    let onToggle: () -> Void

    @State private var shimmerPhase: CGFloat = -0.5

    private var symbol: String { habitSymbol(for: habit.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Layered icon: backing glow + symbol + inner shadow
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
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "ellipsis")
                    .font(.system(size: isCompleted ? 13 : 11))
                    .foregroundStyle(isCompleted ? Color.msGold : Color.msTextMuted)
            }

            Text(habit.name)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(Color.msTextPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            HStack {
                Spacer(minLength: 0)
                Button(action: onToggle) {
                    Text(isCompleted ? "Done ✓" : "Check In")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.msBackgroundDeep)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Capsule().fill(Color.msGold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                // Semi-glass: material base lets the living bg bleed through subtly
                RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24)
                    .fill((isCompleted ? Color.msCardDone : Color.msCardShared).opacity(0.78))
                // Persistent done warmth — candle-lit inner glow that stays
                if isCompleted {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            RadialGradient(
                                colors: [Color.msGold.opacity(0.12), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                }
                // One-shot shimmer on completion moment
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
                // Tighter 0.5pt gold-glow border
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isCompleted ? Color.msGold.opacity(0.55) : Color.msGold.opacity(0.22), lineWidth: 0.5)
            }
        )
        .shadow(color: Color.black.opacity(0.38), radius: 14, x: 0, y: 7)
        .onChange(of: isCompleted) { _, newValue in
            guard newValue else { return }
            shimmerPhase = -0.5
            withAnimation(.easeOut(duration: 1.4)) { shimmerPhase = 1.6 }
        }
    }
}

// MARK: - Personal Habit Card (horizontal sanctuary row)

private struct PersonalHabitCard: View {
    let habit: Habit
    let isCompleted: Bool
    let onToggle: () -> Void

    private var symbol: String { habitSymbol(for: habit.name) }

    var body: some View {
        HStack(spacing: 12) {
            // Layered icon — lower energy, signals secret deeds
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

            Button(action: onToggle) {
                HStack(spacing: 4) {
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    Text(isCompleted ? "Done" : "Check in")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(isCompleted ? Color.msGold : Color.msTextMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isCompleted ? Color.msCardWarmDone : Color.clear)
                        .overlay(Capsule().stroke(
                            isCompleted ? Color.msGold.opacity(0.55) : Color.msTextMuted.opacity(0.25),
                            lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isCompleted ? Color.msCardWarmDone : Color.msCardWarm)
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(isCompleted ? Color.msGold.opacity(0.22) : Color.msGold.opacity(0.06), lineWidth: 0.5))
        )
        .shadow(color: Color.black.opacity(0.18), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Drag-to-reorder Drop Delegate

private struct HabitDropDelegate: DropDelegate {
    let habit: Habit
    @Binding var habits: [Habit]
    @Binding var draggingId: UUID?
    let onReorder: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        onReorder()
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingId,
              draggingId != habit.id,
              let fromIndex = habits.firstIndex(where: { $0.id == draggingId }),
              let toIndex   = habits.firstIndex(where: { $0.id == habit.id })
        else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            habits.move(fromOffsets: IndexSet(integer: fromIndex),
                        toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Members Sheet (4+ circle members)

private struct MembersSheet: View {
    let presence: [HomeViewModel.MemberPresence]
    @Binding var nudgedIds: Set<UUID>
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
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        nudgedIds.insert(member.id)
                                    }
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
            .navigationTitle("Brothers")
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
