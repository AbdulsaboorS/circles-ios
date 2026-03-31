import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class MemberOnboardingCoordinator {

    enum Step: Hashable {
        case habitAlignment
        case location
    }

    // MARK: - Input
    let inviteCode: String

    // MARK: - Fetched Data
    var circle: Circle? = nil

    // MARK: - Collected Data
    var selectedHabits: Set<String> = []
    var cityName: String = ""
    var cityTimezone: String = ""
    var cityLatitude: Double = 0
    var cityLongitude: Double = 0

    // MARK: - Navigation
    var navigationPath: [Step] = []

    // MARK: - State
    var isLoading: Bool = false
    var errorMessage: String? = nil
    private(set) var isComplete: Bool = false

    init(inviteCode: String) {
        self.inviteCode = inviteCode
    }

    // MARK: - Navigation
    func proceedToLocation() {
        navigationPath.append(.location)
    }

    /// Join circle + create accountable habits + save location → complete
    func joinAndComplete(userId: UUID) async {
        guard let circle = circle else {
            errorMessage = "Circle data missing. Please try again."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            // 1. Save location
            try await saveLocation(userId: userId)

            // 2. Join the circle
            _ = try await CircleService.shared.joinByInviteCode(inviteCode, userId: userId)

            // 3. Create accountable habits linked to this circle
            var created: [Habit] = []
            for habitName in selectedHabits {
                let icon = AmiirOnboardingCoordinator.iconForHabit(habitName)
                if let h = try? await HabitService.shared.createAccountableHabit(
                    userId: userId,
                    name: habitName,
                    icon: icon,
                    circleId: circle.id
                ) {
                    created.append(h)
                }
            }

            completeOnboarding(userId: userId, habitsForRoadmap: created)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func completeOnboarding(userId: UUID, habitsForRoadmap: [Habit] = []) {
        let habits = habitsForRoadmap
        Task {
            for habit in habits {
                await HabitPlanService.shared.ensureAIRoadmapForOnboarding(habit: habit, userId: userId)
            }
        }
        UserDefaults.standard.set(true, forKey: "onboardingComplete_\(userId.uuidString)")
        isComplete = true
    }

    // MARK: - Fetch circle on entry
    func loadCircle() async {
        isLoading = true
        circle = try? await CircleService.shared.fetchCircleByCode(inviteCode)
        isLoading = false
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
