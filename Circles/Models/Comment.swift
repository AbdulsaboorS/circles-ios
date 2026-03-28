import Foundation

struct Comment: Codable, Identifiable, Sendable {
    let id: UUID
    let postId: UUID
    let postType: String   // "moment" | "habit_checkin" | "streak_milestone"
    let circleId: UUID
    let userId: UUID
    var text: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case postType = "post_type"
        case circleId = "circle_id"
        case userId = "user_id"
        case text
        case createdAt = "created_at"
    }
}
