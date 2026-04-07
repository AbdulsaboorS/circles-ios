import SwiftUI
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift
import Supabase

/// Unauthenticated landing page shown when a user taps an invite link.
struct CirclePreviewView: View {
    let inviteCode: String

    @State private var circle: Circle? = nil
    @State private var previewMembers: [CircleMember] = []
    @State private var previewProfiles: [UUID: Profile] = [:]
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoadingEmail = false
    @State private var showEmailSection = false

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().tint(Color.msGold).scaleEffect(1.2)
                    Text("Loading your circle…")
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)
                }
            } else if let circle {
                previewContent(circle: circle)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.msGold.opacity(0.7))
                    Text("Invite link not found.")
                        .font(.appHeadline)
                        .foregroundStyle(Color.msTextPrimary)
                    Text("Check the link and try again.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                }
                .padding(.horizontal, 28)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadPreview()
        }
    }

    private func previewContent(circle: Circle) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 14) {
                    ZStack {
                        SwiftUI.Circle()
                            .fill(Color.msGold.opacity(0.12))
                            .frame(width: 88, height: 88)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.msGold)
                    }

                    VStack(spacing: 8) {
                        Text(circle.name)
                            .font(.appTitle)
                            .foregroundStyle(Color.msTextPrimary)
                            .multilineTextAlignment(.center)

                        Text("A private accountability circle")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                    }

                    if !previewMembers.isEmpty {
                        VStack(spacing: 8) {
                            previewFacePile

                            Text(memberPreviewSummary)
                                .font(.appCaption)
                                .foregroundStyle(Color.msTextMuted)
                        }
                    }
                }
                .padding(.top, 56)
                .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    if !previewMembers.isEmpty {
                        memberPreview
                    }

                    if circle.groupStreakDaysSafe > 0 {
                        detailRow(icon: "flame.fill", text: "\(circle.groupStreakDaysSafe)-day group streak")
                    }

                    if !circle.coreHabitsSafe.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Circle Focus")
                                .font(.appCaption)
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .foregroundStyle(Color.msTextMuted)

                            FlowHabitsRow(habits: circle.coreHabitsSafe)
                        }
                    }

                    if circle.genderSettingSafe != "mixed" {
                        detailRow(
                            icon: circle.genderSettingSafe == "brothers" ? "person.fill" : "person.fill.checkmark",
                            text: circle.genderSettingSafe == "brothers" ? "Brothers-only circle" : "Sisters-only circle"
                        )
                    }
                }
                .padding(16)
                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.msBorder, lineWidth: 1)
                )
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    Text("Join \(circle.name)")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)

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
                            Text("Continue with Google")
                                .font(.system(.body, weight: .medium))
                        }
                        .foregroundStyle(Color.msTextPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.msBorder, lineWidth: 1))
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showEmailSection.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Rectangle().fill(Color.msTextMuted.opacity(0.25)).frame(height: 1)
                            Text("test account")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.msTextMuted.opacity(0.7))
                            Rectangle().fill(Color.msTextMuted.opacity(0.25)).frame(height: 1)
                        }
                    }
                    .buttonStyle(.plain)

                    if showEmailSection {
                        VStack(spacing: 10) {
                            TextField("Username", text: $username)
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
                                    Text(isSignUp ? "Create Test Account" : "Sign In")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.msBackground)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(Color.msGold, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingEmail || username.isEmpty || password.isEmpty)
                            .opacity((isLoadingEmail || username.isEmpty || password.isEmpty) ? 0.5 : 1)

                            Text("Testing only: username becomes `username@circles.test`.")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.msTextMuted)

                            Button {
                                withAnimation { isSignUp.toggle() }
                            } label: {
                                Text(isSignUp ? "Already have a test account? Sign in" : "Need a fresh test account? Create one")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.msTextMuted)
                            }
                            .buttonStyle(.plain)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if showError {
                        Text(errorMessage)
                            .font(.appCaption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }

    private var memberPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Members")
                .font(.appCaption)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Color.msTextMuted)

            VStack(spacing: 10) {
                ForEach(Array(previewMembers.prefix(3))) { member in
                    HStack(spacing: 10) {
                        AvatarView(
                            avatarUrl: previewProfiles[member.userId]?.avatarUrl,
                            name: displayName(for: member),
                            size: 36
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName(for: member))
                                .font(.appSubheadline)
                                .foregroundStyle(Color.msTextPrimary)
                            Text(member.role == "admin" ? "Amir" : "Member")
                                .font(.appCaption)
                                .foregroundStyle(Color.msTextMuted)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var previewFacePile: some View {
        HStack(spacing: -10) {
            ForEach(Array(previewMembers.prefix(4))) { member in
                AvatarView(
                    avatarUrl: previewProfiles[member.userId]?.avatarUrl,
                    name: displayName(for: member),
                    size: 42
                )
                .overlay(
                    SwiftUI.Circle()
                        .stroke(Color.msBackground, lineWidth: 2)
                )
            }

            if previewMembers.count > 4 {
                Text("+\(previewMembers.count - 4)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.msTextPrimary)
                    .frame(width: 42, height: 42)
                    .background(Color.msCardShared, in: SwiftUI.Circle())
                    .overlay(
                        SwiftUI.Circle()
                            .stroke(Color.msBorder, lineWidth: 1)
                    )
                    .padding(.leading, 6)
            }
        }
    }

    private var memberPreviewSummary: String {
        let count = previewMembers.count
        guard count > 0 else { return "" }
        return count == 1 ? "1 member already inside" : "\(count) members already inside"
    }

    private func displayName(for member: CircleMember) -> String {
        let preferred = previewProfiles[member.userId]?.preferredName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !preferred.isEmpty { return preferred }
        return member.role == "admin" ? "Amir" : "Member"
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.msGold)
            Text(text)
                .font(.appSubheadline)
                .foregroundStyle(Color.msTextPrimary)
            Spacer()
        }
    }

    private func loadPreview() async {
        do {
            let circle = try await CircleService.shared.fetchCircleByCode(inviteCode)
            self.circle = circle

            if let members = try? await CircleService.shared.fetchMembers(circleId: circle.id) {
                previewMembers = members
                let profiles = (try? await AvatarService.shared.fetchProfiles(userIds: members.map { $0.userId })) ?? []
                previewProfiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

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

    @MainActor
    private func handleEmailAuth() async {
        isLoadingEmail = true
        showError = false
        defer { isLoadingEmail = false }
        do {
            let email = Self.testEmail(for: username)
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

    private static func testEmail(for username: String) -> String {
        let normalized = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        return "\(normalized)@circles.test"
    }
}

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
                .foregroundStyle(Color.msGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.msGold.opacity(0.1), in: Capsule())
            }
            Spacer()
        }
    }
}
