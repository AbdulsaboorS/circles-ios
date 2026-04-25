import SwiftUI

struct JoinerCircleAlignmentView: View {
    @Environment(MemberOnboardingCoordinator.self) private var coordinator
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            if let circle = coordinator.circle {
                content(circle: circle)
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Color.msGold)
                        .scaleEffect(1.2)
                    Text("Loading your circle...")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.msTextMuted)
                }
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

    private func content(circle: Circle) -> some View {
        @Bindable var coord = coordinator
        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 26) {
                    Spacer(minLength: 24)

                    VStack(spacing: 12) {
                        Text("You've been invited to")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.msTextMuted)
                            .textCase(.uppercase)
                            .tracking(0.6)

                        Text(circle.name)
                            .font(.system(size: 28, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.msTextPrimary)
                            .multilineTextAlignment(.center)

                        if circle.groupStreakDaysSafe > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(Color.msGold)
                                Text("\(circle.groupStreakDaysSafe)-day group streak")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.msTextPrimary)
                            }
                        }

                        memberPile
                    }
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Name")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.msTextMuted)
                            .textCase(.uppercase)
                            .tracking(0.6)

                        TextField("e.g. Omar", text: $coord.preferredName)
                            .textInputAutocapitalization(.words)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.msTextPrimary)
                            .padding(14)
                            .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.msBorder, lineWidth: 1))
                            .tint(Color.msGold)
                            .focused($nameFocused)
                    }
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("The group is tracking")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.msTextMuted)
                            .textCase(.uppercase)
                            .tracking(0.6)

                        JoinerFlowHabitsRow(habits: circle.coreHabitsSafe)
                    }
                    .padding(18)
                    .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.msBorder, lineWidth: 1))
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Which will you do with them?")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.msTextMuted)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .padding(.horizontal, 24)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(circle.coreHabitsSafe, id: \.self) { habitName in
                                let isSelected = coordinator.selectedCircleHabits.contains(habitName)
                                Button {
                                    if isSelected {
                                        coordinator.selectedCircleHabits.remove(habitName)
                                    } else {
                                        coordinator.selectedCircleHabits.insert(habitName)
                                    }
                                } label: {
                                    JoinerHabitTile(
                                        name: habitName,
                                        icon: AmiirOnboardingCoordinator.iconForHabit(habitName),
                                        isSelected: isSelected
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }

            VStack(spacing: 16) {
                StepIndicator(current: 1, total: 5)

                Button {
                    coordinator.proceedToTransitionToAI()
                } label: {
                    Text("I'm In")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.msBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.msGold, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(coordinator.selectedCircleHabits.isEmpty)
                .opacity(coordinator.selectedCircleHabits.isEmpty ? 0.45 : 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .background(Color.msBackground)
        }
    }

    private var memberPile: some View {
        HStack(spacing: -10) {
            ForEach(0..<5, id: \.self) { _ in
                ZStack {
                    SwiftUI.Circle()
                        .fill(Color.msCardShared)
                        .frame(width: 40, height: 40)
                        .overlay(SwiftUI.Circle().stroke(Color.msBackground, lineWidth: 2))
                    Image(systemName: "person.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.msGold.opacity(0.65))
                }
            }
        }
        .padding(.top, 4)
    }
}

private struct JoinerHabitTile: View {
    let name: String
    let icon: String
    let isSelected: Bool

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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color(hex: "D4A240") : Color(hex: "F0EAD6"))

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "D4A240"))
            }
        }
        .padding(12)
        .background(isSelected ? Color(hex: "D4A240").opacity(0.1) : Color(hex: "243828"), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color(hex: "D4A240") : Color(hex: "D4A240").opacity(0.18), lineWidth: 1.5)
        )
    }
}

private struct JoinerFlowHabitsRow: View {
    let habits: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(habits, id: \.self) { habit in
                let icon = AmiirOnboardingCoordinator.curatedHabits.first { $0.name == habit }?.icon ?? "star.fill"
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                    Text(habit)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.msGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.msGold.opacity(0.1), in: Capsule())
            }
            Spacer()
        }
    }
}
