import SwiftUI

/// Screen B — "What holds you back day to day?"
struct QuizLifeStrugglesView: View {
    @Bindable var coordinator: OnboardingQuizCoordinator

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 24)

                    VStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.msGold)

                        Text("What holds you back day to day?")
                            .font(.system(size: 24, weight: .regular, design: .serif))
                            .foregroundStyle(Color.msTextPrimary)
                            .multilineTextAlignment(.center)

                        Text("Your deen doesn't live in a vacuum")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        ForEach(LifeStruggle.allCases) { option in
                            QuizChoiceRow(
                                label: option.label,
                                isSelected: coordinator.selectedLife.contains(option)
                            ) {
                                toggle(option)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 24)
                }
            }

            continueButton(enabled: coordinator.canAdvanceFromLife) {
                Task { await coordinator.advanceToProcessing() }
            }
            .padding(20)
        }
    }

    private func toggle(_ option: LifeStruggle) {
        if coordinator.selectedLife.contains(option) {
            coordinator.selectedLife.remove(option)
        } else {
            coordinator.selectedLife.insert(option)
        }
    }

    private func continueButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Next")
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(Color.msBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(enabled ? Color.msGold : Color.msGold.opacity(0.4))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
