import Foundation

/// Persists pre-auth onboarding selections so the auth-last flow can resume after interruption.
struct OnboardingPendingState: Codable {
    var flowType: String = "amir"

    var preferredName: String = ""
    var cityName: String = ""
    var cityTimezone: String = ""
    var cityLatitude: Double = 0
    var cityLongitude: Double = 0
    var selectedPersonalHabits: [String] = []

    var circleName: String = ""
    var genderSetting: String = "mixed"
    var selectedCoreHabits: [String] = []

    var inviteCode: String = ""
    var selectedCircleHabits: [String] = []

    private static let userDefaultsKey = "pending_onboarding_state"

    static func save(_ state: OnboardingPendingState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    static func load() -> OnboardingPendingState? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let state = try? JSONDecoder().decode(OnboardingPendingState.self, from: data) else {
            return nil
        }
        return state
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    static func hasPendingState() -> Bool {
        UserDefaults.standard.data(forKey: userDefaultsKey) != nil
    }
}
