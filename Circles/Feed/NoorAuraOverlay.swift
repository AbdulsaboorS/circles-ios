import SwiftUI

/// Soft gold inner-glow overlay for moment photos that have a Niyyah.
/// Candlelight feel — warm and alive, not flashy.
struct NoorAuraOverlay: View {
    var cornerRadius: CGFloat = 32
    @State private var breathing = false

    var body: some View {
        ZStack {
            // Inner glow: stroked + blurred + masked
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.msGold, lineWidth: 6)
                .blur(radius: 8)
                .mask(RoundedRectangle(cornerRadius: cornerRadius))

            // Secondary softer outer ring
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.msGold.opacity(0.15), lineWidth: 2)
                .blur(radius: 3)
                .mask(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .opacity(breathing ? 0.55 : 0.35)
        .animation(
            .easeInOut(duration: 3).repeatForever(autoreverses: true),
            value: breathing
        )
        .onAppear { breathing = true }
        .allowsHitTesting(false)
    }
}
