import SwiftUI
import UIKit
import Supabase

// MARK: - Environment Key for pending invite code

private struct PendingInviteCodeKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var pendingInviteCode: String? {
        get { self[PendingInviteCodeKey.self] }
        set { self[PendingInviteCodeKey.self] = newValue }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            guard let userId = AuthManager.sharedForAPNs?.session?.user.id else { return }
            await NotificationService.shared.handleToken(deviceToken, userId: userId)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[AppDelegate] APNs registration failed: \(error)")
    }

    // Handle notification tap or foreground delivery
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            await NotificationService.shared.handleNotification(userInfo: userInfo, wasTapped: true)
        }
        completionHandler()
    }

    // Show notification banner even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        Task { @MainActor in
            await NotificationService.shared.handleNotification(userInfo: userInfo, wasTapped: false)
        }
        completionHandler([.banner, .sound])
    }
}

// MARK: - App Entry Point

@main
struct CirclesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authManager = AuthManager()
    @State private var themeManager = ThemeManager.shared
    @State private var pendingInviteCode: String?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(themeManager)
                .environment(\.pendingInviteCode, pendingInviteCode)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onAppear {
                    AuthManager.sharedForAPNs = authManager
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Parse circles://join/ABCD1234
        guard url.scheme == "circles",
              url.host == "join",
              let code = url.pathComponents.dropFirst().first,
              !code.isEmpty else { return }
        pendingInviteCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
