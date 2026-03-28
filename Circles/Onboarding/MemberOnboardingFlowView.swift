import SwiftUI

struct MemberOnboardingFlowView: View {
    @Environment(MemberOnboardingCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coord = coordinator
        NavigationStack(path: $coord.navigationPath) {
            MemberStep1HabitsView()
                .navigationDestination(for: MemberOnboardingCoordinator.Step.self) { step in
                    switch step {
                    case .habitAlignment: MemberStep1HabitsView()
                    case .location:       MemberStep2LocationView()
                    }
                }
        }
        .task {
            await coordinator.loadCircle()
        }
    }
}
