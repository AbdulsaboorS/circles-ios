import SwiftUI
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift
import Supabase

struct JoinerAuthGateView: View {
    @Environment(MemberOnboardingCoordinator.self) private var coordinator

    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 48)

                VStack(spacing: 12) {
                    Image(systemName: "person.badge.checkmark.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.msGold)

                    Text("Don't lose your spot\nin the circle.")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Save your progress to activate your roadmap.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 24)

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Your 28-Day Roadmap")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.msGold)
                        Spacer()
                        Text("Week 1 of 4")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.msTextMuted)
                    }

                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { index in
                            SwiftUI.Circle()
                                .fill(index < 3 ? Color.msGold : Color.msGold.opacity(0.2))
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                .padding(18)
                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.msBorder, lineWidth: 1))
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 12) {
                    SignInWithAppleButton { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        Task { await handleAppleSignIn(result: result) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)

                    Button {
                        Task { await signInWithGoogle() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                            Text("Continue with Google")
                                .font(.system(.body, weight: .medium))
                        }
                        .foregroundStyle(Color.msTextPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.msBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    if showError {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)

                StepIndicator(current: 6, total: 7)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden()
    }

    @MainActor
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        do {
            guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = credential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8) else {
                return
            }

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
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }

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
