import Foundation

struct CircleMoment: Codable, Identifiable, Sendable {
    let id: UUID
    let circleId: UUID
    let userId: UUID
    let photoUrl: String
    let secondaryPhotoUrl: String?
    let caption: String?
    let postedAt: String   // TIMESTAMPTZ stored as String per project convention
    let momentDate: String // DATE stamped from the active window's UTC date ("YYYY-MM-DD")
    let isOnTime: Bool
    let hasNiyyah: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case circleId = "circle_id"
        case userId = "user_id"
        case photoUrl = "photo_url"
        case secondaryPhotoUrl = "secondary_photo_url"
        case caption
        case postedAt = "posted_at"
        case momentDate = "moment_date"
        case isOnTime = "is_on_time"
        case hasNiyyah = "has_niyyah"
    }

    init(id: UUID, circleId: UUID, userId: UUID, photoUrl: String,
         secondaryPhotoUrl: String?, caption: String?, postedAt: String,
         momentDate: String, isOnTime: Bool, hasNiyyah: Bool = false) {
        self.id = id; self.circleId = circleId; self.userId = userId
        self.photoUrl = photoUrl; self.secondaryPhotoUrl = secondaryPhotoUrl
        self.caption = caption; self.postedAt = postedAt
        self.momentDate = momentDate
        self.isOnTime = isOnTime; self.hasNiyyah = hasNiyyah
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
        // Fallback to posted_at's UTC date prefix until migration adds moment_date column on all rows.
        let decodedMomentDate = try c.decodeIfPresent(String.self, forKey: .momentDate)
        momentDate = decodedMomentDate ?? String(postedAt.prefix(10))
        isOnTime = try c.decode(Bool.self, forKey: .isOnTime)
        hasNiyyah = try c.decodeIfPresent(Bool.self, forKey: .hasNiyyah) ?? false
    }
}
