import SwiftUI

/// Seven named tiers for the Noor Bead streak hero. Each tier drives:
/// bead diameter, gradient saturation, aura radius, sparkle count, caption,
/// and the "X days to <next>" hint shown under the streak line.
///
/// Spec source: `.planning/notes/phase14-start.md` lines 22–42.
enum StreakMilestone: Sendable, Equatable {
    case lapsed        // day 0
    case firstLight    // day 1
    case threeFajrs    // day 3
    case oneWeek       // day 7
    case twoWeeks      // day 14
    case threeWeeks    // day 21
    case sanctuary     // day 28+

    // MARK: - Tier mapping

    /// Returns the tier the bead should *display*. We never jump ahead of the
    /// user's actual progress; we floor to the nearest named threshold.
    static func tier(for days: Int) -> StreakMilestone {
        switch days {
        case ..<1:   return .lapsed
        case 1..<3:  return .firstLight
        case 3..<7:  return .threeFajrs
        case 7..<14: return .oneWeek
        case 14..<21: return .twoWeeks
        case 21..<28: return .threeWeeks
        default:     return .sanctuary
        }
    }

    // MARK: - Presentation

    var caption: String {
        switch self {
        case .lapsed:      return "Lapsed"
        case .firstLight:  return "First light"
        case .threeFajrs:  return "Three Fajrs"
        case .oneWeek:     return "One week"
        case .twoWeeks:    return "Two weeks"
        case .threeWeeks:  return "Three weeks"
        case .sanctuary:   return "Sanctuary"
        }
    }

    /// Baseline threshold for the tier (the day the caption "unlocks").
    var thresholdDay: Int {
        switch self {
        case .lapsed:      return 0
        case .firstLight:  return 1
        case .threeFajrs:  return 3
        case .oneWeek:     return 7
        case .twoWeeks:    return 14
        case .threeWeeks:  return 21
        case .sanctuary:   return 28
        }
    }

    /// Next tier in the sequence, or nil if we're already at Sanctuary.
    var next: StreakMilestone? {
        switch self {
        case .lapsed:      return .firstLight
        case .firstLight:  return .threeFajrs
        case .threeFajrs:  return .oneWeek
        case .oneWeek:     return .twoWeeks
        case .twoWeeks:    return .threeWeeks
        case .threeWeeks:  return .sanctuary
        case .sanctuary:   return nil
        }
    }

    // MARK: - Visual knobs

    /// Bead diameter grows ~1.5px/day between milestones, per phase14-start.md.
    /// We compute a piecewise curve that matches the anchor values:
    /// 60 (Lapsed) → 72 (Day 1) → 112 (Day 28).
    static func beadDiameter(forDays days: Int) -> CGFloat {
        guard days > 0 else { return 60 }
        let d = min(days, 28)
        // Anchors: (1, 72) → (28, 112). Linear with ~1.48px/day.
        let t = CGFloat(d - 1) / CGFloat(27)
        return 72 + t * (112 - 72)
    }

    /// Sparkle count per tier: 0 / 1 / 2 / 3 / 5 / 7 / 10.
    var sparkleCount: Int {
        switch self {
        case .lapsed:      return 0
        case .firstLight:  return 1
        case .threeFajrs:  return 2
        case .oneWeek:     return 3
        case .twoWeeks:    return 5
        case .threeWeeks:  return 7
        case .sanctuary:   return 10
        }
    }

    /// Outer aura radius — feeds the blur + scale of the outermost glow layer.
    var auraRadius: CGFloat {
        switch self {
        case .lapsed:      return 70
        case .firstLight:  return 96
        case .threeFajrs:  return 108
        case .oneWeek:     return 124
        case .twoWeeks:    return 140
        case .threeWeeks:  return 156
        case .sanctuary:   return 180
        }
    }

    /// How saturated the bead's gradient reads — 1.0 at full tier health,
    /// 0.15 at Lapsed (ashen).
    var gradientSaturation: Double {
        switch self {
        case .lapsed:      return 0.15
        case .firstLight:  return 0.60
        case .threeFajrs:  return 0.72
        case .oneWeek:     return 0.82
        case .twoWeeks:    return 0.90
        case .threeWeeks:  return 0.96
        case .sanctuary:   return 1.00
        }
    }

    // MARK: - Next-tier hint

    /// "3 days to One week" — nil when at Sanctuary.
    static func nextTierHint(forDays days: Int) -> String? {
        let current = tier(for: days)
        guard let next = current.next else { return nil }
        let remaining = max(1, next.thresholdDay - days)
        return "\(remaining) day\(remaining == 1 ? "" : "s") to \(next.caption)"
    }
}
