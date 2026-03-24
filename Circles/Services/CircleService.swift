import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class CircleService {
    static let shared = CircleService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Circles

    /// Fetch all circles the current user belongs to (via halaqa_members join)
    func fetchMyCircles(userId: UUID) async throws -> [Circle] {
        // 2-step query: fetch halaqa_ids the user belongs to, then fetch those circles
        struct MemberRow: Decodable {
            let halaqaId: UUID
            enum CodingKeys: String, CodingKey {
                case halaqaId = "halaqa_id"
            }
        }
        let memberRows: [MemberRow] = try await client
            .from("halaqa_members")
            .select("halaqa_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        guard !memberRows.isEmpty else { return [] }
        let ids = memberRows.map { $0.halaqaId.uuidString }
        return try await client
            .from("halaqas")
            .select()
            .in("id", values: ids)
            .order("created_at")
            .execute()
            .value
    }

    /// Create a new circle and add the creator as admin member
    func createCircle(name: String, description: String?, prayerTime: String?, userId: UUID) async throws -> Circle {
        let inviteCode = generateInviteCode()
        let row: [String: AnyJSON] = [
            "name": .string(name),
            "description": .string(description ?? ""),
            "created_by": .string(userId.uuidString),
            "prayer_time": .string(prayerTime ?? ""),
            "invite_code": .string(inviteCode)
        ]
        let circle: Circle = try await client
            .from("halaqas")
            .insert(row)
            .select()
            .single()
            .execute()
            .value

        let memberRow: [String: AnyJSON] = [
            "halaqa_id": .string(circle.id.uuidString),
            "user_id": .string(userId.uuidString),
            "role": .string("admin")
        ]
        try await client
            .from("halaqa_members")
            .insert(memberRow)
            .execute()

        return circle
    }

    /// Join a circle by its invite code
    func joinByInviteCode(_ code: String, userId: UUID) async throws -> Circle {
        let results: [Circle] = try await client
            .from("halaqas")
            .select()
            .eq("invite_code", value: code)
            .limit(1)
            .execute()
            .value
        guard let circle = results.first else {
            throw URLError(.resourceUnavailable)
        }
        let memberRow: [String: AnyJSON] = [
            "halaqa_id": .string(circle.id.uuidString),
            "user_id": .string(userId.uuidString),
            "role": .string("member")
        ]
        try await client
            .from("halaqa_members")
            .insert(memberRow)
            .execute()
        return circle
    }

    /// Fetch all members of a circle
    func fetchMembers(circleId: UUID) async throws -> [HalaqaMember] {
        try await client
            .from("halaqa_members")
            .select()
            .eq("halaqa_id", value: circleId.uuidString)
            .execute()
            .value
    }

    // MARK: - Private

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }
}
