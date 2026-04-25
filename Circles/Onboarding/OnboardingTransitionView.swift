import SwiftUI

/// Shared transition quotes used between onboarding steps.
enum OnboardingTransitionQuote {
    static let amirSharedToPrivate = "A believer to another believer is like a building — each part supporting the other."
    static let amirPrivateToAI = "Some growth is shared; some is between you and your Creator."
    static let joinerSharedToPrivate = "Shared growth is powerful, but some habits are just for you and Allah."
}

struct OnboardingTransitionView: View {
    let quote: String
    let attribution: String?
    var subtitle: String? = nil
    let onSkip: () -> Void

    @State private var entryTrigger: Bool = false
    @State private var breathingScale: CGFloat = 1.0
    @State private var stars: [TransitionStar] = (0..<14).map { _ in TransitionStar.random() }

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            TransitionStarfieldView(stars: stars)
                .ignoresSafeArea()
                .opacity(0.55)

            KeyframeAnimator(initialValue: EntryValues(), trigger: entryTrigger) { values in
                VStack(spacing: 20) {
                    ZStack {
                        SwiftUI.Circle()
                            .fill(Color.msGold.opacity(0.20))
                            .frame(width: 140, height: 140)
                            .blur(radius: 36)
                            .scaleEffect(values.entryGlowScale * breathingScale)

                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.msGold.opacity(0.75))
                            .symbolEffect(.pulse, options: .repeating)
                            .scaleEffect(values.iconScale)
                    }
                    .opacity(values.iconOpacity)

                    Text(quote)
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 36)
                        .offset(y: values.quoteY)
                        .opacity(values.quoteOpacity)

                    if let attribution {
                        Text(attribution)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                            .offset(y: values.quoteY)
                            .opacity(values.quoteOpacity)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                            .padding(.top, 4)
                            .offset(y: values.subtitleY)
                            .opacity(values.subtitleOpacity)
                    }

                    Text("Tap to continue")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.msTextMuted.opacity(0.6))
                        .padding(.top, 12)
                        .opacity(values.hintOpacity)
                }
            } keyframes: { _ in
                KeyframeTrack(\.iconScale) {
                    SpringKeyframe(1.05, duration: 0.45, spring: Spring(duration: 0.45, bounce: 0.35))
                    SpringKeyframe(1.0, duration: 0.3)
                }
                KeyframeTrack(\.iconOpacity) {
                    CubicKeyframe(1.0, duration: 0.5)
                }
                KeyframeTrack(\.entryGlowScale) {
                    CubicKeyframe(1.3, duration: 0.5)
                    CubicKeyframe(1.0, duration: 0.5)
                }
                KeyframeTrack(\.quoteY) {
                    LinearKeyframe(8, duration: 0.35)
                    SpringKeyframe(0, duration: 0.55)
                }
                KeyframeTrack(\.quoteOpacity) {
                    LinearKeyframe(0, duration: 0.35)
                    CubicKeyframe(1, duration: 0.55)
                }
                KeyframeTrack(\.subtitleY) {
                    LinearKeyframe(4, duration: 0.6)
                    SpringKeyframe(0, duration: 0.5)
                }
                KeyframeTrack(\.subtitleOpacity) {
                    LinearKeyframe(0, duration: 0.6)
                    CubicKeyframe(1, duration: 0.5)
                }
                KeyframeTrack(\.hintOpacity) {
                    LinearKeyframe(0, duration: 0.95)
                    CubicKeyframe(1, duration: 0.4)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSkip()
        }
        .onAppear {
            entryTrigger.toggle()
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(0.9)) {
                breathingScale = 1.15
            }
        }
        .navigationBarBackButtonHidden()
    }
}

// MARK: - Entry choreography values

private struct EntryValues {
    var iconScale: CGFloat = 0.85
    var iconOpacity: Double = 0
    var entryGlowScale: CGFloat = 1.0
    var quoteY: CGFloat = 8
    var quoteOpacity: Double = 0
    var subtitleY: CGFloat = 4
    var subtitleOpacity: Double = 0
    var hintOpacity: Double = 0
}

// MARK: - Starfield

private struct TransitionStar {
    let x: Double                // 0-1 of width
    let y: Double                // 0-1 of height
    let baseOpacity: Double
    let opacityFreq: Double      // rad/sec
    let opacityPhase: Double
    let driftFreq: Double        // rad/sec
    let driftPhase: Double
    let driftAmplitude: Double   // px
    let radius: Double

    static func random() -> TransitionStar {
        TransitionStar(
            x: .random(in: 0.05...0.95),
            y: .random(in: 0.05...0.95),
            baseOpacity: .random(in: 0.25...0.55),
            opacityFreq: .random(in: 0.4...0.9),
            opacityPhase: .random(in: 0...(2 * .pi)),
            driftFreq: .random(in: 0.15...0.35),
            driftPhase: .random(in: 0...(2 * .pi)),
            driftAmplitude: .random(in: 4...10),
            radius: .random(in: 1.0...2.0)
        )
    }
}

private struct TransitionStarfieldView: View {
    let stars: [TransitionStar]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for star in stars {
                    let opacity = max(0, min(1, star.baseOpacity + sin(t * star.opacityFreq + star.opacityPhase) * 0.25))
                    let drift = sin(t * star.driftFreq + star.driftPhase) * star.driftAmplitude
                    let cx = star.x * size.width
                    let cy = star.y * size.height + drift
                    let rect = CGRect(
                        x: cx - star.radius,
                        y: cy - star.radius,
                        width: star.radius * 2,
                        height: star.radius * 2
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(Color.msGold.opacity(opacity)))
                }
            }
        }
    }
}
