import Foundation
import Observation
import Supabase

/// Manages the Prayer of the Day gate state.
/// Determines which prayer is today's "Moment", when the 30-min window opens,
/// and whether the current user has already posted today.
@Observable
@MainActor
final class DailyMomentService {
    static let shared = DailyMomentService()
    private init() {}

    // MARK: - Published State
    var todayPrayerName: String = "asr"
    var windowStart: Date? = nil              // nil = couldn't determine prayer time
    var hasPostedToday: Bool = false
    var isLoading: Bool = false

    /// Prevents redundant Aladhan API + DB calls when already loaded today
    private var lastLoadedDate: String? = nil

    // MARK: - Computed Gate State

    /// Gate is active once the window opens AND user hasn't posted yet.
    var isGateActive: Bool {
        guard let start = windowStart else { return false }
        return Date() >= start && !hasPostedToday
    }

    var prayerDisplayName: String {
        todayPrayerName.capitalized
    }

    // MARK: - Load

    func load(userId: UUID) async {
        let today = todayUTCString()

        // Skip DB calls if already loaded today and window is set
        if lastLoadedDate == today, windowStart != nil {
            return
        }

        isLoading = true

        // 1. Compute all values locally before touching published state —
        //    prevents the gate from flickering on during intermediate states

        let dailyMoment = await fetchTodayDailyMoment()
        let prayer = dailyMoment?.prayerName ?? "asr"

        let newWindowStart: Date?
        if let timeStr = dailyMoment?.momentTime {
            // New: BeReal-style — use server-set random UTC time directly
            newWindowStart = utcTimeToDate(timeStr)
        } else {
            // Legacy fallback: calculate from prayer time via Aladhan API
            if let profile = try? await AvatarService.shared.fetchProfile(userId: userId),
               let lat = profile.latitude, lat != 0,
               let lng = profile.longitude, lng != 0,
               let tz = profile.timezone, !tz.isEmpty {
                newWindowStart = await fetchPrayerTime(prayer: prayer, lat: lat, lng: lng, timezone: tz)
            } else {
                newWindowStart = Calendar.current.startOfDay(for: Date())
            }
        }

        let postedToday = await computeHasPostedToday(userId: userId)

        // 2. Batch publish — hasPostedToday first so gate never flickers on
        todayPrayerName = prayer
        hasPostedToday = hasPostedToday || postedToday  // never downgrade from true within a day
        windowStart = newWindowStart
        lastLoadedDate = today

        isLoading = false
    }

    /// Call immediately after the user successfully posts a Moment to lift the gate.
    func markPostedToday() {
        hasPostedToday = true
    }

    /// Used by optimistic posting to roll back local state if the background post fails.
    func setPostedToday(_ posted: Bool) {
        hasPostedToday = posted
    }

    #if DEBUG
    /// Forces the gate open immediately — deletes today's DB rows, resets client state.
    func forceOpenWindow(userId: UUID) async {
        try? await MomentService.shared.deleteMyTodayMoments(userId: userId)
        try? await NiyyahService.shared.deleteTodayNiyyah(userId: userId)
        windowStart = Date().addingTimeInterval(-60)
        hasPostedToday = false
        lastLoadedDate = nil
        print("[DailyMomentService] DEBUG: force window opened, today's moments deleted")
    }
    #endif

    // MARK: - Private Helpers

    private func fetchTodayDailyMoment() async -> DailyMoment? {
        let today = todayUTCString()
        let rows: [DailyMoment] = (try? await SupabaseService.shared.client
            .from("daily_moments")
            .select()
            .eq("moment_date", value: today)
            .limit(1)
            .execute()
            .value) ?? []
        return rows.first
    }

    /// Parse "HH:MM" as a UTC time and combine with today's UTC date.
    private func utcTimeToDate(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let today = todayUTCString()
        return formatter.date(from: "\(today) \(timeString)")
    }

    private func fetchPrayerTime(prayer: String, lat: Double, lng: Double, timezone: String) async -> Date? {
        let timestamp = Int(Date().timeIntervalSince1970)
        let urlString = "https://api.aladhan.com/v1/timings/\(timestamp)?latitude=\(lat)&longitude=\(lng)&method=3"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            struct AladhanTimings: Decodable {
                let Fajr: String
                let Dhuhr: String
                let Asr: String
                let Maghrib: String
                let Isha: String
            }
            struct AladhanData: Decodable { let timings: AladhanTimings }
            struct AladhanResponse: Decodable { let data: AladhanData }

            let response = try JSONDecoder().decode(AladhanResponse.self, from: data)
            let t = response.data.timings

            let timeString: String
            switch prayer {
            case "fajr":    timeString = t.Fajr
            case "dhuhr":   timeString = t.Dhuhr
            case "asr":     timeString = t.Asr
            case "maghrib": timeString = t.Maghrib
            case "isha":    timeString = t.Isha
            default:        timeString = t.Asr
            }

            // Aladhan returns "HH:mm" or "HH:mm (EST)" — strip anything after space
            let cleanTime = String(timeString.split(separator: " ").first ?? Substring(timeString))
            return combineToDate(timeString: cleanTime, timezone: timezone)
        } catch {
            return nil
        }
    }

    private func combineToDate(timeString: String, timezone: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        let todayString = localDateString(timezone: timezone)
        return formatter.date(from: "\(todayString) \(timeString)")
    }

    private func computeHasPostedToday(userId: UUID) async -> Bool {
        let today = todayUTCString()
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = (try? await SupabaseService.shared.client
            .from("circle_moments")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .gte("posted_at", value: "\(today)T00:00:00Z")
            .lt("posted_at", value: "\(today)T23:59:59Z")
            .limit(1)
            .execute()
            .value) ?? []
        return !rows.isEmpty
    }

    private func todayUTCString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }

    private func localDateString(timezone: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: timezone) ?? .current
        return f.string(from: Date())
    }
}
