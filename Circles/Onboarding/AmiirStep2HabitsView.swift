import SwiftUI

struct AmiirStep2HabitsView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator

    /// Locally tracked custom habits (typed by the user). Held here rather than
    /// the coordinator because customs are *added unselected* — the coordinator's
    /// `selectedHabits` only contains habits the user has actively chosen. Seeded
    /// on appear from any custom habits already in `selectedHabits` so back-nav
    /// re-entry shows them.
    @State private var addedCustoms: [String] = []
    @State private var didSeed = false

    private static let customIcon = "pencil"

    private var recommendations: HabitCatalog.Recommendations {
        coordinator.sharedHabitRecommendations()
    }

    private var spiritualityLevel: CatalogSpirituality? {
        CatalogSpirituality.fromAnswer(coordinator.spiritualityLevel)
    }

    private var catalogNames: Set<String> {
        Set(HabitCatalog.all.map(\.name))
    }

    private var visibleHabitNames: Set<String> {
        Set((recommendations.top + recommendations.starters).map(\.name))
    }

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 24)

                        VStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.msGold)

                            Text("Your circle's habits")
                                .font(.appTitle)
                                .foregroundStyle(Color.msTextPrimary)
                                .multilineTextAlignment(.center)

                            Text("Recommended for your circle. Pick up to \(HabitCatalog.sharedCap).")
                                .font(.appSubheadline)
                                .foregroundStyle(Color.msTextMuted)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)

                        recommendationSection(
                            title: "Shaped by your answers",
                            habits: recommendations.top
                        )
                        .padding(.horizontal, 20)

                        recommendationSection(
                            title: "Good starters",
                            habits: recommendations.starters
                        )
                        .padding(.horizontal, 20)

                        customSection
                            .padding(.horizontal, 20)

                        if coordinator.selectedHabits.count == HabitCatalog.sharedCap {
                            Text("Maximum \(HabitCatalog.sharedCap) habits selected.")
                                .font(.appCaption)
                                .foregroundStyle(Color.msGold)
                        }

                        Spacer(minLength: 20)
                    }
                }

                VStack(spacing: 16) {
                    StepIndicator(current: 4, total: 10)

                    Button {
                        coordinator.proceedToIdentity()
                    } label: {
                        Text("Build the Foundation")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.msBackground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.msGold, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(coordinator.selectedHabits.isEmpty)
                    .opacity(coordinator.selectedHabits.isEmpty ? 0.45 : 1)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .background(Color.msBackground)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    coordinator.navigationPath.removeLast()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.msGold)
                }
            }
        }
        .onAppear { seedIfNeeded() }
    }

    // MARK: - Sections

    @ViewBuilder
    private func recommendationSection(title: String, habits: [HabitEntry]) -> some View {
        if !habits.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(title)

                VStack(spacing: 10) {
                    ForEach(habits) { habit in
                        let isSelected = coordinator.selectedHabits.contains(habit.name)
                        let isDisabled = !isSelected && !coordinator.canSelectMoreHabits

                        OnboardingHabitRow(
                            name: habit.name,
                            icon: habit.icon,
                            rationale: habit.rationale(for: spiritualityLevel),
                            isSelected: isSelected,
                            isDisabled: isDisabled,
                            onTap: { toggleCatalog(habit) }
                        )
                    }
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
                        let isSelected = coordinator.selectedHabits.contains(name)
                        let isDisabled = !isSelected && !coordinator.canSelectMoreHabits

                        OnboardingHabitRow(
                            name: name,
                            icon: Self.customIcon,
                            rationale: "",
                            isSelected: isSelected,
                            isDisabled: isDisabled,
                            onTap: { toggleCustom(name) },
                            onRemove: { removeCustom(name) }
                        )
                    }
                }
            }

            OnboardingCustomHabitSlot(
                canCommit: { canCommitCustom($0) },
                onCommit: { addCustom($0) }
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

    private func toggleCatalog(_ habit: HabitEntry) {
        if coordinator.selectedHabits.contains(habit.name) {
            coordinator.selectedHabits.remove(habit.name)
        } else if coordinator.canSelectMoreHabits {
            coordinator.selectedHabits.insert(habit.name)
        }
    }

    private func toggleCustom(_ name: String) {
        if coordinator.selectedHabits.contains(name) {
            coordinator.selectedHabits.remove(name)
        } else if coordinator.canSelectMoreHabits {
            coordinator.selectedHabits.insert(name)
        }
    }

    private func canCommitCustom(_ trimmed: String) -> Bool {
        let lower = trimmed.lowercased()
        if visibleHabitNames.contains(where: { $0.lowercased() == lower }) { return false }
        if addedCustoms.contains(where: { $0.lowercased() == lower }) { return false }
        return true
    }

    private func addCustom(_ trimmed: String) {
        addedCustoms.append(trimmed)
        // Customs are added unselected — user must tap the row to select.
    }

    private func removeCustom(_ name: String) {
        addedCustoms.removeAll { $0 == name }
        coordinator.selectedHabits.remove(name)
    }

    private func seedIfNeeded() {
        guard !didSeed else { return }
        didSeed = true

        let catalog = catalogNames
        let existingCustoms = coordinator.selectedHabits
            .filter { !catalog.contains($0) }
            .sorted()
        addedCustoms = existingCustoms
    }
}
