import SwiftUI

struct ReactionBar: View {
    let itemId: UUID
    let itemType: String
    let currentUserId: UUID
    @Bindable var viewModel: FeedViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let reactorIds = viewModel.reactorUserIds(for: itemId)
            if !reactorIds.isEmpty {
                ReactionFacePile(userIds: reactorIds, profiles: viewModel.reactionProfiles)
            }
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
                                    .foregroundStyle(isSelected ? Color(hex: "1A2E1E") : Color(hex: "F0EAD6").opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            isSelected ? Color(hex: "D4A240") : Color(hex: "243828"),
                            in: Capsule()
                        )
                        .overlay(Capsule().stroke(Color(hex: "D4A240").opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Face pile

private struct ReactionFacePile: View {
    let userIds: [UUID]
    let profiles: [UUID: Profile]
    var maxDisplay: Int = 5

    var body: some View {
        let shown = Array(userIds.prefix(maxDisplay))
        let extra = userIds.count - shown.count
        HStack(spacing: -10) {
            ForEach(shown, id: \.self) { uid in
                let p = profiles[uid]
                let label: String = {
                    if let n = p?.preferredName, !n.isEmpty { return n }
                    return String(uid.uuidString.prefix(4))
                }()
                AvatarView(avatarUrl: p?.avatarUrl, name: label, size: 28)
                    .overlay(SwiftUI.Circle().stroke(Color(hex: "1A2E1E"), lineWidth: 2))
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "8FAF94"))
                    .padding(.leading, 6)
            }
        }
        .accessibilityLabel("Reacted by \(userIds.count) people")
    }
}
