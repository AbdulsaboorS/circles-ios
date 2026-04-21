import SwiftUI

/// Screen D — picks one habit from `coordinator.suggestions` (or "Custom…").
/// Suggestions come from `GeminiService.generateHabitSuggestions`, falling back
/// to `HabitSuggestion.fallbackSuggestions` when Gemini is unreachable.
struct QuizHabitSelectionView: View {
    @Bindable var coordinator: OnboardingQuizCoordinator

    @State private var selectedId: UUID?
    @State private var showCustomField: Bool = false
    @State private var customName: String = ""

    private var trimmedCustom: String {
        customName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        if showCustomField { return !trimmedCustom.isEmpty }
        return selectedId != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 20)

                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.msGold)

                        Text("One habit, shaped for you")
                            .font(.system(size: 24, weight: .regular, design: .serif))
                            .foregroundStyle(Color.msTextPrimary)
                            .multilineTextAlignment(.center)

                        Text("Pick the one that feels most alive.")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        ForEach(coordinator.suggestions) { suggestion in
                            let isSelected = !showCustomField && selectedId == suggestion.id
                            SuggestionRow(
                                suggestion: suggestion,
                                isSelected: isSelected
                            ) {
                                selectedId = suggestion.id
                                showCustomField = false
                            }
                        }

                        CustomRow(isSelected: showCustomField) {
                            showCustomField = true
                            selectedId = nil
                        }

                        if showCustomField {
                            TextField("e.g. Tahajjud, Journaling…", text: $customName)
                                .foregroundStyle(Color.msTextPrimary)
                                .padding(14)
                                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.msGold.opacity(0.4), lineWidth: 1))
                                .tint(Color.msGold)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 24)
                }
            }

            continueButton(enabled: canContinue) {
                if showCustomField {
                    coordinator.finish(customName: trimmedCustom)
                } else if let id = selectedId,
                          let match = coordinator.suggestions.first(where: { $0.id == id }) {
                    coordinator.finish(suggestion: match)
                }
            }
            .padding(20)
        }
    }

    private func continueButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Begin")
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

private struct SuggestionRow: View {
    let suggestion: HabitSuggestion
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(isSelected ? Color.msGold : Color.clear)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Color.msBackground : Color.msTextPrimary)
                    Text(suggestion.rationale)
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundStyle(isSelected
                                         ? Color.msBackground.opacity(0.78)
                                         : Color.msTextMuted)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.msBackground)
                }
            }
            .padding(.vertical, 14)
            .padding(.trailing, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.msGold : Color.msCardShared)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.clear : Color.msBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CustomRow: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(isSelected ? Color.msGold : Color.clear)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.msBackground : Color.msGold)

                Text("Something else…")
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.msBackground : Color.msTextPrimary)

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.trailing, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.msGold : Color.msCardShared)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.clear : Color.msBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
