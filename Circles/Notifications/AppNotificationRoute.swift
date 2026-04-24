import Foundation

enum AppTabRoute: String, Codable, Sendable, Equatable {
    case home
    case circles
    case journey
    case profile

    var tabIndex: Int {
        switch self {
        case .home:
            return 0
        case .circles:
            return 1
        case .journey:
            return 2
        case .profile:
            return 3
        }
    }

    init?(tabIndex: Int) {
        switch tabIndex {
        case 0:
            self = .home
        case 1:
            self = .circles
        case 2:
            self = .journey
        case 3:
            self = .profile
        default:
            return nil
        }
    }
}

enum HomeNotificationDestination: String, Codable, Sendable, Equatable {
    case root
    case habitDetail = "habit_detail"
}

enum CircleNotificationDetailTab: String, Codable, Sendable, Equatable {
    case huddle
    case gallery
}

enum CirclesNotificationDestination: String, Codable, Sendable, Equatable {
    case root
    case feed = "circles_feed"
    case circleDetail = "circle_detail"
}

struct AppNotificationRoute: Codable, Sendable, Equatable {
    let tab: AppTabRoute
    let homeDestination: HomeNotificationDestination
    let circlesDestination: CirclesNotificationDestination
    let habitId: UUID?
    let circleId: UUID?
    let circleDetailTab: CircleNotificationDetailTab?

    init(
        tab: AppTabRoute,
        homeDestination: HomeNotificationDestination = .root,
        circlesDestination: CirclesNotificationDestination = .root,
        habitId: UUID? = nil,
        circleId: UUID? = nil,
        circleDetailTab: CircleNotificationDetailTab? = nil
    ) {
        self.tab = tab
        self.homeDestination = homeDestination
        self.circlesDestination = circlesDestination
        self.habitId = habitId
        self.circleId = circleId
        self.circleDetailTab = circleDetailTab
    }

    static let home = AppNotificationRoute(tab: .home)
    static let circles = AppNotificationRoute(tab: .circles)
    static let circlesFeed = AppNotificationRoute(tab: .circles, circlesDestination: .feed)
    static let journey = AppNotificationRoute(tab: .journey)
    static let profile = AppNotificationRoute(tab: .profile)

    static func habitDetail(_ habitId: UUID) -> AppNotificationRoute {
        AppNotificationRoute(
            tab: .home,
            homeDestination: .habitDetail,
            habitId: habitId
        )
    }

    var tabIndex: Int { tab.tabIndex }
    var requiresInTabFollowThrough: Bool {
        switch tab {
        case .home:
            return homeDestination != .root
        case .circles:
            return circlesDestination != .root
        case .journey, .profile:
            return false
        }
    }

    static func fromPayload(
        routeString: String?,
        habitId: UUID?,
        circleId: UUID?,
        detailTab: CircleNotificationDetailTab?
    ) -> AppNotificationRoute? {
        guard let routeString else { return nil }

        if let tab = AppTabRoute(rawValue: routeString) {
            return AppNotificationRoute(
                tab: tab,
                homeDestination: habitId == nil ? .root : .habitDetail,
                habitId: habitId,
                circleId: circleId,
                circleDetailTab: detailTab
            )
        }

        if let homeDestination = HomeNotificationDestination(rawValue: routeString) {
            return AppNotificationRoute(
                tab: .home,
                homeDestination: homeDestination,
                habitId: habitId,
                circleId: circleId,
                circleDetailTab: detailTab
            )
        }

        if let circlesDestination = CirclesNotificationDestination(rawValue: routeString) {
            return AppNotificationRoute(
                tab: .circles,
                circlesDestination: circlesDestination,
                habitId: habitId,
                circleId: circleId,
                circleDetailTab: detailTab
            )
        }

        return nil
    }
}
