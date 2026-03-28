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

    func fetchMyCircles(userId: UUID) async throws -> [Circle] {
        struct MemberRow: Decodable {
            let circleId: UUID
            enum CodingKeys: String, CodingKey {
                case circleId = "circle_id"
            }
        }
        let memberRows: [MemberRow] = try await client
            .from("circle_members")
            .select("circle_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        guard !memberRows.isEmpty else { return [] }
        let ids = memberRows.map { $0.circleId.uuidString }
        return try await client
            .from("circles")
            .select()
            .in("id", values: ids)
            .order("created_at")
            .execute()
            .value
    }

    /// Full Amir onboarding circle creation — includes gender setting and core habits.
    func createCircleForAmir(
        name: String,
        description: String? = nil,
        genderSetting: String,
        coreHabits: [String],
        userId: UUID
    ) async throws -> Circle {
        let inviteCode = generateInviteCode()
        let row: [String: AnyJSON] = [
            "name": .string(name),
            "description": .string(description ?? ""),
            "created_by": .string(userId.uuidString),
            "invite_code": .string(inviteCode),
            "gender_setting": .string(genderSetting),
            "core_habits": .array(coreHabits.map { .string($0) })
        ]
        let circle: Circle = try await client
            .from("circles")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
        let memberRow: [String: AnyJSON] = [
            "circle_id": .string(circle.id.uuidString),
            "user_id": .string(userId.uuidString),
            "role": .string("admin")
        ]
        try await client.from("circle_members").insert(memberRow).execute()
        return circle
    }

    /// Standard circle creation from CommunityView (optional gender setting).
    func createCircle(name: String, description: String?, prayerTime: String?, userId: UUID, genderSetting: String = "mixed") async throws -> Circle {
        let inviteCode = generateInviteCode()
        let row: [String: AnyJSON] = [
            "name": .string(name),
            "description": .string(description ?? ""),
            "created_by": .string(userId.uuidString),
            "invite_code": .string(inviteCode),
            "gender_setting": .string(genderSetting)
        ]
        let circle: Circle = try await client
            .from("circles")
            .insert(row)
            .select()
            .single()
            .execute()
            .value

        let memberRow: [String: AnyJSON] = [
            "circle_id": .string(circle.id.uuidString),
            "user_id": .string(userId.uuidString),
            "role": .string("admin")
        ]
        try await client
            .from("circle_members")
            .insert(memberRow)
            .execute()

        return circle
    }

    func fetchCircleByCode(_ code: String) async throws -> Circle {
        let results: [Circle] = try await client
            .from("circles")
            .select()
            .eq("invite_code", value: code)
            .limit(1)
            .execute()
            .value
        guard let circle = results.first else {
            throw CircleError.notFound
        }
        return circle
    }

    func joinByInviteCode(_ code: String, userId: UUID) async throws -> Circle {
        let circle = try await fetchCircleByCode(code)
        let memberRow: [String: AnyJSON] = [
            "circle_id": .string(circle.id.uuidString),
            "user_id": .string(userId.uuidString),
            "role": .string("member")
        ]
        try await client
            .from("circle_members")
            .insert(memberRow)
            .execute()
        return circle
    }

    func fetchMembers(circleId: UUID) async throws -> [CircleMember] {
        try await client
            .from("circle_members")
            .select()
            .eq("circle_id", value: circleId.uuidString)
            .execute()
            .value
    }

    // MARK: - Private

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }
}


enum CircleError: LocalizedError {
    case notFound
    case genderMismatch(circleName: String, genderSetting: String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Circle not found. Check the invite code and try again."
        case .genderMismatch(let name, let setting):
            let label = setting == "brothers" ? "brothers-only" : "sisters-only"
            return "'\(name)' is a \(label) circle."
        }
    }
}
