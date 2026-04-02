import SwiftUI

// MARK: - Midnight Sanctuary tokens

private extension Color {
    static let msBackground  = Color(hex: "1A2E1E")
    static let msCardShared  = Color(hex: "243828")
    static let msGold        = Color(hex: "D4A240")
    static let msTextPrimary = Color(hex: "F0EAD6")
    static let msTextMuted   = Color(hex: "8FAF94")
}

struct MomentPreviewView: View {
    let image: UIImage
    let onPost: (String?) async throws -> Void
    let onRetake: () -> Void
    @State private var caption: String = ""
    @State private var isPosting = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header row: Retake (top-left)
                HStack {
                    Button("Retake") {
                        onRetake()
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.msTextMuted)
                    .accessibilityLabel("Retake photo")

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Composited photo preview
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.msGold.opacity(0.18), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)

                Spacer().frame(height: 16)

                // Caption input
                TextField("Add a caption...", text: $caption)
                    .font(.body)
                    .foregroundStyle(Color.msTextPrimary)
                    .padding(12)
                    .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 10))
                    .tint(Color.msGold)
                    .padding(.horizontal, 16)

                Spacer().frame(height: 16)

                // Post button
                Button {
                    Task {
                        await postMoment()
                    }
                } label: {
                    ZStack {
                        if isPosting {
                            ProgressView()
                                .tint(Color.msBackground)
                        } else {
                            Text("Post Moment")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Color.msBackground)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(isPosting ? Color.msGold.opacity(0.5) : Color.msGold)
                    .clipShape(Capsule())
                }
                .disabled(isPosting)
                .padding(.horizontal, 16)

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Color.red)
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                }

                Spacer().frame(height: 24)
            }
        }
        .interactiveDismissDisabled(isPosting)
    }

    // MARK: - Post Action

    private func postMoment() async {
        isPosting = true
        errorMessage = nil
        do {
            try await onPost(caption.isEmpty ? nil : caption)
            dismiss()
        } catch {
            let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = message.isEmpty ? String(describing: error) : message
            print("[MomentPreviewView] post failed: \(error)")
            isPosting = false
        }
    }
}
