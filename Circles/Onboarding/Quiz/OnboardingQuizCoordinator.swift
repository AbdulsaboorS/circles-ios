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

    /// Struggle-slug fingerprint of the last *successful* Gemini load. Used to short-circuit
    /// `loadSuggestions()` when the user navigates back-then-forward without changing anything.
    /// Only set on Gemini success — fallback results are not cached, so a transient network
    /// blip never locks the user into the static list for the rest of the session.
    private var cachedSuggestionsKey: String? = nil

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
    /// timeout so the UI does not hang indefinitely. Budget tuned over time:
    /// 3 s was too aggressive (always fell back), 8 s lost to cold-network second
    /// attempts. 15 s is the current ceiling — paired with a `maxOutputTokens`
    /// cap on the Gemini request to bound generation time on the server side.
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
        let key     = Self.suggestionsKey(islamic: islamic, life: life)

        // Cache hit: same struggle set as the last *successful* Gemini call, and we still hold
        // those suggestions. Reuse them instead of re-hitting the API — keeps "back to verify
        // → forward" stable and avoids re-running the 8 s race on a slow second connection.
        if key == cachedSuggestionsKey, !suggestions.isEmpty {
            print("[Gemini suggestions] cache hit — reusing \(suggestions.count) item(s)")
            await Self.holdMinimumPulse(since: start)
            return
        }

        let raced: [HabitSuggestion]? = await withTaskGroup(of: [HabitSuggestion]?.self) { group in
            group.addTask {
                let t0 = Date()
                do {
                    let result = try await GeminiService.shared.generateHabitSuggestions(
                        islamicStruggles: islamic,
                        lifeStruggles: life
                    )
                    let ms = Int(Date().timeIntervalSince(t0) * 1000)
                    print("[Gemini suggestions] ok — \(result.count) item(s) in \(ms)ms")
                    return result
                } catch is CancellationError {
                    return nil
                } catch {
                    // URLSession surfaces task cancellation as NSURLErrorCancelled — suppress
                    // so we don't mistake "sibling timeout won the race" for a real failure.
                    if (error as NSError).code == NSURLErrorCancelled { return nil }
                    let ms = Int(Date().timeIntervalSince(t0) * 1000)
                    print("[Gemini suggestions] error after \(ms)ms — \(error.localizedDescription)")
                    return nil
                }
            }
            group.addTask {
                // Sleep returns normally if uncancelled (= timeout actually fired).
                // Sleep throws CancellationError if Gemini won — silent in that case.
                do {
                    try await Task.sleep(for: .seconds(15.0))
                    print("[Gemini suggestions] race timeout fired (15s) — Gemini still in flight")
                } catch {}
                return nil // timeout sentinel
            }

            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        if let live = raced {
            suggestions = live
            cachedSuggestionsKey = key
        } else {
            print("[Gemini suggestions] using fallback (timeout or error — see prior log)")
            suggestions = HabitSuggestion.fallbackSuggestions
            // Intentionally do NOT update cachedSuggestionsKey — next re-entry should retry Gemini.
        }

        await Self.holdMinimumPulse(since: start)
    }

    /// Stable fingerprint of a struggle selection for cache lookup.
    /// `islamicSlugs` / `lifeSlugs` are already sorted, so this is order-independent by construction.
    private static func suggestionsKey(islamic: [String], life: [String]) -> String {
        "\(islamic.joined(separator: "|"))::\(life.joined(separator: "|"))"
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
