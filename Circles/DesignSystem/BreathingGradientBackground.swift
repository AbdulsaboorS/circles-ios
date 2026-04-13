import SwiftUI

struct BreathingGradientBackground: View {
    let circleName: String

    @State private var breathing = false

    private var colors: [Color] {
        CircleColorDeriver.gradient(for: circleName)
    }

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .opacity(breathing ? 1.0 : 0.85)
        .animation(
            .easeInOut(duration: 4).repeatForever(autoreverses: true),
            value: breathing
        )
        .ignoresSafeArea()
        .onAppear { breathing = true }
    }
}
