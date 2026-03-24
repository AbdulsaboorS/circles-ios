import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @Environment(\.pendingInviteCode) var pendingInviteCode

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            CommunityView()
                .tabItem { Label("Community", systemImage: "person.2.fill") }
                .tag(1)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle.fill") }
                .tag(2)
        }
        .tint(Color(hex: "E8834B"))
        .onChange(of: pendingInviteCode) { _, code in
            if code != nil {
                selectedTab = 1
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthManager())
}
