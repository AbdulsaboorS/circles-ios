import Foundation
import Observation

// SQL Migration — run in Supabase Dashboard before Phase 6 executes:
// ALTER TABLE profiles
//   ADD COLUMN IF NOT EXISTS city_name text,
//   ADD COLUMN IF NOT EXISTS timezone text,
//   ADD COLUMN IF NOT EXISTS latitude double precision,
//   ADD COLUMN IF NOT EXISTS longitude double precision;

// Tracks onboarding step and state. Drives NavigationStack via path.
@Observable
@MainActor
final class OnboardingCoordinator {

    enum Step: Hashable {
        case ramadanAmounts           // after habits selected
        case aiSuggestions            // after amounts entered
        case locationPicker           // after AI step-down (last onboarding step)
    }

    // Habit selection state
    var selectedHabitNames: Set<String> = []
    var customHabitName: String = ""

    // Per-habit Ramadan amounts keyed by habit name (what user did in Ramadan)
    var ramadanAmounts: [String: String] = [:]

    // Per-habit accepted amounts keyed by habit name (what user commits to post-Ramadan).
    // Separate from ramadanAmounts — populated by AIStepDownView after user accepts/edits suggestion.
    var acceptedAmounts: [String: String] = [:]

    // Saved Habit rows after createHabit calls
    var savedHabits: [Habit] = []

    // Location fields (set by LocationPickerView)
    var cityName: String = ""
    var cityTimezone: String = ""   // IANA timezone, e.g. "America/New_York"
    var cityLatitude: Double = 0
    var cityLongitude: Double = 0

    // Navigation
    var navigationPath: [Step] = []

    // Completion flag (stored in UserDefaults for ContentView routing)
    private(set) var isComplete: Bool = false

    // Error propagation
    var errorMessage: String? = nil
    var isSaving: Bool = false

    init() {}

    var canProceedFromSelection: Bool {
        let count = selectedHabitNames.count + (customHabitName.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1)
        return count >= 2 && count <= 5
    }

    func selectHabit(_ name: String) {
        if selectedHabitNames.contains(name) {
            selectedHabitNames.remove(name)
        } else if canAddMore {
            selectedHabitNames.insert(name)
        }
    }

    private var canAddMore: Bool {
        let count = selectedHabitNames.count + (customHabitName.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1)
        return count < 5
    }

    /// All habit names user wants to track (preset selected + custom if non-empty).
    var allSelectedNames: [String] {
        var names = Array(selectedHabitNames)
        let custom = customHabitName.trimmingCharacters(in: .whitespaces)
        if !custom.isEmpty { names.append(custom) }
        return names
    }

    func proceedToAmounts() {
        guard canProceedFromSelection else { return }
        navigationPath.append(.ramadanAmounts)
    }

    func proceedToAI() {
        navigationPath.append(.aiSuggestions)
    }

    func proceedToLocation() {
        navigationPath.append(.locationPicker)
    }

    /// Save all habits to Supabase, then write accepted_amount for each, mark onboarding complete.
    /// Two-step per habit:
    ///   1. createHabit — writes ramadan_amount (what user did in Ramadan)
    ///   2. updateAcceptedAmount — writes accepted_amount + suggested_amount (post-Ramadan commitment)
    func finishOnboarding(userId: UUID) async {
        isSaving = true
        errorMessage = nil
        do {
            var created: [Habit] = []
            for name in allSelectedNames {
                let icon = presetIcon(for: name)
                let ramadanAmount = ramadanAmounts[name] ?? ""
                let habit = try await HabitService.shared.createHabit(
                    userId: userId,
                    name: name,
                    icon: icon,
                    ramadanAmount: ramadanAmount
                )
                // Write the post-Ramadan commitment (accepted_amount) separately.
                // acceptedAmounts[name] is set by AIStepDownView when the user accepts/edits
                // the AI suggestion. Falls back to ramadanAmount if user skipped the AI step.
                let accepted = acceptedAmounts[name] ?? ramadanAmount
                let suggested = acceptedAmounts[name] ?? ramadanAmount // same fallback
                try await HabitService.shared.updateAcceptedAmount(
                    habitId: habit.id,
                    acceptedAmount: accepted,
                    suggestedAmount: suggested
                )
                created.append(habit)
            }
            savedHabits = created
            // Note: markComplete is NOT called here — location picker step calls
            // saveLocationAndMarkComplete() after habits are saved.
            // NavigationStack will push to .locationPicker via proceedToLocation().
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    /// Called by LocationPickerView after city is selected. Upserts location to Supabase profiles,
    /// then marks onboarding complete. Habits must already be saved via finishOnboarding().
    func saveLocationAndMarkComplete(userId: UUID) async {
        isSaving = true
        errorMessage = nil
        do {
            if cityLatitude != 0 {
                try await SupabaseService.shared.client
                    .from("profiles")
                    .upsert([
                        "id": userId.uuidString,
                        "city_name": cityName,
                        "timezone": cityTimezone,
                        "latitude": String(cityLatitude),
                        "longitude": String(cityLongitude)
                    ])
                    .execute()
            }
            markComplete(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    func markComplete(userId: UUID) {
        UserDefaults.standard.set(true, forKey: "onboardingComplete_\(userId.uuidString)")
        isComplete = true
    }

    static func hasCompletedOnboarding(userId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: "onboardingComplete_\(userId.uuidString)")
    }

    var allAmountsEntered: Bool {
        allSelectedNames.allSatisfy { name in
            !(ramadanAmounts[name] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    func presetIcon(for name: String) -> String {
        let map: [String: String] = [
            "Salah": "🕌", "Quran": "📖", "Dhikr": "📿",
            "Fasting": "🌙", "Tahajjud": "⭐", "Sadaqah": "💛", "Dua": "🤲"
        ]
        return map[name] ?? "✨"
    }

    func icon(for name: String) -> String {
        presetIcon(for: name)
    }
}
