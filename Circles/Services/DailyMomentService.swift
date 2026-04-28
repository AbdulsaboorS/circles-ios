import Foundation
import Observation
import Supabase

/// Manages the daily Moment gate state (BeReal-style).
/// The active window opens at a server-selected random UTC `moment_time`
/// for the user's fixed BeReal-style region.
@Observable
@MainActor
final class DailyMomentService {
    static let shared = DailyMomentService()
    private init() {}

    /// Pivot from `.windowOpen` to `.missedWindow` this many seconds after `windowStart`.
    /// This governs gate copy only (open vs missed CTA). On-time pill uses a tighter
    /// 5-minute threshold in `MomentService.computeIsOnTime`.
    private static let missedWindowCutoff: TimeInterval = 30 * 60

    enum GateMode: Sendable {
        case preWindow
        case windowOpen
        case missedWindow
        case posted
    }

    struct ActiveMomentRange: Sendable {
        let start: Date
        let endExclusive: Date

        var startISO8601: String { DailyMomentService.iso8601String(from: start) }
        var endExclusiveISO8601: String { DailyMomentService.iso8601String(from: endExclusive) }
    }

    // MARK: - Published State

    var todayPrayerName: String = "asr"
    var region: MomentRegion = .inferFromDevice()
    var windowStart: Date? = nil
    var hasPostedToday: Bool = false
    var isLoading: Bool = false
    /// Today's `daily_moments.moment_date` string ("YYYY-MM-DD" in the user's region).
    var currentWindowDate: String? = nil

    private var lastLoadedKey: String? = nil

    // MARK: - Computed Gate State

    var gateMode: GateMode {
        if hasPostedToday { return .posted }
        guard let start = windowStart else { return .preWindow }
        let now = Date()
        if now < start { return .preWindow }
        if now < start.addingTimeInterval(Self.missedWindowCutoff) { return .windowOpen }
        return .missedWindow
    }

    var isGateActive: Bool {
        switch gateMode {
        case .windowOpen, .missedWindow:
            return true
        case .preWindow, .posted:
            return false
        }
    }

    var prayerDisplayName: String { todayPrayerName.capitalized }

    /// BeReal Memories pattern: yesterday until today's window opens, then today.
    var activeFeedDate: String {
        let today = todayInRegionString()
        switch gateMode {
        case .preWindow:
            return shiftedLocalDateString(from: today, dayOffset: -1) ?? today
        case .windowOpen, .missedWindow, .posted:
            return today
        }
    }

    // MARK: - Load

    func load(userId: UUID) async {
        let profile = try? await AvatarService.shared.fetchProfile(userId: userId)
        let resolvedRegion = profile?.region
            ?? MomentRegion.infer(from: profile?.timezone ?? TimeZone.current.identifier)

        if region != resolvedRegion {
            setRegion(resolvedRegion)
        }

        let today = todayInRegionString()
        let loadKey = "\(region.rawValue)|\(today)"
        if lastLoadedKey == loadKey, currentWindowDate == today {
            return
        }

        isLoading = true

        let dailyMoment = await fetchTodayDailyMoment()
        let prayer = dailyMoment?.prayerName ?? "asr"
        let newWindowStart = dailyMoment.flatMap(scheduledDate)
        let windowDate = dailyMoment?.momentDate ?? today
        let postedToday = await computeHasPostedToday(userId: userId, momentDate: windowDate)

        todayPrayerName = prayer
        hasPostedToday = postedToday
        windowStart = newWindowStart
        currentWindowDate = windowDate
        lastLoadedKey = loadKey
        isLoading = false
    }

    func setRegion(_ newRegion: MomentRegion) {
        region = newRegion
        windowStart = nil
        hasPostedToday = false
        currentWindowDate = nil
        lastLoadedKey = nil
    }

    func markPostedToday() {
        hasPostedToday = true
    }

    func setPostedToday(_ posted: Bool) {
        hasPostedToday = posted
    }

    #if DEBUG
    func forceOpenWindow(userId: UUID) async {
        try? await MomentService.shared.deleteMyTodayMoments(userId: userId)
        try? await NiyyahService.shared.deleteTodayNiyyah(userId: userId)
        windowStart = Date().addingTimeInterval(-60)
        hasPostedToday = false
        lastLoadedKey = nil
        print("[DailyMomentService] DEBUG: force window opened, today's moments deleted")
    }
    #endif

    // MARK: - Ranges

    func fetchActiveMomentRange(referenceDate: Date = Date()) async -> ActiveMomentRange {
        let localDate = currentWindowDate ?? todayInRegionString(referenceDate: referenceDate)
        return utcRange(for: localDate)
    }

    func utcRange(for localDate: String) -> ActiveMomentRange {
        guard let start = localStartDate(for: localDate, in: region) else {
            let fallbackStart = Date()
            return ActiveMomentRange(
                start: fallbackStart,
                endExclusive: fallbackStart.addingTimeInterval(24 * 60 * 60)
            )
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = region.timeZone
        let end = calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(24 * 60 * 60)
        return ActiveMomentRange(start: start, endExclusive: end)
    }

    func todayInRegionString(referenceDate: Date = Date()) -> String {
        Self.dateString(from: referenceDate, in: region.timeZone)
    }

    // MARK: - Private Helpers

    private func fetchTodayDailyMoment() async -> DailyMoment? {
        let today = todayInRegionString()
        let rows: [DailyMoment] = (try? await SupabaseService.shared.client
            .from("daily_moments")
            .select()
            .eq("region", value: region.rawValue)
            .eq("moment_date", value: today)
            .limit(1)
            .execute()
            .value) ?? []
        return rows.first
    }

    private func scheduledDate(for dailyMoment: DailyMoment) -> Date? {
        guard let momentTime = dailyMoment.momentTime else { return nil }
        return scheduledDate(
            for: dailyMoment.momentDate,
            utcTime: momentTime,
            region: dailyMoment.region ?? region
        )
    }

    private func scheduledDate(for localDate: String, utcTime: String, region: MomentRegion) -> Date? {
        let parts = utcTime.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              let baseUTCDate = utcDate(localDate: localDate, hour: hour, minute: minute) else {
            return nil
        }

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = region.timeZone

        for offset in [0, 1, -1] {
            guard let candidate = utcCalendar.date(byAdding: .day, value: offset, to: baseUTCDate) else {
                continue
            }

            let candidateLocalDate = Self.dateString(from: candidate, in: region.timeZone)
            let candidateLocalHour = localCalendar.component(.hour, from: candidate)
            if candidateLocalDate == localDate && (9..<24).contains(candidateLocalHour) {
                return candidate
            }
        }

        return baseUTCDate
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

    private func shiftedLocalDateString(from localDate: String, dayOffset: Int) -> String? {
        guard let start = localStartDate(for: localDate, in: region) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = region.timeZone
        guard let shifted = calendar.date(byAdding: .day, value: dayOffset, to: start) else { return nil }
        return Self.dateString(from: shifted, in: region.timeZone)
    }

    private func localStartDate(for localDate: String, in region: MomentRegion) -> Date? {
        let parts = localDate.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = region.timeZone
        return calendar.date(from: components)
    }

    private func utcDate(localDate: String, hour: Int, minute: Int) -> Date? {
        let parts = localDate.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: components)
    }

    private static func dateString(from date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }

    static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
