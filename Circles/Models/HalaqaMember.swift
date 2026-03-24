import Foundation

struct HalaqaMember: Codable, Identifiable, Sendable {
    let id: UUID
    let halaqaId: UUID
    let userId: UUID
    let role: String
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case halaqaId = "halaqa_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
    }
}
