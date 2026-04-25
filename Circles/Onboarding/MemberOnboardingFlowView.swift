import SwiftUI

/// Root view for the Joiner onboarding flow.
/// Manages the NavigationStack and routes all 7 steps + 2 Islamic transition screens.
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

                    case .personalHabits:
                        JoinerPersonalHabitsView()

                    case .transitionToAI:
                        OnboardingTransitionView(
                            quote: OnboardingTransitionQuote.amirPrivateToAI,
                            attribution: nil,
                            subtitle: "Next, let's talk through a habit you can personally work on."
                        ) {
                            coordinator.proceedToOnboardingQuiz()
                        }

                    case .aiGeneration:
                        JoinerAIGenerationView {
                            coordinator.proceedToIdentity()
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
