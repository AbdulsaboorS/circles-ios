import SwiftUI
import Supabase

// MARK: - Midnight Sanctuary Color Tokens (HomeView scoped)

private extension Color {
    static let msBackground   = Color(hex: "1A2E1E")
    static let msCardShared   = Color(hex: "243828")
    static let msCardPersonal = Color(hex: "1E3122")
    static let msCardDone     = Color(hex: "2A4A30")   // satisfied / completed warmth
    static let msGold         = Color(hex: "D4A240")
    static let msTextPrimary  = Color(hex: "F0EAD6")
    static let msTextMuted    = Color(hex: "8FAF94")
    static let msBorder       = Color(hex: "D4A240").opacity(0.28)
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
        let points = 8
        var path = Path()
        for i in 0 ..< (points * 2) {
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let pt = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(AuthManager.self)                   private var auth
    @Environment(\.accessibilityReduceMotion)        private var reduceMotion

    @State private var viewModel         = HomeViewModel()
    @State private var preferredName     = "Friend"
    @State private var showAddIntention  = false
    @State private var navigationPath   = NavigationPath()
    @State private var showInviteNudge  = false
    @State private var showNudgeShare   = false
    @State private var nudgeInviteURL   = URL(string: "https://joinlegacy.app")!
    @State private var showRoadmapBanner = false
    @State private var breathe          = false
    @State private var fabGlow          = false
    @State private var scrollOffset: CGFloat = 0
    @State private var nudgeSent        = false

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
        let comps = cal.dateComponents([.day, .month, .year], from: Date())
        let monthNames = [
            "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
            "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
            "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"
        ]
        let idx = (comps.month ?? 1) - 1
        let name = (0 ..< monthNames.count).contains(idx) ? monthNames[idx] : ""
        return "\(comps.day ?? 1) \(name) \(comps.year ?? 1446)"
    }

    private var islamicQuote: String {
        let streak = viewModel.streak?.currentStreak ?? 0
        return islamicQuotes[streak % islamicQuotes.count]
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottomTrailing) {
                Color.msBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 24)

                        heartSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                            // Parallax: heart moves at 35% scroll speed (lags behind cards)
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
                    // Capture scroll offset for parallax
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
                withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { breathe = true }
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { fabGlow = true }
            }
            .refreshable {
                guard let uid = auth.session?.user.id else { return }
                await viewModel.loadAll(userId: uid)
                await loadPreferredName(userId: uid)
                showRoadmapBanner = RoadmapGenerationFlag.isActive(userId: uid)
            }
            .task {
                guard let uid = auth.session?.user.id else { return }
                await viewModel.loadAll(userId: uid)
                await loadPreferredName(userId: uid)
                await loadNudgeState(userId: uid)
                showRoadmapBanner = RoadmapGenerationFlag.isActive(userId: uid)
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
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
    }

    // MARK: - Heart (Centerpiece)

    private var heartSection: some View {
        VStack(spacing: 14) {
            ZStack {
                // Outer ambient bloom — breathes in sync with heart
                SwiftUI.Circle()
                    .fill(Color.msGold.opacity(breathe ? 0.16 : 0.08))
                    .frame(width: 200, height: 200)
                    .blur(radius: 34)

                // Islamic 8-pointed star geometric ring
                IslamicStar()
                    .stroke(Color.msGold.opacity(0.22), lineWidth: 1)
                    .frame(width: 152, height: 152)

                // Mid soft ring
                SwiftUI.Circle()
                    .fill(Color.msGold.opacity(0.07))
                    .frame(width: 132, height: 132)

                // Inner glow halo
                SwiftUI.Circle()
                    .fill(Color(hex: "EEC050").opacity(0.20))
                    .frame(width: 110, height: 110)
                    .blur(radius: 10)

                // Gold medallion — radial gradient for depth
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

                // Heart icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .white.opacity(0.35), radius: 6)
            }
            // Breathing animation applied to entire medallion cluster
            .scaleEffect(breathe ? 1.06 : 1.0)

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
            } else if viewModel.habits.isEmpty {
                emptyState
            } else {
                let accountable = viewModel.habits.filter { $0.isAccountable && $0.circleId != nil }
                let personal    = viewModel.habits.filter { !$0.isAccountable || $0.circleId == nil }
                if !accountable.isEmpty { sharedSection(habits: accountable) }
                if !personal.isEmpty   { personalSection(habits: personal) }
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

    private func sharedSection(habits: [Habit]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared Intentions")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.msTextPrimary)

            // Social proof row — avatars + Nudge CTA
            HStack(spacing: 10) {
                HStack(spacing: -10) {
                    ForEach(Array(msAvatarData.enumerated()), id: \.offset) { _, item in
                        ZStack {
                            SwiftUI.Circle().fill(item.color)
                            Text(item.initials)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 26, height: 26)
                        // Gold ring = "not yet checked in" indicator
                        .overlay(SwiftUI.Circle().stroke(Color.msGold.opacity(0.50), lineWidth: 1.5))
                        .overlay(SwiftUI.Circle().stroke(Color.msBackground, lineWidth: 2))
                    }
                }
                Text("3 brothers keeping you accountable")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.msTextMuted)
                Spacer()
                // Nudge button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) { nudgeSent = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                        withAnimation { nudgeSent = false }
                    }
                } label: {
                    Text(nudgeSent ? "Sent ✓" : "Nudge")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(nudgeSent ? Color.msGold : Color.msGold.opacity(0.75))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.msGold.opacity(nudgeSent ? 0.20 : 0.10))
                                .overlay(Capsule().stroke(Color.msGold.opacity(0.40), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }

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
                }
            }
        }
    }

    private func personalSection(habits: [Habit]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Personal Intentions")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.msTextMuted)
                Spacer()
                // Elegant "Private" script badge instead of lock icon
                Text("Private")
                    .font(.system(size: 9, weight: .light, design: .serif))
                    .foregroundStyle(Color.msGold.opacity(0.50))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay(Capsule().stroke(Color.msGold.opacity(0.22), lineWidth: 1))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
                }
            }
        }
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            showAddIntention = true
        } label: {
            ZStack {
                // Animated glow bloom
                SwiftUI.Circle()
                    .fill(Color.msGold.opacity(fabGlow ? 0.22 : 0.08))
                    .frame(width: 72, height: 72)
                    .blur(radius: fabGlow ? 12 : 5)

                // Gold medallion
                SwiftUI.Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "F0CC6A"), Color(hex: "C08A1A")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(
                        color: Color.msGold.opacity(fabGlow ? 0.60 : 0.30),
                        radius: fabGlow ? 22 : 10,
                        x: 0, y: 4
                    )

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.msBackground)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Supporting data

    private let msAvatarData: [(initials: String, color: Color)] = [
        ("OI", Color(hex: "4A7C59")),
        ("AA", Color(hex: "5E9E72")),
        ("KA", Color(hex: "3D6B4F"))
    ]

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
           let ownedCircle = circles.first,
           let code = ownedCircle.inviteCode {
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
                    .foregroundStyle(Color.msBackground)
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

// MARK: - SharedHabitCard

private struct SharedHabitCard: View {
    let habit: Habit
    let isCompleted: Bool
    let onToggle: () -> Void

    @State private var shimmerPhase: CGFloat = -0.5

    private var chipInitials: [String] {
        let pools = [["OI", "AA"], ["KA", "OI"], ["AA", "KA"], ["OI", "KA"]]
        return pools[abs(habit.name.hashValue) % pools.count]
    }
    private var symbol: String { habitSymbol(for: habit.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(isCompleted ? Color.msGold : Color.msGold.opacity(0.75))
                Spacer()
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "ellipsis")
                    .font(.system(size: isCompleted ? 13 : 11))
                    .foregroundStyle(isCompleted ? Color.msGold : Color.msTextMuted)
            }

            Text(habit.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.msTextPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                ForEach(chipInitials, id: \.self) { initials in
                    Text(initials)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.msTextPrimary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.11)))
                }
                Spacer(minLength: 0)
                Button(action: onToggle) {
                    Text(isCompleted ? "Done ✓" : "Check In")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.msBackground)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.msGold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                // Base fill — warms to msCardDone when completed
                RoundedRectangle(cornerRadius: 24)
                    .fill(isCompleted ? Color.msCardDone : Color.msCardShared)

                // One-shot shimmer on completion
                if isCompleted {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear,                    location: shimmerPhase - 0.25),
                                    .init(color: .white.opacity(0.09),     location: shimmerPhase),
                                    .init(color: .clear,                    location: shimmerPhase + 0.25)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Border — brighter gold when done
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isCompleted ? Color.msGold.opacity(0.50) : Color.msGold.opacity(0.28), lineWidth: 1)
            }
        )
        // Parchment elevation shadow
        .shadow(color: Color.black.opacity(0.38), radius: 14, x: 0, y: 7)
        .onChange(of: isCompleted) { _, newValue in
            guard newValue else { return }
            shimmerPhase = -0.5
            withAnimation(.easeOut(duration: 1.4)) {
                shimmerPhase = 1.6
            }
        }
    }
}

// MARK: - PersonalHabitCard

private struct PersonalHabitCard: View {
    let habit: Habit
    let isCompleted: Bool
    let onToggle: () -> Void

    private var symbol: String { habitSymbol(for: habit.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(isCompleted ? Color.msGold.opacity(0.70) : Color.msTextMuted)
                Spacer()
                // Subtle "Private" script badge — replaces hard lock icon
                Text("Private")
                    .font(.system(size: 8, weight: .light, design: .serif))
                    .foregroundStyle(Color.msGold.opacity(0.40))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(Capsule().stroke(Color.msGold.opacity(0.18), lineWidth: 1))
            }

            Text(habit.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.msTextPrimary.opacity(isCompleted ? 1.0 : 0.88))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button(action: onToggle) {
                Text(isCompleted ? "Done" : "Check in")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isCompleted ? Color.msGold : Color.msTextMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isCompleted ? Color.msCardDone.opacity(0.6) : Color.clear)
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    isCompleted ? Color.msGold.opacity(0.55) : Color.msTextMuted.opacity(0.28),
                                    lineWidth: 1
                                )
                        }
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(isCompleted ? Color.msCardDone : Color.msCardPersonal)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            isCompleted ? Color.msGold.opacity(0.38) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Habit symbol helper

private func habitSymbol(for name: String) -> String {
    let n = name.lowercased()
    if n.contains("quran")  || n.contains("qur")                          { return "book.fill" }
    if n.contains("salah")  || n.contains("salat") || n.contains("prayer"){ return "building.columns.fill" }
    if n.contains("dhikr")  || n.contains("zikr")                         { return "circle.grid.3x3.fill" }
    if n.contains("fast")   || n.contains("sawm")                         { return "moon.stars.fill" }
    if n.contains("sadaqah") || n.contains("charity")                     { return "hands.sparkles.fill" }
    if n.contains("tahajjud") || n.contains("night")                      { return "moon.fill" }
    return "leaf.fill"
}

// MARK: - Preview

#Preview {
    HomeView()
        .environment(AuthManager())
}
