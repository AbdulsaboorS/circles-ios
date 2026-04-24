import Foundation
import Supabase

@MainActor
final class NotificationPreferencesService {
    static let shared = NotificationPreferencesService()

    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    func fetchOrCreate(userId: UUID) async throws -> NotificationPreferences {
        let existing: [NotificationPreferences] = try await client
            .from("notification_preferences")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        if let preferences = existing.first {
            return preferences
        }

        return try await upsert(NotificationPreferences.defaults(for: userId))
    }

    func upsert(_ preferences: NotificationPreferences) async throws -> NotificationPreferences {
        let row: [String: AnyJSON] = [
            "user_id": .string(preferences.userId.uuidString),
            "notifications_enabled": .bool(preferences.notificationsEnabled),
            "moment_window_enabled": .bool(preferences.momentWindowEnabled),
            "nudges_enabled": .bool(preferences.nudgesEnabled),
            "circle_activity_enabled": .bool(preferences.circleActivityEnabled),
            "habit_reminders_enabled": .bool(preferences.habitRemindersEnabled),
        ]

        return try await client
            .from("notification_preferences")
            .upsert(row, onConflict: "user_id")
            .select()
            .single()
            .execute()
            .value
    }
}
