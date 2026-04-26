import SwiftUI

/// Educational primer for the Moment mechanic. Triggers the camera permission
/// prompt in a low-pressure pre-auth context and demonstrates the BeReal-style
/// window before the user commits to auth + their 28-day plan.
///
/// Used by both Amir and Joiner onboarding flows. The host coordinator owns
/// step indicator numbers and the post-tap navigation.
struct OnboardingMomentPrimerView: View {
    let currentStep: Int
    let totalSteps: Int
    let onContinue: () -> Void

    @State private var entryTrigger = false
    @State private var isRequesting = false

    private let beats: [Beat] = [
        Beat(
            icon: "clock.badge.fill",
            title: "A short window each day.",
            body: "Once a day, near a prayer time, you'll get one chance to capture your Moment."
        ),
        Beat(
            icon: "camera.rotate.fill",
            title: "Both cameras. No filters. No retakes.",
            body: "Front and back at once. What you're doing, exactly when it happens."
        ),
        Beat(
            icon: "eye.slash.fill",
            title: "Only your circle sees it.",
            body: "Private to the people walking with you. Never public."
        )
    ]

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            KeyframeAnimator(initialValue: EntryValues(), trigger: entryTrigger) { values in
                VStack(spacing: 0) {
                    Spacer(minLength: 12)

                    VStack(spacing: 28) {
                        BeatRow(beat: beats[0])
                            .scaleEffect(values.beat1Scale)
                            .offset(y: values.beat1Y)
                            .opacity(values.beat1Opacity)

                        BeatRow(beat: beats[1])
                            .scaleEffect(values.beat2Scale)
                            .offset(y: values.beat2Y)
                            .opacity(values.beat2Opacity)

                        BeatRow(beat: beats[2])
                            .scaleEffect(values.beat3Scale)
                            .offset(y: values.beat3Y)
                            .opacity(values.beat3Opacity)
                    }
                    .padding(.horizontal, 28)

                    Spacer(minLength: 24)

                    VStack(spacing: 14) {
                        Button {
                            requestCameraThenContinue()
                        } label: {
                            Text(isRequesting ? "Requesting..." : "Allow Camera")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.msBackground)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.msGold, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isRequesting)

                        Button {
                            onContinue()
                        } label: {
                            Text("Maybe later")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.msTextMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRequesting)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)
                    .opacity(values.footerOpacity)
                }
            } keyframes: { _ in
                // Beat 1
                KeyframeTrack(\.beat1Scale) {
                    SpringKeyframe(1.04, duration: 0.45, spring: Spring(duration: 0.45, bounce: 0.32))
                    SpringKeyframe(1.0, duration: 0.3)
                }
                KeyframeTrack(\.beat1Y) {
                    LinearKeyframe(8, duration: 0.0)
                    SpringKeyframe(0, duration: 0.55)
                }
                KeyframeTrack(\.beat1Opacity) {
                    CubicKeyframe(1, duration: 0.5)
                }

                // Beat 2 — staggered ~0.35s after beat 1
                KeyframeTrack(\.beat2Scale) {
                    LinearKeyframe(0.92, duration: 0.35)
                    SpringKeyframe(1.04, duration: 0.45, spring: Spring(duration: 0.45, bounce: 0.32))
                    SpringKeyframe(1.0, duration: 0.3)
                }
                KeyframeTrack(\.beat2Y) {
                    LinearKeyframe(8, duration: 0.35)
                    SpringKeyframe(0, duration: 0.55)
                }
                KeyframeTrack(\.beat2Opacity) {
                    LinearKeyframe(0, duration: 0.35)
                    CubicKeyframe(1, duration: 0.5)
                }

                // Beat 3 — staggered ~0.7s after beat 1
                KeyframeTrack(\.beat3Scale) {
                    LinearKeyframe(0.92, duration: 0.7)
                    SpringKeyframe(1.04, duration: 0.45, spring: Spring(duration: 0.45, bounce: 0.32))
                    SpringKeyframe(1.0, duration: 0.3)
                }
                KeyframeTrack(\.beat3Y) {
                    LinearKeyframe(8, duration: 0.7)
                    SpringKeyframe(0, duration: 0.55)
                }
                KeyframeTrack(\.beat3Opacity) {
                    LinearKeyframe(0, duration: 0.7)
                    CubicKeyframe(1, duration: 0.5)
                }

                // Footer fades in last
                KeyframeTrack(\.footerOpacity) {
                    LinearKeyframe(0, duration: 1.05)
                    CubicKeyframe(1, duration: 0.4)
                }
            }
        }
        .safeAreaInset(edge: .top) {
            StepIndicator(current: currentStep, total: totalSteps)
                .background(Color.msBackground)
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            entryTrigger.toggle()
        }
    }

    private func requestCameraThenContinue() {
        guard !isRequesting else { return }
        isRequesting = true
        Task {
            _ = await CameraManager.requestVideoAccess()
            await MainActor.run {
                isRequesting = false
                onContinue()
            }
        }
    }
}

// MARK: - Beat

private struct Beat {
    let icon: String
    let title: String
    let body: String
}

private struct BeatRow: View {
    let beat: Beat

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.msGold.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: beat.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.msGold)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(beat.title)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(beat.body)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.msTextMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Entry choreography values

private struct EntryValues {
    var beat1Scale: CGFloat = 0.92
    var beat1Y: CGFloat = 8
    var beat1Opacity: Double = 0

    var beat2Scale: CGFloat = 0.92
    var beat2Y: CGFloat = 8
    var beat2Opacity: Double = 0

    var beat3Scale: CGFloat = 0.92
    var beat3Y: CGFloat = 8
    var beat3Opacity: Double = 0

    var footerOpacity: Double = 0
}
