import SwiftUI

/// Screen D — picks one (or many, in intercept mode) habits from the ranked
/// catalog plus any typed custom habits.
///
/// Selection mode:
/// - `coordinator.allowsMultiSelect == false` (default): tap replaces selection; Continue calls
///   `coordinator.finish(habitName:)`.
/// - `coordinator.allowsMultiSelect == true`: tap toggles into a Set; Continue calls
///   `coordinator.finishMany(habitNames:)` with every selected catalog + custom item.
struct QuizHabitSelectionView: View {
    @Bindable var coordinator: OnboardingQuizCoordinator

    @State private var selectedNames: Set<String> = []
    /// Custom habits the user has typed and committed. Held separately from
    /// `selectedNames` because customs are *added unselected* — the user must
    /// tap the row to select like any other card.
    @State private var addedCustoms: [String] = []
    @State private var didSeedInitialSelection = false

    private static let customIcon = "pencil"

    private var canContinue: Bool {
        !selectedNames.isEmpty
    }

    private var selectedCount: Int {
        selectedNames.count
    }

    private var cap: Int {
        coordinator.selectionCap
    }

    private var atCap: Bool {
        coordinator.allowsMultiSelect && selectedCount >= cap
    }

    private var spiritualityLevel: CatalogSpirituality? {
        CatalogSpirituality.fromAnswer(coordinator.spiritualityAnswer)
    }

    private var ctaLabel: String {
        if coordinator.allowsMultiSelect {
            let n = selectedCount
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
        coordinator.allowsMultiSelect
            ? "Pick up to \(cap). Add your own if you need to."
            : "Pick the one that feels most alive."
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
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

                    if !coordinator.recommendations.top.isEmpty {
                        suggestionSection(
                            title: "Shaped around your struggles",
                            habits: coordinator.recommendations.top
                        )
                        .padding(.horizontal, 20)
                    }

                    if !coordinator.recommendations.starters.isEmpty {
                        suggestionSection(
                            title: "Good starters",
                            habits: coordinator.recommendations.starters
                        )
                        .padding(.horizontal, 20)
                    }

                    customSection
                        .padding(.horizontal, 20)

                    if coordinator.allowsMultiSelect, selectedCount == cap {
                        Text("Maximum \(cap) intentions selected.")
                            .font(.appCaption)
                            .foregroundStyle(Color.msGold)
                    }

                    Spacer(minLength: 24)
                }
            }

            continueButton(enabled: canContinue) {
                handleContinue()
            }
            .padding(20)
        }
        .onAppear {
            seedInitialSelectionIfNeeded()
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func suggestionSection(title: String, habits: [HabitEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title)

            VStack(spacing: 10) {
                ForEach(habits) { habit in
                    let isSelected = selectedNames.contains(habit.name)
                    let isDisabled = !isSelected && atCap

                    OnboardingHabitRow(
                        name: habit.name,
                        icon: habit.icon,
                        rationale: habit.rationale(for: spiritualityLevel),
                        isSelected: isSelected,
                        isDisabled: isDisabled,
                        onTap: { handleTap(name: habit.name) }
                    )
                }
            }
        }
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !addedCustoms.isEmpty {
                sectionHeader("Your additions")

                VStack(spacing: 10) {
                    ForEach(addedCustoms, id: \.self) { name in
                        let isSelected = selectedNames.contains(name)
                        let isDisabled = !isSelected && atCap

                        OnboardingHabitRow(
                            name: name,
                            icon: Self.customIcon,
                            rationale: "",
                            isSelected: isSelected,
                            isDisabled: isDisabled,
                            onTap: { handleTap(name: name) },
                            onRemove: { removeCustomHabit(name) }
                        )
                    }
                }
            }

            OnboardingCustomHabitSlot(
                canCommit: { canCommitCustom($0) },
                onCommit: { addCustomHabit($0) }
            )
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.appCaption)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(Color.msTextMuted)
            .padding(.horizontal, 4)
    }

    // MARK: - Actions

    private func handleTap(name: String) {
        if coordinator.allowsMultiSelect {
            if selectedNames.contains(name) {
                selectedNames.remove(name)
            } else if selectedCount < cap {
                selectedNames.insert(name)
            }
        } else {
            selectedNames = [name]
        }
    }

    private func handleContinue() {
        if coordinator.allowsMultiSelect {
            coordinator.finishMany(habitNames: orderedSelectionNames())
            return
        }
        if let first = orderedSelectionNames().first {
            coordinator.finish(habitName: first)
        }
    }

    private func orderedSelectionNames() -> [String] {
        let catalog = coordinator.suggestions
            .map(\.name)
            .filter { selectedNames.contains($0) }
        let custom = addedCustoms.filter { selectedNames.contains($0) }
        return catalog + custom
    }

    private func canCommitCustom(_ trimmed: String) -> Bool {
        let lower = trimmed.lowercased()
        if coordinator.suggestions.contains(where: { $0.name.lowercased() == lower }) { return false }
        if addedCustoms.contains(where: { $0.lowercased() == lower }) { return false }
        return true
    }

    private func addCustomHabit(_ trimmed: String) {
        addedCustoms.append(trimmed)
        // Added unselected — user must tap the row to select.
    }

    private func removeCustomHabit(_ name: String) {
        addedCustoms.removeAll { $0 == name }
        selectedNames.remove(name)
    }

    private func seedInitialSelectionIfNeeded() {
        guard !didSeedInitialSelection else { return }
        didSeedInitialSelection = true

        let catalogNames = Set(coordinator.suggestions.map(\.name))
        for name in coordinator.initialSelectedHabitNames {
            if catalogNames.contains(name) {
                selectedNames.insert(name)
            } else if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                addedCustoms.append(name)
                selectedNames.insert(name)
            }
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
