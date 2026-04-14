import SwiftUI

/// Post-capture ritual overlay where the user privately writes their Niyyah (intention).
/// Appears over the photo preview with .ultraThinMaterial frosted glass.
struct NiyyahCaptureOverlay: View {
    @Binding var niyyahText: String
    let onSetNiyyah: () -> Void
    let onSkip: () -> Void

    @FocusState private var isTextFocused: Bool
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Frosted glass background
            RoundedRectangle(cornerRadius: 32)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // Islamic geometric pattern
            IslamicGeometricPattern(opacity: 0.025)
                .clipShape(RoundedRectangle(cornerRadius: 32))

            VStack(spacing: 0) {
                Spacer().frame(height: 48)

                // Prompt
                Text("Align your Niyyah")
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)

                Text("for this act.")
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(Color.msGold)
                    .padding(.bottom, 8)

                Text("Your intention is private — only you will ever see it.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.msTextMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer().frame(height: 32)

                // Niyyah text input
                TextEditor(text: $niyyahText)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($isTextFocused)
                    .frame(minHeight: 80, maxHeight: 140)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.msCardShared.opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.msGold.opacity(0.25), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if niyyahText.isEmpty {
                            Text("e.g. \"To provide for my family\" or \"Seeking peace\"")
                                .font(.system(size: 16, weight: .regular, design: .serif))
                                .foregroundStyle(Color.msTextMuted.opacity(0.6))
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, 24)
                    .tint(Color.msGold)

                Spacer().frame(height: 24)

                // Set Niyyah button
                Button(action: onSetNiyyah) {
                    Text("Set Niyyah")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.msBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            niyyahText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.msGold.opacity(0.4)
                                : Color.msGold
                        )
                        .clipShape(Capsule())
                }
                .disabled(niyyahText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 24)

                Spacer()

                // Skip hint
                Button(action: onSkip) {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .light))
                        Text("Skip")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color.msTextMuted.opacity(0.4))
                }
                .padding(.bottom, 24)
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isTextFocused = true
            }
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.height > 40 {
                        onSkip()
                    }
                }
        )
    }
}
