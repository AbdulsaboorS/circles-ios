import Foundation

/// Tracks whether AI roadmap generation is actively in-flight for a user.
/// Set before firing the background Task, cleared when the Task completes.
/// Includes a 5-minute staleness guard so a force-quit can't leave a stale banner.
enum RoadmapGenerationFlag {

    private static func key(userId: UUID) -> String { "roadmap_generating_\(userId.uuidString)" }

    static func set(userId: UUID) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key(userId: userId))
    }

    static func clear(userId: UUID) {
        UserDefaults.standard.removeObject(forKey: key(userId: userId))
    }

    /// Returns true only while the flag is set AND is less than 5 minutes old.
    static func isActive(userId: UUID) -> Bool {
        guard let ts = UserDefaults.standard.object(forKey: key(userId: userId)) as? TimeInterval else {
            return false
        }
        return Date().timeIntervalSince1970 - ts < 300
    }
}
