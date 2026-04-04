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
    /// Uses a shared/ path so the same URL can be inserted into multiple circle rows.
    /// Returns the public URL string of the uploaded file.
    func uploadPhoto(image: UIImage, userId: UUID) async throws -> String {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw MomentError.imageConversionFailed
        }
        let filename = "shared/\(userId.uuidString.lowercased())_\(Self.todayDateString()).jpg"
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

    // MARK: - Post Moment (single circle — legacy, kept for backward compat until Plan 04)

    /// Upload photo and insert a circle_moments row. Returns the created CircleMoment.
    func postMoment(
        image: UIImage,
        circleId: UUID,
        userId: UUID,
        caption: String?,
        windowStart: String?
    ) async throws -> CircleMoment {
        let photoUrl = try await uploadPhoto(image: image, userId: userId)
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

    // MARK: - Post Moment to All Circles

    /// Upload photo once and insert a circle_moments row for each circle.
    /// Returns a MomentPostResult with succeeded inserts and any failed circleIds.
    func postMomentToAllCircles(
        image: UIImage,
        circleIds: [UUID],
        userId: UUID,
        caption: String?,
        windowStart: String?
    ) async throws -> MomentPostResult {
        guard !circleIds.isEmpty else {
            throw MomentError.noCircles
        }

        let photoUrl = try await uploadPhoto(image: image, userId: userId)
        let isOnTime = Self.computeIsOnTime(windowStart: windowStart)

        var succeeded: [CircleMoment] = []
        var failedCircleIds: [UUID] = []

        for circleId in circleIds {
            do {
                var row: [String: AnyJSON] = [
                    "circle_id": .string(circleId.uuidString),
                    "user_id": .string(userId.uuidString),
                    "photo_url": .string(photoUrl),
                    "is_on_time": .bool(isOnTime)
                ]
                if let caption = caption, !caption.isEmpty {
                    row["caption"] = .string(caption)
                }

                let moment: CircleMoment = try await client
                    .from("circle_moments")
                    .insert(row)
                    .select()
                    .single()
                    .execute()
                    .value
                succeeded.append(moment)
            } catch {
                print("[MomentService] insert failed for circle \(circleId): \(error)")
                failedCircleIds.append(circleId)
            }
        }

        if succeeded.isEmpty {
            throw MomentError.allInsertsFailedCircles(failedCircleIds)
        }

        return MomentPostResult(succeeded: succeeded, failedCircleIds: failedCircleIds)
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

struct MomentPostResult {
    let succeeded: [CircleMoment]
    let failedCircleIds: [UUID]
    var isFullSuccess: Bool { failedCircleIds.isEmpty }
    var isPartialSuccess: Bool { !succeeded.isEmpty && !failedCircleIds.isEmpty }
    var totalCount: Int { succeeded.count + failedCircleIds.count }
}

enum MomentError: LocalizedError {
    case imageConversionFailed
    case noCircles
    case allInsertsFailedCircles([UUID])

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to JPEG data."
        case .noCircles:
            return "You are not in any circles yet."
        case .allInsertsFailedCircles:
            return "Could not post your Moment. Please try again."
        }
    }
}
