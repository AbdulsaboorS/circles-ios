import SwiftUI

private enum FeedFilter: String, CaseIterable {
    case posts = "Posts"
    case checkins = "Check-ins"
}

struct FeedView: View {
    let circleIds: [UUID]
    let currentUserId: UUID
    @Bindable var viewModel: FeedViewModel
    var showFilterTabs: Bool = false

    @State private var commentingOnItem: FeedItem? = nil
    @State private var activeFilter: FeedFilter = .posts

    private var filteredItems: [FeedItem] {
        guard showFilterTabs else { return viewModel.items }
        switch activeFilter {
        case .posts:    return viewModel.items.filter { if case .moment = $0 { return true }; return false }
        case .checkins: return viewModel.items.filter { if case .moment = $0 { return false }; return true }
        }
    }

    var body: some View {
        LazyVStack(spacing: 10) {
            if showFilterTabs {
                feedFilterPicker
                    .padding(.bottom, 4)
            }

            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                feedItemView(for: item)
                    .onAppear {
                        if index >= filteredItems.count - 3 {
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

            if filteredItems.isEmpty && !viewModel.isLoadingInitial {
                VStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(hex: "D4A240").opacity(0.5))
                    Text(activeFilter == .checkins && showFilterTabs ? "No check-ins yet." : "No moments yet.")
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

    // MARK: - Filter Picker

    private var feedFilterPicker: some View {
        HStack(spacing: 0) {
            ForEach(FeedFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { activeFilter = filter }
                } label: {
                    Text(filter.rawValue)
                        .font(.system(size: 14, weight: activeFilter == filter ? .semibold : .regular))
                        .foregroundStyle(activeFilter == filter ? Color(hex: "1A2E1E") : Color(hex: "8FAF94"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            activeFilter == filter ? Color(hex: "D4A240") : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(hex: "243828"), in: Capsule())
        .overlay(Capsule().stroke(Color(hex: "D4A240").opacity(0.18), lineWidth: 1))
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
