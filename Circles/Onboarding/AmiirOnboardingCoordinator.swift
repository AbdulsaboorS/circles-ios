import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class AmiirOnboardingCoordinator {

    enum Step: Hashable {
        case sharedPersonalization // Step 1: Circle + personal context
        case coreHabits            // Step 2: Shared habits
        case circleIdentity        // Step 3: Circle identity (name, gender)
        case transitionToAI        // "Some growth is private" gate
        case onboardingQuiz        // Phase 14: Meaningful-Habits quiz
        case momentPrimer          // Moment-mechanic demo + camera priming
        case aiGeneration          // Step 4: AI generation
        case foundation            // Step 5: Location + push ask
        case activation            // Step 6: Auth gate
    }

    // MARK: - Curated Islamic Habits
    static let curatedHabits: [(name: String, icon: String)] = [
        ("Fajr",      "moon.stars.fill"),
        ("Quran",     "book.fill"),
        ("Dhikr",     "circle.grid.3x3.fill"),
        ("Dhuhr",     "sun.max.fill"),
        ("Asr",       "sun.horizon.fill"),
        ("Maghrib",   "sunset.fill"),
        ("Isha",      "moon.fill"),
        ("Sadaqah",   "hands.sparkles.fill"),
        ("Fasting",   "drop.fill"),
        ("Tahajjud",  "sparkles")
    ]

    /// One short generic rationale per curated habit. Renders instantly while Gemini
    /// loads — and stays in place if Gemini times out, so tiles never appear empty.
    static let defaultRationales: [String: String] = [
        "Fajr":     "The hardest prayer to anchor — building it together makes it stick.",
        "Quran":    "A few verses a day keeps your heart turned toward Allah.",
        "Dhikr":    "Small remembrance, repeated, softens the heart through the day.",
        "Dhuhr":    "A midday pause that resets your intention before the rush.",
        "Asr":      "The afternoon prayer the Prophet ﷺ called especially weighty.",
        "Maghrib":  "Closing the day in gratitude as the sun sets together.",
        "Isha":     "Ending the day with your circle keeps you accountable through the night.",
        "Sadaqah":  "Even a small daily gift trains the soul against attachment.",
        "Fasting":  "Voluntary fasts (Mondays/Thursdays) sharpen patience and gratitude.",
        "Tahajjud": "The night prayer is where du'a is answered — beloved practice for the steady."
    ]

    // MARK: - Collected Data
    var preferredName: String = ""
    var circleName: String = ""
    var genderSetting: String = "mixed"   // "mixed" | "brothers" | "sisters"
    var selectedHabits: Set<String> = []         // shared/accountable, max 3
    var selectedPersonalHabits: [String] = []    // personal/private, max 2

    var cityName: String = ""
    var cityTimezone: String = ""
    var cityLatitude: Double = 0
    var cityLongitude: Double = 0

    // Shared-personalization answers (session-only, used for future catalog ranking).
    var spiritualityLevel: String? = nil
    var timeCommitment: String? = nil
    var heartOfCircle: String? = nil

    // Phase 14 Meaningful-Habits struggles (flushed to profiles after auth).
    var strugglesIslamic: [String] = []
    var strugglesLife: [String] = []

    // Habit picked in the quiz — seeded into selectedPersonalHabits and flushed post-auth.
    var quizSelectedHabitName: String? = nil

    // MARK: - Created Entities
    var createdCircle: Circle? = nil
    private(set) var createdHabitsInSession: [Habit] = []

    // MARK: - Routing
    var hasSharedInvite: Bool = false
    var shouldSwitchToJoinerFlow: Bool = false

    // MARK: - Navigation
    var navigationPath: [Step] = []

    // MARK: - State
    var isLoading: Bool = false
    var errorMessage: String? = nil
    private(set) var isComplete: Bool = false

    // MARK: - Computed
    var inviteURL: URL {
        let code = createdCircle?.inviteCode ?? ""
        return URL(string: "https://joinlegacy.app/join/\(code)") ?? URL(string: "https://joinlegacy.app")!
    }

    var canSelectMoreHabits: Bool { selectedHabits.count < 3 }

    // MARK: - Habit Ranking (Step 2 shared-habits screen)

    /// Score a curated habit against the user's step-1 personalization answers.
    /// Higher score = better fit. Source of truth for ranking; the view delegates here
    /// so the rationale-fetch and the rendered list stay in sync.
    private func habitScore(_ habit: (name: String, icon: String)) -> Int {
        var score = 0
        switch spiritualityLevel {
        case "Just starting out":
            if ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"].contains(habit.name) { score += 1 }
        case "Building a foundation":
            if ["Fajr", "Quran", "Dhikr"].contains(habit.name) { score += 1 }
        case "Steady and growing":
            if ["Tahajjud", "Quran", "Sadaqah"].contains(habit.name) { score += 1 }
        case "Deeply rooted":
            if ["Tahajjud", "Sadaqah", "Fasting"].contains(habit.name) { score += 1 }
        default: break
        }
        switch heartOfCircle {
        case "Salah, together":
            if ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"].contains(habit.name) { score += 1 }
        case "Quran in our lives":
            if habit.name == "Quran" { score += 1 }
        case "Remembrance of Allah":
            if habit.name == "Dhikr" { score += 1 }
        case "Brotherhood through hardship":
            if ["Sadaqah", "Fasting"].contains(habit.name) { score += 1 }
        default: break
        }
        switch timeCommitment {
        case "5–10 minutes":
            if ["Tahajjud", "Fasting"].contains(habit.name) { score -= 1 }
        case "More than an hour":
            if ["Tahajjud", "Quran", "Fasting"].contains(habit.name) { score += 1 }
        default: break
        }
        return score
    }

    /// Top-3 ranked curated habits — used by both the Step 2 view and the rationale fetch.
    func rankedTopHabits() -> [(name: String, icon: String)] {
        Self.curatedHabits
            .enumerated()
            .sorted { a, b in
                let sa = habitScore(a.element), sb = habitScore(b.element)
                return sa != sb ? sa > sb : a.offset < b.offset
            }
            .prefix(3)
            .map(\.element)
    }

    // MARK: - Personalized Rationales (Bug #8)

    /// Live Gemini result keyed by exact habit name. Empty until the first load completes.
    /// View renders `habitRationales[name] ?? defaultRationales[name] ?? ""` so the default
    /// covers cold start, timeout, and Gemini-name-mismatch cases.
    var habitRationales: [String: String] = [:]

    /// Fingerprint of the answers + top-3 habit set used for the last *successful* Gemini call.
    /// Mirrors `OnboardingQuizCoordinator.cachedSuggestionsKey` — only set on success.
    private var cachedRationalesKey: String? = nil

    /// Dedupes concurrent calls if the view's `.task` re-fires (e.g. nav back/forward race).
    private var rationalesTask: Task<Void, Never>? = nil

    /// Kicks off (or reuses) a Gemini call for personalized rationales for the top-3 ranked habits.
    /// Pattern copied verbatim from `OnboardingQuizCoordinator.loadSuggestions`: 15s timeout race,
    /// elapsed-time logging, fingerprint cache, only-cache-on-success.
    func loadHabitRationalesIfNeeded() async {
        let topHabits = rankedTopHabits().map(\.name)
        let key = Self.rationalesKey(
            spirituality: spiritualityLevel,
            time: timeCommitment,
            heart: heartOfCircle,
            habits: topHabits
        )

        if key == cachedRationalesKey, !habitRationales.isEmpty {
            print("[Gemini rationales] cache hit — reusing \(habitRationales.count) item(s)")
            return
        }

        // If a load for this same key is already in flight, await it instead of starting a second.
        if let existing = rationalesTask {
            await existing.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.fetchRationales(habits: topHabits, key: key)
        }
        rationalesTask = task
        await task.value
        rationalesTask = nil
    }

    private func fetchRationales(habits: [String], key: String) async {
        let spirit = spiritualityLevel
        let time   = timeCommitment
        let heart  = heartOfCircle

        let raced: [String: String]? = await withTaskGroup(of: [String: String]?.self) { group in
            group.addTask {
                let t0 = Date()
                do {
                    let result = try await GroqService.shared.generateHabitRationales(
                        habits: habits,
                        spiritualityLevel: spirit,
                        timeCommitment: time,
                        heartOfCircle: heart
                    )
                    let ms = Int(Date().timeIntervalSince(t0) * 1000)
                    print("[Groq rationales] ok — \(result.count) item(s) in \(ms)ms")
                    return result
                } catch is CancellationError {
                    return nil
                } catch {
                    if (error as NSError).code == NSURLErrorCancelled { return nil }
                    let ms = Int(Date().timeIntervalSince(t0) * 1000)
                    print("[Groq rationales] error after \(ms)ms — \(error.localizedDescription)")
                    return nil
                }
            }
            group.addTask {
                do {
                    try await Task.sleep(for: .seconds(15.0))
                    print("[Gemini rationales] race timeout fired (15s) — Gemini still in flight")
                } catch {}
                return nil
            }

            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        if let live = raced {
            habitRationales = live
            cachedRationalesKey = key
        } else {
            print("[Gemini rationales] using defaults (timeout or error — see prior log)")
            // Intentionally do NOT update cachedRationalesKey — next entry should retry Gemini.
        }
    }

    private static func rationalesKey(
        spirituality: String?,
        time: String?,
        heart: String?,
        habits: [String]
    ) -> String {
        "\(spirituality ?? "")::\(time ?? "")::\(heart ?? "")::\(habits.joined(separator: "|"))"
    }

    // MARK: - Navigation Helpers
    func proceedToSharedPersonalization() {
        navigationPath.append(.sharedPersonalization)
    }

    func proceedToStruggle() {
        navigationPath.append(.coreHabits)
    }

    func proceedToIdentity() {
        navigationPath.append(.circleIdentity)
    }

    func proceedToTransitionToAI() {
        navigationPath.append(.transitionToAI)
    }

    func proceedToOnboardingQuiz() {
        navigationPath.append(.onboardingQuiz)
    }

    func proceedToMomentPrimer() {
        navigationPath.append(.momentPrimer)
    }

    func proceedToAIGeneration() {
        navigationPath.append(.aiGeneration)
    }

    func proceedToFoundation() {
        navigationPath.append(.foundation)
    }

    func proceedToActivation() {
        savePendingState()
        navigationPath.append(.activation)
    }

    func showJoinFlow() {
        shouldSwitchToJoinerFlow = true
    }

    func fireBackgroundPlans() async {
        // Called from AmiirAIGenerationView — auth hasn't happened yet (auth-last).
        // Real plan creation happens in flushToSupabase after auth succeeds.
        print("[AmiirCoordinator] fireBackgroundPlans — deferred until post-auth flush")
    }

    // MARK: - Post-Auth Flush
    /// Called by ContentView AFTER auth succeeds. Writes everything to Supabase.
    func flushToSupabase(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            // 1. Save location + name to profiles
            try await saveLocation(userId: userId)

            // 2. Create circle
            let circle = try await CircleService.shared.createCircleForAmir(
                name: circleName,
                genderSetting: genderSetting,
                coreHabits: Array(selectedHabits),
                userId: userId
            )
            createdCircle = circle

            // 3. Create accountable habits
            createdHabitsInSession = []
            for habitName in selectedHabits {
                let icon = Self.iconForHabit(habitName)
                if let h = try? await HabitService.shared.createAccountableHabit(
                    userId: userId,
                    name: habitName,
                    icon: icon,
                    circleId: circle.id
                ) {
                    createdHabitsInSession.append(h)
                }
            }

            // 4. Create personal habits
            for habitName in selectedPersonalHabits {
                let icon = Self.iconForHabit(habitName)
                if let h = try? await HabitService.shared.createPrivateHabit(
                    userId: userId,
                    name: habitName,
                    icon: icon,
                    familiarity: "general"
                ) {
                    createdHabitsInSession.append(h)
                }
            }

            // 5. Fire AI roadmap generation (background, non-blocking)
            let habitsForPlan = createdHabitsInSession
            HabitPlanService.setRoadmapGenerating(userId: userId)
            Task {
                for habit in habitsForPlan {
                    await HabitPlanService.shared.ensureAIRoadmapForOnboarding(habit: habit, userId: userId)
                }
                HabitPlanService.clearRoadmapGenerating(userId: userId)
            }

            // 6. Mark complete + clear pending state
            completeOnboarding(userId: userId)
            OnboardingPendingState.clear()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func completeOnboarding(userId: UUID) {
        UserDefaults.standard.set(true, forKey: "onboardingComplete_\(userId.uuidString)")
        UserDefaults.standard.set(true, forKey: "should_show_invite_nudge_\(userId.uuidString)")
        isComplete = true
    }

    // MARK: - Static Helpers
    static func hasCompletedOnboarding(userId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: "onboardingComplete_\(userId.uuidString)")
    }

    /// Returns the SF Symbol name for a habit, checking curated list first then keyword fallback.
    static func iconForHabit(_ name: String) -> String {
        if let curated = curatedHabits.first(where: { $0.name == name }) { return curated.icon }
        let n = name.lowercased()
        if n.contains("quran") || n.contains("qur")                              { return "book.fill" }
        if n.contains("salah") || n.contains("salat") || n.contains("prayer")   { return "building.columns.fill" }
        if n.contains("dhikr") || n.contains("zikr")                            { return "circle.grid.3x3.fill" }
        if n.contains("fast") || n.contains("sawm")                             { return "moon.stars.fill" }
        if n.contains("sadaqah") || n.contains("charity")                       { return "hands.sparkles.fill" }
        if n.contains("tahajjud") || n.contains("night")                        { return "moon.fill" }
        if n.contains("walk") || n.contains("exercise") || n.contains("gym")    { return "figure.walk" }
        if n.contains("journal") || n.contains("write") || n.contains("diary")  { return "note.text" }
        if n.contains("water") || n.contains("drink")                           { return "drop.fill" }
        return "star.fill"
    }

    // MARK: - Private
    private func savePendingState() {
        var state = OnboardingPendingState()
        state.flowType = "amir"
        state.preferredName = preferredName
        state.circleName = circleName
        state.genderSetting = genderSetting
        state.selectedCoreHabits = Array(selectedHabits)
        state.selectedPersonalHabits = selectedPersonalHabits
        state.cityName = cityName
        state.cityTimezone = cityTimezone
        state.cityLatitude = cityLatitude
        state.cityLongitude = cityLongitude
        state.strugglesIslamic = strugglesIslamic
        state.strugglesLife = strugglesLife
        OnboardingPendingState.save(state)
    }

    private func saveLocation(userId: UUID) async throws {
        var updates: [String: AnyJSON] = [
            "city_name":  .string(cityName),
            "latitude":   .double(cityLatitude),
            "longitude":  .double(cityLongitude),
            "timezone":   .string(cityTimezone)
        ]
        let trimmedName = preferredName.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty {
            updates["preferred_name"] = .string(trimmedName)
        }
        if !strugglesIslamic.isEmpty {
            updates["struggles_islamic"] = .array(strugglesIslamic.map { .string($0) })
        }
        if !strugglesLife.isEmpty {
            updates["struggles_life"] = .array(strugglesLife.map { .string($0) })
        }
        try await SupabaseService.shared.client
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()
    }
}
