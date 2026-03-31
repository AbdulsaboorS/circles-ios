import SwiftUI

struct StreakMilestoneCard: View {
    let item: StreakMilestoneFeedItem
    let currentUserId: UUID
    @Bindable var viewModel: FeedViewModel
    var onComment: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("🔥").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.userName) hit a \(item.streakDays)-day streak!")
                        .font(.appSubheadline).fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "F0EAD6"))
                    Text(item.habitName)
                        .font(.appCaption)
                        .foregroundStyle(Color(hex: "D4A240"))
                }
                Spacer()
                Text(relativeTimestamp(item.achievedAt))
                    .font(.appCaption)
                    .foregroundStyle(Color(hex: "8FAF94"))
            }
            HStack {
                ReactionBar(
                    itemId: item.id, itemType: "streak_milestone",
                    currentUserId: currentUserId, viewModel: viewModel
                )
                Spacer()
                if let onComment {
                    Button(action: onComment) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "8FAF94"))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "243828"))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "D4A240").opacity(0.35), lineWidth: 1))
        )
    }

    private func relativeTimestamp(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) ?? { f.formatOptions = [.withInternetDateTime]; return f.date(from: iso) }()
        else { return "" }
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}
