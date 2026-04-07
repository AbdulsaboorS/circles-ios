import SwiftUI

// MARK: - ThemeManager

/// Enforces dark mode throughout the app.
/// The Midnight Sanctuary palette is designed exclusively for dark mode.
@Observable
@MainActor
final class ThemeManager {

    static let shared = ThemeManager()

    /// Always `.dark` — Midnight Sanctuary is dark-mode only.
    let colorScheme: ColorScheme = .dark

    private init() {}
}
