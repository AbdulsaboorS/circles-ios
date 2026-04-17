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
    let secondaryPhotoUrl: String?
    let caption: String?
    let postedAt: String
    let isOnTime: Bool
    let hasNiyyah: Bool

    enum CodingKeys: String, CodingKey {
        case id; case circleId = "circle_id"; case userId = "user_id"
        case photoUrl = "photo_url"; case secondaryPhotoUrl = "secondary_photo_url"
        case caption
        case postedAt = "posted_at"; case isOnTime = "is_on_time"
        case hasNiyyah = "has_niyyah"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        circleId = try c.decode(UUID.self, forKey: .circleId)
        userId = try c.decode(UUID.self, forKey: .userId)
        photoUrl = try c.decode(String.self, forKey: .photoUrl)
        secondaryPhotoUrl = try c.decodeIfPresent(String.self, forKey: .secondaryPhotoUrl)
        caption = try c.decodeIfPresent(String.self, forKey: .caption)
        postedAt = try c.decode(String.self, forKey: .postedAt)
        isOnTime = try c.decode(Bool.self, forKey: .isOnTime)
        hasNiyyah = try c.decodeIfPresent(Bool.self, forKey: .hasNiyyah) ?? false
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

        let momentRange = await DailyMomentService.shared.fetchActiveMomentRange()
        let todayStart = Self.todayUTCStart()
        let todayEnd   = Self.todayUTCEnd()

        // 1+2. Fetch activity_feed and circle_moments concurrently
        async let activityFetch: [ActivityFeedRow] = client
            .from("activity_feed")
            .select()
            .in("circle_id", values: idStrings)
            .gte("created_at", value: todayStart)
            .lt("created_at", value: todayEnd)
            .order("created_at", ascending: false)
            .execute()
            .value

        async let momentFetch: [CircleMomentRow] = client
            .from("circle_moments")
            .select()
            .in("circle_id", values: idStrings)
            .gte("posted_at", value: momentRange.startISO8601)
            .lt("posted_at", value: momentRange.endExclusiveISO8601)
            .order("posted_at", ascending: false)
            .execute()
            .value

        let activityRows = try await activityFetch
        let momentRows = try await momentFetch
        let resolvedPhotoURLs = try await resolveMomentPhotoURLsConcurrent(for: momentRows)

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

        // 6. Deduplicate CircleMomentRows by (userId, date) → one card per photo
        //    Group rows that share the same user and calendar day (prefix 10 of ISO8601 = YYYY-MM-DD).
        typealias DedupeKey = String  // "\(userId)|\(YYYY-MM-DD)"
        var groupOrder: [DedupeKey] = []
        var groups: [DedupeKey: [CircleMomentRow]] = [:]
        for row in momentRows {
            let datePrefix = String(row.postedAt.prefix(10))
            let key = "\(row.userId.uuidString)|\(datePrefix)"
            if groups[key] == nil { groupOrder.append(key) }
            groups[key, default: []].append(row)
        }

        let momentFeedItems: [FeedItem] = groupOrder.compactMap { key -> FeedItem? in
            guard let rowGroup = groups[key], let first = rowGroup.first else { return nil }
            let userName = nameMap[first.userId] ?? String(first.userId.uuidString.prefix(8))
            let dedupedCircleIds = rowGroup.map { $0.circleId }
            let dedupedCircleNames = rowGroup.map { circleNameMap[$0.circleId] ?? "" }
            let resolved = resolvedPhotoURLs[first.id]
            return .moment(MomentFeedItem(
                id: first.id,
                circleId: first.circleId,
                userId: first.userId,
                userName: userName,
                circleName: circleNameMap[first.circleId] ?? "",
                circleIds: dedupedCircleIds,
                circleNames: dedupedCircleNames,
                photoUrl: resolved?.primary ?? first.photoUrl,
                secondaryPhotoUrl: resolved?.secondary,
                caption: first.caption,
                postedAt: first.postedAt,
                isOnTime: first.isOnTime,
                hasNiyyah: first.hasNiyyah
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

    // MARK: - Lightweight Card Queries

    /// Returns the single most recent activity as `LatestActivityInfo` per circle (today only).
    func fetchLatestActivityPerCircle(circleIds: [UUID]) async throws -> [UUID: LatestActivityInfo] {
        guard !circleIds.isEmpty else { return [:] }
        let idStrings = circleIds.map { $0.uuidString }
        let todayStart = Self.todayUTCStart()
        let todayEnd = Self.todayUTCEnd()

        let rows: [ActivityFeedRow] = try await client
            .from("activity_feed")
            .select()
            .in("circle_id", values: idStrings)
            .gte("created_at", value: todayStart)
            .lt("created_at", value: todayEnd)
            .order("created_at", ascending: false)
            .execute()
            .value

        // Group by circle, take first (most recent) per circle
        var latest: [UUID: ActivityFeedRow] = [:]
        for row in rows {
            if latest[row.circleId] == nil {
                latest[row.circleId] = row
            }
        }

        // Fetch display names for the latest-activity users
        let userIds = Array(Set(latest.values.map { $0.userId }))
        let nameMap = await fetchDisplayNames(userIds: userIds)

        var result: [UUID: LatestActivityInfo] = [:]
        for (circleId, row) in latest {
            let name = nameMap[row.userId] ?? String(row.userId.uuidString.prefix(8))
            result[circleId] = LatestActivityInfo(
                userName: name,
                userId: row.userId,
                eventType: row.eventType,
                habitName: row.habitName,
                streakDays: row.streakDays,
                timestamp: row.createdAt
            )
        }
        return result
    }

    /// Returns the most recent Moment per circle for today.
    func fetchLatestMomentPerCircle(circleIds: [UUID]) async throws -> [UUID: LatestMomentInfo] {
        guard !circleIds.isEmpty else { return [:] }
        let idStrings = circleIds.map { $0.uuidString }
        let momentRange = await DailyMomentService.shared.fetchActiveMomentRange()

        let rows: [CircleMomentRow] = try await client
            .from("circle_moments")
            .select()
            .in("circle_id", values: idStrings)
            .gte("posted_at", value: momentRange.startISO8601)
            .lt("posted_at", value: momentRange.endExclusiveISO8601)
            .order("posted_at", ascending: false)
            .execute()
            .value

        var latest: [UUID: CircleMomentRow] = [:]
        for row in rows where latest[row.circleId] == nil {
            latest[row.circleId] = row
        }

        let userIds = Array(Set(latest.values.map { $0.userId }))
        let nameMap = await fetchDisplayNames(userIds: userIds)

        var result: [UUID: LatestMomentInfo] = [:]
        for (circleId, row) in latest {
            let resolvedURL = try await MomentService.shared.resolveMomentPhotoURL(from: row.photoUrl)
            let userName = nameMap[row.userId] ?? String(row.userId.uuidString.prefix(8))
            result[circleId] = LatestMomentInfo(
                id: row.id,
                userId: row.userId,
                userName: userName,
                photoUrl: resolvedURL,
                caption: row.caption,
                postedAt: row.postedAt
            )
        }
        return result
    }

    /// Count active users today per circle across both Moments and activity_feed.
    func fetchActiveUserIdsToday(circleIds: [UUID]) async throws -> [UUID: Set<UUID>] {
        guard !circleIds.isEmpty else { return [:] }
        let idStrings = circleIds.map { $0.uuidString }
        let todayStart = Self.todayUTCStart()
        let todayEnd = Self.todayUTCEnd()
        let momentRange = await DailyMomentService.shared.fetchActiveMomentRange()

        async let activityRowsTask: [ActivityFeedRow] = client
            .from("activity_feed")
            .select("circle_id, user_id, event_type, habit_name, streak_days, created_at, id")
            .in("circle_id", values: idStrings)
            .gte("created_at", value: todayStart)
            .lt("created_at", value: todayEnd)
            .execute()
            .value

        async let momentRowsTask: [CircleMomentRow] = client
            .from("circle_moments")
            .select("id, circle_id, user_id, photo_url, secondary_photo_url, caption, posted_at, is_on_time, has_niyyah")
            .in("circle_id", values: idStrings)
            .gte("posted_at", value: momentRange.startISO8601)
            .lt("posted_at", value: momentRange.endExclusiveISO8601)
            .execute()
            .value

        let (activityRows, momentRows) = try await (activityRowsTask, momentRowsTask)

        var perCircle: [UUID: Set<UUID>] = [:]
        for row in activityRows {
            perCircle[row.circleId, default: []].insert(row.userId)
        }
        for row in momentRows {
            perCircle[row.circleId, default: []].insert(row.userId)
        }
        return perCircle
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

    // MARK: - Date helpers

    private static func todayUTCStart() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return "\(f.string(from: Date()))T00:00:00Z"
    }

    private static func todayUTCEnd() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return "\(f.string(from: Date()))T23:59:59Z"
    }

    // MARK: - Private helpers

    /// Resolves signed photo URLs. Serial today; Swift 6 region-isolation prevents naive TaskGroup
    /// use with @MainActor services — revisit when MomentService is nonisolated.
    private func resolveMomentPhotoURLsConcurrent(for rows: [CircleMomentRow]) async throws -> [UUID: (primary: String, secondary: String?)] {
        var result = [UUID: (primary: String, secondary: String?)]()
        result.reserveCapacity(rows.count)
        for row in rows {
            let primary = try await MomentService.shared.resolveMomentPhotoURL(from: row.photoUrl)
            let secondary: String? = if let sec = row.secondaryPhotoUrl {
                try? await MomentService.shared.resolveMomentPhotoURL(from: sec)
            } else {
                nil
            }
            result[row.id] = (primary: primary, secondary: secondary)
        }
        return result
    }

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
