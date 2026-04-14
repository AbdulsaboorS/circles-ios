import SwiftUI
import Combine

struct MomentDraft: Identifiable {
    let id = UUID()
    let primaryImage: UIImage
    let secondaryImage: UIImage?
}

struct MomentPreviewView: View {
    let primaryImage: UIImage
    let secondaryImage: UIImage?
    let onPost: (String?, Bool, String?) async throws -> Void  // (caption, swapped, niyyahText)
    let onRetake: () -> Void
    let circleCount: Int
    @State private var caption: String = ""
    @State private var isPosting = false
    @State private var swapped = false
    @State private var errorMessage: String?
    @State private var partialErrorMessage: String?
    @State private var windowSecondsRemaining: Int = 0
    @State private var niyyahText: String = ""
    @State private var niyyahPhase: NiyyahPhase = .overlay
    @State private var showNoorAura = false
    @Environment(\.dismiss) private var dismiss

    private enum NiyyahPhase {
        case overlay, dissolving, settled, skipped
    }

    private var mainImage: UIImage { swapped ? (secondaryImage ?? primaryImage) : primaryImage }
    private var pipImage: UIImage? { secondaryImage != nil ? (swapped ? primaryImage : secondaryImage) : nil }

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

                // Photo preview — primary with optional PiP at top-left (tap to swap)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: mainImage)
                        .resizable()
                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(Color.msGold.opacity(0.18), lineWidth: 1)
                        )
                        .overlay {
                            if showNoorAura {
                                NoorAuraOverlay(cornerRadius: 32)
                            }
                        }

                    if let pip = pipImage {
                        Image(uiImage: pip)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.msGold, lineWidth: 2)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) { swapped.toggle() }
                            }
                            .padding(10)
                    }
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 16)

                // Caption + post controls (hidden during niyyah overlay)
                if niyyahPhase == .settled || niyyahPhase == .skipped {
                    captionAndPostSection
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if niyyahPhase == .dissolving {
                    Spacer()
                }

                Spacer().frame(height: 24)
            }

            // Niyyah overlay phase
            if niyyahPhase == .overlay {
                NiyyahCaptureOverlay(
                    niyyahText: $niyyahText,
                    onSetNiyyah: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            niyyahPhase = .dissolving
                        }
                    },
                    onSkip: {
                        niyyahText = ""
                        withAnimation(.easeOut(duration: 0.3)) {
                            niyyahPhase = .skipped
                        }
                    }
                )
                .transition(.opacity)
            }

            // Dissolve animation phase
            if niyyahPhase == .dissolving {
                NiyyahDissolveView(text: niyyahText) {
                    withAnimation(.easeIn(duration: 0.5)) {
                        showNoorAura = true
                        niyyahPhase = .settled
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .interactiveDismissDisabled(isPosting)
        .onAppear { updateWindowCountdown() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            updateWindowCountdown()
        }
    }

    // MARK: - Caption & Post Section

    private var captionAndPostSection: some View {
        VStack(spacing: 0) {
            // Caption input
            TextField("Add a caption...", text: $caption)
                .font(.body)
                .foregroundStyle(Color.msTextPrimary)
                .padding(12)
                .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 10))
                .tint(Color.msGold)
                .padding(.horizontal, 16)

            Spacer().frame(height: 8)

            // Circle disclaimer
            if circleCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.msTextMuted)
                    Text("This will be shared to all your circles (\(circleCount))")
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
            }

            Spacer().frame(height: 8)

            // Window countdown
            if windowSecondsRemaining > 0 {
                let mins = windowSecondsRemaining / 60
                let secs = windowSecondsRemaining % 60
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.msGold)
                    Text(String(format: "%02d:%02d remaining", mins, secs))
                        .font(.appCaption)
                        .foregroundStyle(Color.msGold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                Spacer().frame(height: 8)
            }

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

            if let partial = partialErrorMessage {
                Text(partial)
                    .font(.appCaption)
                    .foregroundStyle(Color.msTextMuted)
                    .padding(.top, 4)
                    .padding(.horizontal, 16)
            }
        }
    }

    private func updateWindowCountdown() {
        guard let start = DailyMomentService.shared.windowStart else {
            windowSecondsRemaining = 0; return
        }
        let windowEnd = start.addingTimeInterval(30 * 60)
        windowSecondsRemaining = max(0, Int(windowEnd.timeIntervalSince(Date())))
    }

    // MARK: - Post Action

    private func postMoment() async {
        isPosting = true
        errorMessage = nil
        let trimmedNiyyah = niyyahText.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await onPost(
                caption.isEmpty ? nil : caption,
                swapped,
                trimmedNiyyah.isEmpty ? nil : trimmedNiyyah
            )
            dismiss()
        } catch {
            // If DB says already posted, sync client state so gate/CTA close
            if case MomentError.alreadyPostedToday = error {
                DailyMomentService.shared.markPostedToday()
            }
            let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = message.isEmpty ? String(describing: error) : message
            print("[MomentPreviewView] post failed: \(error)")
            isPosting = false
        }
    }
}
