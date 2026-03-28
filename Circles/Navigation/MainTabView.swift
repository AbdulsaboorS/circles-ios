import SwiftUI

struct MainTabView: View {
    var initialTab: Int = 1             // Circles by default; Amir onboarding passes 0 (Home)
    @State private var selectedTab: Int
    @Environment(\.pendingInviteCode) var pendingInviteCode

    init(initialTab: Int = 1) {
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }
    private var notifService = NotificationService.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            CommunityView()
                .tabItem { Label("Circles", systemImage: "person.2.fill") }
                .badge(notifService.unreadCount > 0 ? notifService.unreadCount : 0)
                .tag(1)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle.fill") }
                .tag(2)
        }
        .tint(Color.accent)
        .onChange(of: pendingInviteCode) { _, code in
            if code != nil {
                selectedTab = 1
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 1 {
                NotificationService.shared.clearUnread()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthManager())
}
