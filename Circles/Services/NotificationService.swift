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

    private init() {}

    func incrementUnread() {
        unreadCount += 1
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
            permissionStatus = granted ? .authorized : .denied
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            return false
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
}
