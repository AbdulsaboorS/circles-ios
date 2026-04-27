import Foundation

// MARK: - Tag Enums

/// Spirituality level (Amir Q1 — "Where are you in your faith journey?").
enum CatalogSpirituality: String, CaseIterable, Sendable {
    case J  // Just starting out
    case B  // Building a foundation
    case S  // Steady and growing
    case D  // Deeply rooted

    /// Maps the Amir/quiz answer label → enum. Returns nil for unknown strings.
    static func fromAnswer(_ answer: String?) -> CatalogSpirituality? {
        switch answer {
        case "Just starting out":      return .J
        case "Building a foundation":  return .B
        case "Steady and growing":     return .S
        case "Deeply rooted":          return .D
        default: return nil
        }
    }
}

/// Heart of the circle (Amir Q3).
enum CatalogHeart: String, CaseIterable, Sendable {
    case salah, quran, dhikr, brother

    static func fromAnswer(_ answer: String?) -> CatalogHeart? {
        switch answer {
        case "Salah, together":              return .salah
        case "Quran in our lives":           return .quran
        case "Remembrance of Allah":         return .dhikr
        case "Brotherhood through hardship": return .brother
        default: return nil
        }
    }
}

/// Time weight bucket (Amir Q2).
enum CatalogTimeWeight: String, Sendable {
    case S  // 5–10 min
    case M  // 15–30 / 30–60 min
    case L  // 60+ min

    static func fromAnswer(_ answer: String?) -> CatalogTimeWeight? {
        switch answer {
        case "5–10 minutes":         return .S
        case "15–30 minutes":        return .M
        case "30–60 minutes":        return .M
        case "More than an hour":    return .L
        default: return nil
        }
    }
}

// MARK: - HabitEntry

/// One row from the catalog. 44 entries, source of truth for both Amir (shared)
/// and Joiner/Personal flows. Catalog is fully deterministic — no AI in the
/// onboarding suggestion path.
struct HabitEntry: Identifiable, Sendable, Hashable {
    let id: Int
    let name: String
    let icon: String
    let defaultRationale: String
    let spirituality: Set<CatalogSpirituality>
    let heart: Set<CatalogHeart>
    let timeWeight: CatalogTimeWeight
    let islamicStruggles: Set<String>
    let lifeStruggles: Set<String>
    /// Per-spirituality rationale overrides (8 entries use these). Lookup falls
    /// back to `defaultRationale` if the user's level has no entry.
    let variants: [CatalogSpirituality: String]

    /// Returns the rationale to show this user given their spirituality level.
    func rationale(for level: CatalogSpirituality?) -> String {
        if let level, let v = variants[level] { return v }
        return defaultRationale
    }
}

// MARK: - HabitCatalog

enum HabitCatalog {

    /// Caps locked in the build-order doc.
    static let sharedCap: Int = 2
    static let personalCap: Int = 3

    /// Convenience lookup by name (used when seeding icons in flush paths etc.).
    static func entry(named name: String) -> HabitEntry? {
        all.first { $0.name == name }
    }

    /// All 44 catalog entries. Order here is canonical and used as the
    /// secondary tiebreaker after score in `recommendations(for:)`.
    static let all: [HabitEntry] = [
        // 1. Daily Prayers
        HabitEntry(
            id: 1,
            name: "Fajr",
            icon: "moon.stars.fill",
            defaultRationale: "The hardest prayer to anchor — when Fajr stands, the rest of the day follows.",
            spirituality: [.J, .B, .S, .D],
            heart: [.salah],
            timeWeight: .S,
            islamicStruggles: ["prayer_consistency", "fajr"],
            lifeStruggles: ["discipline", "sleep"],
            variants: [.J: "Even one Fajr this week is a real beginning — Allah sees every step."]
        ),
        HabitEntry(
            id: 2,
            name: "Dhuhr",
            icon: "sun.max.fill",
            defaultRationale: "A midday pause that resets your intention before the rush carries you off.",
            spirituality: [.J, .B],
            heart: [.salah],
            timeWeight: .S,
            islamicStruggles: ["prayer_consistency"],
            lifeStruggles: ["time_management"],
            variants: [:]
        ),
        HabitEntry(
            id: 3,
            name: "Asr",
            icon: "sun.horizon.fill",
            defaultRationale: "The afternoon prayer the Prophet ﷺ called especially weighty — easy to miss, easy to keep.",
            spirituality: [.J, .B],
            heart: [.salah],
            timeWeight: .S,
            islamicStruggles: ["prayer_consistency"],
            lifeStruggles: ["discipline"],
            variants: [:]
        ),
        HabitEntry(
            id: 4,
            name: "Maghrib",
            icon: "sunset.fill",
            defaultRationale: "Closing the day in gratitude as the sun sets — a small bow before evening's pull.",
            spirituality: [.J, .B],
            heart: [.salah],
            timeWeight: .S,
            islamicStruggles: ["prayer_consistency"],
            lifeStruggles: ["time_management"],
            variants: [:]
        ),
        HabitEntry(
            id: 5,
            name: "Isha",
            icon: "moon.fill",
            defaultRationale: "Ending the day with prayer settles the heart before sleep, and the night becomes lighter.",
            spirituality: [.J, .B],
            heart: [.salah],
            timeWeight: .S,
            islamicStruggles: ["prayer_consistency"],
            lifeStruggles: ["sleep", "anxiety"],
            variants: [:]
        ),

        // 2. Salah Enhancers
        HabitEntry(
            id: 6,
            name: "Sunnah Rakat",
            icon: "rectangle.stack.fill",
            defaultRationale: "The voluntary rakat before and after fard quietly build a wall around your salah.",
            spirituality: [.B, .S, .D],
            heart: [.salah],
            timeWeight: .S,
            islamicStruggles: ["prayer_consistency"],
            lifeStruggles: ["discipline"],
            variants: [:]
        ),
        HabitEntry(
            id: 7,
            name: "Tahajjud",
            icon: "sparkles",
            defaultRationale: "The night prayer is where du'a is answered — beloved practice for the steady.",
            spirituality: [.S, .D],
            heart: [.salah, .dhikr],
            timeWeight: .M,
            islamicStruggles: ["prayer_consistency"],
            lifeStruggles: ["discipline", "sleep"],
            variants: [.D: "Your night practice is known to Him — let your circle witness it too."]
        ),
        HabitEntry(
            id: 8,
            name: "Witr",
            icon: "book.closed.fill",
            defaultRationale: "Don't sleep without it — the Prophet ﷺ never left it, even on the road.",
            spirituality: [.B, .S, .D],
            heart: [.salah],
            timeWeight: .S,
            islamicStruggles: ["prayer_consistency"],
            lifeStruggles: ["sleep"],
            variants: [:]
        ),

        // 3. Quran Practices
        HabitEntry(
            id: 9,
            name: "Daily Quran reading",
            icon: "book.fill",
            defaultRationale: "A few verses a day keeps your heart turned toward Allah's words.",
            spirituality: [.J, .B, .S, .D],
            heart: [.quran],
            timeWeight: .S,
            islamicStruggles: ["quran_daily"],
            lifeStruggles: ["discipline"],
            variants: [:]
        ),
        HabitEntry(
            id: 10,
            name: "Quran memorization",
            icon: "brain.head.profile",
            defaultRationale: "Even one verse a week, returning to it daily, builds a quiet treasure inside you.",
            spirituality: [.B, .S, .D],
            heart: [.quran],
            timeWeight: .M,
            islamicStruggles: ["quran_daily", "seeking_knowledge"],
            lifeStruggles: ["discipline"],
            variants: [.B: "One verse a week, no rush. Memorization is a slow river, not a race."]
        ),
        HabitEntry(
            id: 11,
            name: "Quran listening",
            icon: "headphones",
            defaultRationale: "On the commute, in the kitchen — let the recitation wash over you and soften the noise.",
            spirituality: [.J, .B],
            heart: [.quran],
            timeWeight: .S,
            islamicStruggles: ["quran_daily"],
            lifeStruggles: ["anxiety", "phone_social"],
            variants: [:]
        ),
        HabitEntry(
            id: 12,
            name: "Quran reflection (tafsir)",
            icon: "text.book.closed.fill",
            defaultRationale: "Read one ayah and sit with it. Understanding deepens what mere recitation cannot.",
            spirituality: [.S, .D],
            heart: [.quran],
            timeWeight: .M,
            islamicStruggles: ["quran_daily", "seeking_knowledge"],
            lifeStruggles: ["time_management"],
            variants: [.D: "Bring tafsir to your sittings — your reflection now feeds others."]
        ),
        HabitEntry(
            id: 13,
            name: "Surah Kahf on Friday",
            icon: "sun.max.circle.fill",
            defaultRationale: "Reciting Surah Kahf on Friday is light between the two Fridays — the Prophet ﷺ's promise.",
            spirituality: [.J, .B, .S, .D],
            heart: [.quran],
            timeWeight: .M,
            islamicStruggles: ["quran_daily"],
            lifeStruggles: ["discipline"],
            variants: [:]
        ),
        HabitEntry(
            id: 14,
            name: "Surah Mulk before sleep",
            icon: "shield.lefthalf.filled",
            defaultRationale: "Surah Mulk recited at night intercedes for its reader — the Prophet ﷺ never slept without it.",
            spirituality: [.B, .S, .D],
            heart: [.quran, .dhikr],
            timeWeight: .S,
            islamicStruggles: ["quran_daily", "dhikr_throughout"],
            lifeStruggles: ["sleep", "anxiety"],
            variants: [:]
        ),

        // 4. Dhikr & Du'a
        HabitEntry(
            id: 15,
            name: "Morning adhkar",
            icon: "sunrise.fill",
            defaultRationale: "The Prophet's ﷺ morning litanies are armor — start the day inside them.",
            spirituality: [.J, .B, .S, .D],
            heart: [.dhikr],
            timeWeight: .S,
            islamicStruggles: ["dhikr_throughout"],
            lifeStruggles: ["anxiety"],
            variants: [:]
        ),
        HabitEntry(
            id: 16,
            name: "Evening adhkar",
            icon: "moon.zzz.fill",
            defaultRationale: "Closing the day with the Prophet's ﷺ words protects sleep and the heart.",
            spirituality: [.J, .B, .S, .D],
            heart: [.dhikr],
            timeWeight: .S,
            islamicStruggles: ["dhikr_throughout"],
            lifeStruggles: ["sleep", "anxiety"],
            variants: [:]
        ),
        HabitEntry(
            id: 17,
            name: "Salawat upon the Prophet ﷺ",
            icon: "heart.fill",
            defaultRationale: "A small daily count brings nearness — the Prophet ﷺ said one salawat returns ten upon you.",
            spirituality: [.J, .B, .S, .D],
            heart: [.dhikr],
            timeWeight: .S,
            islamicStruggles: ["dhikr_throughout"],
            lifeStruggles: ["anxiety"],
            variants: [:]
        ),
        HabitEntry(
            id: 18,
            name: "Du'a journal",
            icon: "pencil.and.outline",
            defaultRationale: "Write your du'a down — it focuses the heart and you'll see Allah's answers in time.",
            spirituality: [.B, .S, .D],
            heart: [.dhikr],
            timeWeight: .S,
            islamicStruggles: ["dhikr_throughout"],
            lifeStruggles: ["anxiety", "patience"],
            variants: [:]
        ),
        HabitEntry(
            id: 19,
            name: "Istighfar count",
            icon: "arrow.counterclockwise.circle.fill",
            defaultRationale: "100 a day, the Prophet ﷺ did. Forgiveness softens what stress hardens.",
            spirituality: [.J, .B, .S, .D],
            heart: [.dhikr],
            timeWeight: .S,
            islamicStruggles: ["dhikr_throughout", "guarding_tongue"],
            lifeStruggles: ["anxiety", "patience"],
            variants: [:]
        ),

        // 5. Fasting
        HabitEntry(
            id: 20,
            name: "Sunnah fasts (Mon/Thu)",
            icon: "drop.fill",
            defaultRationale: "Mondays and Thursdays — the Prophet ﷺ fasted them. Patience and gratitude grow together.",
            spirituality: [.B, .S, .D],
            heart: [.salah, .brother],
            timeWeight: .L,
            islamicStruggles: ["voluntary_fasting"],
            lifeStruggles: ["discipline", "physical_health"],
            variants: [.B: "Start with one — a Monday or a Thursday. The Prophet ﷺ never shamed a small step."]
        ),
        HabitEntry(
            id: 21,
            name: "Ayyam al-Bid (white days)",
            icon: "moon.haze.fill",
            defaultRationale: "Three days each lunar month — small commitment, large reward, gentle on the body.",
            spirituality: [.B, .S, .D],
            heart: [.salah],
            timeWeight: .L,
            islamicStruggles: ["voluntary_fasting"],
            lifeStruggles: ["discipline", "physical_health"],
            variants: [:]
        ),

        // 6. Charity & Character
        HabitEntry(
            id: 22,
            name: "Daily sadaqah",
            icon: "hands.sparkles.fill",
            defaultRationale: "Even a coin a day — sadaqah extinguishes sin like water extinguishes fire.",
            spirituality: [.J, .B, .S, .D],
            heart: [.brother],
            timeWeight: .S,
            islamicStruggles: [],
            lifeStruggles: ["anxiety", "patience"],
            variants: [:]
        ),
        HabitEntry(
            id: 23,
            name: "Guard the tongue",
            icon: "mouth.fill",
            defaultRationale: "Before speaking: ask, is this true, kind, necessary? Most words can wait.",
            spirituality: [.J, .B, .S, .D],
            heart: [.dhikr, .brother],
            timeWeight: .S,
            islamicStruggles: ["guarding_tongue"],
            lifeStruggles: ["patience"],
            variants: [:]
        ),
        HabitEntry(
            id: 24,
            name: "Smile / kindness",
            icon: "face.smiling.fill",
            defaultRationale: "The Prophet ﷺ called a smile sadaqah — a small gift you can give all day.",
            spirituality: [.J, .B, .S, .D],
            heart: [.brother],
            timeWeight: .S,
            islamicStruggles: [],
            lifeStruggles: ["family_ties"],
            variants: [:]
        ),
        HabitEntry(
            id: 25,
            name: "Anger restraint",
            icon: "flame.fill",
            defaultRationale: "When anger rises: silence, then wudu, then sit. The Prophet ﷺ taught the steps.",
            spirituality: [.B, .S, .D],
            heart: [.brother],
            timeWeight: .S,
            islamicStruggles: ["guarding_tongue"],
            lifeStruggles: ["patience", "family_ties"],
            variants: [:]
        ),

        // 7. Family & Community
        HabitEntry(
            id: 26,
            name: "Call parents",
            icon: "phone.fill",
            defaultRationale: "Even five minutes daily — pleasing your parents is among the heaviest deeds.",
            spirituality: [.J, .B, .S, .D],
            heart: [.brother],
            timeWeight: .S,
            islamicStruggles: [],
            lifeStruggles: ["family_ties"],
            variants: [:]
        ),
        HabitEntry(
            id: 27,
            name: "Family meal together",
            icon: "fork.knife",
            defaultRationale: "Eat one meal a day with family, no phones — it's where bonds quietly mend.",
            spirituality: [.J, .B, .S, .D],
            heart: [.brother],
            timeWeight: .M,
            islamicStruggles: [],
            lifeStruggles: ["family_ties", "phone_social"],
            variants: [:]
        ),
        HabitEntry(
            id: 28,
            name: "Check on a friend",
            icon: "bubble.left.and.bubble.right.fill",
            defaultRationale: "One brother or sister, one short message — visit each other for Allah's sake.",
            spirituality: [.J, .B, .S, .D],
            heart: [.brother],
            timeWeight: .S,
            islamicStruggles: [],
            lifeStruggles: ["family_ties"],
            variants: [:]
        ),
        HabitEntry(
            id: 29,
            name: "Du'a for parents",
            icon: "heart.text.square.fill",
            defaultRationale: "A short du'a for them, daily — even after they're gone, this carries.",
            spirituality: [.J, .B, .S, .D],
            heart: [.brother, .dhikr],
            timeWeight: .S,
            islamicStruggles: ["dhikr_throughout"],
            lifeStruggles: ["family_ties"],
            variants: [:]
        ),
        HabitEntry(
            id: 30,
            name: "Pray jamaa'ah at masjid",
            icon: "building.columns.fill",
            defaultRationale: "27× reward in congregation — and one of the few places brothers/sisters meet for Him.",
            spirituality: [.B, .S, .D],
            heart: [.salah, .brother],
            timeWeight: .M,
            islamicStruggles: ["prayer_consistency"],
            lifeStruggles: ["family_ties"],
            variants: [:]
        ),

        // 8. Knowledge
        HabitEntry(
            id: 31,
            name: "Daily lecture / podcast",
            icon: "play.circle.fill",
            defaultRationale: "Replace 15 minutes of scrolling with a scholar's voice — your day will tilt by week's end.",
            spirituality: [.J, .B, .S, .D],
            heart: [.quran, .dhikr],
            timeWeight: .S,
            islamicStruggles: ["seeking_knowledge"],
            lifeStruggles: ["phone_social", "time_management"],
            variants: [:]
        ),
        HabitEntry(
            id: 32,
            name: "One hadith a day",
            icon: "text.quote",
            defaultRationale: "Memorize one short hadith — over a year, you'll carry the Prophet's ﷺ words inside you.",
            spirituality: [.B, .S, .D],
            heart: [.dhikr],
            timeWeight: .S,
            islamicStruggles: ["seeking_knowledge"],
            lifeStruggles: ["discipline"],
            variants: [:]
        ),
        HabitEntry(
            id: 33,
            name: "Sirah reading",
            icon: "book.pages.fill",
            defaultRationale: "A few pages of the Prophet's ﷺ life — the closest thing to walking beside him.",
            spirituality: [.B, .S, .D],
            heart: [.brother],
            timeWeight: .M,
            islamicStruggles: ["seeking_knowledge"],
            lifeStruggles: ["discipline"],
            variants: [.B: "A page a day. The story will pull you forward more than discipline ever could."]
        ),

        // 9. Body & Discipline
        HabitEntry(
            id: 34,
            name: "Sleep on wudu",
            icon: "bed.double.fill",
            defaultRationale: "Sleeping in wudu is sunnah — angels make du'a for you while you sleep.",
            spirituality: [.B, .S, .D],
            heart: [.salah, .dhikr],
            timeWeight: .S,
            islamicStruggles: ["prayer_consistency"],
            lifeStruggles: ["sleep"],
            variants: [:]
        ),
        HabitEntry(
            id: 35,
            name: "Sunnah of eating",
            icon: "leaf.fill",
            defaultRationale: "Bismillah, right hand, sit to eat, stop before full — sunnah of the body.",
            spirituality: [.B, .S, .D],
            heart: [.dhikr],
            timeWeight: .S,
            islamicStruggles: [],
            lifeStruggles: ["physical_health"],
            variants: [:]
        ),
        HabitEntry(
            id: 36,
            name: "Walk after Maghrib",
            icon: "figure.walk",
            defaultRationale: "Ten minutes of fresh air — give the body what it's owed so the soul can work.",
            spirituality: [.J, .B, .S, .D],
            heart: [.brother],
            timeWeight: .S,
            islamicStruggles: [],
            lifeStruggles: ["physical_health", "anxiety"],
            variants: [:]
        ),
        HabitEntry(
            id: 37,
            name: "No phone first hour",
            icon: "iphone.slash",
            defaultRationale: "First hour of the day: no phone. Reclaim the morning the world is trying to steal.",
            spirituality: [.J, .B, .S, .D],
            heart: [.dhikr, .salah],
            timeWeight: .S,
            islamicStruggles: ["dhikr_throughout", "fajr", "lowering_gaze"],
            lifeStruggles: ["phone_social", "time_management", "sleep"],
            variants: [:]
        ),
        HabitEntry(
            id: 38,
            name: "Sleep early",
            icon: "zzz",
            defaultRationale: "Sleep early to rise for Fajr — the night is for rest, not for the screen.",
            spirituality: [.J, .B, .S, .D],
            heart: [.salah],
            timeWeight: .S,
            islamicStruggles: ["fajr", "prayer_consistency"],
            lifeStruggles: ["sleep", "phone_social", "time_management"],
            variants: [:]
        ),

        // 10. Reflection & Heart
        HabitEntry(
            id: 39,
            name: "Muhasaba (self-account)",
            icon: "list.bullet.clipboard.fill",
            defaultRationale: "Before sleep, three minutes: what pleased Allah today, what didn't. Adjust tomorrow.",
            spirituality: [.B, .S, .D],
            heart: [.dhikr],
            timeWeight: .S,
            islamicStruggles: ["lowering_gaze"],
            lifeStruggles: ["discipline"],
            variants: [:]
        ),
        HabitEntry(
            id: 40,
            name: "Gratitude note",
            icon: "hands.and.sparkles.fill",
            defaultRationale: "Three lines — Allah's favors on you today. Gratitude expands what you have.",
            spirituality: [.J, .B, .S, .D],
            heart: [.dhikr],
            timeWeight: .S,
            islamicStruggles: [],
            lifeStruggles: ["anxiety", "patience"],
            variants: [:]
        ),
        HabitEntry(
            id: 41,
            name: "Lower the gaze (intentional)",
            icon: "eye.slash.fill",
            defaultRationale: "Set the intention before leaving home — a single act, repeated, becomes character.",
            spirituality: [.B, .S, .D],
            heart: [.dhikr],
            timeWeight: .S,
            islamicStruggles: ["lowering_gaze"],
            lifeStruggles: ["discipline", "phone_social"],
            variants: [:]
        ),

        // 11. Spiritual Focus
        HabitEntry(
            id: 42,
            name: "Quiet time after Fajr",
            icon: "figure.mind.and.body",
            defaultRationale: "Stay seated after Fajr — adhkar, du'a, or just silence. The Prophet ﷺ loved this hour.",
            spirituality: [.B, .S, .D],
            heart: [.dhikr, .salah],
            timeWeight: .M,
            islamicStruggles: ["fajr", "dhikr_throughout"],
            lifeStruggles: ["time_management", "anxiety"],
            variants: [.B: "Five minutes. Don't rush to the phone — let the morning settle first."]
        ),
        HabitEntry(
            id: 43,
            name: "Mindful wudu",
            icon: "drop.triangle.fill",
            defaultRationale: "Slow the wudu down — sins fall with the water, the Prophet ﷺ said. Don't rush it.",
            spirituality: [.J, .B, .S, .D],
            heart: [.salah],
            timeWeight: .S,
            islamicStruggles: ["prayer_consistency"],
            lifeStruggles: ["anxiety"],
            variants: [.D: "Slow each limb three times — let your wudu become a meditation."]
        ),
        HabitEntry(
            id: 44,
            name: "Du'a before sleep",
            icon: "cloud.moon.fill",
            defaultRationale: "The Prophet's ﷺ sleep du'as turn the bed into a place of remembrance, not just rest.",
            spirituality: [.J, .B, .S, .D],
            heart: [.dhikr],
            timeWeight: .S,
            islamicStruggles: ["dhikr_throughout"],
            lifeStruggles: ["sleep", "anxiety"],
            variants: [:]
        )
    ]
}

// MARK: - Recommendations

extension HabitCatalog {

    /// Inputs to ranking. All fields optional — a fully-empty input falls back
    /// to canonical order (entries 1..44).
    struct RankInput: Sendable {
        var spirituality: CatalogSpirituality?
        var time: CatalogTimeWeight?
        var heart: CatalogHeart?
        var islamicStruggles: Set<String>
        var lifeStruggles: Set<String>
        /// Stable seed for the deterministic tiebreaker. Pass any per-user
        /// string (user id, device id) so two users with identical answers
        /// see slightly different orderings, but the same user always sees
        /// the same result.
        var seed: String

        init(
            spirituality: CatalogSpirituality? = nil,
            time: CatalogTimeWeight? = nil,
            heart: CatalogHeart? = nil,
            islamicStruggles: Set<String> = [],
            lifeStruggles: Set<String> = [],
            seed: String = ""
        ) {
            self.spirituality = spirituality
            self.time = time
            self.heart = heart
            self.islamicStruggles = islamicStruggles
            self.lifeStruggles = lifeStruggles
            self.seed = seed
        }
    }

    /// Result of one ranking pass — split into the top-4 personalized tiles
    /// and the next-3 common starters. View renders both, no overlap.
    struct Recommendations: Sendable {
        let top: [HabitEntry]       // up to 4
        let starters: [HabitEntry]  // up to 3

        var combined: [HabitEntry] { top + starters }
    }

    /// Rank the catalog for a single user and partition into top-4 + 3 starters.
    /// Pure / deterministic given identical input.
    static func recommendations(for input: RankInput) -> Recommendations {
        // Filter: only entries tagged for the user's spirituality level.
        // If level is unknown, keep everything — the score still drives order.
        let pool: [HabitEntry] = {
            guard let s = input.spirituality else { return all }
            return all.filter { $0.spirituality.contains(s) }
        }()

        let tiebreakSeed = stableTiebreakSeed(input.seed)

        let scored = pool
            .map { entry -> (entry: HabitEntry, score: Int, jitter: Int) in
                let s = score(entry: entry, input: input)
                // Jitter is tiny and per-(seed, entry.id) only, so two users
                // with identical scores see slightly different orderings,
                // but the same user is stable across re-entries.
                let jitter = Int(bitPattern: tiebreakSeed &+ UInt64(entry.id) &* 2654435761) & 0xFFFF
                return (entry, s, jitter)
            }
            .sorted { a, b in
                if a.score != b.score { return a.score > b.score }
                if a.jitter != b.jitter { return a.jitter < b.jitter }
                return a.entry.id < b.entry.id
            }
            .map(\.entry)

        let top      = Array(scored.prefix(4))
        let starters = Array(scored.dropFirst(4).prefix(3))
        return Recommendations(top: top, starters: starters)
    }

    /// Score a catalog entry against the user's answers + struggles.
    /// Heart is weighted highest (the user explicitly named it as the focus
    /// of the circle), then struggles, then time-fit.
    private static func score(entry: HabitEntry, input: RankInput) -> Int {
        var s = 0
        if let heart = input.heart, entry.heart.contains(heart) {
            s += 3
        }
        // +1 per matching struggle slug, on either axis.
        s += entry.islamicStruggles.intersection(input.islamicStruggles).count
        s += entry.lifeStruggles.intersection(input.lifeStruggles).count

        // Time fit: penalize length mismatch, reward exact match.
        if let t = input.time {
            switch (t, entry.timeWeight) {
            case (.S, .S), (.M, .M), (.L, .L): s += 1
            case (.S, .L), (.L, .S):           s -= 2
            default: break
            }
        }
        return s
    }

    /// Deterministic 64-bit fold of the seed string. FNV-1a — fine for tiebreak.
    private static func stableTiebreakSeed(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100000001b3
        }
        return h
    }
}
