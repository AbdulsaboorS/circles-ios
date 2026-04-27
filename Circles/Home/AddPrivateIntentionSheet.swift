import SwiftUI
import Supabase

enum AddPrivateIntentionDestination: Equatable {
    case home
    case detail
}

private enum AddIntentionMode {
    case quickAdd
    case guided
}

private struct PendingHabitSpec {
    let name: String
    let icon: String
    let niyyah: String?
    let familiarity: String
}

@Observable
@MainActor
private final class AddIntentionCoordinator {
    enum Step {
        case entryChoice
        case resolvingGuidance
        case quizDelta
        case quizIntercept
        case pickHabit
        case niyyah
        case familiarity
        case generating
    }

    var step: Step = .entryChoice
    var mode: AddIntentionMode = .quickAdd

    var selectedName: String = ""
    var selectedIcon: String = "leaf.fill"
    var customName: String = ""
    var showCustomField = false

    var niyyah: String = ""
    var familiarity: String = ""
    static let familiarityOptions = ["Just starting", "Some experience", "Very familiar"]

    var createdHabit: Habit?
    var createdHabits: [Habit] = []
    var isGenerating = false
    var isSavingQuickAdd = false
    var planDone = false
    var errorMessage: String?
    var generatingProgressText: String = ""

    var pendingQueue: [HabitSuggestion] = []
    var pendingIndex: Int = 0
    var collectedSpecs: [PendingHabitSpec] = []

    var savedStrugglesIslamic: [String] = []
    var savedStrugglesLife: [String] = []

    var multiProgressLabel: String? {
        guard pendingQueue.count > 1 else { return nil }
        return "Habit \(pendingIndex + 1) of \(pendingQueue.count)"
    }

    func startQuickAdd() {
        mode = .quickAdd
        resetHabitInputs()
        step = .pickHabit
    }

    func startGuided() {
        mode = .guided
        resetHabitInputs()
        step = .resolvingGuidance
    }

    func selectCurated(name: String, icon: String) {
        selectedName = name
        selectedIcon = icon
        showCustomField = false
    }

    func resetHabitInputs() {
        selectedName = ""
        selectedIcon = "leaf.fill"
        customName = ""
        showCustomField = false
        niyyah = ""
        familiarity = ""
        pendingQueue = []
        pendingIndex = 0
        collectedSpecs = []
        createdHabit = nil
        createdHabits = []
        isGenerating = false
        isSavingQuickAdd = false
        planDone = false
        generatingProgressText = ""
    }

    func resolvedName() -> String {
        showCustomField ? customName.trimmingCharacters(in: .whitespacesAndNewlines) : selectedName
    }

    func resolvedIcon() -> String {
        if showCustomField { return habitSymbol(for: customName) }
        return selectedIcon
    }

    func canProceedFromPick() -> Bool {
        !resolvedName().isEmpty
    }

    var trimmedNiyyah: String? {
        let trimmed = niyyah.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func createQuickHabit(userId: UUID) async -> Habit? {
        let name = resolvedName()
        guard !name.isEmpty else { return nil }

        isSavingQuickAdd = true
        errorMessage = nil
        defer { isSavingQuickAdd = false }

        do {
            let habit = try await HabitService.shared.createPrivateHabit(
                userId: userId,
                name: name,
                icon: resolvedIcon()
            )
            createdHabit = habit
            createdHabits = [habit]
            return habit
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func createAndGenerate(userId: UUID) async {
        let niyyahValue = trimmedNiyyah
        isGenerating = true
        planDone = false
        errorMessage = nil
        do {
            let habit = try await HabitService.shared.createPrivateHabit(
                userId: userId,
                name: resolvedName(),
                icon: resolvedIcon(),
                familiarity: familiarity,
                niyyah: niyyahValue
            )
            createdHabit = habit

            let promptNotes: String? = {
                switch (habit.planNotes, niyyahValue) {
                case let (notes?, niyyah?): return "\(notes)\nNiyyah: \(niyyah)"
                case let (notes?, nil): return notes
                case let (nil, niyyah?): return "Niyyah: \(niyyah)"
                case (nil, nil): return nil
                }
            }()

            let milestones = try await GeminiService.shared.generate28DayRoadmap(
                habitName: habit.name,
                planNotes: promptNotes,
                userRefinementRequest: nil
            )
            _ = try await HabitPlanService.shared.upsertInitialPlan(
                habitId: habit.id,
                userId: userId,
                milestones: milestones
            )
            planDone = true
        } catch {
            errorMessage = HabitPlanService.userFacingMessage(from: error)
        }
        isGenerating = false
    }

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

        for (index, spec) in specs.enumerated() {
            generatingProgressText = "Building roadmaps… (\(index + 1)/\(specs.count))"
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
                    case let (notes?, niyyah?): return "\(notes)\nNiyyah: \(niyyah)"
                    case let (notes?, nil): return notes
                    case let (nil, niyyah?): return "Niyyah: \(niyyah)"
                    case (nil, nil): return nil
                    }
                }()

                let milestones = try await GeminiService.shared.generate28DayRoadmap(
                    habitName: habit.name,
                    planNotes: promptNotes,
                    userRefinementRequest: nil
                )
                _ = try await HabitPlanService.shared.upsertInitialPlan(
                    habitId: habit.id,
                    userId: userId,
                    milestones: milestones
                )
            } catch {
                continue
            }
        }

        createdHabits = created
        createdHabit = created.first
        planDone = !created.isEmpty
        isGenerating = false
    }
}

struct AddPrivateIntentionSheet: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    var onCreated: (Habit, AddPrivateIntentionDestination) -> Void

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
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var content: some View {
        switch coord.step {
        case .entryChoice:
            entryChoiceStep
        case .resolvingGuidance:
            guidanceResolvingStep
        case .quizDelta:
            quizDeltaStep
        case .quizIntercept:
            OnboardingQuizFlowView(coordinator: quizCoordinator)
        case .pickHabit:
            pickHabitStep
        case .niyyah:
            niyyahStep
        case .familiarity:
            familiarityStep
        case .generating:
            generatingStep
        }
    }

    private var entryChoiceStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 28)

                    VStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.msGold)
                        Text("Add Personal Intention")
                            .font(.appTitle)
                            .foregroundStyle(Color.msTextPrimary)
                        Text("Choose the fast path if you already know the habit, or let Circles help you decide.")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 14) {
                        entryChoiceCard(
                            title: "Quick Add Habit",
                            subtitle: "Create a personal habit right away. You can build a roadmap later from the habit detail screen.",
                            icon: "bolt.fill",
                            action: { coord.startQuickAdd() }
                        )

                        entryChoiceCard(
                            title: "Help Me Choose",
                            subtitle: "Use the guided flow to narrow down your intention and generate a 28-day roadmap.",
                            icon: "sparkles",
                            action: { Task { await beginGuidedFlow() } }
                        )
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func entryChoiceCard(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    SwiftUI.Circle()
                        .fill(Color.msGold.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.msGold)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.msGold.opacity(0.8))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.msCardShared)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.msGold.opacity(0.22), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var guidanceResolvingStep: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView().tint(Color.msGold).scaleEffect(1.2)
            Text("Loading your previous guidance…")
                .font(.appCaption)
                .foregroundStyle(Color.msTextMuted)
            Spacer()
        }
    }

    private var quizDeltaStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 24)

                    VStack(spacing: 10) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.msGold)
                        Text("Use your previous guidance?")
                            .font(.appTitle)
                            .foregroundStyle(Color.msTextPrimary)
                        Text("Here’s what you told us last time. Reuse it to get suggestions faster, or update it first.")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    let chipLabels = savedStruggleLabels()
                    if !chipLabels.isEmpty {
                        let columns = [GridItem(.adaptive(minimum: 100, maximum: 220))]
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
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
                    Text("Use previous guidance")
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
                    quizCoordinator = OnboardingQuizCoordinator()
                    configureInterceptQuiz(userId: userId)
                    coord.step = .quizIntercept
                } label: {
                    Text("Update guidance")
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
        let life = coord.savedStrugglesLife.compactMap { LifeStruggle(rawValue: $0)?.label }
        return islamic + life
    }

    private func beginGuidedFlow() async {
        guard let userId = auth.session?.user.id else { return }
        quizCoordinator = OnboardingQuizCoordinator()
        coord.startGuided()
        coord.savedStrugglesIslamic = []
        coord.savedStrugglesLife = []
        let (islamic, life) = await loadSavedStruggles(userId: userId)
        if islamic.isEmpty && life.isEmpty {
            configureInterceptQuiz(userId: userId)
            coord.step = .quizIntercept
        } else {
            coord.savedStrugglesIslamic = islamic
            coord.savedStrugglesLife = life
            coord.step = .quizDelta
        }
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
        quizCoordinator.selectionCap = HabitCatalog.personalCap
        quizCoordinator.rankingSeed = userId.uuidString
        quizCoordinator.onPersistStruggles = { islamic, life in
            await saveStrugglesToProfile(userId: userId, islamic: islamic, life: life)
        }
        quizCoordinator.onFinish = { habitName in
            guard !habitName.isEmpty else {
                coord.step = .pickHabit
                return
            }
            coord.showCustomField = true
            coord.customName = habitName
            coord.selectedName = ""
            coord.step = .niyyah
        }
        quizCoordinator.onFinishMany = { habitNames in
            let suggestions = habitNames.map { HabitSuggestion(name: $0, rationale: "") }
            beginPerHabitQueue(suggestions: suggestions)
        }
    }

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
            "struggles_life": .array(life.map { .string($0) })
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

    private var pickHabitStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 20)

                    VStack(spacing: 10) {
                        Image(systemName: coord.mode == .quickAdd ? "bolt.fill" : "lock.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.msGold)
                        Text(coord.mode == .quickAdd ? "Quick Add Personal Habit" : "Choose a Personal Intention")
                            .font(.appTitle)
                            .foregroundStyle(Color.msTextPrimary)
                        Text(coord.mode == .quickAdd
                             ? "Add it now and decide later if you want a guided roadmap."
                             : "Pick the habit you want to work on, then we’ll help you shape it.")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

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

                    if coord.showCustomField {
                        TextField("e.g. Morning walk, Journaling…", text: $coord.customName)
                            .foregroundStyle(Color.msTextPrimary)
                            .padding(14)
                            .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.msGold.opacity(0.4), lineWidth: 1)
                            )
                            .tint(Color.msGold)
                            .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 24)
                }
            }

            continueButton(
                title: coord.mode == .quickAdd ? "Add Habit" : "Continue",
                enabled: coord.canProceedFromPick(),
                isLoading: coord.isSavingQuickAdd
            ) {
                if coord.mode == .quickAdd {
                    guard let userId = auth.session?.user.id else { return }
                    Task {
                        if let habit = await coord.createQuickHabit(userId: userId) {
                            onCreated(habit, .home)
                            dismiss()
                        }
                    }
                } else {
                    coord.step = .niyyah
                }
            }
            .padding(20)
        }
    }

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
                        Text("What’s your niyyah for this?")
                            .font(.appSubheadline)
                            .foregroundStyle(Color.msTextMuted)
                            .multilineTextAlignment(.center)
                        Text("A single line between you and Allah. Skip if you’re not ready.")
                            .font(.appCaption)
                            .foregroundStyle(Color.msTextMuted.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    TextField(
                        "e.g. To draw closer to Allah through patience",
                        text: $coord.niyyah,
                        axis: .vertical
                    )
                    .lineLimit(3...5)
                    .foregroundStyle(Color.msTextPrimary)
                    .padding(14)
                    .background(Color.msCardShared, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.msGold.opacity(0.4), lineWidth: 1)
                    )
                    .tint(Color.msGold)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 24)
                }
            }

            VStack(spacing: 10) {
                continueButton(title: "Continue", enabled: true) {
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

            continueButton(title: "Build Roadmap", enabled: !coord.familiarity.isEmpty) {
                guard let userId = auth.session?.user.id else { return }
                if !coord.pendingQueue.isEmpty {
                    coord.collectedSpecs.append(
                        PendingHabitSpec(
                            name: coord.resolvedName(),
                            icon: coord.resolvedIcon(),
                            niyyah: coord.trimmedNiyyah,
                            familiarity: coord.familiarity
                        )
                    )

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
                    Text(
                        coord.pendingQueue.count > 1 && !coord.generatingProgressText.isEmpty
                        ? coord.generatingProgressText
                        : "Building your 28-day roadmap…"
                    )
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
                    Text("Tap below to keep going.")
                        .font(.appSubheadline)
                        .foregroundStyle(Color.msTextMuted)
                }
            } else {
                VStack(spacing: 10) {
                    Text("Intention created!")
                        .font(.appTitle)
                        .foregroundStyle(Color.msTextPrimary)
                    Text("The AI plan didn’t generate. You can try again from the habit detail screen later.")
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
                        let destination: AddPrivateIntentionDestination = coord.createdHabits.count > 1 ? .home : .detail
                        onCreated(habit, destination)
                        dismiss()
                    } label: {
                        Text(coord.createdHabits.count > 1 ? "Open Home" : "Open Habit")
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
                        onCreated(habit, .home)
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

    private func continueButton(
        title: String,
        enabled: Bool,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(Color.msBackground)
                } else {
                    Text(title)
                        .font(.appSubheadline.weight(.semibold))
                        .foregroundStyle(Color.msBackground)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(enabled ? Color.msGold : Color.msGold.opacity(0.4))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled || isLoading)
    }
}

private struct HabitPickTile: View {
    let name: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(isSelected ? Color.msBackground : Color.msGold)
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.msBackground : Color.msTextPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.msGold : Color.msCardShared)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.clear : Color.msGold.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private func habitSymbol(for name: String) -> String {
    let normalized = name.lowercased()
    if normalized.contains("quran") || normalized.contains("qur") { return "book.fill" }
    if normalized.contains("salah") || normalized.contains("salat") || normalized.contains("prayer") { return "building.columns.fill" }
    if normalized.contains("dhikr") || normalized.contains("zikr") { return "circle.grid.3x3.fill" }
    if normalized.contains("fast") || normalized.contains("sawm") { return "moon.stars.fill" }
    if normalized.contains("sadaqah") || normalized.contains("charity") { return "hands.sparkles.fill" }
    if normalized.contains("tahajjud") || normalized.contains("night") { return "moon.fill" }
    if normalized.contains("walk") || normalized.contains("exercise") || normalized.contains("gym") { return "figure.walk" }
    if normalized.contains("journal") || normalized.contains("write") || normalized.contains("diary") { return "note.text" }
    if normalized.contains("sleep") || normalized.contains("rest") { return "bed.double.fill" }
    if normalized.contains("water") || normalized.contains("drink") { return "drop.fill" }
    return "leaf.fill"
}
