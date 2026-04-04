import SwiftUI
import Supabase

struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.pendingInviteCode) private var pendingInviteCode

    @State private var amiirCoordinator = AmiirOnboardingCoordinator()
    @State private var memberCoordinator = MemberOnboardingCoordinator()
    @State private var isFlushingToSupabase = false

    /// True when the active flow is Joiner (member)
    private var isJoinerFlow: Bool {
        amiirCoordinator.shouldSwitchToJoinerFlow || pendingInviteCode != nil
    }

    var body: some View {
        Group {
            if auth.isLoading {
                loadingScreen
            } else if auth.isAuthenticated {
                authenticatedRouting
            } else {
                unauthenticatedOnboarding
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .onChange(of: auth.isAuthenticated) { _, isAuthenticated in
            guard isAuthenticated, let userId = auth.session?.user.id else { return }
            handlePostAuth(userId: userId)
        }
        .onChange(of: pendingInviteCode) { _, code in
            if let code, !code.isEmpty {
                memberCoordinator.inviteCodeInput = code
                if !amiirCoordinator.shouldSwitchToJoinerFlow {
                    amiirCoordinator.shouldSwitchToJoinerFlow = true
                }
            }
        }
        .onAppear {
            if let code = pendingInviteCode, !code.isEmpty {
                memberCoordinator.inviteCodeInput = code
                amiirCoordinator.shouldSwitchToJoinerFlow = true
            }
        }
    }

    // MARK: - Authenticated routing

    @ViewBuilder
    private var authenticatedRouting: some View {
        if let userId = auth.session?.user.id {
            if AmiirOnboardingCoordinator.hasCompletedOnboarding(userId: userId) {
                MainTabView(initialTab: 1)
            } else if isFlushingToSupabase {
                loadingScreen
            } else if amiirCoordinator.isComplete || memberCoordinator.isComplete {
                let tab = memberCoordinator.isComplete ? 1 : 0
                MainTabView(initialTab: tab)
            } else {
                loadingScreen
            }
        } else {
            loadingScreen
        }
    }

    // MARK: - Unauthenticated onboarding

    @ViewBuilder
    private var unauthenticatedOnboarding: some View {
        if isJoinerFlow {
            MemberOnboardingFlowView()
                .environment(memberCoordinator)
                .environment(auth)
                .onAppear {
                    memberCoordinator.onBack = {
                        amiirCoordinator.shouldSwitchToJoinerFlow = false
                    }
                }
        } else {
            AmiirOnboardingFlowView()
                .environment(amiirCoordinator)
                .environment(auth)
        }
    }

    // MARK: - Post-auth flush

    private func handlePostAuth(userId: UUID) {
        guard !AmiirOnboardingCoordinator.hasCompletedOnboarding(userId: userId) else { return }
        isFlushingToSupabase = true
        Task {
            if isJoinerFlow {
                await memberCoordinator.flushToSupabase(userId: userId)
            } else {
                await amiirCoordinator.flushToSupabase(userId: userId)
            }
            isFlushingToSupabase = false
        }
    }

    // MARK: - Loading screen

    private var loadingScreen: some View {
        ZStack {
            Color(hex: "1A2E1E").ignoresSafeArea()
            ProgressView()
                .tint(Color(hex: "D4A240"))
                .scaleEffect(1.4)
        }
    }
}
