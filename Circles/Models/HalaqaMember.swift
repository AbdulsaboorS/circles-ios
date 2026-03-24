import Foundation

struct CircleMember: Codable, Identifiable, Sendable {
    let id: UUID
    let circleId: UUID
    let userId: UUID
    let role: String
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case circleId = "circle_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
    }
}
