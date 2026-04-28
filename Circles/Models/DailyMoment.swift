import Foundation

/// Represents the server-selected "Prayer of the Day" for Circle Moments.
/// One row per calendar date. The server-side cron picks which prayer is
/// today's global Moment trigger.
struct DailyMoment: Codable, Identifiable, Sendable {
    let id: UUID
    let prayerName: String   // "fajr" | "dhuhr" | "asr" | "maghrib" | "isha"
    let region: MomentRegion?
    let momentDate: String   // Region-local DATE stored as String "YYYY-MM-DD"
    let momentTime: String?  // "HH:MM" in UTC for the region's shared window
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case prayerName = "prayer_name"
        case region
        case momentDate = "moment_date"
        case momentTime = "moment_time"
        case createdAt = "created_at"
    }
}

extension DailyMoment {
    var prayerDisplayName: String {
        switch prayerName {
        case "fajr":    return "Fajr"
        case "dhuhr":   return "Dhuhr"
        case "asr":     return "Asr"
        case "maghrib": return "Maghrib"
        case "isha":    return "Isha"
        default:        return prayerName.capitalized
        }
    }
}
