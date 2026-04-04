import SwiftUI

struct MomentFeedCard: View {
    let item: MomentFeedItem
    let currentUserId: UUID
    let hasPostedToday: Bool
    let profile: Profile?
    @Bindable var viewModel: FeedViewModel
    var onComment: (() -> Void)? = nil

    @State private var circleListExpanded = false

    var isOwnPost: Bool { item.userId == currentUserId }
    var isLocked: Bool { !hasPostedToday && !isOwnPost }

    var body: some View {
        VStack(spacing: 0) {
            FeedIdentityHeader(
                avatarUrl: profile?.avatarUrl,
                displayName: displayName,
                circleName: isOwnPost ? nil : item.circleName,
                timestamp: timestampLabel
            )
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, isOwnPost ? 4 : 10)

            // Own-post: expandable circle list
            if isOwnPost {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { circleListExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(circleListExpanded
                             ? "Sent to \(item.circleNames.count) circle\(item.circleNames.count == 1 ? "" : "s") ▾"
                             : "Sent to \(item.circleNames.count) circle\(item.circleNames.count == 1 ? "" : "s") ▸")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "D4A240"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(.plain)

                if circleListExpanded {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(item.circleNames, id: \.self) { name in
                            Text("• \(name)")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "8FAF94"))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 4)
                }

                Spacer().frame(height: 6)
            }

            // Photo with caption + lock overlays
            ZStack(alignment: .bottom) {
                AsyncImage(url: URL(string: item.photoUrl)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(hex: "243828")
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(3.0 / 4.0, contentMode: .fill)
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
                    VStack(alignment: .leading, spacing: 3) {
                        if let caption = item.caption, !caption.isEmpty {
                            Text(caption)
                                .font(.appCaption)
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "243828"))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "D4A240").opacity(0.18), lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var displayName: String {
        let preferred = profile?.preferredName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return preferred.isEmpty ? item.userName : preferred
    }

    private var timestampLabel: String {
        relativeTimestamp(item.postedAt)
    }

    private func relativeTimestamp(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: iso) ?? { f.formatOptions = [.withInternetDateTime]; return f.date(from: iso) }()
        else { return "" }
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 { return "\(max(1, Int(diff / 60)))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}
