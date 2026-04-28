import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class FeedViewModel {
    // MARK: - State

    var items: [FeedItem] = []
    /// reactions keyed by item id — [item_id: [FeedReaction]]
    var reactions: [UUID: [FeedReaction]] = [:]
    /// Avatars for users who reacted (merged across feed items).
    var reactionProfiles: [UUID: Profile] = [:]
    var authorProfiles: [UUID: Profile] = [:]
    var isLoadingInitial = false
    var isLoadingNextPage = false
    var hasMorePages = true
    var errorMessage: String?
    /// Whether the current user has posted a Moment today (used for reciprocity gate)
    var hasPostedToday = false

    // MARK: - Private

    private var currentPage = 0
    private let pageSize = 20

    // MARK: - Public API

    /// Load first page. Pass `[circle.id]` for a single-circle feed or all circle IDs for global.
    /// When `singleCircleId` is provided, also checks reciprocity gate for that circle.
    func loadInitial(circleIds: [UUID], currentUserId: UUID, singleCircleId: UUID? = nil) async {
        guard !isLoadingInitial else { return }
        isLoadingInitial = true
        errorMessage = nil
        currentPage = 0
        hasMorePages = true
        do {
            let firstPage = try await FeedService.shared.fetchFeedPage(circleIds: circleIds, page: 0, pageSize: pageSize)
            // Pin own moments to top in single-circle feed
            let sorted = singleCircleId != nil
                ? Self.pinOwnMoments(firstPage, currentUserId: currentUserId)
                : firstPage
            items = sorted
            hasMorePages = firstPage.count == pageSize

            // Reciprocity gate: only relevant for single-circle views
            if let cid = singleCircleId {
                let todayMoments = try await MomentService.shared.fetchTodayMoments(circleId: cid)
                hasPostedToday = todayMoments.contains { $0.userId == currentUserId }
            } else {
                hasPostedToday = true // no gate on global feed
            }

            if !firstPage.isEmpty {
                let ids = firstPage.map { $0.id }
                reactions = Dictionary(grouping: try await FeedService.shared.fetchReactions(itemIds: ids), by: { $0.itemId })
            } else {
                reactions = [:]
            }
            await mergeAuthorProfiles()
            await mergeReactionProfiles()
        } catch {
            if !(error is CancellationError) { errorMessage = error.localizedDescription }
        }
        isLoadingInitial = false
    }

    func loadNextPage(circleIds: [UUID]) async {
        guard !isLoadingNextPage, hasMorePages else { return }
        isLoadingNextPage = true
        do {
            let nextPage = currentPage + 1
            let newItems = try await FeedService.shared.fetchFeedPage(circleIds: circleIds, page: nextPage, pageSize: pageSize)
            currentPage = nextPage
            items.append(contentsOf: newItems)
            hasMorePages = newItems.count == pageSize

            if !newItems.isEmpty {
                let ids = newItems.map { $0.id }
                let newReactions = try await FeedService.shared.fetchReactions(itemIds: ids)
                for reaction in newReactions {
                    reactions[reaction.itemId, default: []].append(reaction)
                }
                await mergeAuthorProfiles()
                await mergeReactionProfiles()
            } else {
                await mergeAuthorProfiles()
            }
        } catch {
            if !(error is CancellationError) { errorMessage = error.localizedDescription }
        }
        isLoadingNextPage = false
    }

    func refresh(circleIds: [UUID], currentUserId: UUID, singleCircleId: UUID? = nil) async {
        isLoadingInitial = false  // allow reload even if a prior load is in flight
        // Keep existing items visible during refresh — no blank-screen flash
        await loadInitial(circleIds: circleIds, currentUserId: currentUserId, singleCircleId: singleCircleId)
    }

    func insertOptimisticMoment(_ item: MomentFeedItem) {
        items.removeAll { existing in
            guard case .moment(let moment) = existing else { return false }
            return moment.userId == item.userId && moment.momentDate == item.momentDate
        }
        items.insert(.moment(item), at: 0)
        hasPostedToday = true
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        reactions.removeValue(forKey: id)
    }

    // MARK: - Optimistic Caption Update

    /// Immediately updates the caption on the matching moment item in memory.
    /// Called right after a successful DB write — no refresh needed.
    func updateMomentCaption(momentId: UUID, caption: String?) {
        items = items.map { item in
            guard case .moment(let m) = item, m.id == momentId else { return item }
            return .moment(MomentFeedItem(
                id: m.id, circleId: m.circleId, userId: m.userId,
                userName: m.userName, circleName: m.circleName,
                circleIds: m.circleIds, circleNames: m.circleNames,
                photoUrl: m.photoUrl, secondaryPhotoUrl: m.secondaryPhotoUrl,
                caption: caption,
                postedAt: m.postedAt, momentDate: m.momentDate,
                isOnTime: m.isOnTime,
                hasNiyyah: m.hasNiyyah
            ))
        }
    }

    // MARK: - Optimistic Reaction Toggle
    // Pattern mirrors HomeViewModel.toggleHabit — optimistic update, revert on error.

    func toggleReaction(itemId: UUID, itemType: String, currentUserId: UUID, emoji: String) async {
        let existingForUser = reactions[itemId, default: []].first { $0.userId == currentUserId }

        // Optimistic update
        if let existing = existingForUser {
            if existing.emoji == emoji {
                // Remove reaction
                reactions[itemId]?.removeAll { $0.userId == currentUserId }
            } else {
                // Replace emoji
                reactions[itemId]?.removeAll { $0.userId == currentUserId }
                let placeholder = FeedReaction(
                    id: UUID(), itemId: itemId, itemType: itemType,
                    userId: currentUserId, emoji: emoji,
                    createdAt: ISO8601DateFormatter().string(from: Date())
                )
                reactions[itemId, default: []].append(placeholder)
            }
        } else {
            // Add new reaction
            let placeholder = FeedReaction(
                id: UUID(), itemId: itemId, itemType: itemType,
                userId: currentUserId, emoji: emoji,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            reactions[itemId, default: []].append(placeholder)
        }

        // Persist to Supabase (do NOT use do/catch to revert here — optimistic is good enough for reactions)
        do {
            try await FeedService.shared.toggleReaction(
                itemId: itemId, itemType: itemType, userId: currentUserId, emoji: emoji
            )
        } catch {
            print("[FeedViewModel] reaction toggle failed: \(error)")
        }
    }

    // MARK: - Own-Moment Pinning

    /// Moves the current user's moment items to the front, preserving relative order.
    private static func pinOwnMoments(_ items: [FeedItem], currentUserId: UUID) -> [FeedItem] {
        let ownMoments = items.filter {
            if case .moment(let m) = $0 { return m.userId == currentUserId }
            return false
        }
        let others = items.filter {
            if case .moment(let m) = $0 { return m.userId != currentUserId }
            return true
        }
        return ownMoments + others
    }

    // MARK: - Helpers

    /// Count of a specific emoji on an item
    func reactionCount(itemId: UUID, emoji: String) -> Int {
        reactions[itemId, default: []].filter { $0.emoji == emoji }.count
    }

    /// Whether the current user has reacted with this emoji on this item
    func userHasReacted(itemId: UUID, emoji: String, userId: UUID) -> Bool {
        reactions[itemId, default: []].contains { $0.userId == userId && $0.emoji == emoji }
    }

    /// Distinct reactor user ids for face pile (stable: first-seen order in stored reactions).
    func reactorUserIds(for itemId: UUID) -> [UUID] {
        var seen = Set<UUID>()
        var ordered: [UUID] = []
        for r in reactions[itemId, default: []] {
            if !seen.contains(r.userId) {
                seen.insert(r.userId)
                ordered.append(r.userId)
            }
        }
        return ordered
    }

    private func mergeReactionProfiles() async {
        let ids = Set(reactions.values.flatMap { $0.map(\.userId) })
        guard !ids.isEmpty else {
            reactionProfiles = [:]
            return
        }
        let profiles = (try? await AvatarService.shared.fetchProfiles(userIds: Array(ids))) ?? []
        var next = reactionProfiles
        for p in profiles { next[p.id] = p }
        reactionProfiles = next
    }

    private func mergeAuthorProfiles() async {
        let ids = Set(items.map { item -> UUID in
            switch item {
            case .moment(let moment):
                return moment.userId
            case .habitCheckin(let habit):
                return habit.userId
            case .streakMilestone(let streak):
                return streak.userId
            }
        })
        guard !ids.isEmpty else {
            authorProfiles = [:]
            return
        }
        let profiles = (try? await AvatarService.shared.fetchProfiles(userIds: Array(ids))) ?? []
        var next = authorProfiles
        for profile in profiles { next[profile.id] = profile }
        authorProfiles = next
    }
}
