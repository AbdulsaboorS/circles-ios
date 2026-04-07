import SwiftUI
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift
import Supabase

struct AmiirActivationView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var revealPreview = false
    @State private var showTestSection = false
    @State private var testUsername = ""
    @State private var isLoadingTest = false

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 48)

                VStack(spacing: 14) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(Color.msGold)

                    Text("Your sanctuary is ready.")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Save your progress and invite your first 2 brothers/sisters to activate the group streak.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 16)
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 24)

                roadmapPreviewCard
                    .padding(.horizontal, 24)
                    .scaleEffect(revealPreview ? 1 : 0.94)
                    .opacity(revealPreview ? 1 : 0)
                    .offset(y: revealPreview ? 0 : 18)
                    .animation(.spring(duration: 0.75, bounce: 0.22), value: revealPreview)

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

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showTestSection.toggle() }
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

                    if showTestSection {
                        VStack(spacing: 10) {
                            TextField("Username (e.g. amir1)", text: $testUsername)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(Color.msTextPrimary)
                                .padding(12)
                                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.msBorder, lineWidth: 1))
                                .tint(Color.msGold)

                            Button {
                                Task { await handleTestAuth() }
                            } label: {
                                HStack(spacing: 6) {
                                    if isLoadingTest { ProgressView().tint(Color.msBackground).scaleEffect(0.8) }
                                    Text("Enter as \(testUsername.isEmpty ? "..." : testUsername)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.msBackground)
                                }
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(Color.msGold, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingTest || testUsername.isEmpty)
                            .opacity((isLoadingTest || testUsername.isEmpty) ? 0.5 : 1)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

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
        .onAppear {
            revealPreview = true
        }
    }

    private var roadmapPreviewCard: some View {
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
                        .fill(index < 3 ? Color.msGold : Color.msGold.opacity(0.16))
                        .frame(width: 10, height: 10)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                previewMilestone(title: "Fajr", subtitle: "Built into your mornings")
                previewMilestone(title: "Quran", subtitle: "Consistent, not rushed")
            }
        }
        .padding(18)
        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.msBorder, lineWidth: 1))
    }

    private func previewMilestone(title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.msGold.opacity(0.16))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.msGold)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.msTextPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.msTextMuted)
            }

            Spacer()
        }
    }

    @MainActor
    private func handleTestAuth() async {
        isLoadingTest = true
        defer { isLoadingTest = false }
        let normalized = testUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "")
        let email = "\(normalized)@circles.test"
        let password = "circles123"
        do {
            do { try await SupabaseService.shared.client.auth.signUp(email: email, password: password) }
            catch { try await SupabaseService.shared.client.auth.signIn(email: email, password: password) }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
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
