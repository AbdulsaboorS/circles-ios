import SwiftUI

// MARK: - Primitive Color Tokens (D-01 through D-15)

extension Color {

    // MARK: Backgrounds
    /// D-01: Warm near-black — the dark mode background color
    static let darkBackground   = Color(hex: "0E0B08")
    /// D-02: Warm cream — the light mode background color
    static let lightBackground  = Color(hex: "F5F0E8")

    // MARK: Blobs
    /// D-11: Forest green — dark mode blob color
    static let darkBlob         = Color(hex: "1A3A2A")
    /// D-12: Warm beige — light mode blob color
    static let lightBlob        = Color(hex: "EDE0C8")

    // MARK: Accent
    /// D-03: Amber — same in both light and dark modes
    static let accent           = Color(hex: "E8834B")

    // MARK: Text
    static let darkTextPrimary   = Color.white
    static let darkTextSecondary = Color.white.opacity(0.6)
    /// D: Near-black warm — light mode primary text
    static let lightTextPrimary  = Color(hex: "1A1209")
    /// D: Warm brown-grey — light mode secondary text
    static let lightTextSecondary = Color(hex: "6B5B45")

    // MARK: Card surfaces
    /// D-15: White card surface for light mode (dark uses .ultraThinMaterial at call site)
    static let lightCardSurface = Color.white
}

// MARK: - Semantic Token Resolver (D-07)

/// Resolves the full D-07 semantic color set for a given ColorScheme.
/// Usage inside a View body:
///   `let colors = AppColors.resolve(colorScheme)`
struct AppColors {
    let background: Color
    let blobPrimary: Color
    let blobSecondary: Color
    let textPrimary: Color
    let textSecondary: Color
    /// Light mode: `.lightCardSurface`; dark mode: `.clear` — use `.ultraThinMaterial` at the call site.
    let cardSurface: Color
    let accent: Color

    static func resolve(_ scheme: ColorScheme) -> AppColors {
        switch scheme {
        case .dark:
            return AppColors(
                background:    .darkBackground,
                blobPrimary:   .darkBlob,
                blobSecondary: .darkBlob.opacity(0.6),
                textPrimary:   .darkTextPrimary,
                textSecondary: .darkTextSecondary,
                cardSurface:   .clear,   // dark cards → .ultraThinMaterial at call site
                accent:        .accent
            )
        default: // .light
            return AppColors(
                background:    .lightBackground,
                blobPrimary:   .lightBlob,
                blobSecondary: .lightBlob.opacity(0.7),
                textPrimary:   .lightTextPrimary,
                textSecondary: .lightTextSecondary,
                cardSurface:   .lightCardSurface,
                accent:        .accent
            )
        }
    }
}

// MARK: - D-07 Semantic Alias Static Wrappers

/// Per D-07: expose static semantic aliases as Color properties.
/// These resolve to DARK variant by default.
/// For adaptive light/dark colors in a View, use `AppColors.resolve(colorScheme)`.
extension Color {
    /// D-07: semantic alias — resolves to dark variant by default.
    static var appBackground: Color  { .darkBackground }
    static var cardSurface: Color    { .lightCardSurface }
    static var textPrimary: Color    { .darkTextPrimary }
    static var textSecondary: Color  { .darkTextSecondary }
    static var blobPrimary: Color    { .darkBlob }
    static var blobSecondary: Color  { .darkBlob.opacity(0.6) }
}

// MARK: - Typography Tokens (D-04, D-05)

extension Font {
    // MARK: New York serif — D-04 — greeting headers and hero text
    /// 34pt New York serif, scales relative to .largeTitle
    static let appHeroTitle  = Font.custom("NewYork", size: 34, relativeTo: .largeTitle)
    /// 28pt New York serif, scales relative to .title
    static let appTitle      = Font.custom("NewYork", size: 28, relativeTo: .title)
    /// 22pt New York serif, scales relative to .title2
    static let appHeadline   = Font.custom("NewYork", size: 22, relativeTo: .title2)

    // MARK: SF Pro — D-05 — body, labels, UI
    static let appBody          = Font.system(size: 17, weight: .regular,  design: .default)
    static let appSubheadline   = Font.system(size: 15, weight: .medium,   design: .default)
    static let appCaption       = Font.system(size: 13, weight: .regular,  design: .default)
    static let appCaptionMedium = Font.system(size: 13, weight: .medium,   design: .default)
}
