import SwiftUI

/// Animates Niyyah text dissolving into gold particles that drift outward.
/// Sequence: shimmer sweep → text fades → particles drift → completion.
struct NiyyahDissolveView: View {
    let text: String
    let onComplete: () -> Void

    @State private var progress: Double = 0
    @State private var particles: [Particle] = []
    @State private var startTime: Date?

    private let totalDuration: Double = 1.8
    private let shimmerEnd: Double = 0.33    // 0–0.6s as fraction
    private let dissolveEnd: Double = 0.78   // 0.6–1.4s
    // 1.4–1.8s = settle

    private struct Particle: Identifiable {
        let id = UUID()
        let startX: CGFloat
        let startY: CGFloat
        let targetOffsetX: CGFloat
        let targetOffsetY: CGFloat
        let size: CGFloat
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let elapsed = startTime.map { now.timeIntervalSince($0) } ?? 0
            let p = min(elapsed / totalDuration, 1.0)

            Canvas { context, size in
                // Draw particles during dissolve + settle phases
                let dissolveStart: Double = shimmerEnd
                if p > dissolveStart {
                    let particleProgress = min((p - dissolveStart) / (1.0 - dissolveStart), 1.0)
                    let easedProgress = 1.0 - pow(1.0 - particleProgress, 2.0) // easeOut

                    for particle in particles {
                        let x = particle.startX + particle.targetOffsetX * easedProgress
                        let y = particle.startY + particle.targetOffsetY * easedProgress
                        let opacity = max(0, 1.0 - particleProgress * 1.3)
                        let rect = CGRect(
                            x: x - particle.size / 2,
                            y: y - particle.size / 2,
                            width: particle.size,
                            height: particle.size
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(Color(hex: "D4A240").opacity(opacity))
                        )
                    }
                }
            }
            .overlay {
                // Text with shimmer, fading out
                let textOpacity = p < shimmerEnd ? 1.0 : max(0, 1.0 - (p - shimmerEnd) / 0.2)
                let shimmerPhase = p < shimmerEnd ? (p / shimmerEnd) * 2.0 - 0.5 : 1.5
                let textColor = p < shimmerEnd
                    ? Color(hex: "F0EAD6")
                    : Color(hex: "D4A240")

                Text(text)
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .overlay {
                        if p < shimmerEnd + 0.1 {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: shimmerPhase - 0.25),
                                    .init(color: .white.opacity(0.2), location: shimmerPhase),
                                    .init(color: .clear, location: shimmerPhase + 0.25)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .mask {
                                Text(text)
                                    .font(.system(size: 20, weight: .regular, design: .serif))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        }
                    }
                    .opacity(textOpacity)
            }
            .onChange(of: p >= 1.0) { _, done in
                if done { onComplete() }
            }
        }
        .onAppear {
            generateParticles()
            startTime = Date()
        }
    }

    private func generateParticles() {
        var rng = SystemRandomNumberGenerator()
        particles = (0..<40).map { _ in
            let angle = Double.random(in: 0...(2 * .pi), using: &rng)
            let distance = CGFloat.random(in: 60...120, using: &rng)
            return Particle(
                startX: CGFloat.random(in: 80...280, using: &rng),
                startY: CGFloat.random(in: 40...100, using: &rng),
                targetOffsetX: cos(angle) * distance,
                targetOffsetY: sin(angle) * distance,
                size: CGFloat.random(in: 2...4, using: &rng)
            )
        }
    }
}
