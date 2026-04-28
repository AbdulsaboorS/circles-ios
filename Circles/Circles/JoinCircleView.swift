import SwiftUI
import Supabase

struct JoinCircleView: View {
    @Environment(AuthManager.self) var auth
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: CirclesViewModel

    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var pendingCircle: Circle? = nil
    @State private var showGenderAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Join a Circle")
                            .font(.appTitle)
                            .foregroundStyle(Color.msTextPrimary)
                        Text("Enter the 8-character invite code from a circle member.")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("ABCD1234", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .font(.system(.title2, design: .monospaced, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.msTextPrimary)
                        .padding()
                        .background(Color.msGold.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .tint(Color.msGold)
                        .onChange(of: inviteCode) { _, val in
                            inviteCode = String(val.uppercased().prefix(8))
                            if pendingCircle != nil {
                                pendingCircle = nil
                            }
                            if viewModel.errorMessage != nil {
                                viewModel.errorMessage = nil
                            }
                        }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundStyle(Color.red)
                            .multilineTextAlignment(.center)
                    }

                    if let circle = pendingCircle {
                        VStack(spacing: 8) {
                            Text(circle.name)
                                .font(.system(size: 18, weight: .semibold, design: .serif))
                                .foregroundStyle(Color.msTextPrimary)
                            if let desc = circle.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.appSubheadline)
                                    .foregroundStyle(Color.msTextMuted)
                                    .multilineTextAlignment(.center)
                            }
                            if circle.genderSettingSafe != "mixed" {
                                Text(circle.genderSettingSafe.capitalized)
                                    .font(.appCaption)
                                    .foregroundStyle(Color.msGold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.msGold.opacity(0.15), in: Capsule())
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.msGold.opacity(0.2), lineWidth: 1))
                    }

                    Spacer()

                    Button {
                        Task { await checkGenderAndJoin() }
                    } label: {
                        ZStack {
                            if isJoining {
                                ProgressView().tint(Color.msBackground)
                            } else {
                                Text("Join Circle")
                                    .font(.appSubheadline.weight(.semibold))
                                    .foregroundStyle(Color.msBackground)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            inviteCode.trimmingCharacters(in: .whitespaces).count < 8 || isJoining
                                ? Color.msGold.opacity(0.4)
                                : Color.msGold
                        )
                        .clipShape(Capsule())
                    }
                    .disabled(inviteCode.trimmingCharacters(in: .whitespaces).count < 8 || isJoining)
                    .padding(.bottom, 32)
                }
                .padding(24)
            }
            .navigationTitle("Join Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.msGold)
                }
            }
            .onAppear {
                if let code = viewModel.pendingCode {
                    inviteCode = code
                    viewModel.pendingCode = nil
                }
            }
            .alert(genderAlertTitle, isPresented: $showGenderAlert) {
                Button("Join Anyway", role: .destructive) {
                    Task {
                        if let circle = pendingCircle,
                           let userId = auth.session?.user.id {
                            await performJoin(circle: circle, userId: userId)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingCircle = nil
                    isJoining = false
                }
            } message: {
                if let circle = pendingCircle {
                    let label = circle.genderSettingSafe == "brothers" ? "brothers-only" : "sisters-only"
                    Text("'\(circle.name)' is a \(label) circle. Are you sure you want to join?")
                }
            }
        }
    }

    private var genderAlertTitle: String {
        guard let circle = pendingCircle else { return "Gender Setting" }
        return circle.genderSettingSafe == "brothers" ? "Brothers-Only Circle" : "Sisters-Only Circle"
    }

    // MARK: - Join Logic

    private func checkGenderAndJoin() async {
        isJoining = true
        viewModel.errorMessage = nil
        guard let userId = auth.session?.user.id else { isJoining = false; return }

        do {
            let circle = try await CircleService.shared.fetchCircleByCode(
                inviteCode.trimmingCharacters(in: .whitespaces)
            )
            let profile = try? await AvatarService.shared.fetchProfile(userId: userId)
            let userGender = profile?.gender ?? ""
            let circleGender = circle.genderSettingSafe

            // Show circle info before joining
            pendingCircle = circle

            let mismatch = (circleGender == "brothers" && userGender == "sister") ||
                           (circleGender == "sisters"  && userGender == "brother")

            if mismatch {
                pendingCircle = circle
                showGenderAlert = true
                isJoining = false
            } else {
                await performJoin(circle: circle, userId: userId)
            }
        } catch {
            viewModel.errorMessage = "Circle not found. Check the code and try again."
            isJoining = false
        }
    }

    private func performJoin(circle: Circle, userId: UUID) async {
        isJoining = true
        let result = await viewModel.joinCircle(code: circle.inviteCode ?? "", userId: userId)
        if result != nil { dismiss() }
        isJoining = false
    }
}
