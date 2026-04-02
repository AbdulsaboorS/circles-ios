import Foundation

struct ReflectionLogStore {
    private static let keyPrefix = "reflection_log"

    static func load(habitId: UUID, date: String) -> String {
        UserDefaults.standard.string(forKey: storageKey(habitId: habitId, date: date)) ?? ""
    }

    static func save(_ note: String, habitId: UUID, date: String) {
        let key = storageKey(habitId: habitId, date: date)
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(trimmed, forKey: key)
        }
    }

    static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func storageKey(habitId: UUID, date: String) -> String {
        "\(keyPrefix)_\(habitId.uuidString.lowercased())_\(date)"
    }
}
