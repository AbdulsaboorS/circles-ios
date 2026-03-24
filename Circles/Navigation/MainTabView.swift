import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            CommunityView()
                .tabItem { Label("Community", systemImage: "person.2.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle.fill") }
        }
        .tint(Color(hex: "E8834B"))
    }
}

#Preview {
    MainTabView()
        .environment(AuthManager())
}
