import Foundation
import Observation
import UserNotifications

@Observable
@MainActor
final class CirclesViewModel {
    var circles: [Circle] = []
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
