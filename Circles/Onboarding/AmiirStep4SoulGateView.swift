import SwiftUI
import Supabase

// MARK: - Midnight Sanctuary tokens

private extension Color {
    static let msBackground  = Color(hex: "1A2E1E")
    static let msCardShared  = Color(hex: "243828")
    static let msGold        = Color(hex: "D4A240")
    static let msTextPrimary = Color(hex: "F0EAD6")
    static let msTextMuted   = Color(hex: "8FAF94")
    static let msBorder      = Color(hex: "D4A240").opacity(0.18)
}

struct AmiirStep4SoulGateView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator
    @Environment(AuthManager.self) private var auth

    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                // Icon + heading
                VStack(spacing: 16) {
                    ZStack {
                        SwiftUI.Circle()
                            .fill(Color.msGold.opacity(0.12))
                            .frame(width: 96, height: 96)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 42))
                            .foregroundStyle(Color.msGold)
                    }

                    Text("Your circle needs a soul.")
                        .font(.appTitle)
                        .foregroundStyle(Color.msTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Invite 2-3 friends to bring your circle to life.\nYour AI roadmap is being prepared in the background.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                Spacer()

                // Circle info card
                if let circle = coordinator.createdCircle {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 14) {
                            ZStack {
                                SwiftUI.Circle()
                                    .fill(Color.msGold.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.msGold)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(circle.name)
                                    .font(.appSubheadline)
                                    .foregroundStyle(Color.msTextPrimary)
                                Text("Invite code: \(circle.inviteCode ?? "")")
                                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                                    .foregroundStyle(Color.msTextMuted)
                            }
                            Spacer()
                        }
                        .padding(14)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.msCardShared)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.msBorder, lineWidth: 1))
                    )
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Share button (primary gold CTA)
                Button {
                    coordinator.hasSharedInvite = true
                    showShareSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Share Invite Link")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(Color.msBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.msGold, in: Capsule())
                    .shadow(color: Color.msGold.opacity(0.35), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(url: coordinator.inviteURL)
                        .presentationDetents([.medium, .large])
                }

                // Begin button (unlocked after share)
                Button {
                    if let userId = auth.session?.user.id {
                        coordinator.completeOnboarding(userId: userId)
                    }
                } label: {
                    Text(coordinator.hasSharedInvite ? "Begin My Journey" : "Share first to continue")
                        .font(.appSubheadline)
                        .foregroundStyle(coordinator.hasSharedInvite ? Color.msGold : Color.msTextMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(coordinator.hasSharedInvite ? Color.msGold : Color.msTextMuted.opacity(0.3), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!coordinator.hasSharedInvite)
                .padding(.horizontal, 24)
                .padding(.top, 12)

                StepIndicator(current: 3, total: 4)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden()
    }
}

// MARK: - ShareSheet (UIActivityViewController bridge)

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
