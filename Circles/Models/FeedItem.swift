import Foundation

// MARK: - Associated value types for each feed item variant

struct MomentFeedItem: Identifiable, Sendable {
    let id: UUID          // circle_moments.id (first row after dedup)
    let circleId: UUID    // primary circle — used for comment threading
    let userId: UUID
    let userName: String  // display name — fetched alongside (see FeedService note)
    let circleName: String  // primary circle name (= circleNames[0])
    let circleIds: [UUID]   // all circles this photo was posted to
    let circleNames: [String] // all circle names (parallel to circleIds)
    let photoUrl: String
    let secondaryPhotoUrl: String?
    let caption: String?
    let postedAt: String  // ISO8601 string, per project date-as-string convention
    let isOnTime: Bool
}

struct HabitCheckinFeedItem: Identifiable, Sendable {
    let id: UUID          // activity_feed.id
    let circleId: UUID
    let userId: UUID
    let userName: String
    let circleName: String
    let habitName: String
    let checkedAt: String // ISO8601 string (activity_feed.created_at)
}

struct StreakMilestoneFeedItem: Identifiable, Sendable {
    let id: UUID          // activity_feed.id
    let circleId: UUID
    let userId: UUID
    let userName: String
    let circleName: String
    let habitName: String
    let streakDays: Int
    let achievedAt: String // ISO8601 string (activity_feed.created_at)
}

// MARK: - Unified feed item enum

enum FeedItem: Identifiable, Sendable, Equatable {
    public static func == (lhs: FeedItem, rhs: FeedItem) -> Bool { lhs.id == rhs.id }
    case moment(MomentFeedItem)
    case habitCheckin(HabitCheckinFeedItem)
    case streakMilestone(StreakMilestoneFeedItem)

    var id: UUID {
        switch self {
        case .moment(let item): return item.id
        case .habitCheckin(let item): return item.id
        case .streakMilestone(let item): return item.id
        }
    }

    /// Timestamp string for reverse-chronological sorting
    var sortTimestamp: String {
        switch self {
        case .moment(let item): return item.postedAt
        case .habitCheckin(let item): return item.checkedAt
        case .streakMilestone(let item): return item.achievedAt
        }
    }

    var circleId: UUID {
        switch self {
        case .moment(let item): return item.circleId
        case .habitCheckin(let item): return item.circleId
        case .streakMilestone(let item): return item.circleId
        }
    }

    var postType: String {
        switch self {
        case .moment:           return "moment"
        case .habitCheckin:     return "habit_checkin"
        case .streakMilestone:  return "streak_milestone"
        }
    }

    var isMoment: Bool {
        if case .moment = self { return true }
        return false
    }
}
