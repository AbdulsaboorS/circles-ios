import SwiftUI

/// Root view for the Joiner onboarding flow.
/// Manages the NavigationStack and routes the joiner onboarding sequence.
struct MemberOnboardingFlowView: View {
    @Environment(MemberOnboardingCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coord = coordinator
        NavigationStack(path: $coord.navigationPath) {
            JoinerLandingView()
                .navigationDestination(for: MemberOnboardingCoordinator.Step.self) { step in
                    switch step {
                    case .transitionToCircle:
                        OnboardingTransitionView(
                            quote: OnboardingTransitionQuote.amirSharedToPrivate,
                            attribution: nil
                        ) {
                            coordinator.proceedToCircleAlignment()
                        }

                    case .circleAlignment:
                        JoinerCircleAlignmentView()

                    case .onboardingQuiz:
                        JoinerQuizStepView()

                    case .transitionToAI:
                        OnboardingTransitionView(
                            quote: OnboardingTransitionQuote.amirPrivateToAI,
                            attribution: nil,
                            subtitle: "Next, let's talk through a habit you can personally work on."
                        ) {
                            coordinator.proceedToOnboardingQuiz()
                        }

                    case .momentPrimer:
                        OnboardingMomentPrimerView(currentStep: 4, totalSteps: 6) {
                            if coordinator.needsLocation {
                                coordinator.proceedToIdentity()
                            } else {
                                coordinator.proceedToAuthGate()
                            }
                        }

                    case .aiGeneration:
                        JoinerAIGenerationView {
                            coordinator.proceedToMomentPrimer()
                        }

                    case .identity:
                        JoinerIdentityView()

                    case .authGate:
                        JoinerAuthGateView()
                    }
                }
        }
    }
}
