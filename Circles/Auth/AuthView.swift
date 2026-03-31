import SwiftUI
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift
import Supabase

// MARK: - Midnight Sanctuary tokens

private extension Color {
    static let msBackground   = Color(hex: "1A2E1E")
    static let msCardShared   = Color(hex: "243828")
    static let msGold         = Color(hex: "D4A240")
    static let msTextPrimary  = Color(hex: "F0EAD6")
    static let msTextMuted    = Color(hex: "8FAF94")
    static let msBorder       = Color(hex: "D4A240").opacity(0.18)
}

struct AuthView: View {
    @State private var showError = false
    @State private var errorMessage = ""

    // Email/password test login
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
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
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(Color.msTextPrimary)
                                .padding(12)
                                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.msBorder, lineWidth: 1))
                                .tint(Color.msGold)

                            SecureField("Password", text: $password)
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
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.msBackground)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(Color.msGold, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingEmail || email.isEmpty || password.isEmpty)
                            .opacity((isLoadingEmail || email.isEmpty || password.isEmpty) ? 0.5 : 1)

                            Button {
                                withAnimation { isSignUp.toggle() }
                            } label: {
                                Text(isSignUp ? "Already have an account? Sign in" : "No account? Create one")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.msTextMuted)
                            }
                            .buttonStyle(.plain)
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
        do {
            if isSignUp {
                try await SupabaseService.shared.client.auth.signUp(email: email, password: password)
            } else {
                try await SupabaseService.shared.client.auth.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
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
