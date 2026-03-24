import SwiftUI

struct ReactionBar: View {
    let itemId: UUID
    let itemType: String
    let currentUserId: UUID
    @Bindable var viewModel: FeedViewModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(FeedReaction.validEmojis, id: \.self) { emoji in
                let count = viewModel.reactionCount(itemId: itemId, emoji: emoji)
                let isSelected = viewModel.userHasReacted(itemId: itemId, emoji: emoji, userId: currentUserId)

                Button {
                    Task {
                        await viewModel.toggleReaction(
                            itemId: itemId, itemType: itemType,
                            currentUserId: currentUserId, emoji: emoji
                        )
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(emoji).font(.system(size: 14))
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        isSelected
                            ? Color(hex: "E8834B")
                            : Color.white.opacity(0.08)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
