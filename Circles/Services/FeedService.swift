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
        case id; case displayName = "preferred_name"
    }
}

private struct CircleNameRow: Decodable {
    let id: UUID
    let name: String
}

// MARK: - FeedService

@Observable
@MainActor
final class FeedService {
    static let shared = FeedService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Paginated Feed Fetch

    /// Returns up to `pageSize` FeedItems across one or more circles, newest first.
    /// Pass a single-element array for per-circle feeds (CircleDetailView),
    /// or the full list of the user's circle IDs for the global community feed.
    func fetchFeedPage(circleIds: [UUID], page: Int, pageSize: Int = 20) async throws -> [FeedItem] {
        guard !circleIds.isEmpty else { return [] }
        let idStrings = circleIds.map { $0.uuidString }

        // 1. Fetch activity_feed rows for these circles
        let activityRows: [ActivityFeedRow] = try await client
            .from("activity_feed")
            .select()
            .in("circle_id", values: idStrings)
            .order("created_at", ascending: false)
            .execute()
            .value

        // 2. Fetch circle_moments rows for these circles
        let momentRows: [CircleMomentRow] = try await client
            .from("circle_moments")
            .select()
            .in("circle_id", values: idStrings)
            .order("posted_at", ascending: false)
            .execute()
            .value

        // 3. Collect unique user IDs from both result sets
        var userIdSet = Set<UUID>()
        activityRows.forEach { userIdSet.insert($0.userId) }
        momentRows.forEach { userIdSet.insert($0.userId) }

        // 4. Build display name + circle name lookups
        async let nameMapTask = fetchDisplayNames(userIds: Array(userIdSet))
        async let circleNameMapTask = fetchCircleNames(circleIds: circleIds)
        let nameMap = await nameMapTask
        let circleNameMap = await circleNameMapTask

        // 5. Map ActivityFeedRow -> FeedItem (habitCheckin or streakMilestone)
        let activityFeedItems: [FeedItem] = activityRows.compactMap { row in
            let userName = nameMap[row.userId] ?? String(row.userId.uuidString.prefix(8))
            let circleName = circleNameMap[row.circleId] ?? ""
            switch row.eventType {
            case "habit_checkin":
                return .habitCheckin(HabitCheckinFeedItem(
                    id: row.id,
                    circleId: row.circleId,
                    userId: row.userId,
                    userName: userName,
                    circleName: circleName,
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
                    circleName: circleName,
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
            let circleName = circleNameMap[row.circleId] ?? ""
            return .moment(MomentFeedItem(
                id: row.id,
                circleId: row.circleId,
                userId: row.userId,
                userName: userName,
                circleName: circleName,
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
                .select("id, preferred_name")
                .in("id", values: userIds.map { $0.uuidString })
                .execute()
                .value
            var map = [UUID: String]()
            for profile in profiles {
                map[profile.id] = profile.displayName
            }
            return map
        } catch {
            return [:]
        }
    }

    /// Fetch circle names for a set of circle IDs.
    private func fetchCircleNames(circleIds: [UUID]) async -> [UUID: String] {
        guard !circleIds.isEmpty else { return [:] }
        do {
            let rows: [CircleNameRow] = try await client
                .from("circles")
                .select("id, name")
                .in("id", values: circleIds.map { $0.uuidString })
                .execute()
                .value
            var map = [UUID: String]()
            for row in rows { map[row.id] = row.name }
            return map
        } catch {
            return [:]
        }
    }
}
