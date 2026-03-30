import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class AmiirOnboardingCoordinator {

    enum Step: Hashable {
        case coreHabits
        case location
        case soulGate
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

    // MARK: - Collected Data
    var circleName: String = ""
    var genderSetting: String = "mixed"   // "mixed" | "brothers" | "sisters"
    var selectedHabits: Set<String> = []  // max 3

    var cityName: String = ""
    var cityTimezone: String = ""
    var cityLatitude: Double = 0
    var cityLongitude: Double = 0

    // MARK: - Created Entities
    var createdCircle: Circle? = nil
    /// Habits created in `createCircleAndProceed` — used for background AI roadmaps.
    private(set) var createdHabitsInSession: [Habit] = []

    // MARK: - Soul Gate
    var hasSharedInvite: Bool = false

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

    // MARK: - Navigation Helpers
    func proceedToHabits() {
        navigationPath.append(.coreHabits)
    }

    func proceedToLocation() {
        navigationPath.append(.location)
    }

    /// Save location → create circle + accountable habits → proceed to Soul Gate.
    func createCircleAndProceed(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            // 1. Save location to profiles
            try await saveLocation(userId: userId)

            // 2. Create the circle
            let circle = try await CircleService.shared.createCircleForAmir(
                name: circleName,
                genderSetting: genderSetting,
                coreHabits: Array(selectedHabits),
                userId: userId
            )
            createdCircle = circle

            // 3. Create accountable habit rows for each selected habit
            createdHabitsInSession = []
            for habitName in selectedHabits {
                let icon = Self.curatedHabits.first { $0.name == habitName }?.icon ?? "star.fill"
                if let h = try? await HabitService.shared.createAccountableHabit(
                    userId: userId,
                    name: habitName,
                    icon: icon,
                    circleId: circle.id
                ) {
                    createdHabitsInSession.append(h)
                }
            }

            navigationPath.append(.soulGate)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Mark onboarding complete. Fire-and-forget 28-day plan generation per created habit.
    func completeOnboarding(userId: UUID) {
        let habits = createdHabitsInSession
        Task {
            for habit in habits {
                await HabitPlanService.shared.ensureAIRoadmapForOnboarding(habit: habit, userId: userId)
            }
        }
        UserDefaults.standard.set(true, forKey: "onboardingComplete_\(userId.uuidString)")
        isComplete = true
    }

    // MARK: - Static Helpers
    static func hasCompletedOnboarding(userId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: "onboardingComplete_\(userId.uuidString)")
    }

    // MARK: - Private
    private func saveLocation(userId: UUID) async throws {
        let updates: [String: AnyJSON] = [
            "city_name":  .string(cityName),
            "latitude":   .double(cityLatitude),
            "longitude":  .double(cityLongitude),
            "timezone":   .string(cityTimezone)
        ]
        try await SupabaseService.shared.client
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()
    }
}
