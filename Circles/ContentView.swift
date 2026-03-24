import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        Group {
            if auth.isLoading {
                ZStack {
                    Color(hex: "0D1021").ignoresSafeArea()
                    ProgressView()
                        .tint(Color(hex: "E8834B"))
                        .scaleEffect(1.5)
                }
            } else if auth.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
    }
}
