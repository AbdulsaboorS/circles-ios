import Foundation

extension HabitSuggestion {
    /// Used when Gemini is unreachable or returns malformed output. Five gentle,
    /// broadly-useful starting habits (D-13 in `14-CONTEXT.md`).
    static let fallbackSuggestions: [HabitSuggestion] = [
        HabitSuggestion(name: "Fajr on time",      rationale: "Start the day in obedience. Everything else settles from here."),
        HabitSuggestion(name: "One page of Quran", rationale: "A small, daily anchor in the Book of Allah."),
        HabitSuggestion(name: "Morning dhikr",     rationale: "Steady the heart before the day pulls at it."),
        HabitSuggestion(name: "Gratitude note",    rationale: "Three lines — Allah's favors on you today."),
        HabitSuggestion(name: "Ten-minute walk",   rationale: "Give the body what it's owed so the soul can work.")
    ]
}
