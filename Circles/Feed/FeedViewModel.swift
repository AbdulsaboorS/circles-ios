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
            items = firstPage
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
            }
        } catch {
            errorMessage = error.localizedDescription
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
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingNextPage = false
    }

    func refresh(circleIds: [UUID], currentUserId: UUID, singleCircleId: UUID? = nil) async {
        items = []
        reactions = [:]
        await loadInitial(circleIds: circleIds, currentUserId: currentUserId, singleCircleId: singleCircleId)
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
            // On failure: silently log, keep optimistic state (reactions are low-stakes)
            // If stricter revert is needed, reload reactions for this item
            errorMessage = error.localizedDescription
        }
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
}
