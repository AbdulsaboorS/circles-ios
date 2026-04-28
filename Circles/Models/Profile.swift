import Foundation

struct Profile: Codable, Identifiable, Sendable {
    let id: UUID
    var preferredName: String?
    var gender: String?          // "brother" | "sister"
    var avatarUrl: String?
    var cityName: String?
    var region: MomentRegion?
    var timezone: String?
    var latitude: Double?
    var longitude: Double?
    var strugglesIslamic: [String]?
    var strugglesLife: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case preferredName = "preferred_name"
        case gender
        case avatarUrl = "avatar_url"
        case cityName = "city_name"
        case region
        case timezone
        case latitude
        case longitude
        case strugglesIslamic = "struggles_islamic"
        case strugglesLife = "struggles_life"
    }
}
