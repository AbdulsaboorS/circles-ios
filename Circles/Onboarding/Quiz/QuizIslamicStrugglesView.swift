import SwiftUI

/// Screen A — "What do you find hardest in your deen?"
struct QuizIslamicStrugglesView: View {
    @Bindable var coordinator: OnboardingQuizCoordinator

    @State private var showCustomField: Bool = false
    @State private var customText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 24)

                    VStack(spacing: 12) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.msGold)

                        Text("What do you find hardest in your deen?")
                            .font(.system(size: 24, weight: .regular, design: .serif))
                            .foregroundStyle(Color.msTextPrimary)
                            .multilineTextAlignment(.center)

                        Text("Be honest — this shapes your journey")
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

                        QuizCustomRow(isSelected: showCustomField) {
                            showCustomField = true
                        }

                        if showCustomField {
                            TextField("e.g. Doubts, comparing myself…", text: $customText)
                                .foregroundStyle(Color.msTextPrimary)
                                .padding(14)
                                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.msGold.opacity(0.4), lineWidth: 1))
                                .tint(Color.msGold)
                                .padding(.top, 2)
                                .onChange(of: customText) { _, newValue in
                                    coordinator.customIslamic = newValue
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
        .onAppear {
            customText = coordinator.customIslamic
            if !customText.isEmpty { showCustomField = true }
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
