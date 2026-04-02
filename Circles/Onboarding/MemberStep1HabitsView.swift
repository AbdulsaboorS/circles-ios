import SwiftUI

// MARK: - Midnight Sanctuary tokens

private extension Color {
    static let msBackground  = Color(hex: "1A2E1E")
    static let msCardShared  = Color(hex: "243828")
    static let msGold        = Color(hex: "D4A240")
    static let msTextPrimary = Color(hex: "F0EAD6")
    static let msTextMuted   = Color(hex: "8FAF94")
    static let msBorder      = Color(hex: "D4A240").opacity(0.18)
}

struct MemberStep1HabitsView: View {
    @Environment(MemberOnboardingCoordinator.self) private var coordinator

    @State private var showCustomField = false
    @State private var customInput = ""
    @State private var validationMessage: String?
    @FocusState private var isCustomFieldFocused: Bool
    private var customTrimmed: String { customInput.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Core habits the circle focuses on — shown first as must-select
    private var coreHabits: [String] { coordinator.circle?.coreHabitsSafe ?? [] }

    /// Extra curated habits the member can optionally add as personal
    private var additionalHabits: [(name: String, icon: String)] {
        AmiirOnboardingCoordinator.curatedHabits.filter { !coreHabits.contains($0.name) }
    }

    private var knownHabitNames: Set<String> {
        Set(AmiirOnboardingCoordinator.curatedHabits.map(\.name)).union(coreHabits)
    }

    private var selectedCoreHabitCount: Int {
        coordinator.selectedHabits.filter { coreHabits.contains($0) }.count
    }

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer(minLength: 20)

                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "hands.sparkles.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.msGold)

                            Text("Your Commitments")
                                .font(.appTitle)
                                .foregroundStyle(Color.msTextPrimary)
                                .multilineTextAlignment(.center)

                            if coordinator.circle != nil {
                                Text("Your circle is focused on \(coreHabits.joined(separator: ", ")). Which will you do with them?")
                                    .font(.appSubheadline)
                                    .foregroundStyle(Color.msTextMuted)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.horizontal, 24)

                        // Core habits (must pick ≥ 1)
                        if !coreHabits.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Circle Habits")
                                        .font(.appCaptionMedium)
                                        .textCase(.uppercase)
                                        .tracking(0.6)
                                        .foregroundStyle(Color.msTextMuted)

                                    Text("Choose at least 1 to continue.")
                                        .font(.appCaption)
                                        .foregroundStyle(Color.msTextMuted)
                                }
                                .padding(.horizontal, 24)

                                ForEach(coreHabits, id: \.self) { habitName in
                                    let isSelected = coordinator.selectedHabits.contains(habitName)
                                    let icon = AmiirOnboardingCoordinator.curatedHabits.first { $0.name == habitName }?.icon ?? "star.fill"

                                    Button {
                                        if isSelected {
                                            coordinator.selectedHabits.remove(habitName)
                                        } else {
                                            coordinator.selectedHabits.insert(habitName)
                                        }
                                    } label: {
                                        coreHabitRow(name: habitName, icon: icon, isSelected: isSelected)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 24)
                                }
                            }
                        }

                        // Additional personal habits
                        VStack(alignment: .leading, spacing: 10) {
                                Text("Add Personal Habits (optional)")
                                    .font(.appCaptionMedium)
                                    .textCase(.uppercase)
                                .tracking(0.6)
                                .foregroundStyle(Color.msTextMuted)
                                .padding(.horizontal, 24)

                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: 10
                            ) {
                                ForEach(additionalHabits, id: \.name) { habit in
                                    let isSelected = coordinator.selectedHabits.contains(habit.name)
                                    Button {
                                        if isSelected {
                                            coordinator.selectedHabits.remove(habit.name)
                                        } else {
                                            coordinator.selectedHabits.insert(habit.name)
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: habit.icon)
                                                .font(.system(size: 14))
                                                .foregroundStyle(isSelected ? Color(hex: "1A2E1E") : Color(hex: "D4A240"))
                                            Text(habit.name)
                                                .font(.appCaption)
                                                .foregroundStyle(isSelected ? Color(hex: "1A2E1E") : Color(hex: "F0EAD6"))
                                            Spacer()
                                        }
                                        .padding(10)
                                        .background(
                                            isSelected ? Color(hex: "D4A240") : Color(hex: "243828"),
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(hex: "D4A240").opacity(0.18), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }

                                // Custom habit tile
                                if showCustomField {
                                    HStack(spacing: 8) {
                                        Image(systemName: customTrimmed.isEmpty
                                              ? "plus.circle.fill"
                                              : AmiirOnboardingCoordinator.iconForHabit(customTrimmed))
                                            .font(.system(size: 14))
                                            .foregroundStyle(customTrimmed.isEmpty ? Color.msGold : Color.msBackground)

                                        TextField("Custom habit", text: $customInput)
                                            .font(.appCaption)
                                            .foregroundStyle(customTrimmed.isEmpty ? Color.msTextPrimary : Color.msBackground)
                                            .focused($isCustomFieldFocused)
                                            .tint(customTrimmed.isEmpty ? Color.msGold : Color.msBackground)
                                            .onChange(of: customInput) { _, newValue in
                                                let previousCustoms = coordinator.selectedHabits.subtracting(knownHabitNames)
                                                for old in previousCustoms {
                                                    coordinator.selectedHabits.remove(old)
                                                }

                                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                                if !trimmed.isEmpty {
                                                    coordinator.selectedHabits.insert(trimmed)
                                                }
                                            }

                                        if !customTrimmed.isEmpty {
                                            Button {
                                                coordinator.selectedHabits.remove(customTrimmed)
                                                customInput = ""
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundStyle(Color.msBackground.opacity(0.8))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(10)
                                    .background(
                                        customTrimmed.isEmpty ? Color.msCardShared : Color.msGold,
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.msGold.opacity(0.25), lineWidth: 1)
                                    )
                                    .onAppear {
                                        isCustomFieldFocused = true
                                    }
                                } else {
                                    Button {
                                        showCustomField = true
                                        DispatchQueue.main.async {
                                            isCustomFieldFocused = true
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(Color.msGold)
                                            Text("Custom")
                                                .font(.appCaption)
                                                .foregroundStyle(Color.msTextPrimary)
                                            Spacer()
                                        }
                                        .padding(10)
                                        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.msGold.opacity(0.18), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 20)
                    }
                }

                VStack(spacing: 16) {
                    StepIndicator(current: 0, total: 2)

                    if selectedCoreHabitCount == 0 {
                        Text("Select at least one circle habit before continuing.")
                            .font(.appCaption)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.appCaption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Button {
                        if selectedCoreHabitCount == 0 {
                            validationMessage = "Pick at least one circle habit first."
                        } else {
                            validationMessage = nil
                            coordinator.proceedToLocation()
                        }
                    } label: {
                        Text("I'm In")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.msBackground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.msGold, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .opacity(selectedCoreHabitCount == 0 ? 0.7 : 1)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .background(Color.msBackground)
            }
        }
        .navigationBarBackButtonHidden()
    }

    private func coreHabitRow(name: String, icon: String, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.msGold : Color.msGold.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.msBackground : Color.msGold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.msTextPrimary)
                Text("Circle habit")
                    .font(.appCaption)
                    .foregroundStyle(Color.msTextMuted)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? Color.msGold : Color.msTextMuted.opacity(0.4))
        }
        .padding(12)
        .background(
            isSelected ? Color.msGold.opacity(0.08) : Color.msCardShared,
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.msGold : Color.msBorder, lineWidth: 1.5)
        )
    }
}
