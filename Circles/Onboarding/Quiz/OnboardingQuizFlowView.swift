import SwiftUI

/// Container that routes between the four quiz screens using the coordinator's
/// current `step`. No `NavigationStack` of its own — fits inside whichever
/// parent flow or sheet presents it.
struct OnboardingQuizFlowView: View {
    @Bindable var coordinator: OnboardingQuizCoordinator

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            switch coordinator.step {
            case .islamicStruggles:
                QuizIslamicStrugglesView(coordinator: coordinator)
                    .transition(.opacity)
            case .lifeStruggles:
                QuizLifeStrugglesView(coordinator: coordinator)
                    .transition(.opacity)
            case .processing:
                QuizProcessingView(coordinator: coordinator)
                    .transition(.opacity)
            case .habitSelection:
                QuizHabitSelectionView(coordinator: coordinator)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: coordinator.step)
        .alert("Error", isPresented: .constant(coordinator.errorMessage != nil)) {
            Button("OK") { coordinator.errorMessage = nil }
        } message: {
            Text(coordinator.errorMessage ?? "")
        }
    }
}
