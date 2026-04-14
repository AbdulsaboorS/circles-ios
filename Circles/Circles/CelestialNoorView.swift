import SwiftUI

struct CelestialNoorView: View {
    let intensity: Double   // 0.0 to 1.0
    let accentColor: Color

    @State private var breathing = false

    private var coreOpacity: Double {
        if intensity >= 1.0 { return 1.0 }
        if intensity < 0.5 { return 0.42 + intensity * 0.5 }
        return 0.67 + (intensity - 0.5) * 0.66
    }

    private var haloOpacity: Double {
        if intensity < 0.3 { return 0.18 + intensity * 0.2 }
        return 0.24 + intensity * 0.31
    }

    // Visible ember ring at low completion — fades away as noor ignites
    private var emberRingOpacity: Double {
        max(0, 1.0 - intensity * 2.5)
    }

    private var isIgnited: Bool { intensity >= 1.0 }

    var body: some View {
        ZStack {
            // Ember ring — visible at low intensity, fades as noor fills
            SwiftUI.Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.msGold.opacity(0.55),
                            accentColor.opacity(0.3),
                            Color.msGold.opacity(0.15),
                            accentColor.opacity(0.4),
                            Color.msGold.opacity(0.55)
                        ],
                        center: .center
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 96, height: 96)
                .opacity(emberRingOpacity)
                .scaleEffect(breathing ? 1.04 : 0.96)

            // Outer bloom — only visible at 100%
            if isIgnited {
                SwiftUI.Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.msGold.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .scaleEffect(breathing ? 1.06 : 0.94)
                    .transition(.opacity.animation(.easeInOut(duration: 1.2)))
            }

            // Inner halo
            SwiftUI.Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.msGold.opacity(haloOpacity), accentColor.opacity(haloOpacity * 0.4), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 70
                    )
                )
                .frame(width: 150, height: 150)
                .blur(radius: 22)
                .scaleEffect(breathing ? 1.04 : 0.96)

            // Core orb
            SwiftUI.Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.msGold.opacity(coreOpacity),
                            accentColor.opacity(coreOpacity * 0.6),
                            Color.msGold.opacity(coreOpacity * 0.15),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 44
                    )
                )
                .frame(width: 88, height: 88)
                .scaleEffect(breathing ? 1.03 : 0.97)

            // Glass highlight
            SwiftUI.Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(coreOpacity * 0.25), .clear],
                        center: UnitPoint(x: 0.38, y: 0.32),
                        startRadius: 0,
                        endRadius: 28
                    )
                )
                .frame(width: 88, height: 88)
                .scaleEffect(breathing ? 1.03 : 0.97)
        }
        .frame(height: 200)
        .animation(
            .easeInOut(duration: 3).repeatForever(autoreverses: true),
            value: breathing
        )
        .onAppear { breathing = true }
        .accessibilityLabel("Circle completion: \(Int(intensity * 100)) percent")
    }
}
