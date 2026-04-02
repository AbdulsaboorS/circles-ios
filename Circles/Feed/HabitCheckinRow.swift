import SwiftUI

struct HabitCheckinRow: View {
    let item: HabitCheckinFeedItem
    let currentUserId: UUID
    let profile: Profile?
    @Bindable var viewModel: FeedViewModel
    var onComment: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeedIdentityHeader(
                avatarUrl: profile?.avatarUrl,
                displayName: displayName,
                circleName: item.circleName,
                timestamp: relativeTimestamp(item.checkedAt)
            )

            Text("checking into '\(item.habitName)'")
                .font(.appSubheadline)
                .foregroundStyle(Color(hex: "F0EAD6"))

            HStack {
                ReactionBar(
                    itemId: item.id, itemType: "habit_checkin",
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
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "243828"))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "D4A240").opacity(0.18), lineWidth: 1))
        )
    }

    private var displayName: String {
        let preferred = profile?.preferredName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return preferred.isEmpty ? item.userName : preferred
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
