import SwiftUI
import Supabase

// MARK: - Sheet coordinator

/// Captures a single habit's user input while we're queuing up multiple habits
/// from the multi-select intercept path. One spec per habit, then `createAndGenerateAll`
/// creates + roadmaps each in sequence.
private struct PendingHabitSpec {
    let name: String
    let icon: String
    let niyyah: String?
    let familiarity: String
}

@Observable
@MainActor
private final class AddIntentionCoordinator {

    enum Step { case quizDelta, quizIntercept, pickHabit, niyyah, familiarity, generating }

    var step: Step = .pickHabit

    /// True while we're checking whether the user has completed the Phase 14 quiz.
    /// Keeps us from flashing `pickHabit` before the gate decision is made.
    var isResolvingGate: Bool = true

    // Step 1
    var selectedName: String = ""
    var selectedIcon: String = "leaf.fill"
    var customName: String = ""
    var showCustomField = false

    // Step 1.5 — niyyah (optional; blank means "skip")
    var niyyah: String = ""

    // Step 2
    var familiarity: String = ""     // "Just starting" | "Some experience" | "Very familiar"
    static let familiarityOptions = ["Just starting", "Some experience", "Very familiar"]

    // Step 3 / result
    var createdHabit: Habit?
    var createdHabits: [Habit] = []
    var isGenerating = false
    var planDone = false
    var errorMessage: String?
    var generatingProgressText: String = ""

    // Multi-create queue (Bug 1 — multi-select intercept path)
    var pendingQueue: [HabitSuggestion] = []
    var pendingIndex: Int = 0
    var collectedSpecs: [PendingHabitSpec] = []

    var multiProgressLabel: String? {
        guard pendingQueue.count > 1 else { return nil }
        return "Habit \(pendingIndex + 1) of \(pendingQueue.count)"
    }

    // Saved struggles (Bug 2 — quiz delta re-entry)
    var savedStrugglesIslamic: [String] = []
    var savedStrugglesLife: [String] = []

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

    var trimmedNiyyah: String? {
        let t = niyyah.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    func createAndGenerate(userId: UUID) async {
        let name = resolvedName()
        let icon = resolvedIcon()
        let niyyahValue = trimmedNiyyah
        isGenerating = true
        planDone = false
        errorMessage = nil
        do {
            let habit = try await HabitService.shared.createPrivateHabit(
                userId: userId,
                name: name,
                icon: icon,
                familiarity: familiarity,
                niyyah: niyyahValue
            )
            createdHabit = habit

            // Fold niyyah into plan_notes just for the prompt so Gemini's roadmap tone
            // reflects the user's intention. We don't persist the combined string.
            let promptNotes: String? = {
                switch (habit.planNotes, niyyahValue) {
                case let (notes?, niy?): return "\(notes)\nNiyyah: \(niy)"
                case let (notes?, nil):  return notes
                case let (nil, niy?):    return "Niyyah: \(niy)"
                case (nil, nil):         return nil
                }
            }()

            let milestones = try await GeminiService.shared.generate28DayRoadmap(
                habitName: habit.name,
                planNotes: promptNotes,
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

    /// Creates + generates roadmaps for every habit in `collectedSpecs` sequentially.
    /// Continues on partial failure so one bad roadmap doesn't block the rest.
    func createAndGenerateAll(userId: UUID) async {
        let specs = collectedSpecs
        guard !specs.isEmpty else {
            await createAndGenerate(userId: userId)
            return
        }
        isGenerating = true
        planDone = false
        errorMessage = nil
        var created: [Habit] = []
        for (i, spec) in specs.enumerated() {
            generatingProgressText = "Building roadmaps… (\(i + 1)/\(specs.count))"
            do {
                let habit = try await HabitService.shared.createPrivateHabit(
                    userId: userId,
                    name: spec.name,
                    icon: spec.icon,
                    familiarity: spec.familiarity,
                    niyyah: spec.niyyah
                )
                created.append(habit)
                let promptNotes: String? = {
                    switch (habit.planNotes, spec.niyyah) {
                    case let (notes?, niy?): return "\(notes)\nNiyyah: \(niy)"
                    case let (notes?, nil):  return notes
                    case let (nil, niy?):    return "Niyyah: \(niy)"
                    case (nil, nil):         return nil
                    }
                }()
                let milestones = try await GeminiService.shared.generate28DayRoadmap(
                    habitName: habit.name,
                    planNotes: promptNotes,
                    userRefinementRequest: nil
                )
                _ = try await HabitPlanService.shared.upsertInitialPlan(
                    habitId: habit.id, userId: userId, milestones: milestones
                )
            } catch {
                // Continue queue on partial failure.
            }
        }
        createdHabits = created
        createdHabit = created.first
        planDone = !created.isEmpty
        isGenerating = false
    }
}

// MARK: - Public sheet

struct AddPrivateIntentionSheet: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    var onCreated: (Habit) -> Void   // called when user taps "Open" or after plan finishes

    @State private var coord = AddIntentionCoordinator()
    @State private var quizCoordinator = OnboardingQuizCoordinator()

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
            .task { await resolveQuizGate() }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var content: some View {
        if coord.isResolvingGate {
            gateResolvingStep
        } else {
            switch coord.step {
            case .quizDelta:     quizDeltaStep
            case .quizIntercept: quizInterceptStep
            case .pickHabit:     pickHabitStep
            case .niyyah:        niyyahStep
            case .familiarity:   familiarityStep
            case .generating:    generatingStep
            }
        }
    }

    private var gateResolvingStep: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView().tint(Color.msGold).scaleEffect(1.2)
            Spacer()
        }
    }

    private var quizInterceptStep: some View {
        OnboardingQuizFlowView(coordinator: quizCoordinator)
    }

    // MARK: Quiz delta (re-entry)

    /// Shown for returning users who already have struggles saved. Gives them a
    /// "Same" button (skip A+B, jump to processing+selection) or "Changed"
    /// (run the full quiz again, overwriting struggles).
    private var quizDeltaStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 24)

                    VStack(spacing: 10) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.msGold)
                        Text("Still the same?")
                            .font(.system(size: 28, weight: .regular, design: .serif))
                            .foregroundStyle(Color.msTextPrimary)
                        Text("Here's what you shared last time.")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    let chipLabels = savedStruggleLabels()
                    if !chipLabels.isEmpty {
                        let cols = [GridItem(.adaptive(minimum: 100, maximum: 220))]
                        LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
                            ForEach(chipLabels, id: \.self) { label in
                                Text(label)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.msTextPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.msCardShared, in: Capsule())
                                    .overlay(Capsule().stroke(Color.msBorder, lineWidth: 1))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 24)
                }
            }

            VStack(spacing: 12) {
                Button {
                    guard let userId = auth.session?.user.id else { return }
                    configureInterceptQuiz(userId: userId)
                    coord.step = .quizIntercept
                    Task {
                        await quizCoordinator.startFromExistingStruggles(
                            islamicSlugs: coord.savedStrugglesIslamic,
                            lifeSlugs: coord.savedStrugglesLife
                        )
                    }
                } label: {
                    Text("Same — show me habits")
                        .font(.appSubheadline.weight(.semibold))
                        .foregroundStyle(Color.msBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.msGold)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    guard let userId = auth.session?.user.id else { return }
                    // Full quiz from Screen A. Fresh coordinator so stale
                    // state can't leak from a previous visit.
                    quizCoordinator = OnboardingQuizCoordinator()
                    configureInterceptQuiz(userId: userId)
                    coord.step = .quizIntercept
                } label: {
                    Text("Things have changed")
                        .font(.appSubheadline.weight(.medium))
                        .foregroundStyle(Color.msGold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.msGold.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.msGold.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func savedStruggleLabels() -> [String] {
        let islamic = coord.savedStrugglesIslamic.compactMap { IslamicStruggle(rawValue: $0)?.label }
        let life    = coord.savedStrugglesLife.compactMap   { LifeStruggle(rawValue: $0)?.label }
        return islamic + life
    }

    // MARK: Quiz gate

    /// First-time users (no saved struggles) go straight into the intercept quiz.
    /// Returning users see a "delta" screen with their previous answers so they
    /// can confirm "Same" (skip A+B, go to processing+selection) or "Changed"
    /// (rerun the full quiz, overwriting struggles on finish).
    private func resolveQuizGate() async {
        guard let userId = auth.session?.user.id else {
            coord.isResolvingGate = false
            return
        }
        let (islamic, life) = await loadSavedStruggles(userId: userId)
        if islamic.isEmpty && life.isEmpty {
            configureInterceptQuiz(userId: userId)
            coord.step = .quizIntercept
        } else {
            coord.savedStrugglesIslamic = islamic
            coord.savedStrugglesLife    = life
            coord.step = .quizDelta
        }
        coord.isResolvingGate = false
    }

    private func loadSavedStruggles(userId: UUID) async -> ([String], [String]) {
        do {
            let profile: Profile = try await SupabaseService.shared.client
                .from("profiles")
                .select("id,struggles_islamic,struggles_life")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            return (profile.strugglesIslamic ?? [], profile.strugglesLife ?? [])
        } catch {
            return ([], [])
        }
    }

    private func configureInterceptQuiz(userId: UUID) {
        quizCoordinator.allowsMultiSelect = true
        quizCoordinator.onPersistStruggles = { islamic, life in
            await saveStrugglesToProfile(userId: userId, islamic: islamic, life: life)
        }
        quizCoordinator.onFinish = { suggestion, custom in
            let picked = suggestion?.name ?? custom
            if let picked, !picked.isEmpty {
                coord.showCustomField = true
                coord.customName = picked
                coord.selectedName = ""
                coord.step = .niyyah      // name already chosen — skip pickHabit
            } else {
                coord.step = .pickHabit   // defensive fallback
            }
        }
        quizCoordinator.onFinishMany = { suggestions, _ in
            beginPerHabitQueue(suggestions: suggestions)
        }
    }

    /// Seeds the per-habit niyyah/familiarity queue after the user multi-selects on Screen D.
    /// First suggestion pre-populates the coord; subsequent ones swap in on each Continue.
    private func beginPerHabitQueue(suggestions: [HabitSuggestion]) {
        guard !suggestions.isEmpty else {
            coord.step = .pickHabit
            return
        }
        coord.pendingQueue = suggestions
        coord.pendingIndex = 0
        coord.collectedSpecs = []
        let first = suggestions[0]
        coord.selectedName = first.name
        coord.showCustomField = false
        coord.selectedIcon = habitSymbol(for: first.name)
        coord.niyyah = ""
        coord.familiarity = ""
        coord.step = .niyyah
    }

    private func saveStrugglesToProfile(userId: UUID, islamic: [String], life: [String]) async {
        let updates: [String: AnyJSON] = [
            "struggles_islamic": .array(islamic.map { .string($0) }),
            "struggles_life":    .array(life.map    { .string($0) })
        ]
        do {
            try await SupabaseService.shared.client
                .from("profiles")
                .update(updates)
                .eq("id", value: userId.uuidString)
                .execute()
        } catch {
            coord.errorMessage = "Couldn't save your answers. Please try again."
            quizCoordinator.errorMessage = "Couldn't save your answers. Please try again."
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
                coord.step = .niyyah
            }
            .padding(20)
        }
    }

    // MARK: Step 1.5 — niyyah

    private var niyyahStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    if let progress = coord.multiProgressLabel {
                        Text(progress)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.msTextMuted)
                            .padding(.top, 16)
                    }

                    Spacer(minLength: 20)

                    VStack(spacing: 10) {
                        Image(systemName: coord.resolvedIcon())
                            .font(.system(size: 40))
                            .foregroundStyle(Color.msGold)
                        Text(coord.resolvedName())
                            .font(.appTitle)
                            .foregroundStyle(Color.msTextPrimary)
                        Text("What's your niyyah for this?")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                        Text("A single line between you and Allah. Skip if you're not ready.")
                            .font(.appCaption)
                            .foregroundStyle(Color.msTextMuted.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 10) {
                        TextField("e.g. To draw closer to Allah through patience",
                                  text: $coord.niyyah,
                                  axis: .vertical)
                            .lineLimit(3...5)
                            .foregroundStyle(Color.msTextPrimary)
                            .padding(14)
                            .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.msGold.opacity(0.4), lineWidth: 1)
                            )
                            .tint(Color.msGold)
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 24)
                }
            }

            VStack(spacing: 10) {
                continueButton(enabled: true) {
                    coord.step = .familiarity
                }

                Button {
                    coord.niyyah = ""
                    coord.step = .familiarity
                } label: {
                    Text("Skip for now")
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)
                }
                .buttonStyle(.plain)
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
                if !coord.pendingQueue.isEmpty {
                    coord.collectedSpecs.append(PendingHabitSpec(
                        name: coord.resolvedName(),
                        icon: coord.resolvedIcon(),
                        niyyah: coord.trimmedNiyyah,
                        familiarity: coord.familiarity
                    ))
                    let nextIndex = coord.pendingIndex + 1
                    if nextIndex < coord.pendingQueue.count {
                        let next = coord.pendingQueue[nextIndex]
                        coord.pendingIndex = nextIndex
                        coord.selectedName = next.name
                        coord.showCustomField = false
                        coord.selectedIcon = habitSymbol(for: next.name)
                        coord.niyyah = ""
                        coord.familiarity = ""
                        coord.step = .niyyah
                    } else {
                        coord.step = .generating
                        Task { await coord.createAndGenerateAll(userId: userId) }
                    }
                } else {
                    coord.step = .generating
                    Task { await coord.createAndGenerate(userId: userId) }
                }
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
                    Text(coord.pendingQueue.count > 1 && !coord.generatingProgressText.isEmpty
                         ? coord.generatingProgressText
                         : "Building your 28-day roadmap…")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextPrimary)
                    Text("This usually takes 10–20 seconds.")
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)
                }
            } else if coord.planDone {
                let count = coord.createdHabits.count
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.msGold)
                    Text(count > 1 ? "Your \(count) roadmaps are ready!" : "Your roadmap is ready!")
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
                    let count = coord.createdHabits.count
                    Button {
                        onCreated(habit)
                        dismiss()
                    } label: {
                        Text(coord.planDone
                             ? (count > 1 ? "Open Home" : "Open Roadmap")
                             : (count > 1 ? "Open Home" : "Open Habit"))
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
