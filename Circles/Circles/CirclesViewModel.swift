import Foundation
import Observation
import UserNotifications

@Observable
@MainActor
final class CirclesViewModel {
    var circles: [Circle] = []
    var cardDataMap: [UUID: CircleCardData] = [:]
    var isLoading = false
    var errorMessage: String?
    var showCreateSheet = false
    var showJoinSheet = false
    var pendingCode: String?
    var shouldShowPermissionPrompt = false

    func loadCircles(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            circles = try await CircleService.shared.fetchMyCircles(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false

        // Load enriched card data after circles are available
        if !circles.isEmpty {
            await loadCardData(userId: userId)
        }
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
        guard let data = cardDataMap[circleId], data.showEncourageCTA else { return }

        // Optimistic: increment count immediately
        var optimisticData = data
        optimisticData.nudgeSentCountToday += 1
        cardDataMap[circleId] = optimisticData

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
    }

    func createCircle(name: String, description: String?, prayerTime: String?, userId: UUID) async -> Circle? {
        do {
            let circle = try await CircleService.shared.createCircle(
                name: name, description: description,
                prayerTime: prayerTime, userId: userId
            )
            circles.insert(circle, at: 0)
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
            circles.insert(circle, at: 0)
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
}
