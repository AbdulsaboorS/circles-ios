import SwiftUI

/// Hosts the shared `OnboardingQuizFlowView` inside the Amir onboarding stack.
/// Pre-auth — writes struggles + selected habit into the parent coordinator for
/// the eventual `flushToSupabase` pass.
struct AmiirQuizStepView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator
    @State private var quiz = OnboardingQuizCoordinator()

    var body: some View {
        OnboardingQuizFlowView(coordinator: quiz)
            .safeAreaInset(edge: .top) {
                StepIndicator(current: 4, total: 8)
                    .background(Color.msBackground)
            }
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
                quiz.allowsMultiSelect = true

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
                    coordinator.proceedToAIGeneration()
                }

                quiz.onFinishMany = { [weak coordinator] suggestions, _ in
                    guard let coordinator else { return }
                    coordinator.quizSelectedHabitName = suggestions.first?.name
                    for s in suggestions {
                        guard !s.name.isEmpty,
                              !coordinator.selectedPersonalHabits.contains(s.name) else { continue }
                        coordinator.selectedPersonalHabits.append(s.name)
                    }
                    coordinator.proceedToAIGeneration()
                }
            }
    }
}
