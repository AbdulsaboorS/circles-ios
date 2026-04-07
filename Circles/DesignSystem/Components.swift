import SwiftUI

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
