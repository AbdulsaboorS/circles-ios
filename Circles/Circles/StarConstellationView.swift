import SwiftUI

/// Each member is a star in a constellation. Stars light up gold when the member
/// has completed their habits. When all stars are lit the constellation pulses.
struct StarConstellationView: View {
    let members: [CircleMember]
    let ringStatus: (UUID) -> CircleDetailViewModel.NoorRingStatus
    let displayName: (CircleMember) -> String
    let avatarUrl: (CircleMember) -> String?
    let intensity: Double  // 0–1 overall completion

    @State private var allLitPulse = false

    private var allDone: Bool { intensity >= 1.0 }

    // Deterministic positions in a circle layout
    private func starPosition(index: Int, total: Int, in size: CGSize) -> CGPoint {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let radius = min(size.width, size.height) * 0.34

        if total == 1 {
            return CGPoint(x: centerX, y: centerY)
        }

        // Offset so first star is at top (–π/2)
        let angle = (2 * .pi / Double(total)) * Double(index) - .pi / 2
        return CGPoint(
            x: centerX + radius * cos(angle),
            y: centerY + radius * sin(angle)
        )
    }

    var body: some View {
        GeometryReader { geo in
            let total = members.count
            let positions = (0..<total).map { starPosition(index: $0, total: total, in: geo.size) }

            ZStack {
                // Connection lines between adjacent stars
                if total > 1 {
                    constellationLines(positions: positions, total: total)
                }

                // Star nodes
                ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                    let status = ringStatus(member.userId)
                    let pos = positions[index]

                    starNode(member: member, status: status)
                        .position(pos)
                }

                // Central glow when all done
                if allDone {
                    SwiftUI.Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.msGold.opacity(0.25), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .scaleEffect(allLitPulse ? 1.08 : 0.92)
                        .animation(
                            .easeInOut(duration: 2).repeatForever(autoreverses: true),
                            value: allLitPulse
                        )
                }
            }
            .onAppear {
                if allDone { allLitPulse = true }
            }
            .onChange(of: allDone) { _, done in
                allLitPulse = done
            }
        }
        .frame(height: 200)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Star Node

    @ViewBuilder
    private func starNode(member: CircleMember, status: CircleDetailViewModel.NoorRingStatus) -> some View {
        let isLit = status == .gold || status == .pulsingGreen
        let isGold = status == .gold

        VStack(spacing: 4) {
            ZStack {
                // Glow behind lit stars
                if isLit {
                    SwiftUI.Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (isGold ? Color.msGold : Color.green).opacity(0.4),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 4,
                                endRadius: 22
                            )
                        )
                        .frame(width: 44, height: 44)
                }

                // Avatar
                AvatarView(
                    avatarUrl: avatarUrl(member),
                    name: displayName(member).isEmpty ? member.userId.uuidString : displayName(member),
                    size: 34
                )
                .overlay(
                    SwiftUI.Circle()
                        .stroke(
                            isGold ? Color.msGold :
                            status == .pulsingGreen ? Color.green :
                            Color.msTextMuted.opacity(0.2),
                            lineWidth: isLit ? 2 : 1
                        )
                )
                .opacity(isLit ? 1.0 : 0.45)
            }

            // First name below
            Text(firstName(member))
                .font(.system(size: 9, weight: isLit ? .semibold : .regular))
                .foregroundStyle(isLit ? Color.msTextPrimary : Color.msTextMuted.opacity(0.5))
                .lineLimit(1)
        }
    }

    // MARK: - Constellation Lines

    private func constellationLines(positions: [CGPoint], total: Int) -> some View {
        Canvas { context, _ in
            for i in 0..<total {
                let from = positions[i]
                let to = positions[(i + 1) % total]
                var path = Path()
                path.move(to: from)
                path.addLine(to: to)
                context.stroke(
                    path,
                    with: .color(Color.msGold.opacity(intensity * 0.25 + 0.08)),
                    lineWidth: 0.8
                )
            }
        }
    }

    // MARK: - Helpers

    private func firstName(_ member: CircleMember) -> String {
        let name = displayName(member)
        return name.components(separatedBy: .whitespaces).first ?? name
    }

    private var accessibilityText: String {
        let lit = members.filter { ringStatus($0.userId) != .dimmed }.count
        return "\(lit) of \(members.count) members have checked in today"
    }
}
