import Foundation

struct CircleMoment: Codable, Identifiable, Sendable {
    let id: UUID
    let circleId: UUID
    let userId: UUID
    let photoUrl: String
    let caption: String?
    let postedAt: String   // TIMESTAMPTZ stored as String per project convention
    let isOnTime: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case circleId = "circle_id"
        case userId = "user_id"
        case photoUrl = "photo_url"
        case caption
        case postedAt = "posted_at"
        case isOnTime = "is_on_time"
    }
}
