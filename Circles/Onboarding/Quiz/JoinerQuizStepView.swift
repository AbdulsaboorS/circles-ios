import SwiftUI

/// Hosts the shared `OnboardingQuizFlowView` inside the member onboarding stack.
/// Pre-auth — writes struggles + selected habit into the parent coordinator for
/// the eventual `flushToSupabase` pass.
struct JoinerQuizStepView: View {
    @Environment(MemberOnboardingCoordinator.self) private var coordinator
    @State private var quiz = OnboardingQuizCoordinator()

    var body: some View {
        OnboardingQuizFlowView(coordinator: quiz)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        coordinator.navigationPath.removeLast()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Color.msGold)
                    }
                }
            }
            .onAppear {
                quiz.selectedIslamic = Set(coordinator.strugglesIslamic.compactMap(IslamicStruggle.init))
                quiz.selectedLife    = Set(coordinator.strugglesLife.compactMap(LifeStruggle.init))

                quiz.onPersistStruggles = { [weak coordinator] islamic, life in
                    coordinator?.strugglesIslamic = islamic
                    coordinator?.strugglesLife    = life
                }

                quiz.onFinish = { [weak coordinator] suggestion, custom in
                    guard let coordinator else { return }
                    let picked = suggestion?.name ?? custom
                    coordinator.quizSelectedHabitName = picked
                    if let picked,
                       !picked.isEmpty,
                       !coordinator.selectedPersonalHabits.contains(picked) {
                        coordinator.selectedPersonalHabits.insert(picked, at: 0)
                    }
                    coordinator.proceedToTransitionToAI()
                }
            }
    }
}
