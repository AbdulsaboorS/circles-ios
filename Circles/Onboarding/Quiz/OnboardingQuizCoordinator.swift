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

    /// Single free-text struggle entries — escape hatch when the enum doesn't fit.
    /// Persisted as `custom:<text>` slug alongside enum rawValues so re-entry can split them back.
    var customIslamic: String = ""
    var customLife: String = ""

    /// Populated by `loadSuggestions()` from Gemini, or `HabitSuggestion.fallbackSuggestions`
    /// when Gemini is unreachable / malformed.
    var suggestions: [HabitSuggestion] = []
    var isLoadingSuggestions: Bool = false

    var errorMessage: String? = nil
    var allowsMultiSelect: Bool = false

    // MARK: - Callbacks (wired by caller)

    /// Called once the user finishes Screen B, before advancing to processing.
    /// Caller decides whether to write directly to Supabase or stage for later flush.
    var onPersistStruggles: ((_ islamic: [String], _ life: [String]) async -> Void)?

    /// Called when the user picks a single habit on Screen D (or a custom name).
    /// `suggestion` is nil for custom entries; `customName` carries the typed name.
    var onFinish: ((_ suggestion: HabitSuggestion?, _ customName: String?) -> Void)?

    /// Called when the user picks multiple habits (multi-select intercept path only).
    var onFinishMany: ((_ suggestions: [HabitSuggestion], _ customName: String?) -> Void)?

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

    /// Populates `suggestions` from Gemini, racing the call against a bounded
    /// timeout so the UI does not hang indefinitely. The previous 3 s cap was
    /// too aggressive and routinely forced the static fallback list even when
    /// Gemini was healthy, so we give the model a more realistic response window.
    /// Enforces a 1.2 s minimum so the pulse cycle completes one beat.
    func loadSuggestions() async {
        isLoadingSuggestions = true
        let start = Date()
        defer {
            isLoadingSuggestions = false
            step = .habitSelection
        }

        let islamic = islamicSlugs
        let life    = lifeSlugs

        let raced: [HabitSuggestion]? = await withTaskGroup(of: [HabitSuggestion]?.self) { group in
            group.addTask {
                do {
                    return try await GeminiService.shared.generateHabitSuggestions(
                        islamicStruggles: islamic,
                        lifeStruggles: life
                    )
                } catch {
                    return nil
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(8.0))
                return nil // timeout sentinel
            }

            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        suggestions = raced ?? HabitSuggestion.fallbackSuggestions

        let elapsed = Date().timeIntervalSince(start)
        let minSeconds: TimeInterval = 1.2
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
