import SwiftUI

struct MomentFeedCard: View {
    let item: MomentFeedItem
    let currentUserId: UUID
    let hasPostedToday: Bool
    let profile: Profile?
    @Bindable var viewModel: FeedViewModel
    var onComment: (() -> Void)? = nil
    var onOpenFullScreen: (() -> Void)? = nil

    @State private var swapped = false
    @State private var showMenu = false

    private var mainPhotoUrl: String {
        swapped ? (item.secondaryPhotoUrl ?? item.photoUrl) : item.photoUrl
    }
    private var pipPhotoUrl: String? {
        guard let secondary = item.secondaryPhotoUrl else { return nil }
        return swapped ? item.photoUrl : secondary
    }

    var isOwnPost: Bool { item.userId == currentUserId }
    var isLocked: Bool { !hasPostedToday && !isOwnPost }

    var body: some View {
        VStack(spacing: 0) {
            // Identity row — floating on msBackground
            FeedIdentityHeader(
                avatarUrl: profile?.avatarUrl,
                displayName: displayName,
                circleName: isOwnPost ? nil : item.circleName,
                timestamp: timestampLabel,
                isOnTime: isLocked ? nil : item.isOnTime,
                avatarSize: 36,
                onMenuTap: isOwnPost ? nil : { showMenu = true }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            // Photo card — edge-to-edge, 3:4 ratio
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: mainPhotoUrl) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .blur(radius: isLocked ? 20 : 0)
                } placeholder: {
                    Color(hex: "243828")
                        .overlay(ProgressView().tint(Color(hex: "D4A240")))
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(3.0 / 4.0, contentMode: .fill)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isLocked, let onOpenFullScreen { onOpenFullScreen() }
                }

                if isLocked {
                    // Lock overlay
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }

                // PiP — top-left
                if let pipUrl = pipPhotoUrl, !isLocked {
                    CachedAsyncImage(url: pipUrl) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color(hex: "243828")
                    }
                    .frame(width: 118, height: 157)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.msGold, lineWidth: 2)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) { swapped.toggle() }
                    }
                    .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .overlay {
                if item.hasNiyyah {
                    NoorAuraOverlay(cornerRadius: 32)
                }
            }

            // Actions row — floating on msBackground
            if !isLocked {
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
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Caption
                if let caption = item.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(Color(hex: "F0EAD6"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                }
            }

            // Gold divider
            Rectangle()
                .fill(Color.msGold.opacity(0.15))
                .frame(height: 1)
                .padding(.top, 16)
        }
        .confirmationDialog("Post Options", isPresented: $showMenu) {
            Button("Report", role: .destructive) {
                // Stub — toast in future
            }
            Button("Hide post") {
                // Stub — toast in future
            }
            Button("Cancel", role: .cancel) {}
        }
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

// MARK: - Preview

#Preview("Other user — dual camera") {
    let mockItem = MomentFeedItem(
        id: UUID(),
        circleId: UUID(),
        userId: UUID(),
        userName: "Yusuf Al-Rashid",
        circleName: "Brothers Circle",
        circleIds: [UUID()],
        circleNames: ["Brothers Circle"],
        photoUrl: "https://picsum.photos/seed/primary/400/533",
        secondaryPhotoUrl: "https://picsum.photos/seed/secondary/400/533",
        caption: "Alhamdulillah, fajr done ✓",
        postedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-720)),
        isOnTime: true,
        hasNiyyah: true
    )
    let vm = FeedViewModel()
    return ScrollView {
        MomentFeedCard(
            item: mockItem,
            currentUserId: UUID(),
            hasPostedToday: true,
            profile: nil,
            viewModel: vm
        )
    }
    .background(Color(hex: "1A2E1E"))
}
