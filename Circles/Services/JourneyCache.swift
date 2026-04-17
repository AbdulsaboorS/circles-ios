import Foundation

enum JourneyCache {
    static func loadMoments(monthKey: String, userId: UUID) -> [String: CircleMoment]? {
        load([String: CircleMoment].self, from: fileURL(name: "moments_\(monthKey).json", userId: userId))
    }

    static func saveMoments(_ moments: [String: CircleMoment], monthKey: String, userId: UUID) {
        save(moments, to: fileURL(name: "moments_\(monthKey).json", userId: userId))
    }

    static func loadNiyyahs(userId: UUID) -> [String: MomentNiyyah]? {
        load([String: MomentNiyyah].self, from: fileURL(name: "niyyahs.json", userId: userId))
    }

    static func saveNiyyahs(_ niyyahs: [String: MomentNiyyah], userId: UUID) {
        save(niyyahs, to: fileURL(name: "niyyahs.json", userId: userId))
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL?) -> T? {
        guard let url else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    private static func save<T: Encodable>(_ value: T, to url: URL?) {
        guard let url else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
    }

    private static func fileURL(name: String, userId: UUID) -> URL? {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return cachesDirectory
            .appendingPathComponent("journey", isDirectory: true)
            .appendingPathComponent(userId.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent(name)
    }
}
