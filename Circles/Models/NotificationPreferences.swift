import Foundation

struct NotificationPreferences: Codable, Equatable, Sendable {
    let userId: UUID
    var notificationsEnabled: Bool
    var momentWindowEnabled: Bool
    var nudgesEnabled: Bool
    var circleActivityEnabled: Bool
    var habitRemindersEnabled: Bool
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case notificationsEnabled = "notifications_enabled"
        case momentWindowEnabled = "moment_window_enabled"
        case nudgesEnabled = "nudges_enabled"
        case circleActivityEnabled = "circle_activity_enabled"
        case habitRemindersEnabled = "habit_reminders_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension NotificationPreferences {
    static func defaults(for userId: UUID) -> NotificationPreferences {
        NotificationPreferences(
            userId: userId,
            notificationsEnabled: true,
            momentWindowEnabled: true,
            nudgesEnabled: true,
            circleActivityEnabled: true,
            habitRemindersEnabled: true,
            createdAt: nil,
            updatedAt: nil
        )
    }
}
