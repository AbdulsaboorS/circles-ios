import SwiftUI

struct ReactionBar: View {
    let itemId: UUID
    let itemType: String
    let currentUserId: UUID
    @Bindable var viewModel: FeedViewModel

    @State private var showPicker = false

    // Emojis that have at least one reaction
    private var activeReactions: [(emoji: String, count: Int, isMine: Bool)] {
        FeedReaction.validEmojis.compactMap { emoji in
            let count = viewModel.reactionCount(itemId: itemId, emoji: emoji)
            guard count > 0 else { return nil }
            let mine = viewModel.userHasReacted(itemId: itemId, emoji: emoji, userId: currentUserId)
            return (emoji, count, mine)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            // Active reaction chips
            ForEach(activeReactions, id: \.emoji) { item in
                Button {
                    Task {
                        await viewModel.toggleReaction(
                            itemId: itemId, itemType: itemType,
                            currentUserId: currentUserId, emoji: item.emoji
                        )
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(item.emoji)
                            .font(.system(size: 14))
                        Text("\(item.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(item.isMine ? Color(hex: "1A2E1E") : Color(hex: "F0EAD6").opacity(0.75))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        item.isMine ? Color(hex: "D4A240") : Color(hex: "2E4A33"),
                        in: Capsule()
                    )
                    .overlay(Capsule().stroke(Color(hex: "D4A240").opacity(item.isMine ? 0 : 0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // "+" CTA → popover picker
            Button {
                showPicker.toggle()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "8FAF94"))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: "243828"), in: SwiftUI.Circle())
                    .overlay(SwiftUI.Circle().stroke(Color(hex: "D4A240").opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                EmojiPickerPopover(
                    itemId: itemId,
                    itemType: itemType,
                    currentUserId: currentUserId,
                    viewModel: viewModel,
                    onPick: { showPicker = false }
                )
            }
        }
    }
}

// MARK: - Emoji picker popover

private struct EmojiPickerPopover: View {
    let itemId: UUID
    let itemType: String
    let currentUserId: UUID
    @Bindable var viewModel: FeedViewModel
    var onPick: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FeedReaction.validEmojis, id: \.self) { emoji in
                let isSelected = viewModel.userHasReacted(itemId: itemId, emoji: emoji, userId: currentUserId)
                Button {
                    Task {
                        await viewModel.toggleReaction(
                            itemId: itemId, itemType: itemType,
                            currentUserId: currentUserId, emoji: emoji
                        )
                    }
                    onPick()
                } label: {
                    Text(emoji)
                        .font(.system(size: 22))
                        .padding(8)
                        .background(
                            isSelected ? Color(hex: "D4A240").opacity(0.25) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(hex: "243828"))
        .presentationCompactAdaptation(.popover)
    }
}
