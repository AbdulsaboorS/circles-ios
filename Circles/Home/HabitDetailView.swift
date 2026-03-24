import SwiftUI

/// Stub — full implementation in Plan 02-03.
struct HabitDetailView: View {
    let habit: Habit

    var body: some View {
        VStack(spacing: 16) {
            Text(habit.icon).font(.system(size: 60))
            Text(habit.name).font(.title.bold())
            if let goal = habit.acceptedAmount, !goal.isEmpty {
                Text("Goal: \(goal)").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 40)
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
