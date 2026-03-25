import SwiftUI

// MARK: - AppCard (D-17)

/// A rounded card container with automatic light/dark surface treatment.
/// - Dark mode: `.ultraThinMaterial` glassmorphism background
/// - Light mode: white background + subtle shadow
/// - Corner radius: 16pt (D-16)
struct AppCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.lightCardSurface)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - PrimaryButton (D-18)

/// Full-width amber CTA button with optional loading state.
/// Uses `Color.accent` (#E8834B) as background fill.
struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accent)
                    .frame(height: 52)

                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .disabled(isLoading)
    }
}

// MARK: - ChipButton (D-19)

/// Small pill-shaped chip button with filled (selected) and outlined (default) variants.
/// Used for habit chips, reaction chips, and filter chips.
struct ChipButton: View {
    let label: String
    var isSelected: Bool = false
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = systemImage {
                    Image(systemName: icon)
                        .font(.appCaption)
                }
                Text(label)
                    .font(.appCaptionMedium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isSelected ? Color.accent : Color.accent.opacity(0.15))
            }
            .foregroundStyle(isSelected ? .white : Color.accent)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SectionHeader (D-21)

/// Consistent section label style using New York serif headline.
/// Adapts text color based on current color scheme.
struct SectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var subtitle: String? = nil

    private var textColor: Color {
        colorScheme == .dark ? .darkTextPrimary : .lightTextPrimary
    }

    private var subtitleColor: Color {
        colorScheme == .dark ? .darkTextSecondary : .lightTextSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.appHeadline)
                .foregroundStyle(textColor)
            if let sub = subtitle {
                Text(sub)
                    .font(.appCaption)
                    .foregroundStyle(subtitleColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview("Components — Dark") {
    ZStack {
        AppBackground()
        VStack(spacing: 16) {
            SectionHeader(title: "Daily Intentions", subtitle: "3 habits today")
            AppCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sample Card Content").font(.appBody).foregroundStyle(Color.darkTextPrimary)
                }
                .padding()
            }
            HStack {
                ChipButton(label: "Salah", isSelected: true) {}
                ChipButton(label: "Quran", systemImage: "book.fill") {}
            }
            PrimaryButton(title: "Continue") {}
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("Components — Light") {
    ZStack {
        AppBackground()
        VStack(spacing: 16) {
            SectionHeader(title: "Daily Intentions", subtitle: "3 habits today")
            AppCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sample Card Content").font(.appBody).foregroundStyle(Color.lightTextPrimary)
                }
                .padding()
            }
            HStack {
                ChipButton(label: "Salah", isSelected: true) {}
                ChipButton(label: "Quran", systemImage: "book.fill") {}
            }
            PrimaryButton(title: "Continue") {}
        }
        .padding()
    }
    .preferredColorScheme(.light)
}
