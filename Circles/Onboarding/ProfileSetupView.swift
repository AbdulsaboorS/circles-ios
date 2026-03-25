import SwiftUI

struct ProfileSetupView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var nameText = ""
    @State private var selectedGender = ""

    var canProceed: Bool {
        !nameText.trimmingCharacters(in: .whitespaces).isEmpty && !selectedGender.isEmpty
    }

    var body: some View {
        ZStack {
            Color(hex: "0D1021").ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 8) {
                            Text("Welcome to Circles")
                                .font(.title.bold())
                                .foregroundStyle(.white)
                            Text("Let's get to know you")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .padding(.top, 48)

                        // Name field
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your name")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .textCase(.uppercase)

                            TextField("", text: $nameText, prompt: Text("e.g. Abdullah").foregroundStyle(.white.opacity(0.3)))
                                .font(.body)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 24)

                        // Gender selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("I am a")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .textCase(.uppercase)

                            HStack(spacing: 12) {
                                GenderChip(label: "Brother", isSelected: selectedGender == "Brother") {
                                    selectedGender = "Brother"
                                }
                                GenderChip(label: "Sister", isSelected: selectedGender == "Sister") {
                                    selectedGender = "Sister"
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: 40)
                    }
                }

                Button {
                    coordinator.fullName = nameText.trimmingCharacters(in: .whitespaces)
                    coordinator.gender = selectedGender
                    coordinator.proceedToHabits()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canProceed ? Color(hex: "E8834B") : Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canProceed)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden()
    }
}

private struct GenderChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.body.weight(.medium))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isSelected ? Color(hex: "E8834B") : Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
