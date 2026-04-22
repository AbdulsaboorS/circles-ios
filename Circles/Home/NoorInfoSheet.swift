import SwiftUI

struct NoorInfoSheet: View {
    let streakDays: Int

    private var tier: StreakMilestone { StreakMilestone.tier(for: streakDays) }
    private var nextHint: String? { StreakMilestone.nextTierHint(forDays: streakDays) }

    private let ladder: [StreakMilestone] = [
        .firstLight, .threeFajrs, .oneWeek, .twoWeeks, .threeWeeks, .sanctuary
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.bottom, 28)

                tierDescription
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                ladderSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                explainer
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
        .background(Color.msBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.msBackground)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 8) {
            Text("Your Noor")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(Color.msTextPrimary)
                .padding(.top, 32)

            Text(streakDays == 0
                 ? "No active streak"
                 : "\(streakDays) day\(streakDays == 1 ? "" : "s") · \(tier.caption)")
                .font(.system(size: 14, design: .serif).italic())
                .foregroundStyle(Color.msTextMuted)
        }
    }

    private var tierDescription: some View {
        VStack(spacing: 6) {
            Text(tier == .lapsed ? "Streak lapsed" : tier.caption)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(Color.msGold)

            Text(tierBlurb(tier))
                .font(.system(size: 14, design: .serif).italic())
                .foregroundStyle(Color.msTextMuted)
                .multilineTextAlignment(.center)
        }
    }

    private var ladderSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(ladder.enumerated()), id: \.element.thresholdDay) { index, milestone in
                ladderRow(milestone, isLast: index == ladder.count - 1)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.msBackgroundDeep.opacity(0.6))
        )
    }

    private var explainer: some View {
        VStack(spacing: 12) {
            Rectangle()
                .fill(Color.msGold.opacity(0.18))
                .frame(height: 1)

            Text("HOW IT WORKS")
                .font(.system(size: 10, weight: .semibold, design: .serif))
                .tracking(1.5)
                .foregroundStyle(Color.msTextMuted.opacity(0.5))

            VStack(alignment: .leading, spacing: 8) {
                howItWorksRow("Complete all your habits in a day to earn a streak day.")
                howItWorksRow("Your Noor glows brighter and grows larger with each milestone.")
                howItWorksRow("This is your personal streak — separate from your Circle's group streak.")
            }

            if let hint = nextHint {
                Text(hint)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(Color.msGold.opacity(0.85))
            } else {
                Text("You've reached Sanctuary — keep the light going.")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundStyle(Color.msGold.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func howItWorksRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("✦")
                .font(.system(size: 9))
                .foregroundStyle(Color.msGold.opacity(0.6))
                .padding(.top, 3)
            Text(text)
                .font(.system(size: 13, design: .serif).italic())
                .foregroundStyle(Color.msTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Ladder row

    @ViewBuilder
    private func ladderRow(_ milestone: StreakMilestone, isLast: Bool) -> some View {
        let isReached = streakDays >= milestone.thresholdDay
        let isCurrent = tier == milestone

        HStack(spacing: 14) {
            ZStack {
                if isCurrent {
                    SwiftUI.Circle()
                        .stroke(Color.msGold.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
                SwiftUI.Circle()
                    .fill(isReached ? Color.msGold : Color.msGold.opacity(0.12))
                    .frame(width: 10, height: 10)
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(milestone.caption)
                        .font(.system(size: 14,
                                      weight: isCurrent ? .semibold : .regular,
                                      design: .serif))
                        .foregroundStyle(
                            isCurrent   ? Color.msTextPrimary :
                            isReached   ? Color.msTextPrimary.opacity(0.65) :
                                          Color.msTextMuted.opacity(0.4)
                        )

                    Text("· \(milestone.thresholdDay) day\(milestone.thresholdDay == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.msTextMuted.opacity(isReached ? 0.45 : 0.25))

                    if milestone.sparkleCount > 0 {
                        Text(sparkleString(for: milestone.sparkleCount))
                            .font(.system(size: 10))
                            .foregroundStyle(
                                isCurrent ? Color.msGold :
                                isReached ? Color.msGold.opacity(0.6) :
                                            Color.msGold.opacity(0.15)
                            )
                    }
                }

                if isCurrent {
                    Text("you are here")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.msGold.opacity(0.75))
                }
            }

            Spacer()

            if isReached && !isCurrent {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.msGold.opacity(0.6))
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.msGold.opacity(0.08))
                    .frame(height: 1)
                    .padding(.leading, 54)
            }
        }
    }

    // MARK: - Helpers

    private func sparkleString(for count: Int) -> String {
        let capped = min(count, 5)
        let suffix = count > 5 ? "+" : ""
        return String(repeating: "✦", count: capped) + suffix
    }

    // MARK: - Tier copy

    private func tierBlurb(_ t: StreakMilestone) -> String {
        switch t {
        case .lapsed:     return "Your streak has broken. Every day is a new start."
        case .firstLight: return "The dawn of consistency. Keep going."
        case .threeFajrs: return "A rhythm is forming. Don't break the chain."
        case .oneWeek:    return "Seven days of intention. The habit is taking hold."
        case .twoWeeks:   return "A fortnight of presence. You're building something real."
        case .threeWeeks: return "Three weeks — this is who you are now."
        case .sanctuary:  return "A month of light. SubhanAllah — keep going."
        }
    }
}
