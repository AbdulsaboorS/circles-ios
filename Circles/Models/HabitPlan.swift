import Foundation

struct HabitMilestone: Codable, Sendable, Identifiable, Hashable {
    var id: Int { day }
    let day: Int
    var title: String
    var description: String
}

struct HabitPlan: Codable, Identifiable, Sendable {
    let id: UUID
    let habitId: UUID
    let userId: UUID
    var milestones: [HabitMilestone]
    var weekNumber: Int
    var refinementCount: Int    // max 3 per refinement_cycle (server-enforced on refine)
    var refinementWeek: Int     // legacy; server updates on refine
    /// ISO-style key `yyyy-Www` in UTC, matches `apply_habit_plan_refinement` in Postgres.
    var refinementCycle: String?
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
        case refinementCycle = "refinement_cycle"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension HabitPlan {
    /// UTC ISO week label aligned with Postgres `to_char(..., 'IYYY') || '-W' || 'IW'`.
    static func currentRefinementCycleKeyUTC() -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        guard let y = c.yearForWeekOfYear, let w = c.weekOfYear else { return "" }
        return String(format: "%04d-W%02d", y, w)
    }

    /// True if the user has used all 3 refinements in the current UTC ISO week bucket.
    var isRefinementLimitReached: Bool {
        let key = Self.currentRefinementCycleKeyUTC()
        guard let cycle = refinementCycle, !cycle.isEmpty, cycle == key else { return false }
        return refinementCount >= 3
    }

    /// Calendar date string "yyyy-MM-dd" for roadmap day 1...28 (anchor = local start of day of `createdAt`).
    func calendarDateString(forMilestoneDay day: Int, calendar: Calendar = .current) -> String? {
        guard day >= 1, day <= 28 else { return nil }
        let anchor = calendar.startOfDay(for: createdAt)
        guard let d = calendar.date(byAdding: .day, value: day - 1, to: anchor) else { return nil }
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    func isMilestoneToday(day: Int, calendar: Calendar = .current) -> Bool {
        guard let s = calendarDateString(forMilestoneDay: day, calendar: calendar) else { return false }
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        return s == today
    }

    /// 1-based week bucket within the 28-day window from plan start (for grouping in UI).
    func displayWeek(forMilestoneDay day: Int, calendar: Calendar = .current) -> Int {
        guard day >= 1, day <= 28 else { return 1 }
        return (day - 1) / 7 + 1
    }
}
