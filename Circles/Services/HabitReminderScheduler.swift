import Foundation
import UserNotifications

@MainActor
final class HabitReminderScheduler {
    static let shared = HabitReminderScheduler()

    private let reminderPrefix = "habit-reminder:"
    private let scheduleWindowDays = 7

    private init() {}

    func resync(
        userId: UUID,
        permissionStatus: UNAuthorizationStatus,
        preferences: NotificationPreferences?
    ) async {
        let center = UNUserNotificationCenter.current()
        let existingIdentifiers = await reminderIdentifiers()
        removeRequests(withIdentifiers: existingIdentifiers, center: center)

        guard permissionStatus.allowsUserNotifications,
              preferences?.notificationsEnabled != false,
              preferences?.habitRemindersEnabled != false else {
            return
        }

        let profile = try? await AvatarService.shared.fetchProfile(userId: userId)
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let dateFormatter = Self.localDateFormatter()

        async let habitsFetch = HabitService.shared.fetchActiveHabits(userId: userId)
        async let logsFetch = HabitService.shared.fetchLogsInRange(
            userId: userId,
            from: dateFormatter.string(from: today),
            to: dateFormatter.string(
                from: calendar.date(byAdding: .day, value: scheduleWindowDays - 1, to: today) ?? today
            )
        )

        guard let habits = try? await habitsFetch else { return }
        let logs = (try? await logsFetch) ?? []
        let completedKeys = Set(
            logs.filter(\.completed).map { Self.logKey(habitId: $0.habitId, date: $0.date) }
        )

        var prayerCache: [String: Date?] = [:]

        for habit in habits {
            for dayOffset in 0..<scheduleWindowDays {
                guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
                let dateString = dateFormatter.string(from: targetDay)
                guard !completedKeys.contains(Self.logKey(habitId: habit.id, date: dateString)) else { continue }

                let fireDate = await reminderDate(
                    for: habit,
                    on: targetDay,
                    profile: profile,
                    prayerCache: &prayerCache
                )

                guard fireDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Time for \(habit.name)"
                content.body = "Open Circles to check in for today's intention."
                content.sound = .default
                content.userInfo = [
                    "type": AppNotificationType.habitReminder.rawValue,
                    "route": HomeNotificationDestination.habitDetail.rawValue,
                    "habit_id": habit.id.uuidString
                ]

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: identifier(for: habit.id, dateString: dateString),
                    content: content,
                    trigger: trigger
                )

                do {
                    try await add(request, center: center)
                } catch {
                    print("[HabitReminderScheduler] Failed to add request: \(error)")
                }
            }
        }
    }

    func removeAllPendingRequests() async {
        let center = UNUserNotificationCenter.current()
        let identifiers = await reminderIdentifiers()
        removeRequests(withIdentifiers: identifiers, center: center)
    }

    private func reminderIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let identifiers = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(self.reminderPrefix) }
                continuation.resume(returning: identifiers)
            }
        }
    }

    private func add(_ request: UNNotificationRequest, center: UNUserNotificationCenter) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func removeRequests(withIdentifiers identifiers: [String], center: UNUserNotificationCenter) {
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func reminderDate(
        for habit: Habit,
        on day: Date,
        profile: Profile?,
        prayerCache: inout [String: Date?]
    ) async -> Date {
        switch reminderAnchor(for: habit) {
        case .fixed(let hour, let minute):
            return fixedDate(on: day, hour: hour, minute: minute)
        case .prayer(let prayerName):
            return await prayerReminderDate(
                prayerName: prayerName,
                on: day,
                profile: profile,
                prayerCache: &prayerCache
            )
        }
    }

    static func requiresPrayerTimes(habitName: String) -> Bool {
        let name = habitName.lowercased()
        return name.contains("fajr")
            || name.contains("dhuhr")
            || name.contains("asr")
            || name.contains("maghrib")
            || name.contains("isha")
            || name.contains("salah")
            || name.contains("salat")
            || name.contains("prayer")
    }

    private func reminderAnchor(for habit: Habit) -> ReminderAnchor {
        let name = habit.name.lowercased()

        if name.contains("tahajjud") {
            return .fixed(hour: 21, minute: 30)
        }
        if name.contains("fajr") {
            return .prayer("fajr")
        }
        if name.contains("dhuhr") {
            return .prayer("dhuhr")
        }
        if name.contains("asr") {
            return .prayer("asr")
        }
        if name.contains("maghrib") {
            return .prayer("maghrib")
        }
        if name.contains("isha") {
            return .prayer("isha")
        }
        if Self.requiresPrayerTimes(habitName: habit.name) {
            return .prayer("dhuhr")
        }
        if name.contains("reflection")
            || name.contains("journal")
            || name.contains("diary")
            || name.contains("gratitude") {
            return .fixed(hour: 20, minute: 30)
        }
        if name.contains("evening") || name.contains("night") {
            return .fixed(hour: 19, minute: 30)
        }
        if name.contains("morning")
            || name.contains("quran")
            || name.contains("qur")
            || name.contains("dhikr")
            || name.contains("zikr")
            || name.contains("fast")
            || name.contains("sawm")
            || name.contains("water")
            || name.contains("drink")
            || name.contains("walk")
            || name.contains("exercise")
            || name.contains("gym") {
            return .fixed(hour: 8, minute: 0)
        }
        return .fixed(hour: 18, minute: 0)
    }

    private func prayerReminderDate(
        prayerName: String,
        on day: Date,
        profile: Profile?,
        prayerCache: inout [String: Date?]
    ) async -> Date {
        let fallback = fixedDate(on: day, hour: 13, minute: 0)

        guard let profile,
              let latitude = profile.latitude, latitude != 0,
              let longitude = profile.longitude, longitude != 0,
              let timezone = profile.timezone, !timezone.isEmpty else {
            return fallback
        }

        let dayKey = Self.dateString(from: day, timezone: timezone)
        let cacheKey = "\(prayerName)|\(dayKey)|\(timezone)"
        if let cached = prayerCache[cacheKey] {
            return cached ?? fallback
        }

        let reminderDate = await fetchPrayerTime(
            prayer: prayerName,
            on: day,
            latitude: latitude,
            longitude: longitude,
            timezone: timezone
        )?.addingTimeInterval(-10 * 60)

        prayerCache[cacheKey] = reminderDate
        return reminderDate ?? fallback
    }

    private func fetchPrayerTime(
        prayer: String,
        on day: Date,
        latitude: Double,
        longitude: Double,
        timezone: String
    ) async -> Date? {
        let timestamp = Int(referenceDate(for: day, timezone: timezone).timeIntervalSince1970)
        let urlString = "https://api.aladhan.com/v1/timings/\(timestamp)?latitude=\(latitude)&longitude=\(longitude)&method=3"
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
            let timings = response.data.timings

            let rawTime: String
            switch prayer {
            case "fajr":
                rawTime = timings.Fajr
            case "dhuhr":
                rawTime = timings.Dhuhr
            case "asr":
                rawTime = timings.Asr
            case "maghrib":
                rawTime = timings.Maghrib
            case "isha":
                rawTime = timings.Isha
            default:
                rawTime = timings.Dhuhr
            }

            let cleanTime = String(rawTime.split(separator: " ").first ?? Substring(rawTime))
            return combineToDate(timeString: cleanTime, on: day, timezone: timezone)
        } catch {
            print("[HabitReminderScheduler] Prayer lookup failed: \(error)")
            return nil
        }
    }

    private func combineToDate(timeString: String, on day: Date, timezone: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        return formatter.date(from: "\(Self.dateString(from: day, timezone: timezone)) \(timeString)")
    }

    private func fixedDate(on day: Date, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: day
        ) ?? day
    }

    private func referenceDate(for day: Date, timezone: String) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone) ?? .current
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: components.year,
                month: components.month,
                day: components.day,
                hour: 12
            )
        ) ?? day
    }

    private func identifier(for habitId: UUID, dateString: String) -> String {
        "\(reminderPrefix)\(habitId.uuidString):\(dateString)"
    }

    private static func localDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }

    private static func dateString(from date: Date, timezone: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        return formatter.string(from: date)
    }

    private static func logKey(habitId: UUID, date: String) -> String {
        "\(habitId.uuidString)|\(date)"
    }
}

private enum ReminderAnchor {
    case fixed(hour: Int, minute: Int)
    case prayer(String)
}
