import SwiftUI

/// Screen B — "What holds you back day to day?"
struct QuizLifeStrugglesView: View {
    @Bindable var coordinator: OnboardingQuizCoordinator

    @State private var showCustomField: Bool = false
    @State private var customText: String = ""

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

                        QuizCustomRow(isSelected: showCustomField) {
                            showCustomField = true
                        }

                        if showCustomField {
                            TextField("e.g. Money stress, school pressure…", text: $customText)
                                .foregroundStyle(Color.msTextPrimary)
                                .padding(14)
                                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.msGold.opacity(0.4), lineWidth: 1))
                                .tint(Color.msGold)
                                .padding(.top, 2)
                                .onChange(of: customText) { _, newValue in
                                    coordinator.customLife = newValue
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
        .onAppear {
            customText = coordinator.customLife
            if !customText.isEmpty { showCustomField = true }
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
