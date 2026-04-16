import SwiftUI

struct SacredMilestonesSection: View {
    let milestones: [Milestone]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("SACRED MILESTONES")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Color.msTextMuted)

            Text("Commemorations of your journey")
                .font(.system(size: 13, weight: .regular, design: .serif).italic())
                .foregroundStyle(Color.msTextPrimary.opacity(0.6))
                .padding(.top, 3)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(milestones) { milestone in
                        MilestoneBadgeCard(milestone: milestone)
                    }
                }
                .padding(.vertical, 2) // room for shadow
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Badge Card

private struct MilestoneBadgeCard: View {
    let milestone: Milestone

    var body: some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            milestone.isUnlocked ? Color.msGold.opacity(0.35) : Color.msBorder,
                            lineWidth: 1
                        )
                )

            // Geometric pattern background clipped to card
            IslamicGeometricPattern(
                opacity: milestone.isUnlocked ? 0.06 : 0.02,
                tileSize: 20,
                color: milestone.isUnlocked ? Color.msGold : .gray
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(spacing: 6) {
                ZStack {
                    Image(systemName: milestone.icon)
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(
                            milestone.isUnlocked ? Color.msGold : Color.msTextMuted.opacity(0.4)
                        )
                        .shadow(
                            color: milestone.isUnlocked ? Color.msGold.opacity(0.6) : .clear,
                            radius: 6
                        )

                    if !milestone.isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.msTextMuted.opacity(0.5))
                            .offset(x: 12, y: -10)
                    }
                }

                Text(milestone.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        milestone.isUnlocked ? Color.msTextPrimary : Color.msTextMuted.opacity(0.4)
                    )
                    .multilineTextAlignment(.center)

                if milestone.isUnlocked {
                    Text(milestone.subtitle)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.msGold)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .frame(width: 88, height: 100)
    }
}
