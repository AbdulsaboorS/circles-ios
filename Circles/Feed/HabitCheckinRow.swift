import SwiftUI

struct HabitCheckinRow: View {
    let item: HabitCheckinFeedItem
    let currentUserId: UUID
    @Bindable var viewModel: FeedViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(item.userName) checked in ")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                + Text(item.habitName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(relativeTimestamp(item.checkedAt))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            ReactionBar(
                itemId: item.id, itemType: "habit_checkin",
                currentUserId: currentUserId, viewModel: viewModel
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
