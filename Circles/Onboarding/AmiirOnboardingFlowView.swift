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
                    case .coreHabits:
                        AmiirStep2HabitsView()
                    case .onboardingQuiz:
                        AmiirQuizStepView()
                    case .circleIdentity:
                        AmiirStep1IdentityView()
                    case .transitionToPersonal:
                        // Islamic brotherhood quote — shown after circle creation, leads into habits
                        OnboardingTransitionView(
                            quote: OnboardingTransitionQuote.amirSharedToPrivate,
                            attribution: nil
                        ) {
                            coordinator.proceedToStruggle()
                        }
                    case .personalIntentions:
                        AmiirStep3PersonalView()
                    case .transitionToAI:
                        // "Some growth is private" — shown after circle creation, leads into personal intentions
                        OnboardingTransitionView(
                            quote: OnboardingTransitionQuote.amirPrivateToAI,
                            attribution: nil
                        ) {
                            coordinator.proceedToPersonalIntentions()
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
    let current: Int  // 0-indexed
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color(hex: "D4A240") : Color(hex: "D4A240").opacity(0.25))
                    .frame(width: index == current ? 20 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.25), value: current)
            }
        }
        .padding(.vertical, 8)
    }
}
