import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class CircleDetailViewModel {
    let circleId: UUID

    var members: [CircleMember] = []
    var memberProfiles: [UUID: Profile] = [:]
    var completionStats: CircleCompletionStats?
    var isLoadingMembers = true
    var isLoadingStats = true
    var activeTab: DetailTab = .huddle

    enum DetailTab: String, CaseIterable {
        case huddle = "Huddle"
        case gallery = "Gallery"
    }

    enum NoorRingStatus {
        case gold        // all shared habits done
        case pulsingGreen // at least one done
        case dimmed       // nothing done
    }

    var noorIntensity: Double {
        completionStats?.overallFraction ?? 0
    }

    init(circleId: UUID, initialTab: DetailTab = .huddle) {
        self.circleId = circleId
        self.activeTab = initialTab
    }

    func load(userId: UUID) async {
        isLoadingMembers = true
        isLoadingStats = true

        // Fetch members + profiles
        let fetchedMembers = (try? await CircleService.shared.fetchMembers(circleId: circleId)) ?? []
        members = fetchedMembers
        isLoadingMembers = false

        let profiles = (try? await AvatarService.shared.fetchProfiles(userIds: fetchedMembers.map(\.userId))) ?? []
        memberProfiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        // Fetch completion stats
        await refreshStats()
    }

    func refreshStats() async {
        isLoadingStats = true
        let memberIds = members.map(\.userId)
        completionStats = try? await HabitService.shared.fetchCircleCompletionStats(
            circleId: circleId,
            memberIds: memberIds
        )
        isLoadingStats = false
    }

    func noorRingStatus(for userId: UUID) -> NoorRingStatus {
        guard let stats = completionStats, !stats.habits.isEmpty else { return .dimmed }
        if stats.memberCompletedAll(userId) { return .gold }
        if stats.memberCompletedAny(userId) { return .pulsingGreen }
        return .dimmed
    }

    func displayName(for member: CircleMember) -> String {
        memberProfiles[member.userId]?.preferredName ?? ""
    }

    func avatarUrl(for member: CircleMember) -> String? {
        memberProfiles[member.userId]?.avatarUrl
    }
}
