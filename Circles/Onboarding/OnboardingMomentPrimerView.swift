import SwiftUI

/// Educational primer for the Moment mechanic. Comes after the AI plan reveal so
/// "your daily Moment is the cue back to your habits" lands as a felt promise.
/// Shows a stylized in-app demo (dual capture + niyyah) instead of describing it.
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
            title: "Once a day. One chance.",
            body: "At a random time each day, your Moment window opens. A few minutes — that's your window to capture it."
        ),
        Beat(
            icon: "arrow.uturn.right.circle.fill",
            title: "Your daily cue back.",
            body: "Since you can't predict when it'll come, the Moment becomes the anchor that pulls you back — to log your habits and stay close to your plan."
        ),
        Beat(
            icon: "eye.slash.fill",
            title: "Only your circle sees it.",
            body: "Private to the few people walking with you. Never public, never on a stranger's feed."
        )
    ]

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            KeyframeAnimator(initialValue: EntryValues(), trigger: entryTrigger) { values in
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            VStack(spacing: 6) {
                                Text("Your daily Moment")
                                    .font(.system(size: 24, weight: .semibold, design: .serif))
                                    .foregroundStyle(Color.msTextPrimary)
                                Text("Here's how it works.")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.msTextMuted)
                            }
                            .opacity(values.headerOpacity)
                            .padding(.top, 8)

                            MomentDemoView()
                                .frame(maxWidth: .infinity)
                                .scaleEffect(values.demoScale)
                                .opacity(values.demoOpacity)

                            VStack(spacing: 22) {
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
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                            .padding(.bottom, 24)
                        }
                    }

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
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .opacity(values.footerOpacity)
                    .background(Color.msBackground)
                }
            } keyframes: { _ in
                // Header fades in immediately
                KeyframeTrack(\.headerOpacity) {
                    CubicKeyframe(1, duration: 0.35)
                }

                // Demo drops in with a soft scale
                KeyframeTrack(\.demoScale) {
                    LinearKeyframe(0.94, duration: 0.1)
                    SpringKeyframe(1.0, duration: 0.55, spring: Spring(duration: 0.55, bounce: 0.22))
                }
                KeyframeTrack(\.demoOpacity) {
                    LinearKeyframe(0, duration: 0.1)
                    CubicKeyframe(1, duration: 0.4)
                }

                // Beats stagger in after the demo settles
                KeyframeTrack(\.beat1Scale) {
                    LinearKeyframe(0.94, duration: 0.55)
                    SpringKeyframe(1.0, duration: 0.4, spring: Spring(duration: 0.4, bounce: 0.24))
                }
                KeyframeTrack(\.beat1Y) {
                    LinearKeyframe(8, duration: 0.55)
                    SpringKeyframe(0, duration: 0.45)
                }
                KeyframeTrack(\.beat1Opacity) {
                    LinearKeyframe(0, duration: 0.55)
                    CubicKeyframe(1, duration: 0.4)
                }

                KeyframeTrack(\.beat2Scale) {
                    LinearKeyframe(0.94, duration: 0.8)
                    SpringKeyframe(1.0, duration: 0.4, spring: Spring(duration: 0.4, bounce: 0.24))
                }
                KeyframeTrack(\.beat2Y) {
                    LinearKeyframe(8, duration: 0.8)
                    SpringKeyframe(0, duration: 0.45)
                }
                KeyframeTrack(\.beat2Opacity) {
                    LinearKeyframe(0, duration: 0.8)
                    CubicKeyframe(1, duration: 0.4)
                }

                KeyframeTrack(\.beat3Scale) {
                    LinearKeyframe(0.94, duration: 1.05)
                    SpringKeyframe(1.0, duration: 0.4, spring: Spring(duration: 0.4, bounce: 0.24))
                }
                KeyframeTrack(\.beat3Y) {
                    LinearKeyframe(8, duration: 1.05)
                    SpringKeyframe(0, duration: 0.45)
                }
                KeyframeTrack(\.beat3Opacity) {
                    LinearKeyframe(0, duration: 1.05)
                    CubicKeyframe(1, duration: 0.4)
                }

                // Footer fades in last
                KeyframeTrack(\.footerOpacity) {
                    LinearKeyframe(0, duration: 1.4)
                    CubicKeyframe(1, duration: 0.35)
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
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color.msGold.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: beat.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.msGold)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(beat.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(beat.body)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.msTextMuted)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Animated Phone-Frame Demo
//
// SwiftUI-only mock of the Moment capture flow — designed as a single component
// so it can be swapped for a real recorded video later (replace the body with
// an AVPlayer driving a looped MP4; the rest of the primer stays identical).
//
// 6-second loop driven by TimelineView. Phases:
//   0.0–2.0s  viewfinder    — countdown pill + dual capture + shutter
//   2.0–2.35s flash         — white overlay, simulating capture
//   2.35–5.0s niyyahTyping  — niyyah text typewrites in below the captured frame
//   5.0–5.7s  posted        — "Posted ✓" pill fades in
//   5.7–6.0s  fadeOut       — content fades, ready to restart

private struct MomentDemoView: View {
    private static let loopSeconds: TimeInterval = 6.0
    private static let niyyahText = "Reading Qur'an after Maghrib, for the creator."

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: Self.loopSeconds)
            phoneFrame(loopT: t)
        }
        .frame(height: 360)
    }

    private func phoneFrame(loopT: TimeInterval) -> some View {
        ZStack {
            // Phone chassis
            RoundedRectangle(cornerRadius: 36)
                .fill(Color.black)
                .frame(width: 196, height: 360)
                .shadow(color: .black.opacity(0.35), radius: 28, x: 0, y: 12)

            // Screen
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.msBackground)
                .frame(width: 184, height: 348)
                .overlay {
                    screenContent(loopT: loopT)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                }
                .overlay(alignment: .top) {
                    // Subtle notch
                    Capsule()
                        .fill(Color.black)
                        .frame(width: 60, height: 16)
                        .padding(.top, 6)
                }
        }
        .accessibilityElement()
        .accessibilityLabel("Animated demo of the Moment capture flow")
    }

    @ViewBuilder
    private func screenContent(loopT: TimeInterval) -> some View {
        let phase = phase(for: loopT)
        let fadeOutAlpha = phase.isFadeOut
            ? max(0, 1 - (loopT - 5.7) / 0.3)
            : 1.0

        ZStack {
            // Warm "maghrib" gradient as the back-camera frame
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.65, blue: 0.32),
                    Color(red: 0.62, green: 0.31, blue: 0.42),
                    Color(red: 0.20, green: 0.15, blue: 0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle scene element — the "what you're doing" cue
            Image(systemName: "book.pages.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white.opacity(0.78))
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)

            // Front camera PIP (top-left)
            VStack {
                HStack {
                    pipFrame
                        .padding(.top, 32)
                        .padding(.leading, 14)
                    Spacer()
                }
                Spacer()
            }

            // Top countdown pill
            VStack {
                countdownPill
                    .padding(.top, 32)
                    .opacity(phase == .viewfinder ? 1 : 0)
                Spacer()
            }

            // Bottom: shutter OR niyyah box OR posted pill
            VStack {
                Spacer()
                bottomLayer(phase: phase, loopT: loopT)
                    .padding(.bottom, 18)
            }

            // Flash overlay
            Color.white
                .opacity(phase == .flash ? 0.92 : 0)
                .animation(.easeOut(duration: 0.18), value: phase == .flash)
        }
        .opacity(fadeOutAlpha)
    }

    private var pipFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.30, green: 0.36, blue: 0.48),
                            Color(red: 0.18, green: 0.22, blue: 0.32)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 44, height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )

            Image(systemName: "person.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.white.opacity(0.78))
                .offset(y: -2)
        }
    }

    private var countdownPill: some View {
        VStack(spacing: 1) {
            Text("Moment Window")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            Text("04:32")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.msGold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func bottomLayer(phase: DemoPhase, loopT: TimeInterval) -> some View {
        switch phase {
        case .viewfinder, .flash:
            shutterButton
        case .niyyahTyping, .posted, .fadeOut:
            niyyahCard(typedTextProgress: niyyahProgress(loopT: loopT),
                       showPosted: phase == .posted || phase == .fadeOut)
        }
    }

    private var shutterButton: some View {
        ZStack {
            SwiftUI.Circle()
                .fill(.white)
                .frame(width: 50, height: 50)
            SwiftUI.Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 60, height: 60)
        }
    }

    private func niyyahCard(typedTextProgress: Double, showPosted: Bool) -> some View {
        let chars = Self.niyyahText.count
        let endIndex = max(0, min(chars, Int(Double(chars) * typedTextProgress)))
        let typed = String(Self.niyyahText.prefix(endIndex))

        return VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.msGold)
                    .padding(.top, 2)

                Text(typed.isEmpty ? " " : typed)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.msGold.opacity(0.4), lineWidth: 0.8)
                    )
            )

            if showPosted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Posted")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Color.msGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
                .environment(\.colorScheme, .dark)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .animation(.easeOut(duration: 0.25), value: showPosted)
    }

    // MARK: Phase helpers

    private enum DemoPhase {
        case viewfinder, flash, niyyahTyping, posted, fadeOut

        var isFadeOut: Bool { self == .fadeOut }
    }

    private func phase(for t: TimeInterval) -> DemoPhase {
        switch t {
        case ..<2.0:    return .viewfinder
        case ..<2.35:   return .flash
        case ..<5.0:    return .niyyahTyping
        case ..<5.7:    return .posted
        default:        return .fadeOut
        }
    }

    private func niyyahProgress(loopT: TimeInterval) -> Double {
        let start: TimeInterval = 2.5
        let end: TimeInterval = 4.8
        if loopT < start { return 0 }
        if loopT >= end { return 1 }
        return (loopT - start) / (end - start)
    }
}

// MARK: - Entry choreography values

private struct EntryValues {
    var headerOpacity: Double = 0

    var demoScale: CGFloat = 0.94
    var demoOpacity: Double = 0

    var beat1Scale: CGFloat = 0.94
    var beat1Y: CGFloat = 8
    var beat1Opacity: Double = 0

    var beat2Scale: CGFloat = 0.94
    var beat2Y: CGFloat = 8
    var beat2Opacity: Double = 0

    var beat3Scale: CGFloat = 0.94
    var beat3Y: CGFloat = 8
    var beat3Opacity: Double = 0

    var footerOpacity: Double = 0
}
