import SwiftUI

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

// MARK: - App Entry Point

@main
struct CirclesApp: App {
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
