import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class NiyyahService {
    static let shared = NiyyahService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Save

    /// Upsert a private Niyyah for today's moment. One per user per day.
    func saveNiyyah(userId: UUID, text: String, photoDate: String) async throws {
        let row: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "niyyah_text": .string(text),
            "photo_date": .string(photoDate)
        ]
        try await client
            .from("moment_niyyahs")
            .upsert(row, onConflict: "user_id,photo_date")
            .execute()
        print("[NiyyahService] saved niyyah for \(photoDate)")
    }

    // MARK: - Fetch

    /// Fetch all Niyyahs for the user, newest first (for Spiritual Ledger).
    func fetchMyNiyyahs(userId: UUID) async throws -> [MomentNiyyah] {
        try await client
            .from("moment_niyyahs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("photo_date", ascending: false)
            .execute()
            .value
    }

    #if DEBUG
    /// Delete today's niyyah for the given user (debug testing only).
    func deleteTodayNiyyah(userId: UUID) async throws {
        let today = MomentService.todayDateString()
        try await client
            .from("moment_niyyahs")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("photo_date", value: today)
            .execute()
        print("[NiyyahService] DEBUG: deleted today's niyyah for userId=\(userId)")
    }
    #endif

    /// Fetch the count of Niyyahs for the user (for Profile entry point).
    func fetchNiyyahCount(userId: UUID) async throws -> Int {
        let niyyahs: [MomentNiyyah] = try await client
            .from("moment_niyyahs")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return niyyahs.count
    }
}
