import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class NudgeService {
    static let shared = NudgeService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    struct SentCountEvent {
        let sentCount: Int
    }

    /// Sends encouragement to up to two quiet members in a circle, then records
    /// the circle-level nudge event in `nudges` for local card state / analytics.
    @discardableResult
    func sendCircleEncouragement(
        circleId: UUID,
        senderId: UUID,
        targetUserIds: [UUID],
        nudgeType: String = "moment"
    ) async throws -> Int {
        let targets = Self.stableUnique(targetUserIds)
        guard !targets.isEmpty else { throw NudgeError.noQuietMembers }

        var successfulTargetCount = 0

        for targetUserId in targets.prefix(2) where targetUserId != senderId {
            do {
                try await client.functions
                    .invoke(
                        "send-peer-nudge",
                        options: .init(body: [
                            "senderId": senderId.uuidString,
                            "targetUserId": targetUserId.uuidString,
                            "circleId": circleId.uuidString,
                            "nudgeType": nudgeType
                        ])
                    )
                successfulTargetCount += 1
            } catch {
                // The function already enforces sender-target daily rate limits.
                // We only fail the overall card action if no target accepted the nudge.
                print("[NudgeService] send-peer-nudge failed target=\(targetUserId) error=\(error)")
            }
        }

        guard successfulTargetCount > 0 else { throw NudgeError.allTargetsRateLimited }

        let row: [String: AnyJSON] = [
            "circle_id": .string(circleId.uuidString),
            "sender_id": .string(senderId.uuidString)
        ]
        try await client
            .from("nudges")
            .insert(row)
            .execute()

        NotificationCenter.default.post(
            name: .nudgeSent,
            object: SentCountEvent(sentCount: successfulTargetCount)
        )

        return successfulTargetCount
    }

    /// Count how many nudges the sender has sent today across the given circles.
    func fetchNudgeCounts(circleIds: [UUID], senderId: UUID) async throws -> [UUID: Int] {
        guard !circleIds.isEmpty else { return [:] }

        let todayStart = Self.todayUTCStart()
        let rows: [Nudge] = try await client
            .from("nudges")
            .select()
            .in("circle_id", values: circleIds.map { $0.uuidString })
            .eq("sender_id", value: senderId.uuidString)
            .gte("created_at", value: todayStart)
            .execute()
            .value

        var counts: [UUID: Int] = [:]
        for row in rows {
            counts[row.circleId, default: 0] += 1
        }
        return counts
    }

    private static func todayUTCStart() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return "\(formatter.string(from: Date()))T00:00:00Z"
    }

    private static func stableUnique(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }

    func fetchLifetimeSentCount(userId: UUID) async throws -> Int {
        let params: [String: AnyJSON] = [
            "p_user_id": .string(userId.uuidString)
        ]

        do {
            struct SentCountRow: Decodable {
                let sentCount: Int

                enum CodingKeys: String, CodingKey {
                    case sentCount = "sent_count"
                }
            }

            let row: SentCountRow = try await client
                .rpc("fetch_nudges_sent_count", params: params)
                .single()
                .execute()
                .value
            return row.sentCount
        } catch {
            struct NudgeLogRow: Decodable { let id: UUID }
            let rows: [NudgeLogRow] = try await client
                .from("nudge_log")
                .select("id")
                .eq("sender_id", value: userId.uuidString)
                .execute()
                .value
            return rows.count
        }
    }

    /// Send a direct nudge to a single member with an optional custom message.
    /// nudgeType: "habit_reminder" or "custom" (with message text).
    @discardableResult
    func sendDirectNudge(
        circleId: UUID,
        senderId: UUID,
        targetUserId: UUID,
        nudgeType: String,
        message: String? = nil
    ) async throws -> Int {
        guard targetUserId != senderId else { return 0 }

        var body: [String: String] = [
            "senderId": senderId.uuidString,
            "targetUserId": targetUserId.uuidString,
            "circleId": circleId.uuidString,
            "nudgeType": nudgeType
        ]
        if let message, !message.isEmpty {
            body["message"] = message
        }

        try await client.functions
            .invoke("send-peer-nudge", options: .init(body: body))

        NotificationCenter.default.post(
            name: .nudgeSent,
            object: SentCountEvent(sentCount: 1)
        )

        return 1
    }
}

enum NudgeError: LocalizedError {
    case noQuietMembers
    case allTargetsRateLimited

    var errorDescription: String? {
        switch self {
        case .noQuietMembers:
            return "No quiet members need encouragement right now."
        case .allTargetsRateLimited:
            return "You've already nudged the available members today."
        }
    }
}

extension Notification.Name {
    static let nudgeSent = Notification.Name("nudgeSent")
}
