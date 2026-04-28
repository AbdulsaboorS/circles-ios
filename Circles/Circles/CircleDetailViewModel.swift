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
    var errorMessage: String?
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
        errorMessage = nil

        do {
            let fetchedMembers = try await CircleService.shared.fetchMembers(circleId: circleId)
            members = fetchedMembers
            isLoadingMembers = false

            let profiles = (try? await AvatarService.shared.fetchProfiles(userIds: fetchedMembers.map(\.userId))) ?? []
            memberProfiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            await refreshStats()
        } catch {
            if error is CancellationError { isLoadingMembers = false; isLoadingStats = false; return }
            members = []
            memberProfiles = [:]
            completionStats = nil
            errorMessage = "Couldn't load this circle right now. Pull to retry."
            isLoadingMembers = false
            isLoadingStats = false
        }
    }

    func refreshStats() async {
        isLoadingStats = true
        errorMessage = nil
        let memberIds = members.map(\.userId)
        do {
            completionStats = try await HabitService.shared.fetchCircleCompletionStats(
                circleId: circleId,
                memberIds: memberIds
            )
        } catch {
            if !(error is CancellationError) {
                completionStats = nil
                errorMessage = "Couldn't load today's circle activity. Pull to retry."
            }
        }
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
