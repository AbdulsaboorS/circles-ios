import SwiftUI

/// Full-feed blur overlay shown when the Circle Moment window is open
/// and the user hasn't posted their Moment yet.
struct ReciprocityGateView: View {
    let prayerName: String
    let onPostTapped: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Frosted blur
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Icon
                ZStack {
                    SwiftUI.Circle()
                        .fill(Color.accent.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.accent)
                }

                VStack(spacing: 8) {
                    Text("It's \(prayerName) time")
                        .font(.appHeadline)
                        .foregroundStyle(Color.textPrimary)

                    Text("Post your Moment to unlock your circles.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                PrimaryButton(title: "Unlock Your Circles") {
                    onPostTapped()
                }
                .padding(.horizontal, 40)
            }
        }
    }
}
