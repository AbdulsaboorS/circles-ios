import Foundation
import UserNotifications
import UIKit
import Observation
import Supabase

// MARK: - SQL Migration (run in Supabase Dashboard SQL Editor before Phase 6 executes)
//
// CREATE TABLE IF NOT EXISTS device_tokens (
//   id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
//   user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
//   device_token text NOT NULL,
//   created_at   timestamptz DEFAULT now(),
//   UNIQUE(user_id, device_token)
// );
// ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
// CREATE POLICY "Users manage own tokens"
//   ON device_tokens FOR ALL
//   USING (auth.uid() = user_id)
//   WITH CHECK (auth.uid() = user_id);

@Observable
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    var permissionStatus: UNAuthorizationStatus = .notDetermined
    var unreadCount: Int = 0
    var preferences: NotificationPreferences?
    var isLoadingPreferences = false
    var pendingRoute: AppNotificationRoute?
    var currentRoute: AppNotificationRoute = .circles

    private var currentUserId: UUID?

    private init() {}

    func configureForAuthenticatedUser(userId: UUID) async {
        currentUserId = userId
        await refreshPermissionStatus()
        await loadPreferences(userId: userId)
        registerForRemoteNotificationsIfAuthorized()
    }

    func resetForSignedOutUser() {
        currentUserId = nil
        preferences = nil
        isLoadingPreferences = false
        pendingRoute = nil
        unreadCount = 0
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        Task {
            await HabitReminderScheduler.shared.removeAllPendingRequests()
        }
    }

    func updateCurrentRoute(_ route: AppNotificationRoute) {
        currentRoute = route
        if route.tab == .circles {
            clearUnread()
        }
    }

    func consumePendingRoute() {
        pendingRoute = nil
    }

    func incrementUnread() {
        unreadCount += 1
        UNUserNotificationCenter.current().setBadgeCount(unreadCount) { _ in }
    }

    func clearUnread() {
        unreadCount = 0
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    /// Call once after user is authenticated. Checks current status; does NOT prompt.
    func refreshPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    /// Shows iOS system permission prompt. Call only after soft-prompt accepted.
    /// Returns true if granted.
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await refreshPermissionStatus()
            if granted {
                registerForRemoteNotificationsIfAuthorized()
                await refreshHabitReminderScheduling()
            }
            return granted
        } catch {
            await refreshPermissionStatus()
            return false
        }
    }

    func loadPreferences(userId: UUID) async {
        isLoadingPreferences = true
        defer { isLoadingPreferences = false }

        do {
            preferences = try await NotificationPreferencesService.shared.fetchOrCreate(userId: userId)
        } catch {
            preferences = NotificationPreferences.defaults(for: userId)
            print("[NotificationService] Failed to load preferences: \(error)")
        }

        await refreshHabitReminderScheduling()
    }

    func updatePreferences(
        userId: UUID,
        mutate: (inout NotificationPreferences) -> Void
    ) async -> Bool {
        let existing = preferences ?? NotificationPreferences.defaults(for: userId)
        var updated = existing
        mutate(&updated)

        do {
            preferences = try await NotificationPreferencesService.shared.upsert(updated)
            await refreshHabitReminderScheduling()
            return true
        } catch {
            print("[NotificationService] Failed to update preferences: \(error)")
            preferences = existing
            return false
        }
    }

    func handleNotification(userInfo: [AnyHashable: Any], wasTapped: Bool) async {
        guard let payload = NotificationPayload(userInfo: userInfo) else { return }

        switch payload.type {
        case .momentWindow:
            if currentRoute.tab != .circles {
                incrementUnread()
            }

            if let userId = currentUserId ?? AuthManager.sharedForAPNs?.session?.user.id {
                await DailyMomentService.shared.load(userId: userId)
            }

            if wasTapped {
                pendingRoute = .circles
            }
        case .nudge, .circleCheckIn, .habitReminder:
            if currentRoute.tab != payload.route.tab {
                incrementUnread()
            }

            if wasTapped {
                pendingRoute = payload.route
            }
        }
    }

    /// Called by AppDelegate after APNs returns a device token.
    func handleToken(_ tokenData: Data, userId: UUID) async {
        let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
        do {
            try await SupabaseService.shared.client
                .from("device_tokens")
                .upsert(
                    ["user_id": userId.uuidString, "device_token": tokenString],
                    onConflict: "user_id,device_token"
                )
                .execute()
        } catch {
            // Non-fatal — token will be re-uploaded on next launch
            print("[NotificationService] Token upsert failed: \(error)")
        }
    }

    var permissionStatusSummary: String {
        switch permissionStatus {
        case .notDetermined:
            return "Not enabled yet"
        case .denied:
            return "Turned off in iPhone Settings"
        case .authorized:
            return "Allowed"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }

    var isSystemPermissionGranted: Bool {
        permissionStatus.allowsUserNotifications
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func handleAppDidBecomeActive() async {
        await refreshPermissionStatus()
        await refreshHabitReminderScheduling()
    }

    func refreshHabitReminderScheduling() async {
        guard let userId = currentUserId else { return }
        await HabitReminderScheduler.shared.resync(
            userId: userId,
            permissionStatus: permissionStatus,
            preferences: preferences
        )
    }

    private func registerForRemoteNotificationsIfAuthorized() {
        guard permissionStatus.allowsUserNotifications else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }
}

extension UNAuthorizationStatus {
    var allowsUserNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }
}
