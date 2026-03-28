import SwiftUI
import Supabase

struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.pendingInviteCode) private var pendingInviteCode

    @State private var amiirCoordinator = AmiirOnboardingCoordinator()
    @State private var memberCoordinator: MemberOnboardingCoordinator? = nil

    var body: some View {
        Group {
            if auth.isLoading {
                loadingScreen
            } else if !auth.isAuthenticated {
                // Unauthenticated: show circle preview if invite link, else plain auth
                if let code = pendingInviteCode {
                    CirclePreviewView(inviteCode: code)
                } else {
                    AuthView()
                }
            } else if let userId = auth.session?.user.id,
                      !AmiirOnboardingCoordinator.hasCompletedOnboarding(userId: userId) {
                // New user: choose Amir or Member flow
                if let coord = memberCoordinator, !coord.isComplete {
                    // Member/Joiner flow (has invite code)
                    MemberOnboardingFlowView()
                        .environment(coord)
                        .environment(auth)
                } else if !amiirCoordinator.isComplete {
                    // Amir/Creator flow (no invite code)
                    AmiirOnboardingFlowView()
                        .environment(amiirCoordinator)
                        .environment(auth)
                } else {
                    // Amir just completed → Home tab
                    MainTabView(initialTab: 0)
                }
            } else if memberCoordinator?.isComplete == true {
                // Member just completed → Circles tab
                MainTabView(initialTab: 1)
            } else {
                // Returning user → Circles tab
                MainTabView(initialTab: 1)
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .onChange(of: auth.isAuthenticated) { _, isAuthenticated in
            guard isAuthenticated, let userId = auth.session?.user.id else { return }
            // When user just signed in with a pending invite code → start Member flow
            if let code = pendingInviteCode,
               !AmiirOnboardingCoordinator.hasCompletedOnboarding(userId: userId) {
                memberCoordinator = MemberOnboardingCoordinator(inviteCode: code)
            }
        }
        .onAppear {
            // Handle case where user is already authenticated with a pending invite code
            if let userId = auth.session?.user.id,
               let code = pendingInviteCode,
               !AmiirOnboardingCoordinator.hasCompletedOnboarding(userId: userId),
               memberCoordinator == nil {
                memberCoordinator = MemberOnboardingCoordinator(inviteCode: code)
            }
        }
    }

    private var loadingScreen: some View {
        ZStack {
            Color.lightBackground.ignoresSafeArea()
            ProgressView()
                .tint(Color.accent)
                .scaleEffect(1.4)
        }
    }
}
