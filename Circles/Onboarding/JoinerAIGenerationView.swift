import SwiftUI

private extension Color {
    static let msBackground = Color(hex: "1A2E1E")
    static let msGold = Color(hex: "D4A240")
    static let msTextPrimary = Color(hex: "F0EAD6")
    static let msTextMuted = Color(hex: "8FAF94")
}

struct JoinerAIGenerationView: View {
    @Environment(MemberOnboardingCoordinator.self) private var coordinator

    let onComplete: () -> Void

    @State private var hasStarted = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 28) {
                    ZStack {
                        SwiftUI.Circle()
                            .fill(Color.msGold.opacity(0.08))
                            .frame(width: 140, height: 140)
                            .scaleEffect(pulse ? 1.08 : 0.92)
                            .opacity(pulse ? 0.95 : 0.55)
                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                        ProgressView()
                            .tint(Color.msGold)
                            .scaleEffect(1.6)
                    }

                    VStack(spacing: 10) {
                        Text("Generating your 28-day roadmaps\nbased on the Sunnah...")
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .foregroundStyle(Color.msTextPrimary)
                            .multilineTextAlignment(.center)

                        Text("You'll see them on your dashboard when ready.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                StepIndicator(current: 4, total: 7)
                    .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            pulse = true
            guard !hasStarted else { return }
            hasStarted = true
            Task { await coordinator.fireBackgroundPlans() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onComplete()
            }
        }
    }
}
