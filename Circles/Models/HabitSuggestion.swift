import Foundation

/// A single AI-generated (or fallback) habit suggestion shown on Quiz Screen D.
struct HabitSuggestion: Identifiable, Hashable, Sendable, Codable {
    var id = UUID()
    let name: String
    let rationale: String

    enum CodingKeys: String, CodingKey {
        case name
        case rationale
    }
}
