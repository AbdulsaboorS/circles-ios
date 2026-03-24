import SwiftUI

struct StreakMilestoneCard: View {
    let item: StreakMilestoneFeedItem
    let currentUserId: UUID
    @Bindable var viewModel: FeedViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("🔥")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.userName) hit a \(item.streakDays)-day streak!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(item.habitName)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "E8834B"))
                }
                Spacer()
                Text(relativeTimestamp(item.achievedAt))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            ReactionBar(
                itemId: item.id, itemType: "streak_milestone",
                currentUserId: currentUserId, viewModel: viewModel
            )
        }
        .padding(12)
        .background(Color(hex: "E8834B").opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "E8834B").opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
