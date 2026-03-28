import Foundation

struct HabitLog: Codable, Identifiable, Equatable {
    let id: UUID
    let habitId: UUID
    let userId: UUID
    let date: String   // stored as DATE string "YYYY-MM-DD", not Swift Date, to match DB type
    var completed: Bool
    var notes: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case userId = "user_id"
        case date
        case completed
        case notes
        case createdAt = "created_at"
    }
}
