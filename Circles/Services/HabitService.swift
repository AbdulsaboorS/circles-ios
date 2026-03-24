import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class HabitService {
    static let shared = HabitService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Habits

    /// Fetch all active habits for a user, ordered by created_at ascending.
    func fetchActiveHabits(userId: UUID) async throws -> [Habit] {
        try await client
            .from("habits")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("is_active", value: true)
            .order("created_at")
            .execute()
            .value
    }

    /// Insert a new habit row. Returns the created Habit.
    func createHabit(userId: UUID, name: String, icon: String, ramadanAmount: String) async throws -> Habit {
        let row: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "name": .string(name),
            "icon": .string(icon),
            "ramadan_amount": .string(ramadanAmount),
            "is_active": .bool(true)
        ]
        return try await client
            .from("habits")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
    }

    /// Update accepted_amount on an existing habit (after user accepts AI suggestion).
    func updateAcceptedAmount(habitId: UUID, acceptedAmount: String, suggestedAmount: String) async throws {
        try await client
            .from("habits")
            .update([
                "accepted_amount": acceptedAmount,
                "suggested_amount": suggestedAmount
            ])
            .eq("id", value: habitId.uuidString)
            .execute()
    }

    // MARK: - Habit Logs

    /// Fetch all habit_log rows for a user on a specific date string "YYYY-MM-DD".
    func fetchTodayLogs(userId: UUID, date: String) async throws -> [HabitLog] {
        try await client
            .from("habit_logs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("date", value: date)
            .execute()
            .value
    }

    /// Toggle a habit's completion for today. Uses upsert on (habit_id, date) unique constraint.
    /// Optimistic: caller should update local state before awaiting this.
    func toggleHabitLog(habitId: UUID, userId: UUID, date: String, completed: Bool) async throws {
        let row: [String: AnyJSON] = [
            "habit_id": .string(habitId.uuidString),
            "user_id": .string(userId.uuidString),
            "date": .string(date),
            "completed": .bool(completed)
        ]
        try await client
            .from("habit_logs")
            .upsert(row, onConflict: "habit_id,date")
            .execute()
    }

    // MARK: - Streaks

    /// Fetch the streak row for a user. Returns nil if no streak row exists yet.
    func fetchStreak(userId: UUID) async throws -> Streak? {
        let results: [Streak] = try await client
            .from("streaks")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return results.first
    }
}
