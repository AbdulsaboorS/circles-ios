import SwiftUI
import Supabase

// MARK: - Midnight Sanctuary Color Tokens (Phase 11.1 — HomeView scoped)

private extension Color {
    static let msBackground   = Color(hex: "1A2E1E")
    static let msCardShared   = Color(hex: "243828")
    static let msCardPersonal = Color(hex: "1E3122")
    static let msGold         = Color(hex: "D4A240")
    static let msTextPrimary  = Color(hex: "F0EAD6")
    static let msTextMuted    = Color(hex: "8FAF94")
    static let msBorder       = Color(hex: "D4A240").opacity(0.18)
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(AuthManager.self) private var auth
    @State private var viewModel = HomeViewModel()
    @State private var preferredName: String = "Friend"
    @State private var showAddIntention = false
    @State private var navigationPath = NavigationPath()

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

                        habitsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                    }
                }
                .scrollIndicators(.hidden)

                fabButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 88)
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Habit.self) { habit in
                HabitDetailView(habit: habit)
            }
            .refreshable {
                guard let userId = auth.session?.user.id else { return }
                await viewModel.loadAll(userId: userId)
                await loadPreferredName(userId: userId)
            }
            .task {
                guard let userId = auth.session?.user.id else { return }
                await viewModel.loadAll(userId: userId)
                await loadPreferredName(userId: userId)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showAddIntention) {
                AddPrivateIntentionSheet { newHabit in
                    // Reload habits so the new one appears in the list
                    if let userId = auth.session?.user.id {
                        Task { await viewModel.loadAll(userId: userId) }
                    }
                    // Navigate directly into the habit's detail view
                    navigationPath.append(newHabit)
                }
                .environment(auth)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Assalamu Alaikum,")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.msTextMuted)
            Text(preferredName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.msTextPrimary)
            Text(todayFormatted)
                .font(.system(size: 13))
                .foregroundStyle(Color.msTextMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Heart (the Sun of the screen)

    private var heartSection: some View {
        VStack(spacing: 14) {
            ZStack {
                // Outer ambient bloom
                SwiftUI.Circle()
                    .fill(Color.msGold.opacity(0.10))
                    .frame(width: 170, height: 170)
                    .blur(radius: 28)

                // Soft mid-ring
                SwiftUI.Circle()
                    .fill(Color.msGold.opacity(0.07))
                    .frame(width: 124, height: 124)

                // Gold medallion
                SwiftUI.Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "EEC050"), Color(hex: "B8891E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: Color.msGold.opacity(0.45), radius: 22, x: 0, y: 6)

                // White heart
                Image(systemName: "heart.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text("\(viewModel.streak?.currentStreak ?? 0) Day Streak")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.msTextPrimary)

            Text(islamicQuote)
                .font(.system(size: 13).italic())
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

                if !accountable.isEmpty {
                    sharedSection(habits: accountable)
                }
                if !personal.isEmpty {
                    personalSection(habits: personal)
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

            // "X brothers keeping you accountable" sub-row
            HStack(spacing: 8) {
                HStack(spacing: -9) {
                    ForEach(Array(msAvatarData.enumerated()), id: \.offset) { idx, item in
                        ZStack {
                            SwiftUI.Circle().fill(item.color)
                            Text(item.initials)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 22, height: 22)
                        .overlay(SwiftUI.Circle().stroke(Color.msBackground, lineWidth: 2))
                    }
                }
                Text("3 brothers keeping you accountable")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.msTextMuted)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(habits) { habit in
                    NavigationLink(value: habit) {
                        SharedHabitCard(
                            habit: habit,
                            isCompleted: viewModel.isCompleted(habitId: habit.id),
                            onToggle: {
                                guard let userId = auth.session?.user.id else { return }
                                Task { await viewModel.toggleHabit(habit, userId: userId) }
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
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.msGold)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(habits) { habit in
                    NavigationLink(value: habit) {
                        PersonalHabitCard(
                            habit: habit,
                            isCompleted: viewModel.isCompleted(habitId: habit.id),
                            onToggle: {
                                guard let userId = auth.session?.user.id else { return }
                                Task { await viewModel.toggleHabit(habit, userId: userId) }
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
        Button { showAddIntention = true } label: {
            ZStack {
                SwiftUI.Circle()
                    .fill(Color.msGold)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.msGold.opacity(0.35), radius: 14, x: 0, y: 4)
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
}

// MARK: - SharedHabitCard

private struct SharedHabitCard: View {
    let habit: Habit
    let isCompleted: Bool
    let onToggle: () -> Void

    // Phase 11.2: wire real circle member initials
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
                    .foregroundStyle(Color.msGold)
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.msTextMuted)
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
                    Text(isCompleted ? "Done" : "Check In")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isCompleted ? Color.msTextPrimary : Color.msBackground)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(isCompleted ? Color.msGold.opacity(0.45) : Color.msGold)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.msCardShared)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.msBorder, lineWidth: 1))
        )
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
                    .foregroundStyle(Color.msTextMuted)
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.msGold)
            }

            Text(habit.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.msTextPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button(action: onToggle) {
                Text(isCompleted ? "Done" : "Update")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isCompleted ? Color.msGold : Color.msTextMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isCompleted ? Color.msGold.opacity(0.5) : Color.msTextMuted.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.msCardPersonal)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }
}

// MARK: - Shared helper

private func habitSymbol(for name: String) -> String {
    let n = name.lowercased()
    if n.contains("quran") || n.contains("qur")                         { return "book.fill" }
    if n.contains("salah") || n.contains("salat") || n.contains("prayer") { return "building.columns.fill" }
    if n.contains("dhikr") || n.contains("zikr")                        { return "circle.grid.3x3.fill" }
    if n.contains("fast") || n.contains("sawm")                         { return "moon.stars.fill" }
    if n.contains("sadaqah") || n.contains("charity")                   { return "hands.sparkles.fill" }
    if n.contains("tahajjud") || n.contains("night")                    { return "moon.fill" }
    return "leaf.fill"
}

// MARK: - Preview

#Preview {
    HomeView()
        .environment(AuthManager())
}
