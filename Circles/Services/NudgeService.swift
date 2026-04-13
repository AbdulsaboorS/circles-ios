import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class NudgeService {
    static let shared = NudgeService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

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
}

    /// Send a direct nudge to a single member with an optional custom message.
    /// nudgeType: "habit_reminder" or "custom" (with message text).
    func sendDirectNudge(
        circleId: UUID,
        senderId: UUID,
        targetUserId: UUID,
        nudgeType: String,
        message: String? = nil
    ) async throws {
        guard targetUserId != senderId else { return }

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
