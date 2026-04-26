import SwiftUI

struct AmiirStep1IdentityView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator

    private var continueDisabled: Bool {
        coordinator.preferredName.trimmingCharacters(in: .whitespaces).isEmpty ||
        coordinator.circleName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 24)

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

                            // Your name
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Your Name")
                                    .font(.appCaption)
                                    .textCase(.uppercase)
                                    .tracking(0.6)
                                    .foregroundStyle(Color.msTextMuted)

                                TextField("e.g. Omar", text: $coord.preferredName)
                                    .textInputAutocapitalization(.words)
                                    .font(.appSubheadline)
                                    .foregroundStyle(Color.msTextPrimary)
                                    .padding(14)
                                    .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.msBorder, lineWidth: 1))
                                    .tint(Color.msGold)
                            }

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

                        Spacer(minLength: 20)
                    }
                }

                VStack(spacing: 16) {
                    StepIndicator(current: 3, total: 8)

                    Button {
                        coordinator.proceedToTransitionToAI()
                    } label: {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.msBackground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.msGold, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(continueDisabled)
                    .opacity(continueDisabled ? 0.45 : 1)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .background(Color.msBackground)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    coordinator.navigationPath.removeLast()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.msGold)
                }
            }
        }
    }
}
