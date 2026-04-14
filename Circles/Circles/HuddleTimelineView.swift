import SwiftUI

struct HuddleTimelineView: View {
    @Bindable var feedViewModel: FeedViewModel
    let circleId: UUID
    let currentUserId: UUID

    var body: some View {
        LazyVStack(spacing: 0) {
            if feedViewModel.isLoadingInitial && feedViewModel.items.isEmpty {
                huddleShimmer
            } else if feedViewModel.items.isEmpty {
                emptyState
            }

            ForEach(feedViewModel.items) { item in
                timelineRow(item)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Rectangle()
                    .fill(Color.msBorder)
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)

                    .onAppear {
                        // Pagination trigger
                        if item.id == feedViewModel.items.suffix(3).first?.id {
                            Task {
                                await feedViewModel.loadNextPage(circleIds: [circleId])
                            }
                        }
                    }
            }

            if feedViewModel.isLoadingNextPage {
                HStack { Spacer(); ProgressView().tint(Color.msGold); Spacer() }
                    .padding(.vertical, 16)
            }
        }
    }

    @ViewBuilder
    private func timelineRow(_ item: FeedItem) -> some View {
        switch item {
        case .habitCheckin(let h):
            HStack(spacing: 10) {
                AvatarView(
                    avatarUrl: feedViewModel.authorProfiles[h.userId]?.avatarUrl,
                    name: h.userName,
                    size: 28
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(h.userName) finished **\(h.habitName)**")
                        .font(.appBody)
                        .foregroundStyle(Color.msTextPrimary)
                    Text(relativeTime(h.checkedAt))
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)
                }
                Spacer(minLength: 0)
            }

        case .streakMilestone(let s):
            HStack(spacing: 10) {
                AvatarView(
                    avatarUrl: feedViewModel.authorProfiles[s.userId]?.avatarUrl,
                    name: s.userName,
                    size: 28
                )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("🔥")
                            .font(.system(size: 14))
                        Text("\(s.userName) hit a \(s.streakDays)-day streak")
                            .font(.appBody)
                            .foregroundStyle(Color.msTextPrimary)
                    }
                    Text(relativeTime(s.achievedAt))
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)
                }
                Spacer(minLength: 0)
            }

        case .moment(let m):
            HStack(spacing: 10) {
                AvatarView(
                    avatarUrl: feedViewModel.authorProfiles[m.userId]?.avatarUrl,
                    name: m.userName,
                    size: 28
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(m.userName) shared a Moment")
                        .font(.appBody)
                        .foregroundStyle(Color.msTextPrimary)
                    Text(relativeTime(m.postedAt))
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "moon.stars")
                .font(.system(size: 34))
                .foregroundStyle(Color.msGold.opacity(0.55))
            Text("The circle is quiet.")
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(Color.msTextPrimary)
            Text("Check in a habit on the Home tab\nto be the first light today.")
                .font(.system(size: 13))
                .foregroundStyle(Color.msTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private var huddleShimmer: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 10) {
                    ShimmerView()
                        .frame(width: 28, height: 28)
                        .clipShape(SwiftUI.Circle())
                    VStack(alignment: .leading, spacing: 6) {
                        ShimmerView()
                            .frame(height: 12)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        ShimmerView()
                            .frame(width: 80, height: 10)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                Rectangle()
                    .fill(Color.msBorder)
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
            }
        }
    }

    private func relativeTime(_ iso: String) -> String {
        CircleCardData.relativeTimestamp(iso)
    }
}
