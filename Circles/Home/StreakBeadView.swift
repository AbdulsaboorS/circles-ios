import SwiftUI

/// The "Noor Bead" — a single luminous gold bead that replaces the legacy
/// `heartSection` centerpiece. Scales on two axes:
///
/// 1. **Streak tier** (via `StreakMilestone.tier(for:)`) drives bead diameter,
///    gradient saturation, aura radius, and sparkle count.
/// 2. **Today's completion** (`todayComplete`) drives aura opacity — dim when
///    incomplete, full when the user has checked off every habit.
///
/// `igniteTrigger` is an incrementing counter so the parent view can fire a
/// brief ignite burst (scale 1.08 → 1.0 + transient sparkle flash) without
/// owning any of the bead's internal animation state.
struct StreakBeadView: View {
    let streakDays: Int
    let todayComplete: Bool
    let igniteTrigger: Int

    private var tier: StreakMilestone { StreakMilestone.tier(for: streakDays) }
    private var diameter: CGFloat { StreakMilestone.beadDiameter(forDays: streakDays) }
    private var isLapsed: Bool { tier == .lapsed }

    @State private var breathScale: CGFloat = 1.0
    @State private var igniteScale: CGFloat = 1.0
    @State private var igniteBurstActive: Bool = false
    @State private var auraPulse: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        ZStack {
            auraLayer
            sphereLayer
            starCore
            sparkleLayer
            if isLapsed { crackedOverlay }
        }
        .frame(width: diameter * 2.4, height: diameter * 2.4)
        .scaleEffect(breathScale * igniteScale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streakDays) day streak, \(tier.caption)")
        .onAppear {
            startBreathing()
            startAuraPulse()
        }
        .onChange(of: igniteTrigger) { _, _ in
            guard todayComplete else { return }
            fireIgniteBurst()
        }
    }

    // MARK: - Layers

    private var auraLayer: some View {
        let multiplier: Double = todayComplete ? 1.0 : 0.6
        return ZStack {
            SwiftUI.Circle()
                .fill(Color.msGold.opacity(isLapsed ? 0.06 : 0.18 * multiplier * auraPulse))
                .frame(width: tier.auraRadius * 1.8, height: tier.auraRadius * 1.8)
                .blur(radius: 36)

            SwiftUI.Circle()
                .stroke(Color.msGold.opacity(isLapsed ? 0.10 : 0.42 * multiplier * auraPulse), lineWidth: 1)
                .frame(width: diameter * 1.55, height: diameter * 1.55)
                .blur(radius: isLapsed ? 0 : 2)

            SwiftUI.Circle()
                .stroke(Color.msGold.opacity(isLapsed ? 0.05 : 0.20 * multiplier * auraPulse), lineWidth: 2)
                .frame(width: diameter * 1.90, height: diameter * 1.90)
                .blur(radius: isLapsed ? 0 : 6)
        }
        .animation(.easeInOut(duration: 0.6), value: todayComplete)
    }

    private var sphereLayer: some View {
        SwiftUI.Circle()
            .fill(sphereGradient)
            .frame(width: diameter, height: diameter)
            .shadow(color: Color.msGold.opacity(isLapsed ? 0.08 : 0.55 * (todayComplete ? 1.0 : 0.55)),
                    radius: 22, x: 0, y: 8)
            .shadow(color: Color.msGold.opacity(isLapsed ? 0.03 : 0.28),
                    radius: 8, x: 0, y: 2)
            .overlay(
                SwiftUI.Circle()
                    .stroke(Color(hex: "F0EAD6").opacity(isLapsed ? 0.06 : 0.14),
                            lineWidth: 0.75)
            )
    }

    private var sphereGradient: RadialGradient {
        let sat = tier.gradientSaturation
        let highlight = Color(hex: "E8B84F").opacity(0.55 + 0.45 * sat)
        let mid       = Color(hex: "D4A240").opacity(0.55 + 0.45 * sat)
        let deep      = Color(hex: "8B6A28").opacity(0.65 + 0.35 * sat)
        return RadialGradient(
            colors: [highlight, mid, deep],
            center: UnitPoint(x: 0.33, y: 0.28),
            startRadius: 0,
            endRadius: diameter * 0.58
        )
    }

    private var starCore: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { ctx in
            let seconds = ctx.date.timeIntervalSinceReferenceDate
            let angle = reduceMotion ? 0 : seconds * (360.0 / 600.0) // 360° over 600s
            EightPointStar()
                .fill(Color(hex: "F0EAD6").opacity(isLapsed ? 0.25 : 0.82))
                .frame(width: diameter * 0.46, height: diameter * 0.46)
                .rotationEffect(.degrees(angle))
                .shadow(color: Color(hex: "F0EAD6").opacity(isLapsed ? 0 : 0.35), radius: 3)
        }
    }

    @ViewBuilder
    private var sparkleLayer: some View {
        if tier.sparkleCount > 0 && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1 / 24)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let orbit  = diameter * 0.85
                    let baseCount = tier.sparkleCount
                    let extra = igniteBurstActive ? baseCount : 0
                    let total = baseCount + extra

                    for i in 0..<total {
                        // Deterministic per-sparkle seed keeps positions from jittering.
                        let seed = Double(i) * 1.618 + Double(streakDays) * 0.7
                        let speed = 0.18 + fmod(seed * 0.37, 0.20)
                        let angle = fmod(t * speed + seed, .pi * 2)
                        let radial = orbit * (0.78 + 0.18 * Foundation.sin(t * 0.7 + seed))
                        let pt = CGPoint(
                            x: center.x + CGFloat(Foundation.cos(angle)) * radial,
                            y: center.y + CGFloat(Foundation.sin(angle)) * radial
                        )
                        let twinkle = 0.35 + 0.45 * abs(Foundation.sin(t * 2.1 + seed))
                        let boost = i >= baseCount ? 1.4 : 1.0
                        let size: CGFloat = 2.0 * boost
                        let rect = CGRect(x: pt.x - size / 2, y: pt.y - size / 2,
                                          width: size, height: size)
                        context.fill(Path(ellipseIn: rect),
                                     with: .color(Color.msGold.opacity(twinkle * (todayComplete ? 1.0 : 0.6))))
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private var crackedOverlay: some View {
        // Subtle hairline fracture across the ashen bead — no animation.
        Path { p in
            p.move(to: CGPoint(x: -diameter * 0.32, y: -diameter * 0.10))
            p.addLine(to: CGPoint(x:  diameter * 0.06, y:  diameter * 0.02))
            p.addLine(to: CGPoint(x: -diameter * 0.02, y:  diameter * 0.18))
            p.addLine(to: CGPoint(x:  diameter * 0.28, y:  diameter * 0.30))
        }
        .stroke(Color.black.opacity(0.18), lineWidth: 1)
        .frame(width: diameter, height: diameter)
        .offset(x: diameter * 0.32, y: diameter * 0.32)
        .clipShape(SwiftUI.Circle().offset(x: -diameter * 0.32, y: -diameter * 0.32))
    }

    // MARK: - Animations

    private func startBreathing() {
        guard !reduceMotion, !isLapsed else { return }
        breathScale = 0.97
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            breathScale = 1.03
        }
    }

    private func startAuraPulse() {
        guard !reduceMotion, !isLapsed else { return }
        auraPulse = 0.8
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            auraPulse = 1.0
        }
    }

    private func fireIgniteBurst() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.55)) {
            igniteScale = 1.08
        }
        igniteBurstActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            withAnimation(.easeOut(duration: 0.32)) {
                igniteScale = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) {
            igniteBurstActive = false
        }
    }
}

// MARK: - 8-point star shape

/// 8-point star that mirrors the geometry of
/// `IslamicGeometricPattern.starPath` (inner/outer radii at 1 : ~0.44),
/// but packaged as a `Shape` so it participates in SwiftUI layout.
private struct EightPointStar: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * 0.44
        var path = Path()
        for i in 0..<16 {
            let angle = Double(i) * .pi / 8 - .pi / 2
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let pt = CGPoint(
                x: center.x + r * CGFloat(Foundation.cos(angle)),
                y: center.y + r * CGFloat(Foundation.sin(angle))
            )
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}
