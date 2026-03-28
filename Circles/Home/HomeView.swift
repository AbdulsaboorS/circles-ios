import SwiftUI
import Supabase

struct HomeView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = HomeViewModel()
    @State private var preferredName: String = "Friend"

    private var colors: AppColors { AppColors.resolve(colorScheme) }

    private let islamicQuotes = [
        "Verily, with hardship comes ease.",
        "Allah is with the patient.",
        "Take care of your obligations to Allah.",
        "The best of deeds are those done consistently.",
        "Whoever fears Allah, He will make a way out for him."
    ]

    private var todayFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
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

    private var greetingSymbol: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return (hour >= 5 && hour <= 16) ? "sun.max.fill" : "moon.fill"
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
                    VStack(spacing: 24) {
                        greetingHeader
                        heartProgressCard
                        habitsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
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
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(greetingText), \(preferredName)")
                    .font(.appHeroTitle)
                    .foregroundStyle(colors.textPrimary)
                Image(systemName: greetingSymbol)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accent)
            }
            Text(todayFormatted)
                .font(.appCaption)
                .foregroundStyle(colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Heart Progress Card

    private var heartProgressCard: some View {
        AppCard {
            VStack(spacing: 16) {
                Text("Heart Progress")
                    .font(.appHeadline)
                    .foregroundStyle(colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Glowing heart
                ZStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 90))
                        .foregroundStyle(Color.accent.opacity(0.25))
                        .blur(radius: 22)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.98, green: 0.76, blue: 0.45), Color.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.vertical, 4)

                Text("\(viewModel.streak?.currentStreak ?? 0) Day Streak")
                    .font(.appHeadline)
                    .foregroundStyle(Color.accent)

                Text(islamicQuote)
                    .font(.appCaption)
                    .italic()
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)

                Button(action: {}) {
                    Text("Share Light")
                        .font(.appCaptionMedium)
                        .foregroundStyle(colors.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(colors.textSecondary.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
    }

    // MARK: - Habits Section

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if viewModel.isLoading {
                HStack { Spacer(); ProgressView().tint(Color.accent); Spacer() }
            } else if viewModel.habits.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accent.opacity(0.6))
                    Text("No intentions yet.")
                        .font(.appSubheadline)
                        .foregroundStyle(colors.textSecondary)
                    Text("Complete onboarding to begin your journey.")
                        .font(.appCaption)
                        .foregroundStyle(colors.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                let accountable = viewModel.habits.filter { $0.isAccountable && $0.circleId != nil }
                let personal = viewModel.habits.filter { !$0.isAccountable || $0.circleId == nil }

                if !accountable.isEmpty {
                    habitGroup(
                        title: "Shared Intentions",
                        subtitle: "Visible to your circles",
                        icon: "person.2.fill",
                        habits: accountable
                    )
                }
                if !personal.isEmpty {
                    habitGroup(
                        title: "Personal Intentions",
                        subtitle: "Private to you",
                        icon: "lock.fill",
                        habits: personal
                    )
                }
            }
        }
    }

    private func habitGroup(title: String, subtitle: String, icon: String, habits: [Habit]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.appCaptionMedium)
                        .foregroundStyle(colors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(colors.textSecondary)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(habits) { habit in
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

    // MARK: - Data

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

// MARK: - HabitCardView

private struct HabitCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let habit: Habit
    let isCompleted: Bool
    let onToggle: () -> Void

    private var colors: AppColors { AppColors.resolve(colorScheme) }

    private var habitSymbol: String {
        let n = habit.name.lowercased()
        if n.contains("quran") || n.contains("qur") { return "book.fill" }
        if n.contains("salah") || n.contains("salat") || n.contains("masjid") || n.contains("prayer") { return "building.columns.fill" }
        if n.contains("dhikr") || n.contains("zikr") { return "circle.grid.3x3.fill" }
        if n.contains("fast") || n.contains("sawm") { return "moon.stars.fill" }
        if n.contains("sadaqah") || n.contains("charity") { return "hands.sparkles.fill" }
        return "star.fill"
    }

    var body: some View {
        NavigationLink(value: habit) {
            AppCard {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack {
                        SwiftUI.Circle()
                            .fill(Color.accent.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: habitSymbol)
                            .font(.system(size: 22))
                            .foregroundStyle(Color.accent)
                    }

                    Text(habit.name)
                        .font(.appSubheadline)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    ChipButton(
                        label: isCompleted ? "Done" : "Check In",
                        isSelected: isCompleted,
                        systemImage: isCompleted ? "checkmark" : nil,
                        action: onToggle
                    )
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environment(AuthManager())
}
