import Foundation

struct Circle: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let createdBy: UUID
    let inviteCode: String?
    let momentWindowStart: String?   // TIMESTAMPTZ as String, per project convention
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case createdBy = "created_by"
        case inviteCode = "invite_code"
        case momentWindowStart = "moment_window_start"
        case createdAt = "created_at"
    }
}
