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

            JourneyView()
                .tabItem { Label("Journey", systemImage: "calendar") }
                .tag(2)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle.fill") }
                .tag(3)
        }
        .tint(Color.msGold)
        .toolbarBackground(Color.msBackgroundDeep, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .onAppear {
            if let tab = AppTabRoute(tabIndex: selectedTab) {
                let route = AppNotificationRoute(tab: tab)
                notifService.updateCurrentRoute(route)
            }
            applyPendingRouteIfNeeded()
        }
        .onChange(of: pendingInviteCode) { _, code in
            if code != nil {
                selectedTab = 1
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if let tab = AppTabRoute(tabIndex: newTab) {
                let route = AppNotificationRoute(tab: tab)
                notifService.updateCurrentRoute(route)
            }
        }
        .onChange(of: notifService.pendingRoute) { _, _ in
            applyPendingRouteIfNeeded()
        }
    }

    private func applyPendingRouteIfNeeded() {
        guard let route = notifService.pendingRoute else { return }
        selectedTab = route.tabIndex
        if !route.requiresInTabFollowThrough {
            notifService.updateCurrentRoute(route)
            notifService.consumePendingRoute()
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthManager())
}
