import SwiftUI

private extension Color {
    static let msBackground = Color(hex: "1A2E1E")
    static let msGold = Color(hex: "D4A240")
    static let msTextPrimary = Color(hex: "F0EAD6")
    static let msTextMuted = Color(hex: "8FAF94")
}

/// Shared transition quotes used between onboarding steps.
enum OnboardingTransitionQuote {
    static let amirSharedToPrivate = "The believers, in their mutual love and mercy, are like one body — when one part hurts, the whole body responds."
    static let amirPrivateToAI = "Some growth is shared; some is between you and your Creator."
    static let joinerSharedToPrivate = "Shared growth is powerful, but some habits are just for you and Allah."
}

struct OnboardingTransitionView: View {
    let quote: String
    let attribution: String?
    let onSkip: () -> Void

    @State private var opacity: Double = 0
    @State private var hasCompleted = false

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.msGold.opacity(0.6))

                Text(quote)
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 36)

                if let attribution {
                    Text(attribution)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                }
            }
            .opacity(opacity)
            .animation(.easeIn(duration: 0.4), value: opacity)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            completeIfNeeded()
        }
        .onAppear {
            opacity = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                completeIfNeeded()
            }
        }
        .navigationBarBackButtonHidden()
    }

    private func completeIfNeeded() {
        guard !hasCompleted else { return }
        hasCompleted = true
        onSkip()
    }
}
