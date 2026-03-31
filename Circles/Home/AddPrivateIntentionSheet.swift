import SwiftUI
import Supabase

// MARK: - Midnight Sanctuary tokens

private extension Color {
    static let msBackground  = Color(hex: "1A2E1E")
    static let msCardShared  = Color(hex: "243828")
    static let msCardDeep    = Color(hex: "1E3122")
    static let msGold        = Color(hex: "D4A240")
    static let msTextPrimary = Color(hex: "F0EAD6")
    static let msTextMuted   = Color(hex: "8FAF94")
    static let msBorder      = Color(hex: "D4A240").opacity(0.18)
}

// MARK: - Sheet coordinator

@Observable
@MainActor
private final class AddIntentionCoordinator {

    enum Step { case pickHabit, familiarity, generating }

    var step: Step = .pickHabit

    // Step 1
    var selectedName: String = ""
    var selectedIcon: String = "leaf.fill"
    var customName: String = ""
    var showCustomField = false

    // Step 2
    var familiarity: String = ""     // "Just starting" | "Some experience" | "Very familiar"
    static let familiarityOptions = ["Just starting", "Some experience", "Very familiar"]

    // Step 3 / result
    var createdHabit: Habit?
    var isGenerating = false
    var planDone = false
    var errorMessage: String?

    func selectCurated(name: String, icon: String) {
        selectedName = name
        selectedIcon = icon
        showCustomField = false
    }

    func resolvedName() -> String {
        showCustomField ? customName.trimmingCharacters(in: .whitespacesAndNewlines) : selectedName
    }

    func resolvedIcon() -> String {
        if showCustomField { return habitSymbol(for: customName) }
        return selectedIcon
    }

    func canProceedFromPick() -> Bool {
        let name = resolvedName()
        return !name.isEmpty
    }

    func createAndGenerate(userId: UUID) async {
        let name = resolvedName()
        let icon = resolvedIcon()
        isGenerating = true
        planDone = false
        errorMessage = nil
        do {
            let habit = try await HabitService.shared.createPrivateHabit(
                userId: userId, name: name, icon: icon, familiarity: familiarity
            )
            createdHabit = habit
            let milestones = try await GeminiService.shared.generate28DayRoadmap(
                habitName: habit.name,
                planNotes: habit.planNotes,
                userRefinementRequest: nil
            )
            _ = try await HabitPlanService.shared.upsertInitialPlan(
                habitId: habit.id, userId: userId, milestones: milestones
            )
            planDone = true
        } catch {
            errorMessage = HabitPlanService.userFacingMessage(from: error)
        }
        isGenerating = false
    }
}

// MARK: - Public sheet

struct AddPrivateIntentionSheet: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    var onCreated: (Habit) -> Void   // called when user taps "Open" or after plan finishes

    @State private var coord = AddIntentionCoordinator()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.msBackground.ignoresSafeArea()
                content
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.msGold)
                }
            }
            .alert("Error", isPresented: .constant(coord.errorMessage != nil)) {
                Button("OK") { coord.errorMessage = nil }
            } message: {
                Text(coord.errorMessage ?? "")
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var content: some View {
        switch coord.step {
        case .pickHabit:  pickHabitStep
        case .familiarity: familiarityStep
        case .generating: generatingStep
        }
    }

    // MARK: Step 1 — pick habit

    private var pickHabitStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 20)

                    VStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.msGold)
                        Text("Private Intention")
                            .font(.appTitle)
                            .foregroundStyle(Color.msTextPrimary)
                        Text("Just between you and Allah.")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                    }
                    .padding(.horizontal, 24)

                    // Curated grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(AmiirOnboardingCoordinator.curatedHabits, id: \.name) { habit in
                            let isSelected = !coord.showCustomField && coord.selectedName == habit.name
                            Button {
                                coord.selectCurated(name: habit.name, icon: habit.icon)
                            } label: {
                                HabitPickTile(name: habit.name, icon: habit.icon, isSelected: isSelected)
                            }
                            .buttonStyle(.plain)
                        }

                        // Custom tile
                        let customSelected = coord.showCustomField
                        Button {
                            coord.showCustomField = true
                            coord.selectedName = ""
                        } label: {
                            HabitPickTile(
                                name: customSelected ? (coord.customName.isEmpty ? "Custom…" : coord.customName) : "Custom",
                                icon: customSelected ? habitSymbol(for: coord.customName) : "plus.circle.fill",
                                isSelected: customSelected
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)

                    // Custom text field (shown when custom tile selected)
                    if coord.showCustomField {
                        TextField("e.g. Morning walk, Journaling…", text: $coord.customName)
                            .foregroundStyle(Color.msTextPrimary)
                            .padding(14)
                            .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.msGold.opacity(0.4), lineWidth: 1))
                            .tint(Color.msGold)
                            .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 24)
                }
            }

            continueButton(enabled: coord.canProceedFromPick()) {
                coord.step = .familiarity
            }
            .padding(20)
        }
    }

    // MARK: Step 2 — familiarity

    private var familiarityStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 20)

                    VStack(spacing: 10) {
                        Image(systemName: coord.resolvedIcon())
                            .font(.system(size: 44))
                            .foregroundStyle(Color.msGold)
                        Text(coord.resolvedName())
                            .font(.appTitle)
                            .foregroundStyle(Color.msTextPrimary)
                        Text("Where are you with this habit?")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        ForEach(AddIntentionCoordinator.familiarityOptions, id: \.self) { option in
                            let isSelected = coord.familiarity == option
                            Button {
                                coord.familiarity = option
                            } label: {
                                HStack {
                                    Text(option)
                                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                                        .foregroundStyle(isSelected ? Color.msBackground : Color.msTextPrimary)
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color.msBackground)
                                    }
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(isSelected ? Color.msGold : Color.msCardShared)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(isSelected ? Color.clear : Color.msBorder, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 24)
                }
            }

            continueButton(enabled: !coord.familiarity.isEmpty) {
                guard let userId = auth.session?.user.id else { return }
                coord.step = .generating
                Task { await coord.createAndGenerate(userId: userId) }
            }
            .padding(20)
        }
    }

    // MARK: Step 3 — generating / done

    private var generatingStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: coord.resolvedIcon())
                .font(.system(size: 56))
                .foregroundStyle(Color.msGold)

            if coord.isGenerating {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(Color.msGold)
                        .scaleEffect(1.4)
                    Text("Building your 28-day roadmap…")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextPrimary)
                    Text("This usually takes 10–20 seconds.")
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)
                }
            } else if coord.planDone {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.msGold)
                    Text("Your roadmap is ready!")
                        .font(.appTitle)
                        .foregroundStyle(Color.msTextPrimary)
                    Text("Tap below to start your journey.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                }
            } else {
                // Plan failed but habit was created
                VStack(spacing: 10) {
                    Text("Intention created!")
                        .font(.appTitle)
                        .foregroundStyle(Color.msTextPrimary)
                    Text("The AI plan didn't generate — you can try from the habit card later.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                if let habit = coord.createdHabit {
                    Button {
                        onCreated(habit)
                        dismiss()
                    } label: {
                        Text(coord.planDone ? "Open Roadmap" : "Open Habit")
                            .font(.appSubheadline.weight(.semibold))
                            .foregroundStyle(Color.msBackground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.msGold)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(coord.isGenerating)
                }

                if coord.isGenerating, let habit = coord.createdHabit {
                    Button {
                        onCreated(habit)
                        dismiss()
                    } label: {
                        Text("Come back later")
                            .font(.appCaption)
                            .foregroundStyle(Color.msTextMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: Shared CTA button

    private func continueButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Continue")
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(Color.msBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(enabled ? Color.msGold : Color.msGold.opacity(0.4))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Habit pick tile (reusable in this file)

private struct HabitPickTile: View {
    let name: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(isSelected ? Color(hex: "1A2E1E") : Color(hex: "D4A240"))
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color(hex: "1A2E1E") : Color(hex: "F0EAD6"))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color(hex: "D4A240") : Color(hex: "243828"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.clear : Color(hex: "D4A240").opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Icon helper (matches HomeView helper)

private func habitSymbol(for name: String) -> String {
    let n = name.lowercased()
    if n.contains("quran") || n.contains("qur")                             { return "book.fill" }
    if n.contains("salah") || n.contains("salat") || n.contains("prayer")  { return "building.columns.fill" }
    if n.contains("dhikr") || n.contains("zikr")                           { return "circle.grid.3x3.fill" }
    if n.contains("fast") || n.contains("sawm")                            { return "moon.stars.fill" }
    if n.contains("sadaqah") || n.contains("charity")                      { return "hands.sparkles.fill" }
    if n.contains("tahajjud") || n.contains("night")                       { return "moon.fill" }
    if n.contains("walk") || n.contains("exercise") || n.contains("gym")   { return "figure.walk" }
    if n.contains("journal") || n.contains("write") || n.contains("diary") { return "note.text" }
    if n.contains("sleep") || n.contains("rest")                           { return "bed.double.fill" }
    if n.contains("water") || n.contains("drink")                          { return "drop.fill" }
    return "leaf.fill"
}
