import SwiftUI

struct MemberStep1HabitsView: View {
    @Environment(MemberOnboardingCoordinator.self) private var coordinator
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AppColors { AppColors.resolve(colorScheme) }

    /// Core habits the circle focuses on — shown first as must-select
    private var coreHabits: [String] { coordinator.circle?.coreHabitsSafe ?? [] }

    /// Extra curated habits the member can optionally add as personal
    private var additionalHabits: [(name: String, icon: String)] {
        AmiirOnboardingCoordinator.curatedHabits.filter { !coreHabits.contains($0.name) }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer(minLength: 20)

                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "hands.sparkles.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.accent.opacity(0.85))

                            Text("Your Commitments")
                                .font(.appTitle)
                                .foregroundStyle(colors.textPrimary)
                                .multilineTextAlignment(.center)

                            if let circle = coordinator.circle {
                                Text("Your circle is focused on \(coreHabits.joined(separator: ", ")). Which will you do with them?")
                                    .font(.appSubheadline)
                                    .foregroundStyle(colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.horizontal, 24)

                        // Core habits (circle focus — must pick ≥ 1)
                        if !coreHabits.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Circle Habits")
                                    .font(.appCaptionMedium)
                                    .textCase(.uppercase)
                                    .tracking(0.6)
                                    .foregroundStyle(colors.textSecondary)
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
                                .foregroundStyle(colors.textSecondary)
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
                                                .foregroundStyle(isSelected ? .white : Color.accent)
                                            Text(habit.name)
                                                .font(.appCaption)
                                                .foregroundStyle(isSelected ? .white : colors.textPrimary)
                                            Spacer()
                                        }
                                        .padding(10)
                                        .background(
                                            isSelected ? Color.accent : Color.accent.opacity(0.07),
                                            in: RoundedRectangle(cornerRadius: 10)
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

                    PrimaryButton(title: "I'm In") {
                        coordinator.proceedToLocation()
                    }
                    .disabled(coordinator.selectedHabits.filter { coreHabits.contains($0) }.isEmpty)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .background(.ultraThinMaterial)
            }
        }
        .navigationBarBackButtonHidden()
    }

    private func coreHabitRow(name: String, icon: String, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accent : Color.accent.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .white : Color.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.appSubheadline)
                    .foregroundStyle(colorScheme == .dark ? Color.darkTextPrimary : Color.lightTextPrimary)
                Text("Circle habit")
                    .font(.appCaption)
                    .foregroundStyle(colors.textSecondary)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? Color.accent : colors.textSecondary.opacity(0.4))
        }
        .padding(12)
        .background(
            isSelected ? Color.accent.opacity(0.08) : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.8)),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accent : Color.clear, lineWidth: 1.5)
        )
    }
}
