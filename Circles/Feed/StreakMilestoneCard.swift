import SwiftUI

struct StreakMilestoneCard: View {
    let item: StreakMilestoneFeedItem
    let currentUserId: UUID
    @Bindable var viewModel: FeedViewModel

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("🔥")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(item.userName) hit a \(item.streakDays)-day streak!")
                            .font(.appSubheadline).fontWeight(.semibold)
                            .foregroundStyle(Color.textPrimary)
                        Text(item.habitName)
                            .font(.appCaption)
                            .foregroundStyle(Color.accent)
                    }
                    Spacer()
                    Text(relativeTimestamp(item.achievedAt))
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                }
                ReactionBar(
                    itemId: item.id, itemType: "streak_milestone",
                    currentUserId: currentUserId, viewModel: viewModel
                )
            }
            .padding(12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accent.opacity(0.35), lineWidth: 1)
        )
    }

    private func relativeTimestamp(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) ?? {
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: iso)
        }() else { return "" }
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}
