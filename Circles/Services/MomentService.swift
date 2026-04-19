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
    private var signedURLCache: [String: SignedMomentURL] = [:]
    private let signedURLLifetime: TimeInterval = 60 * 60
    private let signedURLReuseLeeway: TimeInterval = 5 * 60

    // MARK: - Fetch

    /// Fetch all Moments for a circle in the currently active daily-moment cycle.
    func fetchTodayMoments(circleId: UUID) async throws -> [CircleMoment] {
        let windowStart = DailyMomentService.shared.windowStart
            ?? Calendar(identifier: .gregorian).startOfDay(for: Date())
        let startISO = DailyMomentService.iso8601String(from: windowStart)
        let endISO = DailyMomentService.iso8601String(from: windowStart.addingTimeInterval(25 * 60 * 60))
        let moments: [CircleMoment] = try await client
            .from("circle_moments")
            .select()
            .eq("circle_id", value: circleId.uuidString)
            .gte("posted_at", value: startISO)
            .lt("posted_at", value: endISO)
            .order("posted_at")
            .execute()
            .value
        return try await resolveMomentPhotoURLs(in: moments)
    }

    /// Fetch a single moment for a user on a given date (for Spiritual Ledger photo lookup).
    func fetchMomentForDate(userId: UUID, date: String) async throws -> CircleMoment? {
        let moments: [CircleMoment] = try await client
            .from("circle_moments")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("posted_at", value: "\(date)T00:00:00Z")
            .lt("posted_at", value: "\(date)T23:59:59Z")
            .limit(1)
            .execute()
            .value
        guard let moment = moments.first else { return nil }
        let resolvedUrl = try await resolveMomentPhotoURL(from: moment.photoUrl)
        return CircleMoment(
            id: moment.id, circleId: moment.circleId, userId: moment.userId,
            photoUrl: resolvedUrl, secondaryPhotoUrl: moment.secondaryPhotoUrl,
            caption: moment.caption, postedAt: moment.postedAt,
            isOnTime: moment.isOnTime, hasNiyyah: moment.hasNiyyah
        )
    }

    /// Fetch unresolved moment rows for a user in a UTC date range.
    /// The stored `photo_url` remains a storage path until a detail view needs signing.
    func fetchMoments(
        userId: UUID,
        from startDate: String,
        toExclusive endDate: String
    ) async throws -> [CircleMoment] {
        try await client
            .from("circle_moments")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("posted_at", value: "\(startDate)T00:00:00Z")
            .lt("posted_at", value: "\(endDate)T00:00:00Z")
            .order("posted_at", ascending: false)
            .execute()
            .value
    }

    /// True when the user has ever posted at least one moment.
    func hasAnyMoments(userId: UUID) async throws -> Bool {
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await client
            .from("circle_moments")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    // MARK: - Upload Photo

    /// Upload a composited UIImage to Supabase Storage bucket "circle-moments".
    /// Uses a shared/ path so the same object can be inserted into multiple circle rows.
    /// Returns the storage path string of the uploaded file.
    func uploadPhoto(image: UIImage, userId: UUID, suffix: String = "") async throws -> String {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw MomentError.imageConversionFailed
        }
        let suffixPart = suffix.isEmpty ? "" : "_\(suffix)"
        let filename = "shared/\(userId.uuidString.lowercased())_\(Self.todayDateString())\(suffixPart).jpg"
        await refreshAuthSessionIfPossible(reason: "moment upload")
        print("[MomentService] upload starting path=\(filename) bytes=\(jpegData.count)")
        try await client.storage
            .from("circle-moments")
            .upload(
                filename,
                data: jpegData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        print("[MomentService] upload succeeded path=\(filename)")
        return filename
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

        do {
            let moment: CircleMoment = try await client
                .from("circle_moments")
                .insert(row)
                .select()
                .single()
                .execute()
                .value
            print("[MomentService] single-circle insert succeeded circleId=\(circleId) momentId=\(moment.id) photoUrl=\(moment.photoUrl)")
            return moment
        } catch {
            print("[MomentService] single-circle insert failed circleId=\(circleId) photoUrl=\(photoUrl) error=\(error)")
            throw error
        }
    }

    // MARK: - Post Moment to All Circles

    /// Upload photo once and insert a circle_moments row for each circle.
    /// Returns a MomentPostResult with succeeded inserts and any failed circleIds.
    func postMomentToAllCircles(
        primaryImage: UIImage,
        secondaryImage: UIImage?,
        circleIds: [UUID],
        userId: UUID,
        caption: String?,
        windowStart: String?,
        niyyahText: String? = nil
    ) async throws -> MomentPostResult {
        guard !circleIds.isEmpty else {
            throw MomentError.noCircles
        }

        print("[MomentService] multi-circle post start circles=\(circleIds.count) userId=\(userId)")
        let photoUrl = try await uploadPhoto(image: primaryImage, userId: userId, suffix: "primary")
        let secondaryUrl: String? = if let secondary = secondaryImage {
            try? await uploadPhoto(image: secondary, userId: userId, suffix: "secondary")
        } else {
            nil
        }
        let isOnTime = Self.computeIsOnTime(windowStart: windowStart)

        var succeeded: [CircleMoment] = []
        var failedCircleIds: [UUID] = []
        var duplicateCircleIds: [UUID] = []

        for circleId in circleIds {
            do {
                var row: [String: AnyJSON] = [
                    "circle_id": .string(circleId.uuidString),
                    "user_id": .string(userId.uuidString),
                    "photo_url": .string(photoUrl),
                    "is_on_time": .bool(isOnTime),
                    "has_niyyah": .bool(niyyahText != nil)
                ]
                if let caption = caption, !caption.isEmpty {
                    row["caption"] = .string(caption)
                }
                if let secondary = secondaryUrl {
                    row["secondary_photo_url"] = .string(secondary)
                }

                let moment: CircleMoment = try await client
                    .from("circle_moments")
                    .insert(row)
                    .select()
                    .single()
                    .execute()
                    .value
                print("[MomentService] insert succeeded circleId=\(circleId) momentId=\(moment.id)")
                succeeded.append(moment)
            } catch {
                print("[MomentService] insert failed circleId=\(circleId) photoUrl=\(photoUrl) error=\(error)")
                if Self.isDuplicateMomentError(error) {
                    duplicateCircleIds.append(circleId)
                }
                failedCircleIds.append(circleId)
            }
        }

        if succeeded.isEmpty {
            if duplicateCircleIds.count == circleIds.count {
                throw MomentError.alreadyPostedToday
            }
            throw MomentError.allInsertsFailedCircles(failedCircleIds)
        }

        // Save private Niyyah (graceful — failure does not fail the post)
        if let text = niyyahText, !text.isEmpty {
            do {
                try await NiyyahService.shared.saveNiyyah(
                    userId: userId,
                    text: text,
                    photoDate: Self.todayDateString()
                )
            } catch {
                print("[MomentService] niyyah save failed (non-fatal): \(error)")
            }
        }

        publishPostRefresh(
            userId: userId,
            succeededCircleIds: succeeded.map(\.circleId),
            failedCircleIds: failedCircleIds
        )

        return MomentPostResult(succeeded: succeeded, failedCircleIds: failedCircleIds)
    }

    // MARK: - Auth

    private func refreshAuthSessionIfPossible(reason: String) async {
        do {
            let session = try await client.auth.refreshSession()
            print("[MomentService] auth refresh succeeded reason=\(reason) userId=\(session.user.id)")
        } catch {
            let currentUserId = client.auth.currentUser?.id.uuidString ?? "nil"
            print("[MomentService] auth refresh failed reason=\(reason) currentUserId=\(currentUserId) error=\(error)")
        }
    }

    private func publishPostRefresh(
        userId: UUID,
        succeededCircleIds: [UUID],
        failedCircleIds: [UUID]
    ) {
        let event = MomentPostRefreshEvent(
            userId: userId,
            succeededCircleIds: succeededCircleIds,
            failedCircleIds: failedCircleIds
        )
        NotificationCenter.default.post(name: .momentPostRefresh, object: event)
    }

    // MARK: - Helpers

    func resolveMomentPhotoURL(from storedValue: String) async throws -> String {
        let path = Self.extractStoragePath(from: storedValue)
        if let cached = signedURLCache[path],
           cached.expiresAt.timeIntervalSinceNow > signedURLReuseLeeway {
            return cached.url
        }

        let signedURL = try await client.storage
            .from("circle-moments")
            .createSignedURL(path: path, expiresIn: Int(signedURLLifetime))
        let resolvedURL = signedURL.absoluteString
        signedURLCache[path] = SignedMomentURL(
            url: resolvedURL,
            expiresAt: Date().addingTimeInterval(signedURLLifetime)
        )
        return resolvedURL
    }

    func resolveMomentMedia(
        primaryStoredValue: String,
        secondaryStoredValue: String?
    ) async throws -> ResolvedMomentMedia {
        let primaryCacheKey = Self.extractStoragePath(from: primaryStoredValue)
        let primaryURL = try await resolveMomentPhotoURL(from: primaryStoredValue)

        let secondaryCacheKey = secondaryStoredValue.map { Self.extractStoragePath(from: $0) }
        let secondaryURL: String? = if let secondaryStoredValue {
            try? await resolveMomentPhotoURL(from: secondaryStoredValue)
        } else {
            nil
        }

        return ResolvedMomentMedia(
            primaryURL: primaryURL,
            primaryCacheKey: primaryCacheKey,
            secondaryURL: secondaryURL,
            secondaryCacheKey: secondaryCacheKey
        )
    }

    func prefetchMomentMedia(
        primaryStoredValue: String,
        secondaryStoredValue: String?
    ) async {
        do {
            let media = try await resolveMomentMedia(
                primaryStoredValue: primaryStoredValue,
                secondaryStoredValue: secondaryStoredValue
            )
            await CachedImagePrefetcher.prefetch(url: media.primaryURL, cacheKey: media.primaryCacheKey)
            if let secondaryURL = media.secondaryURL, let secondaryCacheKey = media.secondaryCacheKey {
                await CachedImagePrefetcher.prefetch(url: secondaryURL, cacheKey: secondaryCacheKey)
            }
        } catch {
            return
        }
    }

    func resolveMomentPhotoURLs(in moments: [CircleMoment]) async throws -> [CircleMoment] {
        var resolved: [CircleMoment] = []
        resolved.reserveCapacity(moments.count)

        for moment in moments {
            let renderableURL = try await resolveMomentPhotoURL(from: moment.photoUrl)
            resolved.append(
                CircleMoment(
                    id: moment.id,
                    circleId: moment.circleId,
                    userId: moment.userId,
                    photoUrl: renderableURL,
                    secondaryPhotoUrl: moment.secondaryPhotoUrl,
                    caption: moment.caption,
                    postedAt: moment.postedAt,
                    isOnTime: moment.isOnTime,
                    hasNiyyah: moment.hasNiyyah
                )
            )
        }

        return resolved
    }

    static func extractStoragePath(from storedValue: String) -> String {
        if !storedValue.contains("://") {
            return storedValue.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        guard let components = URLComponents(string: storedValue) else {
            return storedValue
        }

        let markers = [
            "/storage/v1/object/public/circle-moments/",
            "/storage/v1/object/sign/circle-moments/",
            "/storage/v1/object/authenticated/circle-moments/"
        ]

        for marker in markers {
            if let range = components.path.range(of: marker) {
                return String(components.path[range.upperBound...])
            }
        }

        return storedValue
    }

    /// Update caption on all of today's moment rows for a user.
    /// Uses [String: AnyJSON] so nil caption sends explicit JSON null (Swift Codable omits nil keys).
    func updateCaption(_ caption: String?, userId: UUID) async throws {
        let activeRange = await DailyMomentService.shared.fetchActiveMomentRange()
        let captionValue: AnyJSON = caption.map { .string($0) } ?? .null
        print("[MomentService] updateCaption userId=\(userId) caption=\(caption ?? "nil")")
        do {
            try await client
                .from("circle_moments")
                .update(["caption": captionValue])
                .eq("user_id", value: userId.uuidString)
                .gte("posted_at", value: activeRange.startISO8601)
                .lt("posted_at", value: activeRange.endExclusiveISO8601)
                .execute()
            print("[MomentService] updateCaption succeeded")
        } catch {
            print("[MomentService] updateCaption failed: \(error)")
            throw error
        }
    }

    #if DEBUG
    /// Delete all of today's moments for the given user (debug testing only).
    func deleteMyTodayMoments(userId: UUID) async throws {
        let activeRange = await DailyMomentService.shared.fetchActiveMomentRange()
        try await client
            .from("circle_moments")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .gte("posted_at", value: activeRange.startISO8601)
            .lt("posted_at", value: activeRange.endExclusiveISO8601)
            .execute()
        print("[MomentService] DEBUG: deleted today's moments for userId=\(userId)")
    }
    #endif

    static func isDuplicateMomentError(_ error: Error) -> Bool {
        let message = String(describing: error)
        return message.contains("circle_moments_one_per_day") || message.contains("duplicate key value")
    }

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

private struct SignedMomentURL {
    let url: String
    let expiresAt: Date
}

struct ResolvedMomentMedia: Sendable {
    let primaryURL: String
    let primaryCacheKey: String
    let secondaryURL: String?
    let secondaryCacheKey: String?
}

enum MomentError: LocalizedError {
    case imageConversionFailed
    case noCircles
    case alreadyPostedToday
    case allInsertsFailedCircles([UUID])

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to JPEG data."
        case .noCircles:
            return "You are not in any circles yet."
        case .alreadyPostedToday:
            return "You already posted your Moment for today."
        case .allInsertsFailedCircles:
            return "Could not post your Moment. Please try again."
        }
    }
}

struct MomentPostRefreshEvent: Sendable {
    let userId: UUID
    let succeededCircleIds: [UUID]
    let failedCircleIds: [UUID]
}

extension Notification.Name {
    static let momentPostRefresh = Notification.Name("momentPostRefresh")
}
