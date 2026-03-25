import SwiftUI

// MARK: - AppIconView (D-26, D-27, D-28)

/// Renders a screenshottable Islamic 8-pointed star (rub el hizb) tessellation.
/// Background: #0E0B08 warm near-black. Pattern: #E8834B amber.
///
/// Usage:
///   - Screenshot at size: 1024 for App Store icon export
///   - Preview at smaller sizes for visual testing
struct AppIconView: View {
    var size: CGFloat = 1024

    var body: some View {
        Canvas { context, canvasSize in
            // Fill background
            context.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .color(Color(hex: "0E0B08"))
            )

            let amber = Color(hex: "E8834B")
            let tileSize: CGFloat = canvasSize.width / 4   // 4x4 grid of tiles
            let cols = Int(canvasSize.width  / tileSize) + 1
            let rows = Int(canvasSize.height / tileSize) + 1

            for row in 0..<rows {
                for col in 0..<cols {
                    let cx = CGFloat(col) * tileSize + tileSize / 2
                    let cy = CGFloat(row) * tileSize + tileSize / 2
                    drawEightPointedStar(
                        context: context,
                        center: CGPoint(x: cx, y: cy),
                        radius: tileSize * 0.38,
                        color: amber
                    )
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237)) // Apple icon corner radius
    }

    // MARK: - Star Drawing

    private func drawEightPointedStar(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: Color
    ) {
        // 8-pointed star: outer points at 0°, 45°, 90°... inner points at 22.5°, 67.5°...
        let outerRadius = radius
        let innerRadius = radius * 0.42
        let points = 8
        var path = Path()

        for i in 0..<(points * 2) {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let r = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let x = center.x + r * cos(angle)
            let y = center.y + r * sin(angle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else       { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()

        // Draw filled star
        context.fill(path, with: .color(color))

        // Draw subtle inner circle (decorative dot — dark background punched through)
        let dotRadius = radius * 0.12
        let dotPath = Path(ellipseIn: CGRect(
            x: center.x - dotRadius,
            y: center.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        ))
        context.fill(dotPath, with: .color(Color(hex: "0E0B08")))
    }
}

// MARK: - Previews

#Preview("App Icon 1024") {
    AppIconView(size: 400)
}

#Preview("App Icon 60") {
    AppIconView(size: 60)
}
