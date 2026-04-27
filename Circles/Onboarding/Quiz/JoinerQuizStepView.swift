import SwiftUI

/// Hosts the shared `OnboardingQuizFlowView` inside the member onboarding stack.
/// Pre-auth — writes struggles + selected habit into the parent coordinator for
/// the eventual `flushToSupabase` pass.
struct JoinerQuizStepView: View {
    @Environment(MemberOnboardingCoordinator.self) private var coordinator
    @State private var quiz = OnboardingQuizCoordinator()

    var body: some View {
        OnboardingQuizFlowView(coordinator: quiz)
            .safeAreaInset(edge: .top) {
                StepIndicator(current: 2, total: 6)
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
                let islamicEnums = coordinator.strugglesIslamic.filter { !$0.hasPrefix("custom:") }
                let lifeEnums = coordinator.strugglesLife.filter { !$0.hasPrefix("custom:") }
                quiz.selectedIslamic = Set(islamicEnums.compactMap(IslamicStruggle.init))
                quiz.selectedLife    = Set(lifeEnums.compactMap(LifeStruggle.init))
                quiz.customIslamic = coordinator.strugglesIslamic
                    .first(where: { $0.hasPrefix("custom:") })
                    .map { String($0.dropFirst("custom:".count)) } ?? ""
                quiz.customLife = coordinator.strugglesLife
                    .first(where: { $0.hasPrefix("custom:") })
                    .map { String($0.dropFirst("custom:".count)) } ?? ""
                quiz.allowsMultiSelect = true
                quiz.selectionCap = HabitCatalog.personalCap
                // Personal recs must not overlap the circle's shared habits (issue #3).
                quiz.excludedHabitNames = Set(coordinator.circle?.coreHabitsSafe ?? [])
                quiz.rankingSeed = [
                    coordinator.inviteCodeInput,
                    coordinator.preferredName
                ].joined(separator: "::")
                quiz.initialSelectedHabitNames = coordinator.selectedPersonalHabits

                quiz.onPersistStruggles = { [weak coordinator] islamic, life in
                    coordinator?.strugglesIslamic = islamic
                    coordinator?.strugglesLife    = life
                }

                quiz.onFinish = { [weak coordinator] habitName in
                    guard let coordinator else { return }
                    coordinator.quizSelectedHabitName = habitName
                    coordinator.selectedPersonalHabits = [habitName]
                    coordinator.proceedToAIGeneration()
                }

                quiz.onFinishMany = { [weak coordinator] habitNames in
                    guard let coordinator else { return }
                    coordinator.quizSelectedHabitName = habitNames.first
                    coordinator.selectedPersonalHabits = Array(habitNames.prefix(HabitCatalog.personalCap))
                    coordinator.proceedToAIGeneration()
                }
            }
    }
}
