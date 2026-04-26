import SwiftUI

struct AmiirAIGenerationView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator

    let onComplete: () -> Void

    @State private var hasStarted = false
    @State private var pulse = false
    @State private var phase: Phase = .generating

    private enum Phase { case generating, ready }

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

                        if phase == .generating {
                            ProgressView()
                                .tint(Color.msGold)
                                .scaleEffect(1.6)
                                .transition(.opacity)

                            Image(systemName: "sparkles")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(Color.msGold.opacity(0.85))
                                .offset(y: -34)
                                .transition(.opacity)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 56, weight: .regular))
                                .foregroundStyle(Color.msGold)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    VStack(spacing: 12) {
                        Text(phase == .generating
                             ? "Generating your 28-day roadmaps\nbased on the Sunnah..."
                             : "Your plan is ready.")
                            .font(.system(size: 21, weight: .medium, design: .serif))
                            .foregroundStyle(Color.msTextPrimary)
                            .multilineTextAlignment(.center)

                        Text(phase == .generating
                             ? "You'll see them on your dashboard when ready."
                             : "It'll be waiting for you on your dashboard.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                    }
                    .animation(.easeInOut(duration: 0.35), value: phase)
                }

                Spacer()

                StepIndicator(current: 5, total: 8)
                    .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            pulse = true
            guard !hasStarted else { return }
            hasStarted = true
            Task { await coordinator.fireBackgroundPlans() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    phase = .ready
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                onComplete()
            }
        }
    }
}
