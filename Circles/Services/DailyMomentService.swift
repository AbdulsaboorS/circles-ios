import Foundation
import Observation
import Supabase

/// Manages the daily Moment gate state (BeReal-style).
/// The active window opens at a server-selected random UTC `moment_time`
/// (seeded by pg_cron daily at 00:05 UTC). Prayer anchoring lives in habits, not here.
@Observable
@MainActor
final class DailyMomentService {
    static let shared = DailyMomentService()
    private init() {}

    /// Pivot from `.windowOpen` to `.missedWindow` this many seconds after `windowStart`.
    /// This governs gate copy only (open vs missed CTA). On-time pill uses a tighter
    /// 5-minute threshold in `MomentService.computeIsOnTime` (D1).
    private static let missedWindowCutoff: TimeInterval = 30 * 60

    enum GateMode: Sendable {
        case preWindow       // today's window hasn't opened yet
        case windowOpen      // within 30 min of windowStart, not posted
        case missedWindow    // past 30 min, not posted — late-post CTA
        case posted          // already posted today
    }

    struct ActiveMomentRange: Sendable {
        let start: Date
        let endExclusive: Date

        var startISO8601: String { DailyMomentService.iso8601String(from: start) }
        var endExclusiveISO8601: String { DailyMomentService.iso8601String(from: endExclusive) }
    }

    // MARK: - Published State

    /// Legacy: kept for back-compat callers. Mechanic no longer anchors on prayers.
    var todayPrayerName: String = "asr"
    var windowStart: Date? = nil
    var hasPostedToday: Bool = false
    var isLoading: Bool = false
    /// Today's `daily_moments.moment_date` string ("YYYY-MM-DD" UTC). Source of truth
    /// for the `moment_date` column stamped on each posted `circle_moments` row.
    var currentWindowDate: String? = nil

    private var lastLoadedDate: String? = nil

    // MARK: - Computed Gate State

    var gateMode: GateMode {
        if hasPostedToday { return .posted }
        guard let start = windowStart else { return .preWindow }
        let now = Date()
        if now < start { return .preWindow }
        if now < start.addingTimeInterval(Self.missedWindowCutoff) { return .windowOpen }
        return .missedWindow
    }

    /// Gate should render for both open and missed-window states.
    var isGateActive: Bool {
        switch gateMode {
        case .windowOpen, .missedWindow: return true
        case .preWindow, .posted: return false
        }
    }

    var prayerDisplayName: String { todayPrayerName.capitalized }

    /// BeReal-Memories feed anchor. Yesterday's UTC date while today's window
    /// hasn't opened yet; otherwise today. Feed queries filter moments by this
    /// date so users continue seeing yesterday's posts until today's window pops.
    var activeFeedDate: String {
        switch gateMode {
        case .preWindow:
            return Self.utcDateString(from: Date().addingTimeInterval(-24 * 60 * 60))
        case .windowOpen, .missedWindow, .posted:
            return Self.utcDateString(from: Date())
        }
    }

    // MARK: - Load

    func load(userId: UUID) async {
        let today = todayUTCString()

        if lastLoadedDate == today, windowStart != nil {
            return
        }

        isLoading = true

        let dailyMoment = await fetchTodayDailyMoment()
        let prayer = dailyMoment?.prayerName ?? "asr"
        let newWindowStart: Date? = dailyMoment?.momentTime.flatMap(utcTimeToDate)
        let windowDate = dailyMoment?.momentDate ?? today

        let postedToday = await computeHasPostedToday(userId: userId, momentDate: windowDate)

        todayPrayerName = prayer
        hasPostedToday = postedToday
        windowStart = newWindowStart
        currentWindowDate = windowDate
        lastLoadedDate = today

        isLoading = false
    }

    /// Call immediately after a successful post to lift the gate.
    func markPostedToday() {
        hasPostedToday = true
    }

    /// Used by optimistic posting to roll back local state if the background post fails.
    func setPostedToday(_ posted: Bool) {
        hasPostedToday = posted
    }

    #if DEBUG
    func forceOpenWindow(userId: UUID) async {
        try? await MomentService.shared.deleteMyTodayMoments(userId: userId)
        try? await NiyyahService.shared.deleteTodayNiyyah(userId: userId)
        windowStart = Date().addingTimeInterval(-60)
        hasPostedToday = false
        lastLoadedDate = nil
        print("[DailyMomentService] DEBUG: force window opened, today's moments deleted")
    }
    #endif

    // MARK: - Ranges (back-compat)

    /// Back-compat range used by callers still filtering `circle_moments.posted_at` by
    /// the active day (Feed/MomentService update + delete paths). Returns today's
    /// UTC-day boundaries, matching the `moment_date` stamp.
    func fetchActiveMomentRange(referenceDate: Date = Date()) async -> ActiveMomentRange {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? cal.timeZone
        let start = cal.startOfDay(for: referenceDate)
        let end = cal.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(24 * 60 * 60)
        return ActiveMomentRange(start: start, endExclusive: end)
    }

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

    private func computeHasPostedToday(userId: UUID, momentDate: String) async -> Bool {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = (try? await SupabaseService.shared.client
            .from("circle_moments")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("moment_date", value: momentDate)
            .limit(1)
            .execute()
            .value) ?? []
        return !rows.isEmpty
    }

    private func todayUTCString() -> String {
        Self.utcDateString(from: Date())
    }

    private static func utcDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
