import SwiftUI
import Supabase

struct HomeView: View {
    @Environment(AuthManager.self) private var auth
    @State private var viewModel = HomeViewModel()
    @State private var publicCircles: [Circle] = []
    @State private var isLoadingPublicCircles = false

    private let islamicQuotes = [
        "Verily, with hardship comes ease.",
        "Allah is with the patient.",
        "Take care of your obligations to Allah.",
        "The best of deeds are those done consistently.",
        "Whoever fears Allah, He will make a way out for him."
    ]

    private var todayFormatted: String {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f.string(from: Date())
    }

    private var firstName: String {
        guard let email = auth.session?.user.email else { return "Friend" }
        let prefix = email.split(separator: "@").first.map(String.init) ?? "Friend"
        return prefix.prefix(1).uppercased() + prefix.dropFirst()
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0...4:   return "Peaceful Night"
        case 5...11:  return "Good Morning"
        case 12...16: return "Good Afternoon"
        case 17...20: return "Good Evening"
        default:      return "Peaceful Night"
        }
    }

    private var greetingEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5...16: return "☀️"
        default:     return "🌙"
        }
    }

    private var islamicQuote: String {
        let streak = viewModel.streak?.currentStreak ?? 0
        return islamicQuotes[streak % islamicQuotes.count]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        greetingHeader
                        streakCard
                        habitsSection
                        communitySection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Habit.self) { habit in
                HabitDetailView(habit: habit)
            }
            .refreshable {
                guard let userId = auth.session?.user.id else { return }
                await viewModel.loadAll(userId: userId)
                await loadPublicCircles()
            }
            .task {
                guard let userId = auth.session?.user.id else { return }
                await viewModel.loadAll(userId: userId)
                await loadPublicCircles()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Greeting Header (D-04)

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(greetingText), \(firstName) \(greetingEmoji)")
                .font(.appHeroTitle)
                .foregroundStyle(Color.textPrimary)
            Text(todayFormatted)
                .font(.appCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Streak Card (D-05)

    @ViewBuilder
    private var streakCard: some View {
        if let streak = viewModel.streak, streak.currentStreak > 0 {
            AppCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("🔥")
                            .font(.appTitle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(streak.currentStreak) day streak")
                                .font(.appHeadline)
                                .foregroundStyle(Color.textPrimary)
                            Text("Best: \(streak.longestStreak) days")
                                .font(.appCaption)
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                    }
                    Text(islamicQuote)
                        .font(.appCaption)
                        .foregroundStyle(Color.accent)
                        .italic()
                }
                .padding(16)
            }
        }
    }

    // MARK: - Habits Section (D-06, D-07)

    private var habitsSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Daily Intentions")
            if viewModel.isLoading {
                HStack { Spacer(); ProgressView().tint(Color.accent); Spacer() }
            } else if viewModel.habits.isEmpty {
                Text("Complete onboarding to add habits.")
                    .font(.appCaption)
                    .foregroundStyle(Color.textSecondary)
            } else {
                ForEach(viewModel.habits) { habit in
                    HabitCardView(
                        habit: habit,
                        isCompleted: viewModel.isCompleted(habitId: habit.id),
                        onToggle: {
                            guard let userId = auth.session?.user.id else { return }
                            Task { await viewModel.toggleHabit(habit, userId: userId) }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Community Circles Section (D-08)

    @ViewBuilder
    private var communitySection: some View {
        if isLoadingPublicCircles || !publicCircles.isEmpty {
            VStack(spacing: 12) {
                SectionHeader(title: "Community Circles", subtitle: "Discover public circles")
                if isLoadingPublicCircles {
                    HStack { Spacer(); ProgressView().tint(Color.accent); Spacer() }
                } else {
                    ForEach(publicCircles.prefix(3)) { circle in
                        AppCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(circle.name)
                                        .font(.appSubheadline)
                                        .foregroundStyle(Color.textPrimary)
                                    Text("Public Circle")
                                        .font(.appCaption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                                Spacer()
                                NavigationLink(destination: CircleDetailView(circle: circle)) {
                                    Image(systemName: "chevron.right")
                                        .font(.appCaption)
                                        .foregroundStyle(Color.accent)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(14)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data

    private func loadPublicCircles() async {
        isLoadingPublicCircles = true
        do {
            publicCircles = try await CircleService.shared.fetchPublicCircles()
        } catch {
            // Silently fail — community section simply stays hidden
        }
        isLoadingPublicCircles = false
    }
}

// MARK: - HabitCardView (D-06)

private struct HabitCardView: View {
    let habit: Habit
    let isCompleted: Bool
    let onToggle: () -> Void

    private var habitSymbol: String {
        let n = habit.name.lowercased()
        if n.contains("quran") || n.contains("qur") { return "book.fill" }
        if n.contains("salah") || n.contains("salat") || n.contains("prayer") { return "hands.sparkles.fill" }
        if n.contains("dhikr") || n.contains("zikr") { return "circle.hexagongrid.fill" }
        if n.contains("fast") || n.contains("sawm") { return "moon.stars.fill" }
        if n.contains("sadaqah") || n.contains("charity") { return "gift.fill" }
        return "star.fill"
    }

    var body: some View {
        NavigationLink(value: habit) {
            AppCard {
                HStack(spacing: 14) {
                    Image(systemName: habitSymbol)
                        .font(.system(size: 22))
                        .foregroundStyle(Color.accent)
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name)
                            .font(.appSubheadline)
                            .foregroundStyle(Color.textPrimary)
                        if let goal = habit.acceptedAmount, !goal.isEmpty {
                            Text(goal)
                                .font(.appCaption)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }

                    Spacer()

                    ChipButton(
                        label: isCompleted ? "Done" : "Check In",
                        isSelected: isCompleted,
                        systemImage: isCompleted ? "checkmark" : nil,
                        action: onToggle
                    )
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environment(AuthManager())
}
