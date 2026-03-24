import SwiftUI

struct HabitSelectionView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator

    let presetHabits: [(name: String, icon: String)] = [
        ("Salah", "🕌"), ("Quran", "📖"), ("Dhikr", "📿"),
        ("Fasting", "🌙"), ("Tahajjud", "⭐"), ("Sadaqah", "💛"), ("Dua", "🤲")
    ]

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        @Bindable var coord = coordinator
        ScrollView {
            VStack(spacing: 24) {
                Text("Choose Your Habits")
                    .font(.title.bold())
                Text("Select 2–5 habits to track daily")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(presetHabits, id: \.name) { habit in
                        HabitTile(
                            icon: habit.icon,
                            name: habit.name,
                            isSelected: coordinator.selectedHabitNames.contains(habit.name),
                            isDisabled: !coordinator.selectedHabitNames.contains(habit.name) && coordinator.allSelectedNames.count >= 5
                        )
                        .onTapGesture { coordinator.selectHabit(habit.name) }
                    }
                }

                TextField("Custom habit...", text: $coord.customHabitName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Button("Continue") {
                    coordinator.proceedToAmounts()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!coordinator.canProceedFromSelection)
                .padding(.bottom)
            }
            .padding()
        }
        .navigationTitle("Habits")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HabitTile: View {
    let icon: String
    let name: String
    let isSelected: Bool
    let isDisabled: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(icon).font(.system(size: 36))
            Text(name).font(.caption).fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isDisabled ? 0.4 : 1.0)
    }
}
