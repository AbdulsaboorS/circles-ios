import Foundation
import Observation

@Observable
@MainActor
final class CirclesViewModel {
    var circles: [Circle] = []
    var isLoading = false
    var errorMessage: String?
    var showCreateSheet = false
    var showJoinSheet = false
    var pendingCode: String?

    func loadCircles(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            circles = try await CircleService.shared.fetchMyCircles(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createCircle(name: String, description: String?, prayerTime: String?, userId: UUID) async -> Circle? {
        do {
            let circle = try await CircleService.shared.createCircle(
                name: name, description: description,
                prayerTime: prayerTime, userId: userId
            )
            circles.insert(circle, at: 0)
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
            return circle
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
