import SwiftUI

// MARK: - Midnight Sanctuary tokens

private extension Color {
    static let msBackground   = Color(hex: "1A2E1E")
    static let msCardShared   = Color(hex: "243828")
    static let msGold         = Color(hex: "D4A240")
    static let msTextPrimary  = Color(hex: "F0EAD6")
    static let msTextMuted    = Color(hex: "8FAF94")
    static let msBorder       = Color(hex: "D4A240").opacity(0.18)
}

struct AmiirStep1IdentityView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer(minLength: 40)

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.msGold)

                    Text("Build Your Circle")
                        .font(.appTitle)
                        .foregroundStyle(Color.msTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Give your circle its name and set who it's for.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                // Fields
                VStack(spacing: 20) {
                    @Bindable var coord = coordinator

                    // Circle name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Circle Name")
                            .font(.appCaption)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundStyle(Color.msTextMuted)

                        TextField("e.g. The Fajr Squad", text: $coord.circleName)
                            .textInputAutocapitalization(.words)
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextPrimary)
                            .padding(14)
                            .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.msBorder, lineWidth: 1))
                            .tint(Color.msGold)
                    }

                    // Gender setting
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Circle Setting")
                            .font(.appCaption)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundStyle(Color.msTextMuted)

                        HStack(spacing: 8) {
                            ForEach([("Mixed", "mixed"), ("Brothers", "brothers"), ("Sisters", "sisters")], id: \.1) { label, value in
                                Button {
                                    coordinator.genderSetting = value
                                } label: {
                                    Text(label)
                                        .font(.appCaptionMedium)
                                        .foregroundStyle(coordinator.genderSetting == value ? Color.msBackground : Color.msGold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(
                                            coordinator.genderSetting == value
                                                ? Color.msGold
                                                : Color.msCardShared,
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(coordinator.genderSetting == value ? Color.clear : Color.msBorder, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Step indicator + CTA
                StepIndicator(current: 0, total: 4)

                Button {
                    coordinator.proceedToHabits()
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.msBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.msGold, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(coordinator.circleName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(coordinator.circleName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden()
    }
}
