import SwiftUI

// MARK: - Theme Mode

/// Controls how the app chooses its light or dark color scheme.
enum ThemeMode: String, CaseIterable {
    /// Auto: switches to light at local sunrise, dark at local sunset.
    case auto
    /// Always render in light mode regardless of time.
    case alwaysLight
    /// Always render in dark mode regardless of time.
    case alwaysDark
}

// MARK: - ThemeManager

@Observable
@MainActor
final class ThemeManager {

    // MARK: Singleton

    static let shared = ThemeManager()

    // MARK: Published State

    /// The effective color scheme to apply via `.preferredColorScheme()` at root level.
    var colorScheme: ColorScheme = .dark

    /// Current mode — persisted to UserDefaults on change.
    var mode: ThemeMode = .alwaysLight {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "themeMode")
            applyMode()
        }
    }

    // MARK: Private

    private var sunriseTimer: Timer?
    private var sunsetTimer: Timer?

    // MARK: Init

    private init() {
        // Restore saved mode
        if let raw = UserDefaults.standard.string(forKey: "themeMode"),
           let saved = ThemeMode(rawValue: raw) {
            // Assign directly to avoid triggering didSet before init is complete
            _mode = saved
        }
        applyMode()
    }

    // MARK: - Public API

    /// Call on app launch and on applicationDidBecomeActive to (re-)schedule timers.
    func scheduleAutoSwitch() {
        guard mode == .auto else { return }
        invalidateTimers()

        guard let (sunrise, sunset) = todaySunTimes() else {
            // No lat/lng stored yet — use time-of-day heuristic (6am light, 8pm dark)
            applyTimeHeuristic()
            return
        }

        let now = Date()
        colorScheme = (now >= sunrise && now < sunset) ? .light : .dark

        scheduleTimer(at: sunrise) { [weak self] in
            Task { @MainActor [weak self] in self?.colorScheme = .light }
        }
        scheduleTimer(at: sunset) { [weak self] in
            Task { @MainActor [weak self] in self?.colorScheme = .dark }
        }
    }

    // MARK: - Private Helpers

    private func applyMode() {
        switch mode {
        case .alwaysLight:
            colorScheme = .light
            invalidateTimers()
        case .alwaysDark:
            colorScheme = .dark
            invalidateTimers()
        case .auto:
            scheduleAutoSwitch()
        }
    }

    /// Reads lat/lng stored by LocationPickerView during onboarding and returns
    /// today's sunrise and sunset using the NOAA solar calculation algorithm.
    private func todaySunTimes() -> (sunrise: Date, sunset: Date)? {
        let lat = UserDefaults.standard.double(forKey: "cityLatitude")
        let lng = UserDefaults.standard.double(forKey: "cityLongitude")
        guard lat != 0 || lng != 0 else { return nil }
        return SolarCalculator.sunriseSunset(latitude: lat, longitude: lng, date: Date())
    }

    private func applyTimeHeuristic() {
        let hour = Calendar.current.component(.hour, from: Date())
        colorScheme = (hour >= 6 && hour < 20) ? .light : .dark
    }

    private func scheduleTimer(at date: Date, action: @escaping @Sendable () -> Void) {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in action() }
        }
        if sunriseTimer == nil {
            sunriseTimer = t
        } else {
            sunsetTimer = t
        }
    }

    private func invalidateTimers() {
        sunriseTimer?.invalidate()
        sunriseTimer = nil
        sunsetTimer?.invalidate()
        sunsetTimer = nil
    }
}

// MARK: - Solar Calculator (NOAA algorithm — no external dependencies)

/// Pure Swift sunrise/sunset calculator using the NOAA solar calculation algorithm.
/// Accurate to ±1 minute for latitudes between ±60°.
private enum SolarCalculator {

    /// Returns local sunrise and sunset dates for the given lat/lng and calendar date.
    /// Returns nil if no sunrise or sunset occurs on that date (polar regions).
    static func sunriseSunset(latitude: Double, longitude: Double, date: Date) -> (sunrise: Date, sunset: Date)? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else { return nil }

        let jd = julianDay(year: year, month: month, day: day)

        guard let sunriseMinutes = solarEvent(jd: jd, latitude: latitude, longitude: longitude, isSunrise: true),
              let sunsetMinutes  = solarEvent(jd: jd, latitude: latitude, longitude: longitude, isSunrise: false)
        else { return nil }

        guard let sunriseDate = minutesToDate(minutes: sunriseMinutes, date: date, calendar: calendar),
              let sunsetDate  = minutesToDate(minutes: sunsetMinutes,  date: date, calendar: calendar)
        else { return nil }

        return (sunriseDate, sunsetDate)
    }

    // MARK: - Julian Day

    private static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = year
        var m = month
        if m <= 2 { y -= 1; m += 12 }
        let A = Int(Double(y) / 100.0)
        let B = 2 - A + Int(Double(A) / 4.0)
        return Double(Int(365.25 * Double(y + 4716))) + Double(Int(30.6001 * Double(m + 1))) + Double(day) + Double(B) - 1524.5
    }

    // MARK: - Solar Event Calculation

    /// Returns minutes past UTC midnight for the solar event, or nil for polar day/night.
    private static func solarEvent(jd: Double, latitude: Double, longitude: Double, isSunrise: Bool) -> Double? {
        // Julian centuries from J2000.0
        let jcent = (jd - 2451545.0) / 36525.0

        // Mean longitude and mean anomaly (degrees)
        let l0 = (280.46646 + jcent * (36000.76983 + jcent * 0.0003032)).truncatingRemainder(dividingBy: 360)
        let m  = 357.52911 + jcent * (35999.05029 - 0.0001537 * jcent)
        let mRad = deg2rad(m)

        // Equation of center
        let c = sin(mRad) * (1.914602 - jcent * (0.004817 + 0.000014 * jcent))
            + sin(2 * mRad) * (0.019993 - 0.000101 * jcent)
            + sin(3 * mRad) * 0.000289

        // Sun's true longitude and apparent longitude
        let sunLon = l0 + c
        let omega  = 125.04 - 1934.136 * jcent
        let lambda = sunLon - 0.00569 - 0.00478 * sin(deg2rad(omega))

        // Mean obliquity of the ecliptic (corrected)
        let epsilon0 = 23.0 + (26.0 + (21.448 - jcent * (46.8150 + jcent * (0.00059 - jcent * 0.001813))) / 60.0) / 60.0
        let epsilon  = epsilon0 + 0.00256 * cos(deg2rad(omega))

        // Sun's right ascension and declination
        let sinDec = sin(deg2rad(epsilon)) * sin(deg2rad(lambda))
        let decRad = asin(sinDec)

        // Equation of time (minutes)
        let y     = tan(deg2rad(epsilon / 2)) * tan(deg2rad(epsilon / 2))
        let l0Rad = deg2rad(l0)
        let mRad2 = deg2rad(m)
        let eot = 4 * rad2deg(
            y * sin(2 * l0Rad)
            - 2 * 0.016708634 * sin(mRad2)
            + 4 * 0.016708634 * y * sin(mRad2) * cos(2 * l0Rad)
            - 0.5 * y * y * sin(4 * l0Rad)
            - 1.25 * 0.016708634 * 0.016708634 * sin(2 * mRad2)
        )

        // Solar noon in minutes from UTC midnight
        let solarNoon = 720 - 4 * longitude - eot

        // Hour angle for sunrise/sunset (zenith = 90.833°)
        let latRad = deg2rad(latitude)
        let cosHA = cos(deg2rad(90.833)) / (cos(latRad) * cos(decRad)) - tan(latRad) * tan(decRad)

        guard cosHA >= -1 && cosHA <= 1 else { return nil } // polar day or night

        let ha = rad2deg(acos(cosHA)) // in degrees

        return isSunrise ? solarNoon - 4 * ha : solarNoon + 4 * ha
    }

    // MARK: - Helpers

    private static func minutesToDate(minutes: Double, date: Date, calendar: Calendar) -> Date? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let midnight = calendar.date(from: components) else { return nil }
        return midnight.addingTimeInterval(minutes * 60)
    }

    private static func deg2rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func rad2deg(_ r: Double) -> Double { r * 180 / .pi }
}
