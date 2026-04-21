import Foundation
import Observation
import Supabase

/// Drives the four-screen Meaningful Habits quiz (Islamic struggles → Life struggles →
/// Processing → Habit selection). Used in three contexts:
///
/// 1. Amir onboarding (pre-auth, answers flushed after auth)
/// 2. Member onboarding (pre-auth, answers flushed after auth)
/// 3. Habit creation intercept (post-auth, answers saved directly)
///
/// The parent chooses how to persist by wiring `onPersistStruggles` and `onFinish`.
@Observable
@MainActor
final class OnboardingQuizCoordinator {

    enum Step: Hashable {
        case islamicStruggles
        case lifeStruggles
        case processing
        case habitSelection
    }

    // MARK: - State

    var step: Step = .islamicStruggles
    var selectedIslamic: Set<IslamicStruggle> = []
    var selectedLife: Set<LifeStruggle> = []

    /// Populated by `loadSuggestions()`. Task 2 ships a static stub list so the
    /// quiz flow is demonstrable end-to-end; Task 3 replaces the body of
    /// `loadSuggestions()` with a live Gemini call + static fallback.
    var suggestions: [HabitSuggestion] = []
    var isLoadingSuggestions: Bool = false

    var errorMessage: String? = nil

    // MARK: - Callbacks (wired by caller)

    /// Called once the user finishes Screen B, before advancing to processing.
    /// Caller decides whether to write directly to Supabase or stage for later flush.
    var onPersistStruggles: ((_ islamic: [String], _ life: [String]) async -> Void)?

    /// Called when the user picks a habit on Screen D (or a custom name).
    /// `suggestion` is nil for custom entries; `customName` carries the typed name.
    var onFinish: ((_ suggestion: HabitSuggestion?, _ customName: String?) -> Void)?

    // MARK: - Derived

    var canAdvanceFromIslamic: Bool { !selectedIslamic.isEmpty }
    var canAdvanceFromLife: Bool    { !selectedLife.isEmpty }

    var islamicSlugs: [String] { selectedIslamic.map(\.rawValue).sorted() }
    var lifeSlugs: [String]    { selectedLife.map(\.rawValue).sorted() }

    // MARK: - Static stub suggestions (Task 2)
    //
    // Task 3 will replace this with a live Gemini call. The list intentionally
    // mirrors the structure of what Gemini will return so Screen D doesn't
    // need to change once the live loader lands.
    static let stubSuggestions: [HabitSuggestion] = [
        HabitSuggestion(name: "Fajr on time",      rationale: "Start the day in obedience. Everything else settles from here."),
        HabitSuggestion(name: "One page of Quran", rationale: "A small, daily anchor in the Book of Allah."),
        HabitSuggestion(name: "Morning dhikr",     rationale: "Steady the heart before the day pulls at it."),
        HabitSuggestion(name: "Gratitude note",    rationale: "Three lines — Allah's favors on you today."),
        HabitSuggestion(name: "Ten-minute walk",   rationale: "Give the body what it's owed so the soul can work.")
    ]

    // MARK: - Advances

    func advanceToLife() {
        guard canAdvanceFromIslamic else { return }
        step = .lifeStruggles
    }

    /// Advances to processing, persists struggles through the caller-provided callback,
    /// then populates the stub suggestion list before showing Screen D.
    func advanceToProcessing() async {
        guard canAdvanceFromLife else { return }
        step = .processing
        if let onPersistStruggles {
            await onPersistStruggles(islamicSlugs, lifeSlugs)
        }
        await loadSuggestions()
    }

    /// Populates `suggestions`. Task 2 uses `stubSuggestions` directly; Task 3
    /// replaces this body with a live Gemini call that falls back to the
    /// stub list on error. Always advances to `.habitSelection` so the user
    /// is never stranded on the processing screen.
    func loadSuggestions() async {
        isLoadingSuggestions = true
        // Small artificial delay so the processing screen doesn't flash.
        try? await Task.sleep(for: .milliseconds(800))
        suggestions = Self.stubSuggestions
        isLoadingSuggestions = false
        step = .habitSelection
    }

    func finish(suggestion: HabitSuggestion) {
        onFinish?(suggestion, nil)
    }

    func finish(customName: String) {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onFinish?(nil, trimmed)
    }
}
