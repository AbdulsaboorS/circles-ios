import SwiftUI

/// Brief "الحمد لله" swell shown on top of a habit row the moment the user
/// checks it off (incomplete → complete). Self-contained animation:
/// fade-in 180ms, hold 900ms, fade-out 420ms (~1.5s total).
///
/// Mount via `.overlay { if celebrating { HamdulillahOverlay() } }` and
/// unmount after ~1.5s. The overlay intentionally ignores interaction so
/// the underlying row stays tappable (undo still works immediately).
struct HamdulillahOverlay: View {
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.92

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("الحمد لله")
            .font(.system(size: 24, weight: .regular, design: .serif))
            .foregroundStyle(Color.msGold)
            .shadow(color: Color.msGold.opacity(0.45), radius: 8)
            .opacity(opacity)
            .scaleEffect(scale)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear(perform: animate)
    }

    private func animate() {
        guard !reduceMotion else {
            opacity = 1
            return
        }
        withAnimation(.easeOut(duration: 0.18)) {
            opacity = 1
            scale = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18 + 0.90) {
            withAnimation(.easeIn(duration: 0.42)) {
                opacity = 0
                scale = 1.02
            }
        }
    }
}
