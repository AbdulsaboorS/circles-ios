import SwiftUI

struct MomentFeedCard: View {
    let item: MomentFeedItem
    let currentUserId: UUID
    let hasPostedToday: Bool
    @Bindable var viewModel: FeedViewModel
    var onComment: (() -> Void)? = nil

    var isLocked: Bool { !hasPostedToday && item.userId != currentUserId }

    var body: some View {
        AppCard {
            VStack(spacing: 0) {
                // Photo with caption + lock overlays
                ZStack(alignment: .bottom) {
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
                                .font(.appSubheadline)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Caption + username gradient overlay (D-20)
                    if !isLocked {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.userName)
                                .font(.appCaptionMedium)
                                .foregroundStyle(.white)
                            if let caption = item.caption, !caption.isEmpty {
                                Text(caption)
                                    .font(.appCaption)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }

                // Reaction bar + comment
                HStack {
                    ReactionBar(
                        itemId: item.id, itemType: "moment",
                        currentUserId: currentUserId, viewModel: viewModel
                    )
                    Spacer()
                    if let onComment {
                        Button(action: onComment) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                if item.isOnTime {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accent)
                    Text("Posted at \(DailyMomentService.shared.prayerDisplayName)")
                        .font(.appCaption)
                        .foregroundStyle(Color.accent)
                } else {
                    Text("Posted late")
                        .font(.appCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(10)
        }
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
