import SwiftUI

struct MomentGalleryView: View {
    @Bindable var feedViewModel: FeedViewModel
    let currentUserId: UUID
    let hasPostedToday: Bool

    @State private var selectedMoment: MomentFeedItem?

    private var moments: [MomentFeedItem] {
        feedViewModel.items.compactMap {
            if case .moment(let m) = $0 { return m }
            return nil
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        if moments.isEmpty && !feedViewModel.isLoadingInitial {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(moments.enumerated()), id: \.element.id) { index, moment in
                    let isLocked = moment.userId != currentUserId && !hasPostedToday
                    let aspectHeight: CGFloat = index % 3 == 0 ? 240 : 180

                    ZStack {
                        CachedAsyncImage(url: moment.photoUrl) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                        }
                        .frame(height: aspectHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if isLocked {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.msTextMuted)
                        }

                        if !isLocked {
                            VStack {
                                Spacer()
                                HStack(spacing: 6) {
                                    AvatarView(
                                        avatarUrl: feedViewModel.authorProfiles[moment.userId]?.avatarUrl,
                                        name: moment.userName,
                                        size: 20
                                    )
                                    Text(moment.userName.components(separatedBy: .whitespaces).first ?? moment.userName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                .padding(8)
                                .background(
                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.5)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(height: aspectHeight)
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        guard !isLocked else { return }
                        selectedMoment = moment
                    }
                }
            }
            .padding(.horizontal, 16)
            .fullScreenCover(item: $selectedMoment) { moment in
                MomentFullScreenView(
                    item: moment,
                    currentUserId: currentUserId,
                    profile: feedViewModel.authorProfiles[moment.userId],
                    viewModel: feedViewModel
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36))
                .foregroundStyle(Color.msGold.opacity(0.5))
            Text("No moments shared yet")
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundStyle(Color.msTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
