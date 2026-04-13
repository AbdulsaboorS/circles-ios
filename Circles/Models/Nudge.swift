import Foundation

struct Nudge: Codable, Identifiable, Sendable {
    let id: UUID
    let circleId: UUID
    let senderId: UUID
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case circleId = "circle_id"
        case senderId = "sender_id"
        case createdAt = "created_at"
    }
}
