import Foundation

// MARK: - Supabase Migration Required (Phase 06.2)
// Run this SQL in Supabase Dashboard → SQL Editor before using fetchPublicCircles():
//
// ALTER TABLE circles ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false;
//
// To make a circle public (for testing):
// UPDATE circles SET is_public = true WHERE id = '<circle-uuid>';

struct Circle: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let createdBy: UUID
    let inviteCode: String?
    let momentWindowStart: String?   // TIMESTAMPTZ as String, per project convention
    let createdAt: Date
    let isPublic: Bool?              // is_public BOOLEAN DEFAULT false — added Phase 06.2

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case createdBy = "created_by"
        case inviteCode = "invite_code"
        case momentWindowStart = "moment_window_start"
        case createdAt = "created_at"
        case isPublic = "is_public"
    }
}

extension Circle {
    var isPublicSafe: Bool { isPublic ?? false }
}
