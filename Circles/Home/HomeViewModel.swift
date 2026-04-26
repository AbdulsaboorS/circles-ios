import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    var habits: [Habit] = []
    var todayLogs: [HabitLog] = []
    var streak: Streak? = nil
    var computedStreak: Int = 0
    var isLoading: Bool = false
    var errorMessage: String? = nil

    /// Increments when the user checks off the last pending habit of the day.
    var beadIgniteCounter: Int = 0

    private let todayString: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }()

    func isCompleted(habitId: UUID) -> Bool {
        todayLogs.first { $0.habitId == habitId }?.completed ?? false
    }

    var allHabitsCompleted: Bool {
        !habits.isEmpty && habits.allSatisfy { isCompleted(habitId: $0.id) }
    }

    func loadAll(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            async let habitsFetch = HabitService.shared.fetchActiveHabits(userId: userId)
            async let logsFetch = HabitService.shared.fetchTodayLogs(userId: userId, date: todayString)
            async let streakFetch = HabitService.shared.fetchStreak(userId: userId)

            habits = try await habitsFetch
            todayLogs = try await logsFetch
            streak = try await streakFetch
            computedStreak = await HabitToggleService.shared.computeAccountableStreak(userId: userId, habits: habits)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteHabit(_ habit: Habit) async {
        habits.removeAll { $0.id == habit.id }
        do {
            try await HabitService.shared.archiveHabit(habitId: habit.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleHabit(_ habit: Habit, userId: UUID) async {
        let alreadyCompleted = isCompleted(habitId: habit.id)
        let wasAllDone = allHabitsCompleted

        setLocalCompletion(for: habit, userId: userId, completed: !alreadyCompleted)

        if !alreadyCompleted && !wasAllDone && allHabitsCompleted {
            beadIgniteCounter &+= 1
        }

        do {
            let result = try await HabitToggleService.shared.toggleToday(
                habit: habit,
                userId: userId,
                date: todayString,
                alreadyCompleted: alreadyCompleted
            )
            streak = result.streak
            computedStreak = result.computedStreak
        } catch {
            setLocalCompletion(for: habit, userId: userId, completed: alreadyCompleted)
            errorMessage = error.localizedDescription
        }
    }

    private func setLocalCompletion(for habit: Habit, userId: UUID, completed: Bool) {
        if let existingIndex = todayLogs.firstIndex(where: { $0.habitId == habit.id }) {
            todayLogs[existingIndex].completed = completed
        } else if completed {
            todayLogs.append(
                HabitLog(
                    id: UUID(),
                    habitId: habit.id,
                    userId: userId,
                    date: todayString,
                    completed: true,
                    notes: nil,
                    createdAt: Date()
                )
            )
        }
    }
}
