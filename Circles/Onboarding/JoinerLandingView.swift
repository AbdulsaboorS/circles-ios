import SwiftUI

private extension Color {
    static let msBackground = Color(hex: "1A2E1E")
    static let msCardShared = Color(hex: "243828")
    static let msGold = Color(hex: "D4A240")
    static let msTextPrimary = Color(hex: "F0EAD6")
    static let msTextMuted = Color(hex: "8FAF94")
    static let msBorder = Color(hex: "D4A240").opacity(0.18)
}

struct JoinerLandingView: View {
    @Environment(MemberOnboardingCoordinator.self) private var coordinator

    @State private var animating = false

    private let orbSymbols = ["flame.fill", "person.2.fill", "heart.fill"]

    var body: some View {
        @Bindable var coord = coordinator

        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 44)

                previewPanel
                    .padding(.horizontal, 24)

                Spacer(minLength: 30)

                VStack(spacing: 14) {
                    Text("Join the circle\nyou were invited to.")
                        .font(.system(size: 29, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Your brothers and sisters are waiting.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                Spacer()

                VStack(spacing: 12) {
                    TextField("Enter invite code", text: $coord.inviteCodeInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.msTextPrimary)
                        .multilineTextAlignment(.center)
                        .padding(15)
                        .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.msBorder, lineWidth: 1))
                        .tint(Color.msGold)

                    Button {
                        Task { await coordinator.submitInviteCode(coord.inviteCodeInput) }
                    } label: {
                        HStack(spacing: 8) {
                            if coordinator.isLoading {
                                ProgressView()
                                    .tint(Color.msBackground)
                                    .scaleEffect(0.8)
                            }

                            Text(coordinator.isLoading ? "Finding your circle..." : "Join My Circle")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.msBackground)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.msGold, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(coord.inviteCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || coordinator.isLoading)
                    .opacity((coord.inviteCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || coordinator.isLoading) ? 0.45 : 1)

                    if let error = coordinator.errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    coordinator.onBack?()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.msGold)
                }
            }
        }
        .onAppear {
            animating = true
            if !coordinator.inviteCodeInput.isEmpty && coordinator.circle == nil {
                Task { await coordinator.submitInviteCode(coordinator.inviteCodeInput) }
            }
        }
    }

    private var previewPanel: some View {
        RoundedRectangle(cornerRadius: 30)
            .fill(
                LinearGradient(
                    colors: [Color.msCardShared, Color.msBackground.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color.msBorder, lineWidth: 1)

                    VStack(spacing: 22) {
                        HStack(spacing: 22) {
                            ForEach(Array(orbSymbols.enumerated()), id: \.offset) { index, symbol in
                                ZStack {
                                    SwiftUI.Circle()
                                        .fill(Color.msGold.opacity(animating ? 0.18 : 0.06))
                                        .frame(width: 72, height: 72)
                                        .animation(
                                            .easeInOut(duration: 1.4)
                                                .repeatForever(autoreverses: true)
                                                .delay(Double(index) * 0.3),
                                            value: animating
                                        )

                                    Image(systemName: symbol)
                                        .font(.system(size: 28))
                                        .foregroundStyle(Color.msGold.opacity(animating ? 1.0 : 0.4))
                                        .animation(
                                            .easeInOut(duration: 1.4)
                                                .repeatForever(autoreverses: true)
                                                .delay(Double(index) * 0.3),
                                            value: animating
                                        )
                                }
                            }
                        }

                        VStack(spacing: 12) {
                            joinerPreviewRow(icon: "person.2.fill", title: "Invite opens instantly")
                            joinerPreviewRow(icon: "flame.fill", title: "Group streak stays visible")
                            joinerPreviewRow(icon: "heart.fill", title: "Private habits remain yours")
                        }
                    }
                    .padding(24)
                }
            }
            .frame(height: 300)
    }

    private func joinerPreviewRow(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.msGold)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.msTextMuted)
            Spacer()
        }
    }
}
