import Foundation

enum JourneyDateSupport {
    private static let utcTimeZone = TimeZone(identifier: "UTC") ?? .gmt

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        calendar.timeZone = utcTimeZone
        return calendar
    }

    static func monthAnchor(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: DateComponents(
            timeZone: utcTimeZone,
            year: components.year,
            month: components.month,
            day: 1,
            hour: 12
        )) ?? date
    }

    static func monthKey(for anchor: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone = utcTimeZone
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: anchor)
    }

    static func monthTitle(for anchor: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone = utcTimeZone
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: anchor)
    }

    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone = utcTimeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func date(from dayKey: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone = utcTimeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: "\(dayKey) 12:00")
    }

    static func formattedDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone = utcTimeZone
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    static func weekdaySymbols() -> [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        let symbols = formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? []
        guard !symbols.isEmpty else { return ["S", "M", "T", "W", "T", "F", "S"] }

        let firstWeekdayIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }

    static func leadingEmptyCellCount(for monthAnchor: Date) -> Int {
        let weekday = calendar.component(.weekday, from: monthAnchor)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    static func daysInMonth(for monthAnchor: Date) -> Int {
        calendar.range(of: .day, in: .month, for: monthAnchor)?.count ?? 0
    }

    static func dayDate(day: Int, monthAnchor: Date) -> Date? {
        calendar.date(byAdding: .day, value: day - 1, to: monthAnchor)
    }

    static func monthBounds(for monthAnchor: Date) -> (start: String, endExclusive: String) {
        let start = dayKey(for: monthAnchor)
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
        let end = dayKey(for: nextMonth)
        return (start, end)
    }

    static func isToday(_ date: Date) -> Bool {
        dayKey(for: date) == dayKey(for: Date())
    }
}
