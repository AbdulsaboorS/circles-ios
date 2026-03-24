import Foundation
import Observation
import Supabase

// MARK: - Private raw DB row types

private struct ActivityFeedRow: Decodable {
    let id: UUID
    let circleId: UUID
    let userId: UUID
    let eventType: String   // "habit_checkin" | "streak_milestone"
    let habitName: String
    let streakDays: Int?    // non-nil only for streak_milestone
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case circleId = "circle_id"
        case userId = "user_id"
        case eventType = "event_type"
        case habitName = "habit_name"
        case streakDays = "streak_days"
        case createdAt = "created_at"
    }
}

private struct CircleMomentRow: Decodable {
    let id: UUID
    let circleId: UUID
    let userId: UUID
    let photoUrl: String
    let caption: String?
    let postedAt: String
    let isOnTime: Bool

    enum CodingKeys: String, CodingKey {
        case id; case circleId = "circle_id"; case userId = "user_id"
        case photoUrl = "photo_url"; case caption
        case postedAt = "posted_at"; case isOnTime = "is_on_time"
    }
}

private struct ProfileRow: Decodable {
    let id: UUID
    let displayName: String
    enum CodingKeys: String, CodingKey {
        case id; case displayName = "display_name"
    }
}

// MARK: - FeedService

@Observable
@MainActor
final class FeedService {
    static let shared = FeedService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Paginated Feed Fetch

    /// Returns up to `pageSize` FeedItems for `circleId`, newest first.
    /// `page` is 0-indexed. Merges activity_feed rows and circle_moments rows,
    /// sorts by timestamp descending, then slices the page window.
    func fetchFeedPage(circleId: UUID, page: Int, pageSize: Int = 20) async throws -> [FeedItem] {
        // 1. Fetch all activity_feed rows for this circle
        let activityRows: [ActivityFeedRow] = try await client
            .from("activity_feed")
            .select()
            .eq("circle_id", value: circleId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        // 2. Fetch all circle_moments rows for this circle (all time, not just today)
        let momentRows: [CircleMomentRow] = try await client
            .from("circle_moments")
            .select()
            .eq("circle_id", value: circleId.uuidString)
            .order("posted_at", ascending: false)
            .execute()
            .value

        // 3. Collect unique user IDs from both result sets
        var userIdSet = Set<UUID>()
        activityRows.forEach { userIdSet.insert($0.userId) }
        momentRows.forEach { userIdSet.insert($0.userId) }

        // 4. Build display name lookup from profiles table
        let nameMap = await fetchDisplayNames(userIds: Array(userIdSet))

        // 5. Map ActivityFeedRow -> FeedItem (habitCheckin or streakMilestone)
        let activityFeedItems: [FeedItem] = activityRows.compactMap { row in
            let userName = nameMap[row.userId] ?? String(row.userId.uuidString.prefix(8))
            switch row.eventType {
            case "habit_checkin":
                return .habitCheckin(HabitCheckinFeedItem(
                    id: row.id,
                    circleId: row.circleId,
                    userId: row.userId,
                    userName: userName,
                    habitName: row.habitName,
                    checkedAt: row.createdAt
                ))
            case "streak_milestone":
                guard let streakDays = row.streakDays else { return nil }
                return .streakMilestone(StreakMilestoneFeedItem(
                    id: row.id,
                    circleId: row.circleId,
                    userId: row.userId,
                    userName: userName,
                    habitName: row.habitName,
                    streakDays: streakDays,
                    achievedAt: row.createdAt
                ))
            default:
                return nil
            }
        }

        // 6. Map CircleMomentRow -> FeedItem.moment
        let momentFeedItems: [FeedItem] = momentRows.map { row in
            let userName = nameMap[row.userId] ?? String(row.userId.uuidString.prefix(8))
            return .moment(MomentFeedItem(
                id: row.id,
                circleId: row.circleId,
                userId: row.userId,
                userName: userName,
                photoUrl: row.photoUrl,
                caption: row.caption,
                postedAt: row.postedAt,
                isOnTime: row.isOnTime
            ))
        }

        // 7. Merge, sort by sortTimestamp descending (lexicographic ISO8601 is valid for UTC)
        let all = (activityFeedItems + momentFeedItems)
            .sorted { $0.sortTimestamp > $1.sortTimestamp }

        // 8. Slice page window
        let start = page * pageSize
        guard start < all.count else { return [] }
        let end = min(start + pageSize, all.count)
        return Array(all[start..<end])
    }

    // MARK: - Reactions

    /// Fetch all FeedReactions for a batch of item IDs.
    func fetchReactions(itemIds: [UUID]) async throws -> [FeedReaction] {
        guard !itemIds.isEmpty else { return [] }
        return try await client
            .from("habit_reactions")
            .select()
            .in("item_id", values: itemIds.map { $0.uuidString })
            .execute()
            .value
    }

    /// Toggle a reaction: if current user already has this emoji on this item, delete it.
    /// Otherwise, delete any existing reaction from this user on this item, then insert the new one.
    func toggleReaction(itemId: UUID, itemType: String, userId: UUID, emoji: String) async throws {
        // 1. Check for existing reaction from this user on this item
        let existing: [FeedReaction] = try await client
            .from("habit_reactions")
            .select()
            .eq("item_id", value: itemId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        if let existingReaction = existing.first {
            if existingReaction.emoji == emoji {
                // 2. Same emoji — user is un-reacting: delete it
                try await client
                    .from("habit_reactions")
                    .delete()
                    .eq("id", value: existingReaction.id.uuidString)
                    .execute()
            } else {
                // 3. Different emoji — delete old, insert new
                try await client
                    .from("habit_reactions")
                    .delete()
                    .eq("id", value: existingReaction.id.uuidString)
                    .execute()
                let newRow: [String: AnyJSON] = [
                    "item_id": .string(itemId.uuidString),
                    "item_type": .string(itemType),
                    "user_id": .string(userId.uuidString),
                    "emoji": .string(emoji)
                ]
                try await client
                    .from("habit_reactions")
                    .insert(newRow)
                    .execute()
            }
        } else {
            // 4. No existing reaction — insert new
            let newRow: [String: AnyJSON] = [
                "item_id": .string(itemId.uuidString),
                "item_type": .string(itemType),
                "user_id": .string(userId.uuidString),
                "emoji": .string(emoji)
            ]
            try await client
                .from("habit_reactions")
                .insert(newRow)
                .execute()
        }
    }

    // MARK: - Private helpers

    /// Fetch display names for a set of user IDs from the profiles table.
    /// Falls back to UUID prefix if profiles table is unavailable or returns no rows.
    private func fetchDisplayNames(userIds: [UUID]) async -> [UUID: String] {
        guard !userIds.isEmpty else { return [:] }
        do {
            let profiles: [ProfileRow] = try await client
                .from("profiles")
                .select("id, display_name")
                .in("id", values: userIds.map { $0.uuidString })
                .execute()
                .value
            var map = [UUID: String]()
            for profile in profiles {
                map[profile.id] = profile.displayName
            }
            return map
        } catch {
            // Profiles table may not exist yet — fall back to UUID prefix
            return [:]
        }
    }
}
