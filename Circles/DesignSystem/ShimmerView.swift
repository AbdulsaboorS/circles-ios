import SwiftUI

/// A shimmering placeholder used during loading states.
struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.06), location: 0),
                    .init(color: Color.white.opacity(0.14), location: 0.4),
                    .init(color: Color.white.opacity(0.06), location: 0.8)
                ],
                startPoint: UnitPoint(x: phase, y: 0),
                endPoint: UnitPoint(x: phase + 1, y: 0)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4).repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
        }
        .background(Color.white.opacity(0.05))
    }
}
