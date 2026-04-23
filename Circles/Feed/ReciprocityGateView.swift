import SwiftUI

struct ReciprocityGateView: View {
    enum Mode {
        case open
        case missed

        var title: String {
            switch self {
            case .open:   return "Time to share your Moment"
            case .missed: return "You missed today's Moment"
            }
        }

        var subtitle: String {
            switch self {
            case .open:   return "Your circle is waiting. Share this moment to unlock."
            case .missed: return "Post a late one to unlock everyone else's Moments."
            }
        }

        var buttonTitle: String {
            switch self {
            case .open:   return "Share your Moment"
            case .missed: return "Post a late Moment"
            }
        }
    }

    var mode: Mode = .open
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
                    Text(mode.title)
                        .font(.appHeadline)
                        .foregroundStyle(Color(hex: "F0EAD6"))
                    Text(mode.subtitle)
                        .font(.appSubheadline)
                        .foregroundStyle(Color(hex: "8FAF94"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button(action: onPostTapped) {
                    Text(mode.buttonTitle)
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
