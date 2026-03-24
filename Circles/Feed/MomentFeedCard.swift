import SwiftUI

struct MomentFeedCard: View {
    let item: MomentFeedItem
    let currentUserId: UUID
    let hasPostedToday: Bool
    @Bindable var viewModel: FeedViewModel

    var isLocked: Bool { !hasPostedToday && item.userId != currentUserId }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: name + star + timestamp
            HStack {
                Text(item.userName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                if item.isOnTime {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "E8834B"))
                }
                Spacer()
                Text(relativeTimestamp(item.postedAt))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Photo area
            ZStack {
                AsyncImage(url: URL(string: item.photoUrl)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.white.opacity(0.05)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .clipped()
                .blur(radius: isLocked ? 20 : 0)

                if isLocked {
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                        Text("Post your Moment to see theirs")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            // Caption (if present)
            if let caption = item.caption, !caption.isEmpty {
                Text(caption)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            // Reaction bar
            ReactionBar(
                itemId: item.id, itemType: "moment",
                currentUserId: currentUserId, viewModel: viewModel
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
