import SwiftUI
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift
import Supabase

/// Unauthenticated landing page shown when a user taps an invite link.
/// Fetches circle preview data (name, core habits, streak) and shows sign-in buttons.
struct CirclePreviewView: View {
    let inviteCode: String

    @State private var circle: Circle? = nil
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AppColors { AppColors.resolve(colorScheme) }

    var body: some View {
        ZStack {
            AppBackground()

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().tint(Color.accent).scaleEffect(1.2)
                    Text("Loading your circle…")
                        .font(.appCaption)
                        .foregroundStyle(colors.textSecondary)
                }
            } else if let circle {
                previewContent(circle: circle)
            } else {
                // Circle not found
                VStack(spacing: 16) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accent.opacity(0.6))
                    Text("Invite link not found.")
                        .font(.appHeadline)
                        .foregroundStyle(colors.textPrimary)
                    Text("Check the link and try again.")
                        .font(.appSubheadline)
                        .foregroundStyle(colors.textSecondary)
                }
            }
        }
        .task {
            circle = try? await CircleService.shared.fetchCircleByCode(inviteCode)
            isLoading = false
        }
    }

    // MARK: - Preview Content

    private func previewContent(circle: Circle) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            // Header
            VStack(spacing: 16) {
                // Circle icon
                ZStack {
                    SwiftUI.Circle()
                        .fill(Color.accent.opacity(0.12))
                        .frame(width: 88, height: 88)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accent)
                }

                VStack(spacing: 8) {
                    Text(circle.name)
                        .font(.appTitle)
                        .foregroundStyle(colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("A private accountability circle")
                        .font(.appSubheadline)
                        .foregroundStyle(colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 24)

            // Circle details card
            AppCard {
                VStack(spacing: 14) {
                    // Group streak
                    if circle.groupStreakDaysSafe > 0 {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(Color.accent)
                            Text("\(circle.groupStreakDaysSafe)-day group streak")
                                .font(.appSubheadline)
                                .foregroundStyle(colors.textPrimary)
                            Spacer()
                        }
                        Divider().opacity(0.2)
                    }

                    // Core habits
                    if !circle.coreHabitsSafe.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Circle Focus")
                                .font(.appCaption)
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .foregroundStyle(colors.textSecondary)

                            FlowHabitsRow(habits: circle.coreHabitsSafe)
                        }
                    }

                    // Gender setting
                    if circle.genderSettingSafe != "mixed" {
                        HStack {
                            Image(systemName: circle.genderSettingSafe == "brothers" ? "person.fill" : "person.fill.checkmark")
                                .font(.appCaption)
                                .foregroundStyle(Color.accent)
                            Text(circle.genderSettingSafe == "brothers" ? "Brothers-only circle" : "Sisters-only circle")
                                .font(.appCaption)
                                .foregroundStyle(colors.textSecondary)
                            Spacer()
                        }
                    }
                }
                .padding(16)
            }
            .padding(.horizontal, 24)

            Spacer()

            // Sign-in section
            VStack(spacing: 12) {
                Text("Join \(circle.name)")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(colors.textPrimary)

                SignInWithAppleButton { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    Task { await handleAppleSignIn(result: result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .cornerRadius(12)

                Button(action: { Task { await signInWithGoogle() } }) {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                        Text("Continue with Google")
                            .font(.system(.body, weight: .medium))
                    }
                    .foregroundStyle(colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accent.opacity(0.2), lineWidth: 1))
                }

                if showError {
                    Text(errorMessage)
                        .font(.appCaption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Auth

    @MainActor
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        do {
            guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = credential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8)
            else { return }
            try await SupabaseService.shared.client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken)
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    @MainActor
    private func signInWithGoogle() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController
        else { return }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else { return }
            try await SupabaseService.shared.client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Flow Habits Row

private struct FlowHabitsRow: View {
    let habits: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(habits, id: \.self) { habit in
                let icon = AmiirOnboardingCoordinator.curatedHabits.first { $0.name == habit }?.icon ?? "star.fill"
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                    Text(habit)
                        .font(.appCaption)
                }
                .foregroundStyle(Color.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accent.opacity(0.1), in: Capsule())
            }
            Spacer()
        }
    }
}
