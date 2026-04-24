import Foundation

enum AppNotificationType: String, Codable, Sendable {
    case momentWindow = "moment_window"
    case nudge = "nudge"
    case circleCheckIn = "circle_check_in"
    case habitReminder = "habit_reminder"

    init?(payloadType: String) {
        switch payloadType {
        case "moment_window":
            self = .momentWindow
        case "nudge", "peer_nudge":
            self = .nudge
        case "circle_check_in", "member_posted":
            self = .circleCheckIn
        case "habit_reminder":
            self = .habitReminder
        default:
            return nil
        }
    }

    var defaultRoute: AppNotificationRoute {
        switch self {
        case .momentWindow, .nudge, .circleCheckIn:
            return .circles
        case .habitReminder:
            return .home
        }
    }
}
