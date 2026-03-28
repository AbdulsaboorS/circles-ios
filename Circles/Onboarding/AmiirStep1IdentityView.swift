import SwiftUI

struct AmiirStep1IdentityView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AppColors { AppColors.resolve(colorScheme) }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 32) {
                Spacer(minLength: 40)

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.accent.opacity(0.85))

                    Text("Build Your Circle")
                        .font(.appTitle)
                        .foregroundStyle(colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Give your circle its name and set who it's for.")
                        .font(.appSubheadline)
                        .foregroundStyle(colors.textSecondary)
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
                            .foregroundStyle(colors.textSecondary)

                        TextField("e.g. The Fajr Squad", text: $coord.circleName)
                            .textInputAutocapitalization(.words)
                            .font(.appSubheadline)
                            .foregroundStyle(colors.textPrimary)
                            .padding(14)
                            .background(Color.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                            .tint(Color.accent)
                    }

                    // Gender setting
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Circle Setting")
                            .font(.appCaption)
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundStyle(colors.textSecondary)

                        HStack(spacing: 8) {
                            ForEach([("Mixed", "mixed"), ("Brothers", "brothers"), ("Sisters", "sisters")], id: \.1) { label, value in
                                Button {
                                    coordinator.genderSetting = value
                                } label: {
                                    Text(label)
                                        .font(.appCaptionMedium)
                                        .foregroundStyle(coordinator.genderSetting == value ? .white : Color.accent)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(
                                            coordinator.genderSetting == value
                                                ? Color.accent
                                                : Color.accent.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Step indicator
                StepIndicator(current: 0, total: 4)

                PrimaryButton(title: "Continue") {
                    coordinator.proceedToHabits()
                }
                .disabled(coordinator.circleName.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden()
    }
}
