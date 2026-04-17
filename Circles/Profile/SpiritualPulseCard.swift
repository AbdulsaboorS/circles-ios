import SwiftUI

struct SpiritualPulseCard: View {
    let totalDays: Int
    let bestStreak: Int
    let circleCount: Int
    let nudgesSent: Int
    let isLoading: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.msBorder, lineWidth: 1)
                )

            HStack(spacing: 0) {
                statItem(icon: "flame.fill",         value: "\(totalDays)",   label: "Total Days")
                divider
                statItem(icon: "bolt.fill",          value: "\(bestStreak)",  label: "Best Streak")
                divider
                statItem(icon: "person.2.fill",      value: "\(circleCount)", label: "Circles")
                divider
                statItem(icon: "hands.sparkles.fill", value: "\(nudgesSent)", label: "Nudges Sent")
            }
            .padding(.vertical, 18)

            if isLoading {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.msBackground.opacity(0.5))
                    .overlay(ProgressView().tint(Color.msGold))
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.msBorder)
            .frame(width: 1, height: 36)
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.msGold)
            Text(value)
                .font(.appHeadline)
                .foregroundStyle(Color.msTextPrimary)
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.msTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
