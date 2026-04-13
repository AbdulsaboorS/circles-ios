import SwiftUI

struct DailyStatusShelfView: View {
    let stats: CircleCompletionStats
    let memberCount: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(stats.habits) { habit in
                    let done = stats.completionCount(for: habit.id)
                    let iconName = AmiirOnboardingCoordinator.iconForHabit(habit.name)

                    VStack(spacing: 6) {
                        Image(systemName: iconName)
                            .font(.system(size: 24))
                            .foregroundStyle(done == memberCount ? Color.msGold : Color.msGold.opacity(0.6))

                        Text("\(done) of \(memberCount)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.msTextPrimary)

                        Text(habit.name)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.msTextMuted)
                            .lineLimit(1)
                    }
                    .frame(width: 72)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.msGold.opacity(done == memberCount ? 0.3 : 0.1), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
