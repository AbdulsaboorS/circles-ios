import Foundation

struct NotificationPayload: Equatable, Sendable {
    let type: AppNotificationType
    let route: AppNotificationRoute
    let habitId: UUID?
    let prayerName: String?
    let nudgeType: String?

    init?(userInfo: [AnyHashable: Any]) {
        guard let typeString = userInfo["type"] as? String,
              let type = AppNotificationType(payloadType: typeString)
        else {
            return nil
        }

        self.type = type
        let habitId: UUID?
        if let habitString = userInfo["habitId"] as? String {
            habitId = UUID(uuidString: habitString)
        } else if let habitString = userInfo["habit_id"] as? String {
            habitId = UUID(uuidString: habitString)
        } else {
            habitId = nil
        }
        self.habitId = habitId

        let circleId: UUID?
        if let circleString = userInfo["circleId"] as? String {
            circleId = UUID(uuidString: circleString)
        } else if let circleString = userInfo["circle_id"] as? String {
            circleId = UUID(uuidString: circleString)
        } else {
            circleId = nil
        }

        let detailTab: CircleNotificationDetailTab?
        if let detailTabString = userInfo["detailTab"] as? String {
            detailTab = CircleNotificationDetailTab(rawValue: detailTabString)
        } else if let detailTabString = userInfo["detail_tab"] as? String {
            detailTab = CircleNotificationDetailTab(rawValue: detailTabString)
        } else {
            detailTab = nil
        }

        if let routeString = userInfo["route"] as? String,
           let route = AppNotificationRoute.fromPayload(
            routeString: routeString,
            habitId: habitId,
            circleId: circleId,
            detailTab: detailTab
           ) {
            self.route = route
        } else if type == .habitReminder, let habitId {
            self.route = .habitDetail(habitId)
        } else {
            self.route = type.defaultRoute
        }

        if let prayer = userInfo["prayer"] as? String {
            self.prayerName = prayer
        } else if let prayer = userInfo["prayer_name"] as? String {
            self.prayerName = prayer
        } else {
            self.prayerName = nil
        }

        self.nudgeType = userInfo["nudgeType"] as? String
    }
}
