import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class MemberOnboardingCoordinator {

    enum Step: Hashable {
        case transitionToCircle    // Islamic transition (before circle preview)
        case circleAlignment       // Step 2: Rich circle preview + habit selection
        case personalHabits        // Step 3: Private habits, max 2
        case transitionToAI        // Islamic transition (after personal habits)
        case aiGeneration          // Step 4: Background AI generation
        case identity              // Step 5: Location + push ask
        case authGate              // Step 6: Auth gate
    }

    // MARK: - Input
    var inviteCodeInput: String

    // MARK: - Fetched Data
    var circle: Circle? = nil

    // MARK: - Collected Data
    var selectedCircleHabits: Set<String> = []   // min 1 required
    var selectedPersonalHabits: [String] = []     // max 2
    var preferredName: String = ""
    var cityName: String = ""
    var cityTimezone: String = ""
    var cityLatitude: Double = 0
    var cityLongitude: Double = 0

    // MARK: - Back to Amir flow
    var onBack: (() -> Void)? = nil

    // MARK: - Navigation
    var navigationPath: [Step] = []

    // MARK: - State
    var isLoading: Bool = false
    var errorMessage: String? = nil
    private(set) var isComplete: Bool = false

    /// Default argument keeps ContentView's `MemberOnboardingCoordinator(inviteCode:)` call valid
    /// until Plan 06 updates ContentView to use the no-arg form.
    init(inviteCode: String = "") {
        self.inviteCodeInput = inviteCode
    }

    // MARK: - Invite Code Submission
    func submitInviteCode(_ code: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a valid invite code."
            return
        }
        isLoading = true
        errorMessage = nil
        inviteCodeInput = trimmed
        defer { isLoading = false }
        do {
            circle = try await CircleService.shared.fetchCircleByCode(trimmed)
            if navigationPath.last != .transitionToCircle {
                navigationPath.append(.transitionToCircle)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Navigation Helpers
    func proceedToCircleAlignment() {
        navigationPath.append(.circleAlignment)
    }

    func proceedToPersonalHabits() {
        navigationPath.append(.personalHabits)
    }

    func proceedToTransitionToAI() {
        navigationPath.append(.transitionToAI)
    }

    func proceedToAIGeneration() {
        navigationPath.append(.aiGeneration)
    }

    func proceedToIdentity() {
        navigationPath.append(.identity)
    }

    func proceedToAuthGate() {
        savePendingState()
        navigationPath.append(.authGate)
    }

    func fireBackgroundPlans() async {
        // Called from JoinerAIGenerationView — auth hasn't happened yet (auth-last).
        // Real plan creation happens in flushToSupabase after auth succeeds.
        print("[MemberCoordinator] fireBackgroundPlans — deferred until post-auth flush")
    }

    // MARK: - Post-Auth Flush
    /// Called by ContentView AFTER auth succeeds. Writes everything to Supabase.
    func flushToSupabase(userId: UUID) async {
        guard let circle else {
            errorMessage = "Circle data missing."
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            // 1. Save location + name to profiles
            try await saveLocation(userId: userId)

            // 2. Join circle
            _ = try await CircleService.shared.joinByInviteCode(inviteCodeInput, userId: userId)

            // 3. Create accountable habits
            var created: [Habit] = []
            for habitName in selectedCircleHabits {
                let icon = AmiirOnboardingCoordinator.iconForHabit(habitName)
                if let h = try? await HabitService.shared.createAccountableHabit(
                    userId: userId,
                    name: habitName,
                    icon: icon,
                    circleId: circle.id
                ) { created.append(h) }
            }

            // 4. Create personal habits
            for habitName in selectedPersonalHabits {
                let icon = AmiirOnboardingCoordinator.iconForHabit(habitName)
                _ = try? await HabitService.shared.createPrivateHabit(
                    userId: userId,
                    name: habitName,
                    icon: icon,
                    familiarity: "general"
                )
            }

            // 5. Fire AI plans (background, non-blocking)
            let habitsForPlan = created
            RoadmapGenerationFlag.set(userId: userId)
            Task {
                for habit in habitsForPlan {
                    await HabitPlanService.shared.ensureAIRoadmapForOnboarding(habit: habit, userId: userId)
                }
                RoadmapGenerationFlag.clear(userId: userId)
            }

            // 6. Complete + clear pending state
            completeOnboarding(userId: userId)
            OnboardingPendingState.clear()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func completeOnboarding(userId: UUID) {
        UserDefaults.standard.set(true, forKey: "onboardingComplete_\(userId.uuidString)")
        isComplete = true
    }

    // MARK: - Legacy
    /// Kept for backward compat with ContentView pre-Plan-06. Uses inviteCodeInput already set.
    func loadCircle() async {
        guard !inviteCodeInput.isEmpty else { return }
        isLoading = true
        circle = try? await CircleService.shared.fetchCircleByCode(inviteCodeInput)
        isLoading = false
    }

    // MARK: - Private
    private func savePendingState() {
        var state = OnboardingPendingState()
        state.flowType = "member"
        state.inviteCode = inviteCodeInput
        state.preferredName = preferredName
        state.selectedCircleHabits = Array(selectedCircleHabits)
        state.selectedPersonalHabits = selectedPersonalHabits
        state.cityName = cityName
        state.cityTimezone = cityTimezone
        state.cityLatitude = cityLatitude
        state.cityLongitude = cityLongitude
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
        try await SupabaseService.shared.client
            .from("profiles")
            .update(updates)
            .eq("id", value: userId.uuidString)
            .execute()
    }
}
