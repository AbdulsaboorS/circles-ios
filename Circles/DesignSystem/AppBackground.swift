import SwiftUI

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var animating = false

    private var bgColor: Color {
        colorScheme == .dark ? Color(hex: "0E0B08") : Color(hex: "F5F0E8")
    }

    private var blobColor: Color {
        colorScheme == .dark ? Color(hex: "1A3A2A") : Color(hex: "EDE0C8")
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                bgColor.ignoresSafeArea()

                // Primary blob — top-left quadrant, large
                Ellipse()
                    .fill(blobColor)
                    .opacity(animating ? 0.6 : 0.45)
                    .frame(
                        width:  geo.size.width  * 0.75,
                        height: geo.size.height * 0.45
                    )
                    .scaleEffect(animating ? 1.08 : 0.94)
                    .blur(radius: 100)
                    .offset(
                        x: -geo.size.width  * 0.20,
                        y: -geo.size.height * 0.20
                    )
                    .animation(
                        .easeInOut(duration: 4).repeatForever(autoreverses: true),
                        value: animating
                    )

                // Secondary blob — bottom-right quadrant, smaller
                Ellipse()
                    .fill(blobColor)
                    .opacity(animating ? 0.50 : 0.35)
                    .frame(
                        width:  geo.size.width  * 0.55,
                        height: geo.size.height * 0.30
                    )
                    .scaleEffect(animating ? 0.95 : 1.10)
                    .blur(radius: 80)
                    .offset(
                        x:  geo.size.width  * 0.25,
                        y:  geo.size.height * 0.25
                    )
                    .animation(
                        .easeInOut(duration: 5).repeatForever(autoreverses: true).delay(1.2),
                        value: animating
                    )
            }
            .onAppear { animating = true }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview("Dark") {
    AppBackground()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    AppBackground()
        .preferredColorScheme(.light)
}
