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

    @State private var iconOpacity: Double = 0
    @State private var quoteOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var hintOpacity: Double = 0
    @State private var glowScale: CGFloat = 1.0
    @State private var stars: [TransitionStar] = (0..<14).map { _ in TransitionStar.random() }

    var body: some View {
        ZStack {
            Color.msBackground.ignoresSafeArea()

            TransitionStarfieldView(stars: stars)
                .ignoresSafeArea()
                .opacity(0.55)

            VStack(spacing: 20) {
                ZStack {
                    SwiftUI.Circle()
                        .fill(Color.msGold.opacity(0.20))
                        .frame(width: 140, height: 140)
                        .blur(radius: 36)
                        .scaleEffect(glowScale)

                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.msGold.opacity(0.75))
                        .symbolEffect(.pulse, options: .repeating)
                }
                .opacity(iconOpacity)

                Text(quote)
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(Color.msTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 36)
                    .opacity(quoteOpacity)

                if let attribution {
                    Text(attribution)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                        .opacity(quoteOpacity)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                        .padding(.top, 4)
                        .opacity(subtitleOpacity)
                }

                Text("Tap to continue")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.msTextMuted.opacity(0.6))
                    .padding(.top, 12)
                    .opacity(hintOpacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSkip()
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) { iconOpacity = 1 }
            withAnimation(.easeIn(duration: 0.5).delay(0.3)) { quoteOpacity = 1 }
            withAnimation(.easeIn(duration: 0.5).delay(0.6)) { subtitleOpacity = 1 }
            withAnimation(.easeIn(duration: 0.5).delay(1.0)) { hintOpacity = 1 }

            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                glowScale = 1.15
            }
        }
        .navigationBarBackButtonHidden()
    }
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
