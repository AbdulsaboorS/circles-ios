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

    private func currentCycleAnchorDate(referenceDate: Date = Date(), calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: createdAt)
        let today = calendar.startOfDay(for: referenceDate)
        let elapsedDays = max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)
        let completedCycles = elapsedDays / 28
        return calendar.date(byAdding: .day, value: completedCycles * 28, to: start) ?? start
    }

    func currentCycleMilestoneDay(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: createdAt)
        let today = calendar.startOfDay(for: referenceDate)
        let elapsedDays = max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)
        return (elapsedDays % 28) + 1
    }

    /// Calendar date string "yyyy-MM-dd" for roadmap day 1...28 in the current repeating cycle.
    func calendarDateString(forMilestoneDay day: Int, calendar: Calendar = .current) -> String? {
        guard day >= 1, day <= 28 else { return nil }
        let anchor = currentCycleAnchorDate(calendar: calendar)
        guard let d = calendar.date(byAdding: .day, value: day - 1, to: anchor) else { return nil }
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    func isMilestoneToday(day: Int, calendar: Calendar = .current) -> Bool {
        currentCycleMilestoneDay(calendar: calendar) == day
    }

    /// 1-based week bucket within the 28-day window from plan start (for grouping in UI).
    func displayWeek(forMilestoneDay day: Int, calendar: Calendar = .current) -> Int {
        guard day >= 1, day <= 28 else { return 1 }
        return (day - 1) / 7 + 1
    }
}
