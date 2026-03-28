import SwiftUI

struct AmiirStep2HabitsView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AppColors { AppColors.resolve(colorScheme) }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer(minLength: 24)

                        VStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.accent.opacity(0.85))

                            Text("The Core Mission")
                                .font(.appTitle)
                                .foregroundStyle(colors.textPrimary)
                                .multilineTextAlignment(.center)

                            Text("Choose up to 3 habits your circle will commit to together.")
                                .font(.appSubheadline)
                                .foregroundStyle(colors.textSecondary)
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
                                .foregroundStyle(Color.accent)
                        }

                        Spacer(minLength: 20)
                    }
                }

                VStack(spacing: 16) {
                    StepIndicator(current: 1, total: 4)

                    PrimaryButton(title: "Build the Foundation") {
                        coordinator.proceedToLocation()
                    }
                    .disabled(coordinator.selectedHabits.isEmpty)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .background(.ultraThinMaterial)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    coordinator.navigationPath.removeLast()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.accent)
                }
            }
        }
    }
}

private struct HabitTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let name: String
    let icon: String
    let isSelected: Bool
    let isDisabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accent : Color.accent.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .white : Color.accent)
            }
            Text(name)
                .font(.appSubheadline)
                .foregroundStyle(isSelected ? Color.accent : (colorScheme == .dark ? Color.darkTextPrimary : Color.lightTextPrimary))
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accent)
                    .font(.system(size: 16))
            }
        }
        .padding(12)
        .background(
            isSelected
                ? Color.accent.opacity(0.1)
                : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.8)),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accent : Color.clear, lineWidth: 1.5)
        )
        .opacity(isDisabled ? 0.45 : 1)
    }
}
