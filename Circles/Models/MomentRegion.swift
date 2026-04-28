import Foundation

enum MomentRegion: String, Codable, CaseIterable, Identifiable, Sendable {
    case americas
    case europe
    case eastAsia = "east_asia"
    case westAsia = "west_asia"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .americas:
            return "Americas"
        case .europe:
            return "Europe"
        case .eastAsia:
            return "East Asia"
        case .westAsia:
            return "West Asia"
        }
    }

    var summary: String {
        switch self {
        case .americas:
            return "Shared with Eastern time"
        case .europe:
            return "Shared with Paris time"
        case .eastAsia:
            return "Shared with Tokyo time"
        case .westAsia:
            return "Shared with Dubai time"
        }
    }

    var representativeTimezoneIdentifier: String {
        switch self {
        case .americas:
            return "America/New_York"
        case .europe:
            return "Europe/Paris"
        case .eastAsia:
            return "Asia/Tokyo"
        case .westAsia:
            return "Asia/Dubai"
        }
    }

    var timeZone: TimeZone {
        TimeZone(identifier: representativeTimezoneIdentifier)
            ?? TimeZone(secondsFromGMT: 0)
            ?? .current
    }

    static func infer(from timezoneIdentifier: String?) -> MomentRegion {
        guard let timezoneIdentifier, !timezoneIdentifier.isEmpty else {
            return .americas
        }

        if timezoneIdentifier.hasPrefix("America/")
            || timezoneIdentifier.hasPrefix("US/")
            || timezoneIdentifier.hasPrefix("Canada/") {
            return .americas
        }

        if timezoneIdentifier.hasPrefix("Europe/")
            || timezoneIdentifier.hasPrefix("Africa/")
            || timezoneIdentifier.hasPrefix("Atlantic/") {
            return .europe
        }

        if timezoneIdentifier.hasPrefix("Asia/Tok")
            || timezoneIdentifier == "Asia/Seoul"
            || timezoneIdentifier.hasPrefix("Asia/Shang")
            || timezoneIdentifier.hasPrefix("Asia/Hong")
            || timezoneIdentifier == "Asia/Taipei"
            || timezoneIdentifier.hasPrefix("Asia/Singap")
            || timezoneIdentifier.hasPrefix("Australia/")
            || timezoneIdentifier.hasPrefix("Pacific/") {
            return .eastAsia
        }

        if timezoneIdentifier.hasPrefix("Asia/")
            || timezoneIdentifier.hasPrefix("Indian/") {
            return .westAsia
        }

        return .americas
    }

    static func inferFromDevice() -> MomentRegion {
        infer(from: TimeZone.current.identifier)
    }
}
