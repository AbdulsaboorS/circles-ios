import SwiftUI

/// Root view for the Amir onboarding flow.
/// Manages the NavigationStack and routes all 7 steps + 2 transition screens.
struct AmiirOnboardingFlowView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coord = coordinator
        NavigationStack(path: $coord.navigationPath) {
            AmiirLandingSanctuaryView()
                .navigationDestination(for: AmiirOnboardingCoordinator.Step.self) { step in
                    switch step {
                    case .sharedPersonalization:
                        AmiirSharedPersonalizationView()
                    case .coreHabits:
                        AmiirStep2HabitsView()
                    case .circleIdentity:
                        AmiirStep1IdentityView()
                    case .transitionToAI:
                        // "Some growth is private" — bridges identity to the private quiz
                        OnboardingTransitionView(
                            quote: OnboardingTransitionQuote.amirPrivateToAI,
                            attribution: nil,
                            subtitle: "Next, let's talk through a habit you can personally work on."
                        ) {
                            coordinator.proceedToOnboardingQuiz()
                        }
                    case .onboardingQuiz:
                        AmiirQuizStepView()
                    case .momentPrimer:
                        OnboardingMomentPrimerView(currentStep: 5, totalSteps: 8) {
                            coordinator.proceedToAIGeneration()
                        }
                    case .aiGeneration:
                        AmiirAIGenerationView {
                            coordinator.proceedToFoundation()
                        }
                    case .foundation:
                        AmiirStep3LocationView()
                    case .activation:
                        AmiirActivationView()
                    }
                }
        }
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let current: Int  // 1-indexed; current step the user is on (1...total)
    let total: Int

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return min(1, max(0, CGFloat(current) / CGFloat(total)))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.msGold.opacity(0.15))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.msGold.opacity(0.85), Color.msGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * progress))
                    .animation(.spring(duration: 0.55, bounce: 0.18), value: progress)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .accessibilityElement()
        .accessibilityLabel("Step \(current) of \(total)")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}
