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
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AppColors { AppColors.resolve(colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Join a Circle")
                            .font(.appTitle)
                            .foregroundStyle(colors.textPrimary)
                        Text("Enter the 8-character invite code from a circle member.")
                            .font(.appSubheadline)
                            .foregroundStyle(colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("ABCD1234", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .font(.system(.title2, design: .monospaced, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(colors.textPrimary)
                        .padding()
                        .background(Color.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        .tint(Color.accent)
                        .onChange(of: inviteCode) { _, val in
                            inviteCode = String(val.uppercased().prefix(8))
                        }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    PrimaryButton(title: isJoining ? "" : "Join Circle", isLoading: isJoining) {
                        Task { await checkGenderAndJoin() }
                    }
                    .disabled(inviteCode.trimmingCharacters(in: .whitespaces).count < 8)
                    .padding(.bottom, 32)
                }
                .padding(24)
            }
            .navigationTitle("Join Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.accent)
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
