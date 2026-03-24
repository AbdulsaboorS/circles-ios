import Foundation
import Observation
import Supabase
import UIKit   // For UIImage -> JPEG data conversion

@Observable
@MainActor
final class MomentService {
    static let shared = MomentService()
    private init() {}

    private var client: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Fetch

    /// Fetch all Moments for a circle posted today (UTC date).
    func fetchTodayMoments(circleId: UUID) async throws -> [CircleMoment] {
        let today = Self.todayDateString()
        return try await client
            .from("circle_moments")
            .select()
            .eq("circle_id", value: circleId.uuidString)
            .gte("posted_at", value: "\(today)T00:00:00Z")
            .lt("posted_at", value: "\(today)T23:59:59Z")
            .order("posted_at")
            .execute()
            .value
    }

    // MARK: - Upload Photo

    /// Upload a composited UIImage to Supabase Storage bucket "circle-moments".
    /// Returns the public URL string of the uploaded file.
    func uploadPhoto(image: UIImage, circleId: UUID, userId: UUID) async throws -> String {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw MomentError.imageConversionFailed
        }
        let filename = "\(circleId.uuidString)/\(userId.uuidString)_\(Self.todayDateString()).jpg"
        try await client.storage
            .from("circle-moments")
            .upload(
                filename,
                data: jpegData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        let publicURL = try client.storage
            .from("circle-moments")
            .getPublicURL(path: filename)
        return publicURL.absoluteString
    }

    // MARK: - Post Moment

    /// Upload photo and insert a circle_moments row. Returns the created CircleMoment.
    func postMoment(
        image: UIImage,
        circleId: UUID,
        userId: UUID,
        caption: String?,
        windowStart: String?
    ) async throws -> CircleMoment {
        let photoUrl = try await uploadPhoto(image: image, circleId: circleId, userId: userId)

        let isOnTime = Self.computeIsOnTime(windowStart: windowStart)

        var row: [String: AnyJSON] = [
            "circle_id": .string(circleId.uuidString),
            "user_id": .string(userId.uuidString),
            "photo_url": .string(photoUrl),
            "is_on_time": .bool(isOnTime)
        ]
        if let caption = caption, !caption.isEmpty {
            row["caption"] = .string(caption)
        }

        return try await client
            .from("circle_moments")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Helpers

    /// Returns "YYYY-MM-DD" for today in UTC.
    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }

    /// Determine if current time is within 30 minutes of window start.
    /// windowStart is an ISO8601 TIMESTAMPTZ string from the circles.moment_window_start column.
    static func computeIsOnTime(windowStart: String?) -> Bool {
        guard let windowStart = windowStart else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let startDate = formatter.date(from: windowStart) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let startDate = formatter.date(from: windowStart) else { return false }
            return Date().timeIntervalSince(startDate) < 1800  // 30 minutes
        }
        return Date().timeIntervalSince(startDate) < 1800
    }
}

enum MomentError: LocalizedError {
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to JPEG data."
        }
    }
}
