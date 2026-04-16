import SwiftUI

/// Wraps any content (typically an avatar) with a layered golden glow ring
/// whose intensity scales with the user's current streak.
struct NoorRingView<Content: View>: View {
    let currentStreak: Int
    let size: CGFloat
    @ViewBuilder let content: () -> Content

    private var glowOpacity: Double {
        switch currentStreak {
        case 0:       return 0.30
        case 1...6:   return 0.50
        case 7...29:  return 0.80
        default:      return 1.0
        }
    }

    private var blurRadius: CGFloat {
        switch currentStreak {
        case 0:       return 4
        case 1...6:   return 8
        case 7...29:  return 12
        default:      return 18
        }
    }

    var body: some View {
        content()
            .frame(width: size, height: size)
            // Inner subtle ring
            .overlay(
                SwiftUI.Circle()
                    .stroke(Color.msGold.opacity(glowOpacity * 0.3), lineWidth: 1)
                    .padding(-3)
            )
            // Middle solid ring
            .overlay(
                SwiftUI.Circle()
                    .stroke(Color.msGold.opacity(glowOpacity), lineWidth: 2.5)
                    .padding(-6)
            )
            // Outer glow ring
            .overlay(
                SwiftUI.Circle()
                    .stroke(Color.msGold.opacity(glowOpacity * 0.4), lineWidth: 3)
                    .shadow(color: Color.msGold.opacity(glowOpacity * 0.6), radius: blurRadius)
                    .padding(-10)
            )
    }
}
