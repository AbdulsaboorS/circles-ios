import SwiftUI

private extension Color {
    static let msBackground = Color(hex: "1A2E1E")
    static let msCardShared = Color(hex: "243828")
    static let msGold = Color(hex: "D4A240")
    static let msTextPrimary = Color(hex: "F0EAD6")
    static let msTextMuted = Color(hex: "8FAF94")
    static let msBorder = Color(hex: "D4A240").opacity(0.18)
}

struct AmiirLandingSanctuaryView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator

    @State private var animating = false
    @State private var showLogin = false

    private let orbSymbols = ["moon.stars.fill", "book.fill", "circle.grid.3x3.fill"]

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 56)

                sanctuaryPreview
                    .padding(.horizontal, 28)

                Spacer(minLength: 44)

                VStack(spacing: 16) {
                    Text("A Brotherhood\nforged in Sunnah.")
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Build a private circle. Track prayers together. Hold each other accountable.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        coordinator.proceedToStruggle()
                    } label: {
                        Text("Build My Circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.msBackground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.msGold, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        coordinator.showJoinFlow()
                    } label: {
                        Text("Join with Invite Code")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.msTextMuted)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showLogin = true
                    } label: {
                        Text("Already have an account? Log in")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.msTextMuted.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .sheet(isPresented: $showLogin) {
                    AuthView()
                }
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            animating = true
        }
    }

    private var sanctuaryPreview: some View {
        VStack(spacing: 28) {
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.msCardShared,
                            Color.msBackground.opacity(0.92)
                        ],
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
                                    orb(symbol: symbol, index: index)
                                }
                            }

                            VStack(spacing: 14) {
                                previewRow(title: "Fajr", value: "7 friends steady")
                                previewRow(title: "Quran", value: "2 ayat left tonight")
                                previewRow(title: "Dhikr", value: "Circle still glowing")
                            }
                        }
                        .padding(24)
                    }
                }
                .frame(height: 270)

            HStack(spacing: 10) {
                previewPill(icon: "flame.fill", text: "Group streak rising")
                previewPill(icon: "sparkles", text: "Private by design")
            }
        }
    }

    private func orb(symbol: String, index: Int) -> some View {
        ZStack {
            SwiftUI.Circle()
                .fill(Color.msGold.opacity(animating ? 0.18 : 0.06))
                .frame(width: 74, height: 74)
                .overlay(
                    SwiftUI.Circle()
                        .stroke(Color.msGold.opacity(animating ? 0.45 : 0.14), lineWidth: 1)
                )
                .scaleEffect(animating ? 1.04 : 0.92)
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

    private func previewRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.msTextPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.msTextMuted)
        }
    }

    private func previewPill(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Color.msGold)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.msGold.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(Color.msBorder, lineWidth: 1))
    }
}
