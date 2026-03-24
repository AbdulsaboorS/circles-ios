import Foundation

struct Habit: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    var name: String
    var icon: String
    var ramadanAmount: String?
    var suggestedAmount: String?
    var acceptedAmount: String?
    var isActive: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case icon
        case ramadanAmount = "ramadan_amount"
        case suggestedAmount = "suggested_amount"
        case acceptedAmount = "accepted_amount"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}
