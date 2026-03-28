import Foundation

struct Circle: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let createdBy: UUID
    let inviteCode: String?
    let momentWindowStart: String?   // TIMESTAMPTZ as String, per project convention
    let createdAt: Date
    var genderSetting: String?       // 'brothers' | 'sisters' | 'mixed'
    var groupStreakDays: Int?
    var coreHabits: [String]?        // JSON array of habit names e.g. ["Fajr", "Quran"]

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case createdBy = "created_by"
        case inviteCode = "invite_code"
        case momentWindowStart = "moment_window_start"
        case createdAt = "created_at"
        case genderSetting = "gender_setting"
        case groupStreakDays = "group_streak_days"
        case coreHabits = "core_habits"
    }
}

extension Circle {
    var genderSettingSafe: String { genderSetting ?? "mixed" }
    var groupStreakDaysSafe: Int { groupStreakDays ?? 0 }
    var coreHabitsSafe: [String] { coreHabits ?? [] }
}

