import SwiftUI
import Supabase

struct ContentView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(ThemeManager.self) private var themeManager
    @State private var onboardingCoordinator = OnboardingCoordinator()

    var body: some View {
        Group {
            if auth.isLoading {
                ZStack {
                    Color(hex: "0D1021").ignoresSafeArea()
                    ProgressView()
                        .tint(Color(hex: "E8834B"))
                        .scaleEffect(1.5)
                }
            } else if !auth.isAuthenticated {
                AuthView()
            } else if let userId = auth.session?.user.id,
                      !OnboardingCoordinator.hasCompletedOnboarding(userId: userId),
                      !onboardingCoordinator.isComplete {
                NavigationStack(path: Binding(
                    get: { onboardingCoordinator.navigationPath },
                    set: { onboardingCoordinator.navigationPath = $0 }
                )) {
                    ProfileSetupView()
                        .navigationDestination(for: OnboardingCoordinator.Step.self) { step in
                            switch step {
                            case .habitSelection:
                                HabitSelectionView()
                            case .ramadanAmounts:
                                RamadanAmountView()
                            case .aiSuggestions:
                                AIStepDownView()
                            case .locationPicker:
                                LocationPickerView()
                            }
                        }
                }
                .environment(onboardingCoordinator)
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }
}
