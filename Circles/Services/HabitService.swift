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
            .upsert(row, onConflict: "user_id,name")
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

    // MARK: - Private Habit Creation

    /// Create a personal (non-accountable) habit with no circle link.
    /// `familiarity` is stored in plan_notes for AI context.
    func createPrivateHabit(userId: UUID, name: String, icon: String, familiarity: String) async throws -> Habit {
        let row: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "name": .string(name),
            "icon": .string(icon),
            "is_active": .bool(true),
            "is_accountable": .bool(false),
            "plan_notes": .string("Familiarity: \(familiarity)")
        ]
        return try await client
            .from("habits")
            .upsert(row, onConflict: "user_id,name")
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Accountable Habit Creation

    /// Create a habit linked to a circle (is_accountable = true).
    /// Used by Amir onboarding when setting up circle core habits.
    func createAccountableHabit(userId: UUID, name: String, icon: String, circleId: UUID) async throws -> Habit {
        let row: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "name": .string(name),
            "icon": .string(icon),
            "is_active": .bool(true),
            "is_accountable": .bool(true),
            "circle_id": .string(circleId.uuidString),
            "ramadan_amount": .string("daily")
        ]
        return try await client
            .from("habits")
            .upsert(row, onConflict: "user_id,name")
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Accountable Habit Broadcast

    /// Insert a habit_checkin event into activity_feed for accountable habits.
    /// Only called when completed = true and habit.circleId is set.
    /// Fire-and-forget — feed is additive, no rollback on failure.
    /// Guarded: skips insert if a row already exists for this user+habit+today (prevents duplicate feed cards).
    func broadcastHabitCompletion(habitId: UUID, habitName: String, circleId: UUID, userId: UUID) async throws {
        let todayStart: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date()) + "T00:00:00"
        }()
        struct IdRow: Decodable {
            let id: String
            enum CodingKeys: String, CodingKey { case id }
        }
        let existing: [IdRow] = (try? await client
            .from("activity_feed")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("habit_name", value: habitName)
            .eq("event_type", value: "habit_checkin")
            .gte("created_at", value: todayStart)
            .limit(1)
            .execute()
            .value) ?? []
        guard existing.isEmpty else { return }

        let row: [String: AnyJSON] = [
            "circle_id":  .string(circleId.uuidString),
            "user_id":    .string(userId.uuidString),
            "event_type": .string("habit_checkin"),
            "habit_name": .string(habitName)
        ]
        try await client
            .from("activity_feed")
            .insert(row)
            .execute()
    }

    /// Delete today's activity_feed entry for an accountable habit (called on undo check-in).
    func removeHabitCompletion(habitName: String, circleId: UUID, userId: UUID) async throws {
        let todayStart: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date()) + "T00:00:00"
        }()
        try await client
            .from("activity_feed")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("habit_name", value: habitName)
            .eq("event_type", value: "habit_checkin")
            .gte("created_at", value: todayStart)
            .execute()
    }

    /// Soft-delete a habit by setting is_active = false.
    /// Preserves habit_logs and habit_plans for history.
    func archiveHabit(habitId: UUID) async throws {
        struct Payload: Encodable { let is_active: Bool }
        try await client
            .from("habits")
            .update(Payload(is_active: false))
            .eq("id", value: habitId.uuidString)
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
