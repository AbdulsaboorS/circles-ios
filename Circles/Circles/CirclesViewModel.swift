import Foundation
import Observation
import SwiftUI
import UserNotifications

@Observable
@MainActor
final class CirclesViewModel {
    var circles: [Circle] = []
    var cardDataMap: [UUID: CircleCardData] = [:]
    var pinnedCircleIDs: Set<UUID> = []
    var isLoading = false
    var errorMessage: String?
    var showCreateSheet = false
    var showJoinSheet = false
    var showLayoutEditor = false
    var pendingCode: String?
    var shouldShowPermissionPrompt = false
    var sendingNudgeCircleIDs: Set<UUID> = []

    private var layoutUserId: UUID?
    private static let circleOrderKeyPrefix = "circles.layout.order"
    private static let pinnedCircleKeyPrefix = "circles.layout.pinned"

    var pinnedCircles: [Circle] {
        circles.filter { pinnedCircleIDs.contains($0.id) }
    }

    var unpinnedCircles: [Circle] {
        circles.filter { !pinnedCircleIDs.contains($0.id) }
    }

    func loadCircles(userId: UUID) async {
        layoutUserId = userId
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await CircleService.shared.fetchMyCircles(userId: userId)
            let layout = loadLayout(userId: userId)
            pinnedCircleIDs = layout.pinnedIDs
            circles = applyLayout(to: fetched, orderedIDs: layout.orderedIDs, pinnedIDs: layout.pinnedIDs)
            saveLayoutIfPossible()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false

        // Load enriched card data after circles are available
        if !circles.isEmpty {
            await loadCardData(userId: userId)
        }
    }

    func togglePinned(circleId: UUID) {
        guard let index = circles.firstIndex(where: { $0.id == circleId }) else { return }
        let circle = circles.remove(at: index)

        if pinnedCircleIDs.contains(circleId) {
            pinnedCircleIDs.remove(circleId)
            let pinnedCount = circles.filter { pinnedCircleIDs.contains($0.id) }.count
            circles.insert(circle, at: pinnedCount)
        } else {
            pinnedCircleIDs.insert(circleId)
            let pinnedCount = circles.filter { pinnedCircleIDs.contains($0.id) }.count
            circles.insert(circle, at: pinnedCount)
        }

        saveLayoutIfPossible()
    }

    func movePinnedCircles(from source: IndexSet, to destination: Int) {
        var pinned = pinnedCircles
        let unpinned = unpinnedCircles
        pinned.move(fromOffsets: source, toOffset: destination)
        circles = pinned + unpinned
        saveLayoutIfPossible()
    }

    func moveUnpinnedCircles(from source: IndexSet, to destination: Int) {
        let pinned = pinnedCircles
        var unpinned = unpinnedCircles
        unpinned.move(fromOffsets: source, toOffset: destination)
        circles = pinned + unpinned
        saveLayoutIfPossible()
    }

    /// Fetch member profiles, latest activity, active counts, and nudge counts
    /// for all circles concurrently, then assemble `CircleCardData` per circle.
    func loadCardData(userId: UUID) async {
        let circleIds = circles.map { $0.id }
        do {
            async let membersTask = CircleService.shared.fetchMembersForCircles(circleIds: circleIds)
            async let activityTask = FeedService.shared.fetchLatestActivityPerCircle(circleIds: circleIds)
            async let latestMomentTask = FeedService.shared.fetchLatestMomentPerCircle(circleIds: circleIds)
            async let activeUserIdsTask = FeedService.shared.fetchActiveUserIdsToday(circleIds: circleIds)
            async let nudgeCountsTask = NudgeService.shared.fetchNudgeCounts(circleIds: circleIds, senderId: userId)

            let membersMap = try await membersTask
            let activityMap = try await activityTask
            let latestMomentMap = try await latestMomentTask
            let activeUserIdsMap = try await activeUserIdsTask
            let nudgeCounts = try await nudgeCountsTask

            // Collect all unique user IDs across all circles for batch profile fetch
            let allUserIds = Array(Set(membersMap.values.flatMap { $0.map { $0.userId } }))
            let profiles = try await AvatarService.shared.fetchProfiles(userIds: allUserIds)
            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            // Assemble card data per circle
            var newMap: [UUID: CircleCardData] = [:]
            for circle in circles {
                let members = membersMap[circle.id] ?? []
                let latestActivity = activityMap[circle.id]
                let latestMoment = latestMomentMap[circle.id]
                let cardMembers: [CircleCardMember] = members.map { member in
                    let profile = profileMap[member.userId]
                    let displayName: String
                    if member.userId == userId {
                        displayName = "You"
                    } else if let preferred = profile?.preferredName?.trimmingCharacters(in: .whitespacesAndNewlines),
                              !preferred.isEmpty {
                        displayName = preferred
                    } else if latestMoment?.userId == member.userId {
                        displayName = latestMoment?.userName ?? "Member"
                    } else if latestActivity?.userId == member.userId {
                        displayName = latestActivity?.userName ?? "Member"
                    } else {
                        displayName = "Member"
                    }

                    return CircleCardMember(
                        id: member.userId,
                        displayName: displayName,
                        avatarUrl: profile?.avatarUrl,
                        isCurrentUser: member.userId == userId
                    )
                }

                newMap[circle.id] = CircleCardData(
                    id: circle.id,
                    circle: circle,
                    members: cardMembers,
                    latestActivity: latestActivity,
                    latestMoment: latestMoment,
                    activeUserIdsToday: activeUserIdsMap[circle.id] ?? [],
                    nudgeSentCountToday: nudgeCounts[circle.id] ?? 0
                )
            }
            cardDataMap = newMap
        } catch {
            // Non-fatal — cards will show in loading/skeleton state
            print("[CirclesVM] loadCardData error: \(error)")
        }
    }

    /// Send an in-app nudge with optimistic UI update.
    func sendNudge(circleId: UUID, userId: UUID) async {
        guard let data = cardDataMap[circleId],
              data.showEncourageCTA,
              !sendingNudgeCircleIDs.contains(circleId)
        else { return }

        // Optimistic: increment count immediately
        var optimisticData = data
        optimisticData.nudgeSentCountToday += 1
        cardDataMap[circleId] = optimisticData
        sendingNudgeCircleIDs.insert(circleId)

        do {
            let sentCount = try await NudgeService.shared.sendCircleEncouragement(
                circleId: circleId,
                senderId: userId,
                targetUserIds: data.nudgeTargetIds,
                nudgeType: "moment"
            )
            print("[CirclesVM] sent circle encouragement circleId=\(circleId) targets=\(sentCount)")
        } catch {
            // Revert on failure
            cardDataMap[circleId] = data
            errorMessage = error.localizedDescription
        }
        sendingNudgeCircleIDs.remove(circleId)
    }

    func createCircle(
        name: String,
        description: String?,
        prayerTime: String?,
        userId: UUID,
        genderSetting: String
    ) async -> Circle? {
        do {
            let circle = try await CircleService.shared.createCircle(
                name: name, description: description,
                prayerTime: prayerTime, userId: userId, genderSetting: genderSetting
            )
            insertNewCircle(circle)
            if circles.count == 1 {
                await NotificationService.shared.refreshPermissionStatus()
                if NotificationService.shared.permissionStatus == .notDetermined {
                    shouldShowPermissionPrompt = true
                }
            }
            return circle
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func joinCircle(code: String, userId: UUID) async -> Circle? {
        do {
            let circle = try await CircleService.shared.joinByInviteCode(code, userId: userId)
            insertNewCircle(circle)
            if circles.count == 1 {
                await NotificationService.shared.refreshPermissionStatus()
                if NotificationService.shared.permissionStatus == .notDetermined {
                    shouldShowPermissionPrompt = true
                }
            }
            return circle
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Layout Persistence

    private func insertNewCircle(_ circle: Circle) {
        guard !circles.contains(where: { $0.id == circle.id }) else { return }
        circles.append(circle)
        saveLayoutIfPossible()
    }

    private func applyLayout(to fetched: [Circle], orderedIDs: [UUID], pinnedIDs: Set<UUID>) -> [Circle] {
        let fallback = defaultSortedCircles(fetched)
        guard !orderedIDs.isEmpty else {
            return normalizePinnedFirst(circles: fallback, pinnedIDs: pinnedIDs)
        }

        let fetchedByID = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        var ordered: [Circle] = orderedIDs.compactMap { fetchedByID[$0] }

        let knownIDs = Set(ordered.map(\.id))
        let newCircles = fallback.filter { !knownIDs.contains($0.id) }
        ordered.append(contentsOf: newCircles)

        return normalizePinnedFirst(circles: ordered, pinnedIDs: pinnedIDs)
    }

    private func normalizePinnedFirst(circles: [Circle], pinnedIDs: Set<UUID>) -> [Circle] {
        let pinned = circles.filter { pinnedIDs.contains($0.id) }
        let unpinned = circles.filter { !pinnedIDs.contains($0.id) }
        return pinned + unpinned
    }

    private func defaultSortedCircles(_ circles: [Circle]) -> [Circle] {
        circles.sorted { a, b in
            if a.groupStreakDaysSafe != b.groupStreakDaysSafe {
                return a.groupStreakDaysSafe > b.groupStreakDaysSafe
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private func loadLayout(userId: UUID) -> (orderedIDs: [UUID], pinnedIDs: Set<UUID>) {
        let defaults = UserDefaults.standard
        let orderIDs = (defaults.stringArray(forKey: Self.circleOrderKey(userId: userId)) ?? [])
            .compactMap(UUID.init(uuidString:))
        let pinnedIDs = Set((defaults.stringArray(forKey: Self.pinnedCircleKey(userId: userId)) ?? [])
            .compactMap(UUID.init(uuidString:)))
        return (orderIDs, pinnedIDs)
    }

    private func saveLayoutIfPossible() {
        guard let layoutUserId else { return }
        let defaults = UserDefaults.standard
        defaults.set(circles.map(\.id.uuidString), forKey: Self.circleOrderKey(userId: layoutUserId))
        defaults.set(Array(pinnedCircleIDs).map(\.uuidString), forKey: Self.pinnedCircleKey(userId: layoutUserId))
    }

    private static func circleOrderKey(userId: UUID) -> String {
        "\(circleOrderKeyPrefix).\(userId.uuidString)"
    }

    private static func pinnedCircleKey(userId: UUID) -> String {
        "\(pinnedCircleKeyPrefix).\(userId.uuidString)"
    }
}
