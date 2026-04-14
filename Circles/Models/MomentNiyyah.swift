import Foundation

struct MomentNiyyah: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let niyyahText: String
    let photoDate: String   // "YYYY-MM-DD"
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case niyyahText = "niyyah_text"
        case photoDate = "photo_date"
        case createdAt = "created_at"
    }
}
