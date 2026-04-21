import SwiftUI
import Foundation

/// A tiling 8-pointed star pattern drawn at very low opacity.
/// Used on Niyyah overlay and Spiritual Ledger backgrounds to create
/// a physical, "carved" material feel.
struct IslamicGeometricPattern: View {
    var opacity: Double = 0.025
    var tileSize: CGFloat = 40
    var color: Color = .white

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / tileSize)) + 1
            let rows = Int(ceil(size.height / tileSize)) + 1

            for row in 0..<rows {
                for col in 0..<cols {
                    let center = CGPoint(
                        x: CGFloat(col) * tileSize + tileSize / 2,
                        y: CGFloat(row) * tileSize + tileSize / 2
                    )
                    let s = tileSize * 0.42
                    let rect = CGRect(x: center.x - s / 2, y: center.y - s / 2, width: s, height: s)
                    let starPath = EightPointStar().path(in: rect)
                    context.stroke(
                        starPath,
                        with: .color(color.opacity(opacity)),
                        lineWidth: 0.5
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// Canonical 8-point star geometry shared by `IslamicGeometricPattern` (tiled
/// background) and `StreakBeadView` (rotating bead core). Inner/outer radii 1 : 0.44.
struct EightPointStar: Shape {
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
