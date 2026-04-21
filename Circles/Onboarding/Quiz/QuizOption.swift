import Foundation

/// The 8 Islamic-struggle options the user can select on Quiz Screen A.
/// Content confirmed in `14-CONTEXT.md` D-15 and `onboarding_quiz_state.md`.
enum IslamicStruggle: String, CaseIterable, Identifiable, Sendable {
    case prayerConsistency = "prayer_consistency"
    case quranDaily = "quran_daily"
    case fajr = "fajr"
    case dhikrThroughout = "dhikr_throughout"
    case voluntaryFasting = "voluntary_fasting"
    case loweringGaze = "lowering_gaze"
    case guardingTongue = "guarding_tongue"
    case seekingKnowledge = "seeking_knowledge"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .prayerConsistency: return "Praying 5 times consistently"
        case .quranDaily:        return "Connecting with the Quran daily"
        case .fajr:              return "Waking up for Fajr"
        case .dhikrThroughout:   return "Keeping dhikr alive through the day"
        case .voluntaryFasting:  return "Voluntary fasting"
        case .loweringGaze:      return "Lowering my gaze"
        case .guardingTongue:    return "Guarding my tongue"
        case .seekingKnowledge:  return "Seeking Islamic knowledge"
        }
    }
}

/// The 8 life-struggle options the user can select on Quiz Screen B.
enum LifeStruggle: String, CaseIterable, Identifiable, Sendable {
    case discipline = "discipline"
    case sleep = "sleep"
    case physicalHealth = "physical_health"
    case familyTies = "family_ties"
    case anxiety = "anxiety"
    case timeManagement = "time_management"
    case phoneSocial = "phone_social"
    case patience = "patience"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .discipline:     return "Discipline and follow-through"
        case .sleep:          return "Sleep and waking early"
        case .physicalHealth: return "Physical health"
        case .familyTies:     return "Family and relationship ties"
        case .anxiety:        return "Restlessness or anxiety"
        case .timeManagement: return "Managing my time"
        case .phoneSocial:    return "Phone and social media"
        case .patience:       return "Patience"
        }
    }
}
