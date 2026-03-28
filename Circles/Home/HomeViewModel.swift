import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    var habits: [Habit] = []
    var todayLogs: [HabitLog] = []    // logs for today (date = todayString)
    var streak: Streak? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let todayString: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }()

    // MARK: - Derived state

    func isCompleted(habitId: UUID) -> Bool {
        todayLogs.first { $0.habitId == habitId }?.completed ?? false
    }

    // MARK: - Load

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
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Optimistic toggle

    /// Optimistically flips completed state in todayLogs, then writes to Supabase.
    /// On Supabase failure: reverts optimistic change and sets errorMessage.
    func toggleHabit(_ habit: Habit, userId: UUID) async {
        let newCompleted = !isCompleted(habitId: habit.id)

        // Optimistic update
        if let idx = todayLogs.firstIndex(where: { $0.habitId == habit.id }) {
            todayLogs[idx].completed = newCompleted
        } else {
            // Create a placeholder log entry (id will be replaced on next full refresh)
            let placeholder = HabitLog(
                id: UUID(),
                habitId: habit.id,
                userId: userId,
                date: todayString,
                completed: newCompleted,
                notes: nil,
                createdAt: Date()
            )
            todayLogs.append(placeholder)
        }

        do {
            try await HabitService.shared.toggleHabitLog(
                habitId: habit.id,
                userId: userId,
                date: todayString,
                completed: newCompleted
            )
            streak = try await HabitService.shared.fetchStreak(userId: userId)

            // Broadcast to circle feed if this is an accountable habit being completed
            if newCompleted, habit.isAccountable, let circleId = habit.circleId {
                try? await HabitService.shared.broadcastHabitCompletion(
                    habitId: habit.id,
                    habitName: habit.name,
                    circleId: circleId,
                    userId: userId
                )
            }
        } catch {
            if let idx = todayLogs.firstIndex(where: { $0.habitId == habit.id }) {
                todayLogs[idx].completed = !newCompleted
            }
            errorMessage = error.localizedDescription
        }
    }
}
