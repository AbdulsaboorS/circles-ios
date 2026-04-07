import SwiftUI

struct AmiirStep3PersonalView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator

    @State private var showCustomField = false
    @State private var customInput = ""

    private var customTrimmed: String { customInput.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Curated habits not already picked as shared circle habits
    private var availableHabits: [(name: String, icon: String)] {
        AmiirOnboardingCoordinator.curatedHabits.filter {
            !coordinator.selectedHabits.contains($0.name)
        }
    }

    private var canSelectMore: Bool { coordinator.selectedPersonalHabits.count < 2 }

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer(minLength: 24)

                        VStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.msGold)

                            Text("Your Personal Journey")
                                .font(.appTitle)
                                .foregroundStyle(Color.msTextPrimary)
                                .multilineTextAlignment(.center)

                            Text("Add intentions just for yourself — between you and Allah.")
                                .font(.appSubheadline)
                                .foregroundStyle(Color.msTextMuted)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)

                        // Habit grid
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 12
                        ) {
                            ForEach(availableHabits, id: \.name) { habit in
                                let isSelected = coordinator.selectedPersonalHabits.contains(habit.name)
                                let isDisabled = !isSelected && !canSelectMore

                                Button {
                                    if isSelected {
                                        coordinator.selectedPersonalHabits.removeAll { $0 == habit.name }
                                    } else if canSelectMore {
                                        coordinator.selectedPersonalHabits.append(habit.name)
                                    }
                                } label: {
                                    PersonalHabitTile(name: habit.name, icon: habit.icon, isSelected: isSelected, isDisabled: isDisabled)
                                }
                                .buttonStyle(.plain)
                                .disabled(isDisabled)
                            }

                            // Custom habit tile
                            let customIsSelected = showCustomField && !customTrimmed.isEmpty && coordinator.selectedPersonalHabits.contains(customTrimmed)
                            let customDisabled = !customIsSelected && !canSelectMore
                            Button {
                                showCustomField = true
                            } label: {
                                PersonalHabitTile(
                                    name: showCustomField && !customTrimmed.isEmpty ? customTrimmed : "Custom",
                                    icon: showCustomField && !customTrimmed.isEmpty
                                        ? AmiirOnboardingCoordinator.iconForHabit(customTrimmed)
                                        : "plus.circle.fill",
                                    isSelected: customIsSelected,
                                    isDisabled: customDisabled
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(customDisabled && !showCustomField)
                        }
                        .padding(.horizontal, 24)

                        // Custom input field
                        if showCustomField {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("e.g. Morning walk, Journaling…", text: $customInput)
                                    .foregroundStyle(Color.msTextPrimary)
                                    .padding(14)
                                    .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.msGold.opacity(0.4), lineWidth: 1))
                                    .tint(Color.msGold)
                                    .onChange(of: customInput) { _, _ in
                                        // Remove old custom entry when user edits the name
                                        let curated = Set(AmiirOnboardingCoordinator.curatedHabits.map(\.name))
                                        coordinator.selectedPersonalHabits.removeAll { !curated.contains($0) }
                                    }

                                if !customTrimmed.isEmpty && (canSelectMore || coordinator.selectedPersonalHabits.contains(customTrimmed)) {
                                    Button {
                                        if coordinator.selectedPersonalHabits.contains(customTrimmed) {
                                            coordinator.selectedPersonalHabits.removeAll { $0 == customTrimmed }
                                        } else if canSelectMore {
                                            coordinator.selectedPersonalHabits.append(customTrimmed)
                                        }
                                    } label: {
                                        Text(coordinator.selectedPersonalHabits.contains(customTrimmed) ? "Remove" : "Add \"\(customTrimmed)\"")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color.msBackground)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 9)
                                            .background(Color.msGold, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        if coordinator.selectedPersonalHabits.count == 2 {
                            Text("Maximum 2 intentions selected.")
                                .font(.appCaption)
                                .foregroundStyle(Color.msGold)
                        }

                        Spacer(minLength: 20)
                    }
                }

                VStack(spacing: 16) {
                    StepIndicator(current: 3, total: 7)

                    Button {
                        coordinator.proceedToAIGeneration()
                    } label: {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.msBackground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.msGold, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .background(Color.msBackground)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    coordinator.navigationPath.removeLast()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.msGold)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Skip") {
                    coordinator.proceedToAIGeneration()
                }
                .font(.appSubheadline)
                .foregroundStyle(Color.msTextMuted)
            }
        }
    }
}

// MARK: - PersonalHabitTile

private struct PersonalHabitTile: View {
    let name: String
    let icon: String
    let isSelected: Bool
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(hex: "D4A240") : Color(hex: "D4A240").opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color(hex: "1A2E1E") : Color(hex: "D4A240"))
            }
            Text(name)
                .font(.appSubheadline)
                .foregroundStyle(isSelected ? Color(hex: "D4A240") : Color(hex: "F0EAD6"))
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "D4A240"))
                    .font(.system(size: 16))
            }
        }
        .padding(12)
        .background(
            isSelected
                ? Color(hex: "D4A240").opacity(0.1)
                : Color(hex: "243828"),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color(hex: "D4A240") : Color(hex: "D4A240").opacity(0.18), lineWidth: 1.5)
        )
        .opacity(isDisabled ? 0.45 : 1)
    }
}
