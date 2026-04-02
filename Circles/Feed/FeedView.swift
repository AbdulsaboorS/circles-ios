import SwiftUI

struct FeedView: View {
    let circleIds: [UUID]
    let currentUserId: UUID
    @Bindable var viewModel: FeedViewModel

    @State private var commentingOnItem: FeedItem? = nil

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                feedItemView(for: item)
                    .onAppear {
                        if index >= viewModel.items.count - 3 {
                            Task { await viewModel.loadNextPage(circleIds: circleIds) }
                        }
                    }
            }

            if viewModel.isLoadingNextPage {
                HStack {
                    Spacer()
                    ProgressView().tint(Color(hex: "D4A240"))
                    Spacer()
                }
                .padding(.vertical, 12)
            }

            if viewModel.items.isEmpty && !viewModel.isLoadingInitial {
                VStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(hex: "D4A240").opacity(0.5))
                    Text("No moments yet.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color(hex: "F0EAD6"))
                    Text("Be the first to post today.")
                        .font(.appCaption)
                        .foregroundStyle(Color(hex: "8FAF94"))
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 24)
            }
        }
        .padding(.horizontal, 16)
        .sheet(item: $commentingOnItem) { item in
            CommentDrawerView(
                postId: item.id,
                postType: item.postType,
                circleId: item.circleId,
                currentUserId: currentUserId
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func feedItemView(for item: FeedItem) -> some View {
        switch item {
        case .moment(let m):
            MomentFeedCard(item: m, currentUserId: currentUserId,
                           hasPostedToday: viewModel.hasPostedToday,
                           profile: viewModel.authorProfiles[m.userId],
                           viewModel: viewModel, onComment: { commentingOnItem = item })
        case .habitCheckin(let h):
            HabitCheckinRow(item: h, currentUserId: currentUserId,
                            profile: viewModel.authorProfiles[h.userId],
                            viewModel: viewModel, onComment: { commentingOnItem = item })
        case .streakMilestone(let s):
            StreakMilestoneCard(item: s, currentUserId: currentUserId,
                                profile: viewModel.authorProfiles[s.userId],
                                viewModel: viewModel, onComment: { commentingOnItem = item })
        }
    }
}
