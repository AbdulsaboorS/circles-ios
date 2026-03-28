import Foundation

struct Profile: Codable, Identifiable, Sendable {
    let id: UUID
    var preferredName: String?
    var gender: String?          // "brother" | "sister"
    var avatarUrl: String?
    var cityName: String?
    var timezone: String?
    var latitude: Double?
    var longitude: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case preferredName = "preferred_name"
        case gender
        case avatarUrl = "avatar_url"
        case cityName = "city_name"
        case timezone
        case latitude
        case longitude
    }
}
