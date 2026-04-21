import SwiftUI

/// Screen D — picks one (or many, in intercept mode) habits from `coordinator.suggestions`
/// or a "Custom…" name. Suggestions come from `GeminiService.generateHabitSuggestions`,
/// falling back to `HabitSuggestion.fallbackSuggestions` when Gemini is unreachable.
///
/// Selection mode:
/// - `coordinator.allowsMultiSelect == false` (default): tap replaces selection; Continue calls
///   `coordinator.finish(suggestion:)` or `coordinator.finish(customName:)`.
/// - `coordinator.allowsMultiSelect == true`: tap toggles into a Set; Continue calls
///   `coordinator.onFinishMany(suggestions, nil)` with every selected suggestion. Custom name
///   still falls back to `finish(customName:)` (single item).
struct QuizHabitSelectionView: View {
    @Bindable var coordinator: OnboardingQuizCoordinator

    @State private var selectedIds: Set<UUID> = []
    @State private var showCustomField: Bool = false
    @State private var customName: String = ""

    private var trimmedCustom: String {
        customName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        if showCustomField { return !trimmedCustom.isEmpty }
        return !selectedIds.isEmpty
    }

    private var ctaLabel: String {
        if showCustomField { return "Begin" }
        if coordinator.allowsMultiSelect {
            let n = selectedIds.count
            if n > 1 { return "Create \(n) habits" }
            if n == 1 { return "Create 1 habit" }
            return "Begin"
        }
        return "Begin"
    }

    private var headerTitle: String {
        coordinator.allowsMultiSelect ? "Habits shaped for you" : "One habit, shaped for you"
    }

    private var headerSubtitle: String {
        coordinator.allowsMultiSelect ? "Pick as many as feel right." : "Pick the one that feels most alive."
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

                        Text(headerTitle)
                            .font(.system(size: 24, weight: .regular, design: .serif))
                            .foregroundStyle(Color.msTextPrimary)
                            .multilineTextAlignment(.center)

                        Text(headerSubtitle)
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        ForEach(coordinator.suggestions) { suggestion in
                            let isSelected = !showCustomField && selectedIds.contains(suggestion.id)
                            SuggestionRow(
                                suggestion: suggestion,
                                isSelected: isSelected
                            ) {
                                handleTap(suggestion: suggestion)
                            }
                        }

                        CustomRow(isSelected: showCustomField) {
                            showCustomField = true
                            selectedIds.removeAll()
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
                handleContinue()
            }
            .padding(20)
        }
    }

    private func handleTap(suggestion: HabitSuggestion) {
        showCustomField = false
        if coordinator.allowsMultiSelect {
            if selectedIds.contains(suggestion.id) {
                selectedIds.remove(suggestion.id)
            } else {
                selectedIds.insert(suggestion.id)
            }
        } else {
            selectedIds = [suggestion.id]
        }
    }

    private func handleContinue() {
        if showCustomField {
            coordinator.finish(customName: trimmedCustom)
            return
        }
        if coordinator.allowsMultiSelect {
            let picked = coordinator.suggestions.filter { selectedIds.contains($0.id) }
            guard !picked.isEmpty else { return }
            if let onFinishMany = coordinator.onFinishMany {
                onFinishMany(picked, nil)
            } else if let first = picked.first {
                coordinator.finish(suggestion: first)
            }
            return
        }
        if let id = selectedIds.first,
           let match = coordinator.suggestions.first(where: { $0.id == id }) {
            coordinator.finish(suggestion: match)
        }
    }

    private func continueButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(ctaLabel)
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
