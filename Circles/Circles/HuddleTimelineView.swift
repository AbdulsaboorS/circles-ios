import SwiftUI

struct HuddleTimelineView: View {
    @Bindable var feedViewModel: FeedViewModel
    let circleId: UUID
    let currentUserId: UUID

    var body: some View {
        LazyVStack(spacing: 0) {
            if feedViewModel.items.isEmpty && !feedViewModel.isLoadingInitial {
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
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(Color.msGold.opacity(0.5))
            Text("No activity yet today")
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundStyle(Color.msTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func relativeTime(_ iso: String) -> String {
        CircleCardData.relativeTimestamp(iso)
    }
}
