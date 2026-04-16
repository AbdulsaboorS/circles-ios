import Foundation
import Observation
import Supabase
import UIKit

@Observable
@MainActor
final class AvatarService {
    static let shared = AvatarService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Avatar Upload

    /// Compress, upload to `avatars` bucket, save URL to profiles row.
    /// Returns the public URL string.
    func uploadAvatar(userId: UUID, image: UIImage) async throws -> String {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw AvatarError.imageConversionFailed
        }
        let path = "\(userId.uuidString.lowercased())/avatar.jpg"
        try await client.storage
            .from("avatars")
            .upload(path, data: jpegData, options: FileOptions(contentType: "image/jpeg", upsert: true))
        let publicURL = try client.storage
            .from("avatars")
            .getPublicURL(path: path)
        try await updateProfileAvatarUrl(userId: userId, url: publicURL.absoluteString)
        return publicURL.absoluteString
    }

    func updateProfileAvatarUrl(userId: UUID, url: String) async throws {
        try await client
            .from("profiles")
            .update(["avatar_url": url])
            .eq("id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Profile Fetch

    func fetchProfile(userId: UUID) async throws -> Profile? {
        let rows: [Profile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func fetchProfiles(userIds: [UUID]) async throws -> [Profile] {
        guard !userIds.isEmpty else { return [] }
        return try await client
            .from("profiles")
            .select()
            .in("id", values: userIds.map { $0.uuidString })
            .execute()
            .value
    }

    // MARK: - Impact Stats

    func fetchTotalCompletedDays(userId: UUID) async throws -> Int {
        struct LogId: Decodable { let id: UUID }
        let rows: [LogId] = try await client
            .from("habit_logs")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("completed", value: true)
            .execute()
            .value
        return rows.count
    }

    func fetchCircleCount(userId: UUID) async throws -> Int {
        struct CircleIdRow: Decodable {
            let circleId: UUID
            enum CodingKeys: String, CodingKey { case circleId = "circle_id" }
        }
        let rows: [CircleIdRow] = try await client
            .from("circle_members")
            .select("circle_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return rows.count
    }

    func fetchReactionsGivenCount(userId: UUID) async throws -> Int {
        struct ReactionId: Decodable { let id: UUID }
        let rows: [ReactionId] = try await client
            .from("habit_reactions")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return rows.count
    }

    func fetchIsCircleFounder(userId: UUID) async throws -> Bool {
        struct MemberId: Decodable { let id: UUID }
        let rows: [MemberId] = try await client
            .from("circle_members")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("role", value: "admin")
            .execute()
            .value
        return !rows.isEmpty
    }
}

enum AvatarError: LocalizedError {
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "Failed to convert image to JPEG."
        }
    }
}
