import SwiftUI

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
            Color(hex: "0D1021").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header row: Retake (top-left)
                HStack {
                    Button("Retake") {
                        onRetake()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
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
                    .padding(.horizontal, 16)

                Spacer().frame(height: 16)

                // Caption input
                TextField("Add a caption...", text: $caption)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color(hex: "1A1D35"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
                                .tint(.white)
                        } else {
                            Text("Post Moment")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "E8834B").opacity(isPosting ? 0.5 : 1.0))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isPosting)
                .padding(.horizontal, 16)

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
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
            errorMessage = "Failed to post. Try again."
            isPosting = false
        }
    }
}
