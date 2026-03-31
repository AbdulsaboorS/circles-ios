import SwiftUI

// MARK: - Midnight Sanctuary tokens

private extension Color {
    static let msBackground   = Color(hex: "1A2E1E")
    static let msCardShared   = Color(hex: "243828")
    static let msGold         = Color(hex: "D4A240")
    static let msTextPrimary  = Color(hex: "F0EAD6")
    static let msTextMuted    = Color(hex: "8FAF94")
    static let msBorder       = Color(hex: "D4A240").opacity(0.18)
}

struct AmiirStep2HabitsView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer(minLength: 24)

                        VStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.msGold)

                            Text("The Core Mission")
                                .font(.appTitle)
                                .foregroundStyle(Color.msTextPrimary)
                                .multilineTextAlignment(.center)

                            Text("Choose up to 3 habits your circle will commit to together.")
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
                            ForEach(AmiirOnboardingCoordinator.curatedHabits, id: \.name) { habit in
                                let isSelected = coordinator.selectedHabits.contains(habit.name)
                                let isDisabled = !isSelected && !coordinator.canSelectMoreHabits

                                Button {
                                    if isSelected {
                                        coordinator.selectedHabits.remove(habit.name)
                                    } else if coordinator.canSelectMoreHabits {
                                        coordinator.selectedHabits.insert(habit.name)
                                    }
                                } label: {
                                    HabitTile(name: habit.name, icon: habit.icon, isSelected: isSelected, isDisabled: isDisabled)
                                }
                                .buttonStyle(.plain)
                                .disabled(isDisabled)
                            }
                        }
                        .padding(.horizontal, 24)

                        if coordinator.selectedHabits.count == 3 {
                            Text("Maximum 3 habits selected.")
                                .font(.appCaption)
                                .foregroundStyle(Color.msGold)
                        }

                        Spacer(minLength: 20)
                    }
                }

                VStack(spacing: 16) {
                    StepIndicator(current: 1, total: 4)

                    Button {
                        coordinator.proceedToLocation()
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
    }
}

private struct HabitTile: View {
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
