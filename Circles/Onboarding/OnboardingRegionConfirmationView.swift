import SwiftUI

struct AmiirRegionConfirmationView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator

    var body: some View {
        OnboardingRegionConfirmationContent(
            selectedRegion: Binding(
                get: { coordinator.selectedRegion },
                set: { coordinator.selectedRegion = $0 }
            ),
            currentStep: 10,
            totalSteps: 11,
            onContinue: { coordinator.proceedToActivation() },
            onBack: { coordinator.navigationPath.removeLast() }
        )
    }
}

struct JoinerRegionConfirmationView: View {
    @Environment(MemberOnboardingCoordinator.self) private var coordinator

    var body: some View {
        OnboardingRegionConfirmationContent(
            selectedRegion: Binding(
                get: { coordinator.selectedRegion },
                set: { coordinator.selectedRegion = $0 }
            ),
            currentStep: 6,
            totalSteps: 7,
            onContinue: { coordinator.proceedToAuthGate() },
            onBack: { coordinator.navigationPath.removeLast() }
        )
    }
}

private struct OnboardingRegionConfirmationContent: View {
    @Binding var selectedRegion: MomentRegion
    let currentStep: Int
    let totalSteps: Int
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 28) {
                        Spacer(minLength: 28)

                        VStack(spacing: 12) {
                            Image(systemName: "globe.europe.africa.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.msGold)

                            Text("Your Moment Region")
                                .font(.appTitle)
                                .foregroundStyle(Color.msTextPrimary)
                                .multilineTextAlignment(.center)

                            Text("We've placed you in \(selectedRegion.displayName). Everyone in that region gets the same daily Moment window.")
                                .font(.appSubheadline)
                                .foregroundStyle(Color.msTextMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        VStack(spacing: 10) {
                            ForEach(MomentRegion.allCases) { region in
                                Button {
                                    selectedRegion = region
                                } label: {
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(region.displayName)
                                                .font(.appSubheadline)
                                                .foregroundStyle(Color.msTextPrimary)

                                            Text(region.summary)
                                                .font(.appCaption)
                                                .foregroundStyle(Color.msTextMuted)
                                        }

                                        Spacer()

                                        Image(systemName: selectedRegion == region ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(selectedRegion == region ? Color.msGold : Color.msTextMuted)
                                    }
                                    .padding(16)
                                    .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(selectedRegion == region ? Color.msGold : Color.msBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                VStack(spacing: 16) {
                    StepIndicator(current: currentStep, total: totalSteps)

                    Button(action: onContinue) {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.msBackground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.msGold, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .background(Color.msBackground)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.msGold)
                }
            }
        }
    }
}
