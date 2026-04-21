import SwiftUI

/// Screen A — "Where is your Islamic practice pulling you right now?"
struct QuizIslamicStrugglesView: View {
    @Bindable var coordinator: OnboardingQuizCoordinator

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 24)

                    VStack(spacing: 12) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.msGold)

                        Text("Where is your Islamic practice pulling you right now?")
                            .font(.system(size: 24, weight: .regular, design: .serif))
                            .foregroundStyle(Color.msTextPrimary)
                            .multilineTextAlignment(.center)

                        Text("Pick what resonates. You can pick more than one.")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        ForEach(IslamicStruggle.allCases) { option in
                            QuizChoiceRow(
                                label: option.label,
                                isSelected: coordinator.selectedIslamic.contains(option)
                            ) {
                                toggle(option)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 24)
                }
            }

            continueButton(enabled: coordinator.canAdvanceFromIslamic) {
                coordinator.advanceToLife()
            }
            .padding(20)
        }
    }

    private func toggle(_ option: IslamicStruggle) {
        if coordinator.selectedIslamic.contains(option) {
            coordinator.selectedIslamic.remove(option)
        } else {
            coordinator.selectedIslamic.insert(option)
        }
    }

    private func continueButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("This is me")
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
