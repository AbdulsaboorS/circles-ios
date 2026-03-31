import SwiftUI

struct ReciprocityGateView: View {
    let prayerName: String
    let onPostTapped: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    SwiftUI.Circle()
                        .fill(Color(hex: "D4A240").opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(hex: "D4A240"))
                }

                VStack(spacing: 8) {
                    Text("It's \(prayerName) time")
                        .font(.appHeadline)
                        .foregroundStyle(Color(hex: "F0EAD6"))
                    Text("Post your Moment to unlock your circles.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color(hex: "8FAF94"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button(action: onPostTapped) {
                    Text("Unlock Your Circles")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: "1A2E1E"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color(hex: "D4A240"), in: Capsule())
                        .shadow(color: Color(hex: "D4A240").opacity(0.35), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
            }
        }
    }
}
