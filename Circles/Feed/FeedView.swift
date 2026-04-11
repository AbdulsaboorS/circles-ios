import SwiftUI

// MARK: - Feed Filter

enum FeedFilter: String, CaseIterable {
    case posts = "Posts"
    case checkins = "Check-ins"
}

// MARK: - Grouped Check-in types

struct UserCheckinGroup: Identifiable {
    let id: UUID        // userId
    let userName: String
    let avatarUrl: String?
    let circleName: String
    let habitCheckins: [HabitCheckinFeedItem]
    let streakMilestones: [StreakMilestoneFeedItem]
    let latestTimestamp: String  // ISO8601 of most recent activity
}

// MARK: - FeedView

struct FeedView: View {
    let circleIds: [UUID]
    let currentUserId: UUID
    @Bindable var viewModel: FeedViewModel
    private let showFilterTabs: Bool
    private let activeFilter: Binding<FeedFilter>
    private let excludeUserId: UUID?

    @State private var commentingOnItem: FeedItem? = nil

    // CommunityView path — filter tabs active, own moment excluded (shown in pinned card)
    init(
        circleIds: [UUID],
        currentUserId: UUID,
        viewModel: FeedViewModel,
        activeFilter: Binding<FeedFilter>,
        excludeUserId: UUID? = nil
    ) {
        self.circleIds = circleIds
        self.currentUserId = currentUserId
        self._viewModel = Bindable(wrappedValue: viewModel)
        self.showFilterTabs = true
        self.activeFilter = activeFilter
        self.excludeUserId = excludeUserId
    }

    // CircleDetailView path — no filter tabs
    init(
        circleIds: [UUID],
        currentUserId: UUID,
        viewModel: FeedViewModel,
        excludeUserId: UUID? = nil
    ) {
        self.circleIds = circleIds
        self.currentUserId = currentUserId
        self._viewModel = Bindable(wrappedValue: viewModel)
        self.showFilterTabs = false
        self.activeFilter = .constant(.posts)
        self.excludeUserId = excludeUserId
    }

    // MARK: - Computed Properties

    private var filteredItems: [FeedItem] {
        let base: [FeedItem]
        if showFilterTabs {
            switch activeFilter.wrappedValue {
            case .posts:
                base = viewModel.items.filter { if case .moment = $0 { return true }; return false }
            case .checkins:
                base = viewModel.items.filter { if case .moment = $0 { return false }; return true }
            }
        } else {
            base = viewModel.items
        }
        guard let excludeId = excludeUserId else { return base }
        return base.filter { item in
            if case .moment(let m) = item { return m.userId != excludeId }
            return true
        }
    }

    private var checkinGroups: [UserCheckinGroup] {
        var checkinMap: [UUID: [HabitCheckinFeedItem]] = [:]
        var streakMap: [UUID: [StreakMilestoneFeedItem]] = [:]
        var userMeta: [UUID: (name: String, circleName: String)] = [:]

        for item in viewModel.items {
            switch item {
            case .habitCheckin(let h):
                checkinMap[h.userId, default: []].append(h)
                userMeta[h.userId] = (h.userName, h.circleName)
            case .streakMilestone(let s):
                streakMap[s.userId, default: []].append(s)
                if userMeta[s.userId] == nil { userMeta[s.userId] = (s.userName, s.circleName) }
            case .moment:
                break
            }
        }

        return userMeta.keys.sorted { a, b in
            (userMeta[a]?.name ?? "") < (userMeta[b]?.name ?? "")
        }.map { userId in
            let checkins = checkinMap[userId, default: []]
            let streaks = streakMap[userId, default: []]
            let allTimestamps = checkins.map { $0.checkedAt } + streaks.map { $0.achievedAt }
            let latest = allTimestamps.max() ?? ""
            return UserCheckinGroup(
                id: userId,
                userName: userMeta[userId]!.name,
                avatarUrl: viewModel.authorProfiles[userId]?.avatarUrl,
                circleName: userMeta[userId]!.circleName,
                habitCheckins: checkins,
                streakMilestones: streaks,
                latestTimestamp: latest
            )
        }
    }

    // MARK: - Body

    var body: some View {
        LazyVStack(spacing: 10) {
            if showFilterTabs && activeFilter.wrappedValue == .checkins {
                // Grouped check-ins
                ForEach(checkinGroups) { group in
                    GroupedCheckinCard(
                        group: group,
                        currentUserId: currentUserId,
                        viewModel: viewModel,
                        onComment: {
                            if let first = group.habitCheckins.first {
                                commentingOnItem = .habitCheckin(first)
                            } else if let first = group.streakMilestones.first {
                                commentingOnItem = .streakMilestone(first)
                            }
                        }
                    )
                }
                if checkinGroups.isEmpty && !viewModel.isLoadingInitial {
                    emptyState(message: "No check-ins yet.", subMessage: "Check-ins from your circles will appear here.")
                }
            } else {
                // Normal feed items
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
                    emptyState(message: "No moments yet.", subMessage: "Be the first to post today.")
                }
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

    // MARK: - Helpers

    @ViewBuilder
    private func feedItemView(for item: FeedItem) -> some View {
        switch item {
        case .moment(let m):
            MomentFeedCard(
                item: m, currentUserId: currentUserId,
                hasPostedToday: viewModel.hasPostedToday,
                profile: viewModel.authorProfiles[m.userId],
                viewModel: viewModel,
                onComment: { commentingOnItem = item }
            )
        case .habitCheckin(let h):
            HabitCheckinRow(
                item: h, currentUserId: currentUserId,
                profile: viewModel.authorProfiles[h.userId],
                viewModel: viewModel,
                onComment: { commentingOnItem = item }
            )
        case .streakMilestone(let s):
            StreakMilestoneCard(
                item: s, currentUserId: currentUserId,
                profile: viewModel.authorProfiles[s.userId],
                viewModel: viewModel,
                onComment: { commentingOnItem = item }
            )
        }
    }

    @ViewBuilder
    private func emptyState(message: String, subMessage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color(hex: "D4A240").opacity(0.5))
            Text(message)
                .font(.appSubheadline)
                .foregroundStyle(Color(hex: "F0EAD6"))
            Text(subMessage)
                .font(.appCaption)
                .foregroundStyle(Color(hex: "8FAF94"))
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

// MARK: - GroupedCheckinCard

struct GroupedCheckinCard: View {
    let group: UserCheckinGroup
    let currentUserId: UUID
    @Bindable var viewModel: FeedViewModel
    var onComment: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Floating identity header — no card background behind it
            FeedIdentityHeader(
                avatarUrl: group.avatarUrl,
                displayName: group.userName,
                circleName: group.circleName,
                timestamp: relativeTimestamp(group.latestTimestamp)
            )
            .padding(.horizontal, 4)

            // Card body — habit pills + reactions + comment button only
            VStack(alignment: .leading, spacing: 10) {
                if !group.habitCheckins.isEmpty {
                    Text("Completed \(group.habitCheckins.count) intention\(group.habitCheckins.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "8FAF94"))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(group.habitCheckins) { checkin in
                                Text(checkin.habitName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color(hex: "1A2E1E"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(hex: "D4A240"), in: Capsule())
                            }
                        }
                    }
                }

                ForEach(group.streakMilestones) { milestone in
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "D4A240"))
                        Text("\(milestone.streakDays)-day streak on '\(milestone.habitName)'")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "F0EAD6"))
                    }
                }

                HStack {
                    if let first = group.habitCheckins.first {
                        ReactionBar(itemId: first.id, itemType: "habit_checkin",
                                    currentUserId: currentUserId, viewModel: viewModel)
                    } else if let first = group.streakMilestones.first {
                        ReactionBar(itemId: first.id, itemType: "streak_milestone",
                                    currentUserId: currentUserId, viewModel: viewModel)
                    }
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
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "243828"))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "D4A240").opacity(0.18), lineWidth: 1))
            )
        }
    }

    private func relativeTimestamp(_ iso: String) -> String {
        guard !iso.isEmpty else { return "" }
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
