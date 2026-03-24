import Foundation

struct Circle: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let createdBy: UUID
    let prayerTime: String?
    let inviteCode: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case createdBy = "created_by"
        case prayerTime = "prayer_time"
        case inviteCode = "invite_code"
        case createdAt = "created_at"
    }
}
