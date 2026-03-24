import SwiftUI

struct FeedView: View {
    let circleId: UUID
    let currentUserId: UUID
    @Bindable var viewModel: FeedViewModel

    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                feedItemView(for: item)
                    .onAppear {
                        // Trigger next page when last 3 items come into view
                        if index >= viewModel.items.count - 3 {
                            Task {
                                await viewModel.loadNextPage(circleId: circleId)
                            }
                        }
                    }
            }

            // Bottom pagination indicator
            if viewModel.isLoadingNextPage {
                HStack {
                    Spacer()
                    ProgressView().tint(Color(hex: "E8834B"))
                    Spacer()
                }
                .padding(.vertical, 12)
            }

            // Empty feed state
            if viewModel.items.isEmpty && !viewModel.isLoadingInitial {
                VStack(spacing: 12) {
                    Text("No activity yet")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Check in to your habits or post a Moment to get started.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 24)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func feedItemView(for item: FeedItem) -> some View {
        switch item {
        case .moment(let m):
            MomentFeedCard(
                item: m, currentUserId: currentUserId,
                hasPostedToday: viewModel.hasPostedToday,
                viewModel: viewModel
            )
        case .habitCheckin(let h):
            HabitCheckinRow(
                item: h, currentUserId: currentUserId,
                viewModel: viewModel
            )
        case .streakMilestone(let s):
            StreakMilestoneCard(
                item: s, currentUserId: currentUserId,
                viewModel: viewModel
            )
        }
    }
}
