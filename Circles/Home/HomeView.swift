import SwiftUI
import Supabase

struct HomeView: View {
    @Environment(AuthManager.self) private var auth
    @State private var viewModel = HomeViewModel()

    private var todayFormatted: String {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .none
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            List {
                // Greeting header
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Assalamu Alaikum")
                            .font(.title2.bold())
                        Text(todayFormatted)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowSeparator(.hidden)
                }

                // Streak banner
                if let streak = viewModel.streak, streak.currentStreak > 0 {
                    Section {
                        HStack(spacing: 12) {
                            Text("🔥")
                                .font(.title)
                            VStack(alignment: .leading) {
                                Text("\(streak.currentStreak) day streak")
                                    .font(.headline)
                                Text("Best: \(streak.longestStreak) days")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Habits
                Section("Today's Habits") {
                    if viewModel.isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if viewModel.habits.isEmpty {
                        Text("No habits yet. Complete onboarding to add habits.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(viewModel.habits) { habit in
                            HabitRow(
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
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Habit.self) { habit in
                HabitDetailView(habit: habit)
            }
            .refreshable {
                guard let userId = auth.session?.user.id else { return }
                await viewModel.loadAll(userId: userId)
            }
            .task {
                guard let userId = auth.session?.user.id else { return }
                await viewModel.loadAll(userId: userId)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

private struct HabitRow: View {
    let habit: Habit
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        NavigationLink(value: habit) {
            HStack(spacing: 12) {
                Button(action: onToggle) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)

                Text(habit.icon).font(.title3)
                Text(habit.name).font(.body)
                Spacer()
                if let goal = habit.acceptedAmount, !goal.isEmpty {
                    Text(goal)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(AuthManager())
}
