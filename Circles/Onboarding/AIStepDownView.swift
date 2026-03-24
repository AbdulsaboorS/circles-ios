import SwiftUI
import Supabase

struct AIStepDownView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(AuthManager.self) private var auth

    // Local state: suggestions keyed by habit name
    @State private var suggestions: [String: AISuggestion] = [:]
    @State private var loadingNames: Set<String> = []
    // The user's accepted/edited goal per habit — written to coordinator.acceptedAmounts on save.
    // NEVER overwrites coordinator.ramadanAmounts (that is Ramadan history, not post-Ramadan goal).
    @State private var acceptedAmounts: [String: String] = [:]
    @State private var fetchErrors: [String: String] = [:]

    var body: some View {
        @Bindable var coord = coordinator
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Your Post-Ramadan Plan")
                        .font(.title2.bold())
                        .padding(.top)

                    ForEach(coordinator.allSelectedNames, id: \.self) { name in
                        SuggestionCard(
                            habitName: name,
                            icon: coordinator.presetIcon(for: name),
                            suggestion: suggestions[name],
                            isLoading: loadingNames.contains(name),
                            fetchError: fetchErrors[name],
                            acceptedAmount: Binding(
                                get: { acceptedAmounts[name] ?? suggestions[name]?.suggestedAmount ?? "" },
                                set: { acceptedAmounts[name] = $0 }
                            )
                        )
                    }

                    Button("Save My Habits") {
                        guard let userId = auth.session?.user.id else { return }
                        // Persist accepted amounts to coordinator before saving.
                        // acceptedAmounts[name] holds what user typed/accepted in this view.
                        // Falls back to suggestedAmount or ramadanAmount if not edited.
                        for name in coordinator.allSelectedNames {
                            coordinator.acceptedAmounts[name] = acceptedAmounts[name]
                                ?? suggestions[name]?.suggestedAmount
                                ?? coordinator.ramadanAmounts[name]
                                ?? ""
                        }
                        Task {
                            await coordinator.finishOnboarding(userId: userId)
                            // Advance to city/location picker (last onboarding step)
                            if coordinator.errorMessage == nil {
                                coordinator.proceedToLocation()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(coordinator.isSaving || !allSuggestionsLoaded)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal)
            }

            if coordinator.isSaving {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView("Saving...").tint(.white)
            }
        }
        .navigationTitle("AI Suggestions")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(coordinator.errorMessage != nil)) {
            Button("OK") { coordinator.errorMessage = nil }
        } message: {
            Text(coordinator.errorMessage ?? "")
        }
        .task {
            await fetchAllSuggestions()
        }
    }

    private var allSuggestionsLoaded: Bool {
        coordinator.allSelectedNames.allSatisfy { suggestions[$0] != nil || fetchErrors[$0] != nil }
    }

    private func fetchAllSuggestions() async {
        // Capture coordinator state on MainActor before entering task group
        // (coordinator is @MainActor — cannot access its properties from non-isolated tasks)
        let habitNames = coordinator.allSelectedNames
        let ramadanAmountsCopy = coordinator.ramadanAmounts

        await withTaskGroup(of: Void.self) { group in
            for name in habitNames {
                guard suggestions[name] == nil else { continue }
                let amount = ramadanAmountsCopy[name] ?? ""
                group.addTask {
                    await MainActor.run { loadingNames.insert(name) }
                    do {
                        let suggestion = try await GeminiService.shared.fetchSuggestion(
                            habitName: name,
                            ramadanAmount: amount
                        )
                        await MainActor.run {
                            suggestions[name] = suggestion
                            // Pre-fill acceptedAmounts with the AI suggestion.
                            // User can edit before saving; this is just the default.
                            if acceptedAmounts[name] == nil {
                                acceptedAmounts[name] = suggestion.suggestedAmount
                            }
                            loadingNames.remove(name)
                        }
                    } catch {
                        await MainActor.run {
                            fetchErrors[name] = error.localizedDescription
                            loadingNames.remove(name)
                        }
                    }
                }
            }
        }
    }
}

private struct SuggestionCard: View {
    let habitName: String
    let icon: String
    let suggestion: AISuggestion?
    let isLoading: Bool
    let fetchError: String?
    @Binding var acceptedAmount: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(icon).font(.title2)
                Text(habitName).font(.headline)
                Spacer()
                if isLoading { ProgressView().scaleEffect(0.8) }
            }

            if let error = fetchError {
                Text("Could not load suggestion: \(error)")
                    .font(.caption).foregroundStyle(.red)
            } else if let s = suggestion {
                Text(s.motivation)
                    .font(.subheadline).italic().foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggested daily goal").font(.caption).foregroundStyle(.secondary)
                    TextField("Daily goal", text: $acceptedAmount)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.bold())
                }

                Text(s.tip).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
