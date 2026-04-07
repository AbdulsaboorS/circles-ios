import SwiftUI
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift
import Supabase

struct AuthView: View {
    @State private var showError = false
    @State private var errorMessage = ""

    // Test account login (username only, fixed password)
    @State private var username = ""
    @State private var isLoadingEmail = false
    @State private var showEmailSection = false

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo section
                VStack(spacing: 16) {
                    ZStack {
                        SwiftUI.Circle()
                            .fill(Color.msGold.opacity(0.12))
                            .frame(width: 96, height: 96)
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.msGold)
                    }

                    Text("Circles")
                        .font(.system(.largeTitle, design: .serif, weight: .semibold))
                        .foregroundStyle(Color.msTextPrimary)

                    Text("Your Islamic accountability circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Auth buttons
                VStack(spacing: 12) {
                    SignInWithAppleButton { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        Task { await handleAppleSignIn(result: result) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)

                    Button(action: { Task { await signInWithGoogle() } }) {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .foregroundStyle(Color.msTextPrimary)
                            Text("Continue with Google")
                                .foregroundStyle(Color.msTextPrimary)
                                .font(.system(.body, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.msCardShared)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.msBorder, lineWidth: 1))
                    }

                    // Dev / test divider
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showEmailSection.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Rectangle().fill(Color.msTextMuted.opacity(0.25)).frame(height: 1)
                            Text("test account")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.msTextMuted.opacity(0.6))
                            Rectangle().fill(Color.msTextMuted.opacity(0.25)).frame(height: 1)
                        }
                    }
                    .buttonStyle(.plain)

                    if showEmailSection {
                        VStack(spacing: 10) {
                            TextField("Username (e.g. amir1)", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(Color.msTextPrimary)
                                .padding(12)
                                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.msBorder, lineWidth: 1))
                                .tint(Color.msGold)

                            Button {
                                Task { await handleEmailAuth() }
                            } label: {
                                HStack(spacing: 6) {
                                    if isLoadingEmail {
                                        ProgressView().tint(Color.msBackground).scaleEffect(0.8)
                                    }
                                    Text("Enter as \(username.isEmpty ? "..." : username)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.msBackground)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(Color.msGold, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingEmail || username.isEmpty)
                            .opacity((isLoadingEmail || username.isEmpty) ? 0.5 : 1)

                            Text("Creates or signs into your test account")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.msTextMuted.opacity(0.6))
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if showError {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 24)

                Text("By continuing, you agree to our Terms and Privacy Policy")
                    .font(.caption2)
                    .foregroundStyle(Color.msTextMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Email auth

    @MainActor
    private func handleEmailAuth() async {
        isLoadingEmail = true
        showError = false
        defer { isLoadingEmail = false }
        let email = Self.testEmail(for: username)
        let password = "circles123"
        do {
            // Try sign-up first; if account exists, fall back to sign-in
            do {
                try await SupabaseService.shared.client.auth.signUp(email: email, password: password)
            } catch {
                try await SupabaseService.shared.client.auth.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private static func testEmail(for username: String) -> String {
        let normalized = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        return "\(normalized)@circles.test"
    }

    // MARK: - Apple

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

            if let fullName = credential.fullName {
                var parts: [String] = []
                if let given = fullName.givenName { parts.append(given) }
                if let family = fullName.familyName { parts.append(family) }
                if !parts.isEmpty {
                    try await SupabaseService.shared.client.auth.update(
                        user: UserAttributes(data: ["full_name": .string(parts.joined(separator: " "))])
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Google

    @MainActor
    private func signInWithGoogle() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController
        else { return }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else { return }
            let accessToken = result.user.accessToken.tokenString

            try await SupabaseService.shared.client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    AuthView()
}
