import Foundation
import Observation

/// Drives the four-screen Meaningful Habits quiz (Islamic struggles → Life struggles →
/// Processing → Habit selection). Used in onboarding flows to deterministically
/// surface catalog habits from the user's struggle answers.
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

    /// Single free-text struggle entries — escape hatch when the enum doesn't fit.
    /// Persisted as `custom:<text>` slug alongside enum rawValues so re-entry can split them back.
    var customIslamic: String = ""
    var customLife: String = ""

    /// Ranked catalog result surfaced on the final screen as:
    /// - top 4 personalized picks
    /// - next 3 common starters
    var recommendations = HabitCatalog.Recommendations(top: [], starters: [])
    var isLoadingSuggestions: Bool = false
    var errorMessage: String? = nil
    var allowsMultiSelect: Bool = false
    var selectionCap: Int = HabitCatalog.personalCap
    var spiritualityAnswer: String? = nil
    var rankingSeed: String = ""
    var initialSelectedHabitNames: [String] = []
    /// Names already committed elsewhere in the flow (e.g. shared circle habits)
    /// so the personal screen can't recommend them again. Filtered before ranking.
    var excludedHabitNames: Set<String> = []

    // MARK: - Callbacks (wired by caller)

    /// Called once the user finishes Screen B, before advancing to processing.
    /// Caller decides whether to write directly to Supabase or stage for later flush.
    var onPersistStruggles: ((_ islamic: [String], _ life: [String]) async -> Void)?

    /// Called when the user picks a single habit on Screen D.
    var onFinish: ((_ habitName: String) -> Void)?

    /// Called when the user finishes a multi-select flow (catalog picks + custom entries).
    var onFinishMany: ((_ habitNames: [String]) -> Void)?

    // MARK: - Derived

    var canAdvanceFromIslamic: Bool {
        !selectedIslamic.isEmpty || !customIslamic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var canAdvanceFromLife: Bool {
        !selectedLife.isEmpty || !customLife.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var islamicSlugs: [String] {
        let enums = selectedIslamic.map(\.rawValue)
        let custom = customIslamic.trimmingCharacters(in: .whitespacesAndNewlines)
        return (custom.isEmpty ? enums : enums + ["custom:\(custom)"]).sorted()
    }
    var lifeSlugs: [String] {
        let enums = selectedLife.map(\.rawValue)
        let custom = customLife.trimmingCharacters(in: .whitespacesAndNewlines)
        return (custom.isEmpty ? enums : enums + ["custom:\(custom)"]).sorted()
    }

    var suggestions: [HabitEntry] {
        recommendations.combined
    }

    // MARK: - Advances

    func advanceToLife() {
        guard canAdvanceFromIslamic else { return }
        step = .lifeStruggles
    }

    /// Advances to processing, persists struggles through the caller-provided callback,
    /// then ranks the deterministic catalog suggestions.
    func advanceToProcessing() async {
        guard canAdvanceFromLife else { return }
        step = .processing
        if let onPersistStruggles {
            await onPersistStruggles(islamicSlugs, lifeSlugs)
        }
        await loadSuggestions()
    }

    /// Ranks the catalog from the user's struggle answers. Kept async so the
    /// processing screen still gets a short settling beat before we advance.
    func loadSuggestions() async {
        isLoadingSuggestions = true
        let start = Date()
        defer {
            isLoadingSuggestions = false
            step = .habitSelection
        }

        recommendations = HabitCatalog.recommendations(
            for: .init(
                spirituality: CatalogSpirituality.fromAnswer(spiritualityAnswer),
                islamicStruggles: Set(islamicSlugs),
                lifeStruggles: Set(lifeSlugs),
                excludedNames: excludedHabitNames,
                seed: rankingSeed.isEmpty
                    ? "\(spiritualityAnswer ?? "")::\(islamicSlugs.joined(separator: "|"))::\(lifeSlugs.joined(separator: "|"))"
                    : rankingSeed
            )
        )
        await Self.holdMinimumPulse(since: start)
    }

    /// Ensures the processing-screen pulse completes at least one beat before we transition.
    /// Pulled out so the cache-hit and live-fetch paths share the timing rule.
    private static func holdMinimumPulse(since start: Date) async {
        let elapsed = Date().timeIntervalSince(start)
        let minSeconds: TimeInterval = 1.2
        if elapsed < minSeconds {
            try? await Task.sleep(for: .seconds(minSeconds - elapsed))
        }
    }

    func finish(habitName: String) {
        onFinish?(habitName)
    }

    func finishMany(habitNames: [String]) {
        let trimmed = habitNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return }
        if allowsMultiSelect {
            onFinishMany?(trimmed)
        } else if let first = trimmed.first {
            onFinish?(first)
        }
    }

    /// Re-entry path (Bug 2 — quiz delta). Jumps straight from the delta "Same"
    /// button into processing + habit selection, using the user's previously-saved
    /// struggle slugs. Does not re-persist (caller already has them on file).
    func startFromExistingStruggles(islamicSlugs: [String], lifeSlugs: [String]) async {
        let (islamicEnumSlugs, islamicCustom) = Self.splitCustom(islamicSlugs)
        let (lifeEnumSlugs, lifeCustom)       = Self.splitCustom(lifeSlugs)
        selectedIslamic = Set(islamicEnumSlugs.compactMap(IslamicStruggle.init(rawValue:)))
        selectedLife    = Set(lifeEnumSlugs.compactMap(LifeStruggle.init(rawValue:)))
        customIslamic   = islamicCustom ?? ""
        customLife      = lifeCustom ?? ""
        step = .processing
        await loadSuggestions()
    }

    /// Splits persisted slugs into (enum slugs, first custom string).
    /// Custom slugs are prefixed `custom:` — see `islamicSlugs` / `lifeSlugs`.
    private static func splitCustom(_ slugs: [String]) -> (enums: [String], custom: String?) {
        var enums: [String] = []
        var custom: String? = nil
        for slug in slugs {
            if slug.hasPrefix("custom:") {
                if custom == nil { custom = String(slug.dropFirst("custom:".count)) }
            } else {
                enums.append(slug)
            }
        }
        return (enums, custom)
    }
}
