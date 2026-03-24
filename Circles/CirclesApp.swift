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

class AppDelegate: NSObject, UIApplicationDelegate {
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
}

// MARK: - App Entry Point

@main
struct CirclesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authManager = AuthManager()
    @State private var pendingInviteCode: String?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
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
        pendingInviteCode = code
    }
}
