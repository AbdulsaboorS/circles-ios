import Foundation

struct Habit: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    var name: String
    var icon: String
    var ramadanAmount: String?
    var suggestedAmount: String?
    var acceptedAmount: String?
    var planNotes: String?
    var niyyah: String?             // user's intention; one-line "why" of the habit
    var isActive: Bool
    var isAccountable: Bool         // true = broadcasts to circleId's feed
    var circleId: UUID?             // nil = Personal habit
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case icon
        case ramadanAmount = "ramadan_amount"
        case suggestedAmount = "suggested_amount"
        case acceptedAmount = "accepted_amount"
        case planNotes = "plan_notes"
        case niyyah
        case isActive = "is_active"
        case isAccountable = "is_accountable"
        case circleId = "circle_id"
        case createdAt = "created_at"
    }
}

extension Habit {
    var isPersonal: Bool { !isAccountable || circleId == nil }
}
