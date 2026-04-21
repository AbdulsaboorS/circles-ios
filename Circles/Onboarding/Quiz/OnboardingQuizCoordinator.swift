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

    /// Populated by `loadSuggestions()` from Gemini, or `HabitSuggestion.fallbackSuggestions`
    /// when Gemini is unreachable / malformed.
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

    // MARK: - Advances

    func advanceToLife() {
        guard canAdvanceFromIslamic else { return }
        step = .lifeStruggles
    }

    /// Advances to processing, persists struggles through the caller-provided callback,
    /// then kicks off the live Gemini suggestion load.
    func advanceToProcessing() async {
        guard canAdvanceFromLife else { return }
        step = .processing
        if let onPersistStruggles {
            await onPersistStruggles(islamicSlugs, lifeSlugs)
        }
        await loadSuggestions()
    }

    /// Populates `suggestions` from Gemini, falling back to a static list if the
    /// call throws. Enforces a 1.6 s minimum so the processing screen completes
    /// at least one full pulse cycle before transitioning.
    func loadSuggestions() async {
        isLoadingSuggestions = true
        let start = Date()
        defer {
            isLoadingSuggestions = false
            step = .habitSelection
        }
        do {
            let live = try await GeminiService.shared.generateHabitSuggestions(
                islamicStruggles: islamicSlugs,
                lifeStruggles: lifeSlugs
            )
            suggestions = live
        } catch {
            suggestions = HabitSuggestion.fallbackSuggestions
        }
        let elapsed = Date().timeIntervalSince(start)
        let minSeconds: TimeInterval = 1.6
        if elapsed < minSeconds {
            try? await Task.sleep(for: .seconds(minSeconds - elapsed))
        }
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
