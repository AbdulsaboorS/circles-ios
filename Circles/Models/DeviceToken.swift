import Foundation

struct DeviceToken: Codable, Sendable {
    let userId: UUID
    let deviceToken: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deviceToken = "device_token"
        case createdAt = "created_at"
    }
}
