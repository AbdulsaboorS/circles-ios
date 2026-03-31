import SwiftUI

/// Root view for the Amir onboarding flow.
/// Manages the NavigationStack and routes between the 4 steps.
struct AmiirOnboardingFlowView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coord = coordinator
        NavigationStack(path: $coord.navigationPath) {
            AmiirStep1IdentityView()
                .navigationDestination(for: AmiirOnboardingCoordinator.Step.self) { step in
                    switch step {
                    case .coreHabits:          AmiirStep2HabitsView()
                    case .personalIntentions:  AmiirStep3PersonalView()
                    case .location:            AmiirStep3LocationView()
                    case .soulGate:            AmiirStep4SoulGateView()
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
