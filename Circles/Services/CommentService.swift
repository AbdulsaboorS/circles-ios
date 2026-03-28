import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class CommentService {
    static let shared = CommentService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Fetch

    func fetchComments(postId: UUID, circleId: UUID) async throws -> [Comment] {
        try await client
            .from("comments")
            .select()
            .eq("post_id", value: postId.uuidString)
            .eq("circle_id", value: circleId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    // MARK: - Add

    func addComment(
        postId: UUID,
        postType: String,
        circleId: UUID,
        userId: UUID,
        text: String
    ) async throws -> Comment {
        let row: [String: AnyJSON] = [
            "post_id":   .string(postId.uuidString),
            "post_type": .string(postType),
            "circle_id": .string(circleId.uuidString),
            "user_id":   .string(userId.uuidString),
            "text":      .string(text)
        ]
        return try await client
            .from("comments")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Delete

    func deleteComment(commentId: UUID) async throws {
        try await client
            .from("comments")
            .delete()
            .eq("id", value: commentId.uuidString)
            .execute()
    }
}
