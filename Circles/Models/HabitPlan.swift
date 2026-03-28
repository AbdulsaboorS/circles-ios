import Foundation

struct HabitMilestone: Codable, Sendable, Identifiable {
    var id: Int { day }
    let day: Int
    let title: String
    let description: String
}

struct HabitPlan: Codable, Identifiable, Sendable {
    let id: UUID
    let habitId: UUID
    let userId: UUID
    var milestones: [HabitMilestone]
    var weekNumber: Int
    var refinementCount: Int    // resets each week; max 3
    var refinementWeek: Int     // ISO week number when count was last reset
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case userId = "user_id"
        case milestones
        case weekNumber = "week_number"
        case refinementCount = "refinement_count"
        case refinementWeek = "refinement_week"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension HabitPlan {
    /// True if the user has used all 3 refinements this week.
    var isRefinementLimitReached: Bool {
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        if refinementWeek != currentWeek { return false }
        return refinementCount >= 3
    }
}
