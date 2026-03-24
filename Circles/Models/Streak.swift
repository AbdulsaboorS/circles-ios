import Foundation

struct Streak: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedDate: String?  // DATE string "YYYY-MM-DD"
    var totalCompletions: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastCompletedDate = "last_completed_date"
        case totalCompletions = "total_completions"
        case updatedAt = "updated_at"
    }
}
