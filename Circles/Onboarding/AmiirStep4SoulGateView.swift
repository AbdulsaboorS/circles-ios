import SwiftUI
import Supabase

struct AmiirStep4SoulGateView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator
    @Environment(AuthManager.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    @State private var showShareSheet = false

    private var colors: AppColors { AppColors.resolve(colorScheme) }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                // Icon + heading
                VStack(spacing: 16) {
                    ZStack {
                        SwiftUI.Circle()
                            .fill(Color.accent.opacity(0.12))
                            .frame(width: 96, height: 96)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 42))
                            .foregroundStyle(Color.accent)
                    }

                    Text("Your circle needs a soul.")
                        .font(.appTitle)
                        .foregroundStyle(colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Invite 2-3 friends to bring your circle to life.\nYour AI roadmap is being prepared in the background.")
                        .font(.appSubheadline)
                        .foregroundStyle(colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                Spacer()

                // Circle info card
                if let circle = coordinator.createdCircle {
                    AppCard {
                        HStack(spacing: 14) {
                            ZStack {
                                SwiftUI.Circle()
                                    .fill(Color.accent.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.accent)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(circle.name)
                                    .font(.appSubheadline)
                                    .foregroundStyle(colors.textPrimary)
                                Text("Invite code: \(circle.inviteCode ?? "")")
                                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                                    .foregroundStyle(colors.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(14)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Share button
                Button {
                    coordinator.hasSharedInvite = true
                    showShareSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Share Invite Link")
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "1A3A2A"))
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "1A3A2A").opacity(0.25), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(url: coordinator.inviteURL)
                        .presentationDetents([.medium, .large])
                }

                // Begin button (unlocked after share initiated)
                Button {
                    if let userId = auth.session?.user.id {
                        coordinator.completeOnboarding(userId: userId)
                    }
                } label: {
                    Text(coordinator.hasSharedInvite ? "Begin My Journey" : "Share first to continue")
                        .font(.appSubheadline)
                        .foregroundStyle(coordinator.hasSharedInvite ? Color.accent : colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(coordinator.hasSharedInvite ? Color.accent : colors.textSecondary.opacity(0.3), lineWidth: 1.5)
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
