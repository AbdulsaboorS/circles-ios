# main — Session Note (2026-04-21, Session 3)

## What Was Done This Session

### Planned (plan file exists, not yet executed)

Full plan written at:
`/Users/abdulsaboorshaikh/.claude/plans/read-planning-notes-main-md-in-full-tingly-pelican.md`

Three tasks queued, in order:
1. Bug 1 — Multi-select Gemini suggestions
2. Bug 2 — Quiz re-entry delta screen
3. Habit Detail redesign (full spec in session 2 note — still valid)

### Partially Executed

**ONE edit committed** to `OnboardingQuizCoordinator.swift`:
- Added `var allowsMultiSelect: Bool = false`
- Added `var onFinishMany: ((_ suggestions: [HabitSuggestion], _ customName: String?) -> Void)?`
- Build is green (these are additive properties only)

---

## Remaining Work — Bug 1 (Multi-select Gemini suggestions)

### Files to change

#### 1. `Circles/Onboarding/Quiz/QuizHabitSelectionView.swift` — full rewrite
Key changes:
- `@State selectedId: UUID?` → `@State selectedIds: Set<UUID> = []`
- Tap handler: if `coordinator.allowsMultiSelect` → toggle in set; else → replace set with singleton
- `canContinue`: `!selectedIds.isEmpty || !trimmedCustom.isEmpty`
- New `ctaLabel` computed: `"Create N habits"` when allowsMultiSelect && N > 0; else `"Begin"`
- Header copy: `"Habits shaped for you"` / `"Pick as many as feel right."` when multi-select
- Continue button action:
  - custom: `coordinator.finish(customName:)` (unchanged)
  - multi: `coordinator.onFinishMany?(suggestions.filter { selectedIds.contains($0.id) }, nil)`
  - single: `coordinator.finish(suggestion:)` (unchanged)

#### 2. `Circles/Home/AddPrivateIntentionSheet.swift` — multiple targeted edits

**A. Add `PendingHabitSpec` struct (before coordinator class):**
```swift
private struct PendingHabitSpec {
    let name: String
    let icon: String
    let niyyah: String?
    let familiarity: String
}
```

**B. Extend `AddIntentionCoordinator`:**
Add after `var createdHabit: Habit?`:
```swift
var createdHabits: [Habit] = []
var generatingProgressText: String = ""

// Multi-create queue (Bug 1)
var pendingQueue: [HabitSuggestion] = []
var pendingIndex: Int = 0
var collectedSpecs: [PendingHabitSpec] = []

var multiProgressLabel: String? {
    guard pendingQueue.count > 1 else { return nil }
    return "Habit \(pendingIndex + 1) of \(pendingQueue.count)"
}
```

**C. Add `createAndGenerateAll` method on coordinator (after `createAndGenerate`):**
```swift
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
                userId: userId, name: spec.name, icon: spec.icon,
                familiarity: spec.familiarity, niyyah: spec.niyyah
            )
            created.append(habit)
            let milestones = try await GeminiService.shared.generate28DayRoadmap(
                habitName: habit.name,
                planNotes: spec.niyyah.map { "Niyyah: \($0)" },
                userRefinementRequest: nil
            )
            _ = try await HabitPlanService.shared.upsertInitialPlan(
                habitId: habit.id, userId: userId, milestones: milestones
            )
        } catch { /* continue on partial failure */ }
    }
    createdHabits = created
    createdHabit = created.first
    planDone = !created.isEmpty
    isGenerating = false
}
```

**D. Update `configureInterceptQuiz` (L208–223) — add 2 lines:**
```swift
private func configureInterceptQuiz(userId: UUID) {
    quizCoordinator.allowsMultiSelect = true    // ADD THIS
    quizCoordinator.onPersistStruggles = { ... } // unchanged
    quizCoordinator.onFinish = { ... }           // unchanged
    quizCoordinator.onFinishMany = { suggestions, _ in   // ADD THIS BLOCK
        beginPerHabitQueue(suggestions: suggestions)
    }
}
```

**E. Add `beginPerHabitQueue` method on the view (after `configureInterceptQuiz`):**
```swift
private func beginPerHabitQueue(suggestions: [HabitSuggestion]) {
    guard !suggestions.isEmpty else { coord.step = .pickHabit; return }
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
```

**F. Update `niyyahStep` — add progress header at the top of the VStack:**
```swift
if let progress = coord.multiProgressLabel {
    Text(progress)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Color.msTextMuted)
        .padding(.top, 16)
}
```

**G. Update `familiarityStep` continue button action (replace the `guard let userId` block):**
```swift
continueButton(enabled: !coord.familiarity.isEmpty) {
    guard let userId = auth.session?.user.id else { return }
    if !coord.pendingQueue.isEmpty {
        coord.collectedSpecs.append(PendingHabitSpec(
            name: coord.resolvedName(), icon: coord.resolvedIcon(),
            niyyah: coord.trimmedNiyyah, familiarity: coord.familiarity
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
```

**H. Update `generatingStep` progress text (inside `if coord.isGenerating`):**
```swift
Text(coord.pendingQueue.count > 1 && !coord.generatingProgressText.isEmpty
     ? coord.generatingProgressText
     : "Building your 28-day roadmap…")
```

**I. Update `generatingStep` plan-done block (count-aware copy):**
```swift
let count = coord.createdHabits.count
Text(count > 1 ? "Your \(count) roadmaps are ready!" : "Your roadmap is ready!")
// CTA label:
Text(coord.planDone ? (count > 1 ? "Open Home" : "Open Roadmap") : (count > 1 ? "Open Home" : "Open Habit"))
```

---

## Remaining Work — Bug 2 (Quiz re-entry delta screen)

### Files to change

#### 1. `OnboardingQuizCoordinator.swift` — add `startFromExistingStruggles`:
```swift
func startFromExistingStruggles(islamicSlugs: [String], lifeSlugs: [String]) async {
    selectedIslamic = Set(islamicSlugs.compactMap(IslamicStruggle.init(rawValue:)))
    selectedLife    = Set(lifeSlugs.compactMap(LifeStruggle.init(rawValue:)))
    step = .processing
    await loadSuggestions()
}
```

#### 2. `AddPrivateIntentionSheet.swift`

**A. Add `case quizDelta` to `AddIntentionCoordinator.Step` enum:**
`enum Step { case quizDelta, quizIntercept, pickHabit, niyyah, familiarity, generating }`

**B. Add to coordinator (after `multiProgressLabel`):**
```swift
var savedStrugglesIslamic: [String] = []
var savedStrugglesLife: [String] = []
```

**C. Add `case .quizDelta: quizDeltaStep` to the `content` switch.**

**D. Add `quizDeltaStep` view:**
```swift
private var quizDeltaStep: some View {
    VStack(spacing: 0) {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 24)
                VStack(spacing: 10) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 40)).foregroundStyle(Color.msGold)
                    Text("Still the same?")
                        .font(.system(size: 28, weight: .regular, design: .serif))
                        .foregroundStyle(Color.msTextPrimary)
                    Text("Here's what you shared last time.")
                        .font(.appSubheadline).foregroundStyle(Color.msTextMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                let allStruggles = coord.savedStrugglesIslamic + coord.savedStrugglesLife
                if !allStruggles.isEmpty {
                    let cols = [GridItem(.adaptive(minimum: 100, maximum: 200))]
                    LazyVGrid(columns: cols, spacing: 8) {
                        ForEach(allStruggles, id: \.self) { slug in
                            Text(slug.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.msTextPrimary)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Color.msCardShared, in: Capsule())
                                .overlay(Capsule().stroke(Color.msBorder, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
                }
                Spacer(minLength: 24)
            }
        }

        VStack(spacing: 12) {
            // "Same" — pre-populate coordinator, skip A+B
            Button {
                guard let userId = auth.session?.user.id else { return }
                configureInterceptQuiz(userId: userId)
                quizCoordinator.selectedIslamic = Set(coord.savedStrugglesIslamic.compactMap(IslamicStruggle.init(rawValue:)))
                quizCoordinator.selectedLife    = Set(coord.savedStrugglesLife.compactMap(LifeStruggle.init(rawValue:)))
                quizCoordinator.step = .processing
                coord.step = .quizIntercept
                Task { await quizCoordinator.loadSuggestions() }
            } label: {
                Text("Same — show me habits")
                    .font(.appSubheadline.weight(.semibold)).foregroundStyle(Color.msBackground)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.msGold).clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // "Changed" — full quiz, overwrites struggles
            Button {
                guard let userId = auth.session?.user.id else { return }
                quizCoordinator = OnboardingQuizCoordinator()
                configureInterceptQuiz(userId: userId)
                coord.step = .quizIntercept
            } label: {
                Text("Things have changed")
                    .font(.appSubheadline.weight(.medium)).foregroundStyle(Color.msGold)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.msGold.opacity(0.12)).clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.msGold.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.bottom, 24)
    }
}
```

**E. Rewrite `resolveQuizGate()` (replace entirely):**
```swift
private func resolveQuizGate() async {
    guard let userId = auth.session?.user.id else {
        coord.isResolvingGate = false; return
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
            .single().execute().value
        return (profile.strugglesIslamic ?? [], profile.strugglesLife ?? [])
    } catch { return ([], []) }
}
```
Replace the old `loadNeedsQuiz` with `loadSavedStruggles` above (it's the same Supabase query, just returns values instead of Bool).

**F. Remove `markQuizCompletedLocally(for: userId)` call in `saveStrugglesToProfile` (L236).**

**G. Delete three UserDefaults helper functions (L581–591):**
- `quizCompletionKey(for:)`
- `isQuizCompletedLocally(for:)`
- `markQuizCompletedLocally(for:)`

---

## Remaining Work — Habit Detail Redesign

Full spec still in session 2 note (this file, above). Full execution plan in plan file.

### Code map (from exploration this session)

#### HabitDetailView.swift — structure to keep vs remove
- **KEEP**: `fetchLogs()`, `loadPlan()`, `generatePlan()`, `refineWithAI()`, `applyMilestoneEdit()`, `planLoadingOverlay`, `RefinePlanSheet`, `EditMilestoneSheet`, `RoadmapLoadingIndicator`, `StatPill`, existing computed `isCompletedToday`, `habitStreak`, `totalCompletions`
- **REMOVE**: `DetailTab` enum, `selectedTab` state, `tabBar`, `tabContent`, `constellationSection`, `revealedGlow` state, `triggerConstellationReveal()`, `reflectionTabContent`, `todayReflectionCard`, `pastReflectionCard`, `loadTodayReflection()`, `loadAllReflections()`, `saveReflection()`, `heroSection`, `showReflectionSheet`/`editingReflectionDate`/`todayReflection`/`allReflections` state, `ReflectionLogSheet` struct, `fullRoadmapSheet` computed (promote to FullRoadmapView), `showFullRoadmapSheet` state
- **MODIFY**: `fetchLogs()` — remove `gte("date", value: twentyEightDaysAgoString)` filter (need ALL logs for calendar + longestStreak)
- **ADD state**: `displayedMonth: Date = Date()`, `showAlhamdulillah: Bool = false`, `alhamdulillahTask: Task<Void,Never>?`, `memberPresence: [CircleMemberSummary] = []`
- **ADD computed**: `longestStreak: Int`, `completionRate: Double`, `todayMilestone: HabitMilestone?`

#### New views needed (in HabitDetailView.swift or separate files)
- `CheckInOrb` — hold-to-confirm orb (LongPressGesture + progress animation)
- `HabitMonthCalendar` — calendar grid with month navigation
- `FullRoadmapView` — promoted from `fullRoadmapSheet`; new file `Circles/Home/FullRoadmapView.swift`

#### HomeView.swift changes
- Remove `@State celebratingHabitId: UUID?` (L173)
- Remove `@State celebrationTask: Task<Void, Never>?` (L174)  
- Remove 3 `HamdulillahOverlay()` overlay mounts (L547-551, L577-581, L613-617)
- Remove `handleHabitToggle` function (L630-650)
- Cards: remove `onToggle: { handleHabitToggle(habit) }` closures → pass `{}` or remove param
- `HeroHabitCard` (L957): remove check-in Button(action: onToggle); replace with chevron hint
- `SharedHabitCard` (L1088): same
- `PersonalHabitCard` (L1220): same

#### Delete
- `Circles/Home/ReflectionLogStore.swift` — sole consumer is HabitDetailView, safe to delete

#### HabitDetailView toggle logic (no HomeViewModel injection needed)
- Optimistic toggle via direct `HabitService.shared.toggleHabitLog(habitId:userId:date:completed:true)`
- Optimistically append to local `logs` array
- Fire-and-forget: broadcast, group streak, streak refetch
- `isCompletedToday` computed from local `logs` → transitions to State 2 immediately

---

## Notes For Re-entry

- **Plan file**: `/Users/abdulsaboorshaikh/.claude/plans/read-planning-notes-main-md-in-full-tingly-pelican.md`
- **Partially done**: `OnboardingQuizCoordinator.swift` has `allowsMultiSelect` + `onFinishMany` added. Build green.
- **Next session must**: Execute Bug 1 (all edits above), commit, then Bug 2, commit, then Redesign, commit. Three commits total.
- **Commit order**: Bug 1 first, Bug 2 second, Redesign third. Do not mix.
- `phase-15-social-pulse` worktree untouched — do not merge.
- Phase 14 QA (8 drifts) still pending on-device after all three commits.

## Scoped & Parked
- Habit frequency (every N days) — post-MVP, do not scope
- Onboarding multi-select — deferred, only intercept path gets multi-select
