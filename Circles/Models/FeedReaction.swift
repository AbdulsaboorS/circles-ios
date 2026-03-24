import Foundation

struct FeedReaction: Codable, Identifiable, Sendable {
    let id: UUID
    let itemId: UUID        // habit_reactions.item_id — generic foreign key for any feed item
    let itemType: String    // "moment" | "habit_checkin" | "streak_milestone"
    let userId: UUID
    let emoji: String       // One of: "❤️", "🤲", "💪", "🌟", "🫶", "✨"
    let createdAt: String   // TIMESTAMPTZ stored as String per project convention

    enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case itemType = "item_type"
        case userId = "user_id"
        case emoji
        case createdAt = "created_at"
    }
}

// MARK: - Valid emoji set (single source of truth)
extension FeedReaction {
    static let validEmojis: [String] = ["❤️", "🤲", "💪", "🌟", "🫶", "✨"]
}
