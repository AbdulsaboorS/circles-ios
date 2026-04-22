import SwiftUI

struct AmiirSharedPersonalizationView: View {
    @Environment(AmiirOnboardingCoordinator.self) private var coordinator

    private var canContinue: Bool {
        coordinator.spiritualityLevel != nil &&
        coordinator.timeCommitment != nil &&
        coordinator.heartOfCircle != nil
    }

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 24)

                        VStack(spacing: 12) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.msGold)

                            Text("Shape Your Circle")
                                .font(.appTitle)
                                .foregroundStyle(Color.msTextPrimary)
                                .multilineTextAlignment(.center)

                            Text("Help us understand your circle so we can build the right foundation.")
                                .font(.appSubheadline)
                                .foregroundStyle(Color.msTextMuted)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)

                        PersonalizationSection(
                            question: "Where are you in your faith journey?",
                            options: ["Just starting out", "Building a foundation", "Steady and growing", "Deeply rooted"],
                            selected: Binding(
                                get: { coordinator.spiritualityLevel },
                                set: { coordinator.spiritualityLevel = $0 }
                            )
                        )

                        PersonalizationSection(
                            question: "How much time can you give each day?",
                            options: ["5–10 minutes", "15–30 minutes", "30–60 minutes", "More than an hour"],
                            selected: Binding(
                                get: { coordinator.timeCommitment },
                                set: { coordinator.timeCommitment = $0 }
                            )
                        )

                        PersonalizationSection(
                            question: "What's the heart of your circle?",
                            options: ["Salah, together", "Quran in our lives", "Remembrance of Allah", "Brotherhood through hardship"],
                            selected: Binding(
                                get: { coordinator.heartOfCircle },
                                set: { coordinator.heartOfCircle = $0 }
                            )
                        )

                        Spacer(minLength: 20)
                    }
                }

                VStack(spacing: 16) {
                    StepIndicator(current: 1, total: 7)

                    Button {
                        coordinator.proceedToStruggle()
                    } label: {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.msBackground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.msGold, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.45)
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

// MARK: - PersonalizationSection

private struct PersonalizationSection: View {
    let question: String
    let options: [String]
    @Binding var selected: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.msTextPrimary)
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    PersonalizationChip(
                        label: option,
                        isSelected: selected == option
                    ) {
                        selected = option
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - PersonalizationChip

private struct PersonalizationChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(label)
                    .font(.appSubheadline)
                    .foregroundStyle(isSelected ? Color.msGold : Color.msTextPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.msGold)
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                isSelected ? Color.msGold.opacity(0.1) : Color(hex: "243828"),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color.msGold : Color.msGold.opacity(0.18),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
