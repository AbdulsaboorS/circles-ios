import Foundation

@MainActor
final class HabitToggleService {
    static let shared = HabitToggleService()

    private init() {}

    struct ToggleResult {
        let isCompleted: Bool
        let streak: Streak?
        let computedStreak: Int
    }

    func toggleToday(
        habit: Habit,
        userId: UUID,
        date: String,
        alreadyCompleted: Bool
    ) async throws -> ToggleResult {
        let activeHabits = try await HabitService.shared.fetchActiveHabits(userId: userId)
        let previousStreak = await computeAccountableStreak(userId: userId, habits: activeHabits)

        if alreadyCompleted {
            try await HabitService.shared.toggleHabitLog(
                habitId: habit.id,
                userId: userId,
                date: date,
                completed: false
            )

            if habit.isAccountable, let circleId = habit.circleId {
                try? await HabitService.shared.removeHabitCompletion(
                    habitName: habit.name,
                    circleId: circleId,
                    userId: userId
                )
            }
        } else {
            try await HabitService.shared.toggleHabitLog(
                habitId: habit.id,
                userId: userId,
                date: date,
                completed: true
            )

            if habit.isAccountable, let circleId = habit.circleId {
                try? await HabitService.shared.broadcastHabitCompletion(
                    habitId: habit.id,
                    habitName: habit.name,
                    circleId: circleId,
                    userId: userId
                )

                let recomputedStreak = await computeAccountableStreak(userId: userId, habits: activeHabits)
                let milestones = [7, 14, 30, 100]
                if let milestone = milestones.first(where: { previousStreak < $0 && recomputedStreak >= $0 }) {
                    try? await HabitService.shared.broadcastStreakMilestone(
                        habitId: habit.id,
                        habitName: habit.name,
                        circleId: circleId,
                        userId: userId,
                        streakDays: milestone
                    )
                }

                _ = try? await CircleService.shared.checkAndUpdateGroupStreak(circleId: circleId)
                NotificationCenter.default.post(name: .groupStreakUpdated, object: circleId)
            }
        }

        let streak = try? await HabitService.shared.fetchStreak(userId: userId)
        let computedStreak = await computeAccountableStreak(userId: userId, habits: activeHabits)
        await NotificationService.shared.refreshHabitReminderScheduling()

        return ToggleResult(
            isCompleted: !alreadyCompleted,
            streak: streak,
            computedStreak: computedStreak
        )
    }

    func computeAccountableStreak(userId: UUID, habits: [Habit]) async -> Int {
        let accountable = habits.filter(\.isAccountable)
        let targetHabits = accountable.isEmpty ? habits : accountable
        guard !targetHabits.isEmpty else { return 0 }

        let targetIds = Set(targetHabits.map(\.id))
        let calendar = Calendar.current
        let now = Date()
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else { return 0 }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fromString = formatter.string(from: thirtyDaysAgo)
        let toString = formatter.string(from: now)

        guard let logs = try? await HabitService.shared.fetchLogsInRange(
            userId: userId,
            from: fromString,
            to: toString
        ) else {
            return 0
        }

        let completedSet = Set(logs.compactMap { log -> String? in
            guard log.completed, targetIds.contains(log.habitId) else { return nil }
            return "\(log.habitId.uuidString)|\(log.date)"
        })

        var streak = 0
        for dayOffset in 0...30 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { break }
            let dateString = formatter.string(from: day)
            let allDone = targetIds.allSatisfy { habitId in
                completedSet.contains("\(habitId.uuidString)|\(dateString)")
            }

            if allDone {
                streak += 1
            } else if dayOffset == 0 {
                continue
            } else {
                break
            }
        }

        return streak
    }
}
