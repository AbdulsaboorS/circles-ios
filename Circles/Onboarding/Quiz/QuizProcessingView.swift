import SwiftUI

/// Screen C — quiet "Building your intentions…" moment between struggle capture
/// and the suggestion list. Stubbed for Task 2; advances automatically when
/// `coordinator.loadSuggestions()` populates `suggestions`.
struct QuizProcessingView: View {
    @Bindable var coordinator: OnboardingQuizCoordinator

    @State private var pulseOpacity: Double = 0.55
    @State private var starAngle: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            IslamicGeometricPattern(opacity: 0.04, tileSize: 48)

            VStack(spacing: 28) {
                ZStack {
                    SwiftUI.Circle()
                        .fill(Color.msGold.opacity(0.08))
                        .frame(width: 160, height: 160)
                        .blur(radius: 28)
                        .opacity(pulseOpacity)

                    SwiftUI.Circle()
                        .stroke(Color.msGold.opacity(0.25), lineWidth: 1)
                        .frame(width: 120, height: 120)

                    Image(systemName: "sparkle")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(Color.msGold)
                        .rotationEffect(.degrees(starAngle))
                }

                VStack(spacing: 10) {
                    Text("Building your intentions…")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)

                    Text("Just a moment.")
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulseOpacity = 1.0
            }
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                starAngle = 360
            }
        }
    }
}
