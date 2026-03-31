import SwiftUI

struct MomentFeedCard: View {
    let item: MomentFeedItem
    let currentUserId: UUID
    let hasPostedToday: Bool
    @Bindable var viewModel: FeedViewModel
    var onComment: (() -> Void)? = nil

    var isLocked: Bool { !hasPostedToday && item.userId != currentUserId }

    var body: some View {
        VStack(spacing: 0) {
            // Photo with caption + lock overlays
            ZStack(alignment: .bottom) {
                AsyncImage(url: URL(string: item.photoUrl)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(hex: "243828")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .clipped()
                .blur(radius: isLocked ? 20 : 0)

                if isLocked {
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color(hex: "F0EAD6"))
                        Text("Post your Moment to see theirs")
                            .font(.appSubheadline)
                            .foregroundStyle(Color(hex: "F0EAD6"))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

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
                            startPoint: .top, endPoint: .bottom
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
                            .foregroundStyle(Color(hex: "8FAF94"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "243828"))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "D4A240").opacity(0.18), lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                if item.isOnTime {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "D4A240"))
                    Text("Posted at \(DailyMomentService.shared.prayerDisplayName)")
                        .font(.appCaption)
                        .foregroundStyle(Color(hex: "D4A240"))
                } else {
                    Text("Posted late")
                        .font(.appCaption)
                        .foregroundStyle(Color(hex: "8FAF94"))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: "243828").opacity(0.9), in: Capsule())
            .overlay(Capsule().stroke(Color(hex: "D4A240").opacity(0.25), lineWidth: 1))
            .padding(10)
        }
    }
}
