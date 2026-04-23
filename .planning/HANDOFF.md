# Shared Handoff

Repo-wide coordination only. Session detail lives in `.planning/notes/`.

---

## On Main (2026-04-23)

- Phases 1–14 complete
- Amir Onboarding Overhaul tasks 1-5 shipped: flow reorder, personalization screen, dead code removed, routing bug fixed, catalog ranking done
- Session 8: Amir identity step layout/nav parity fix shipped
- Phase 14 QA tests 1-2 still pending (Task 6 next session)
- **Joiner routing bug identified** — one-line fix, see below
- **Moment mechanic bugs identified** — UTC day-key + missing closed-window UI, see session 8 note in `.planning/notes/main.md`

## Active Branches

- `phase-15-social-pulse` — worktree at `.claude/worktrees/phase-15-social-pulse`
  - 15.1 + 15.2 built, pending user verification
  - Remaining: 15.3 circle check-in notifications, 15.4 habit reminders, hardening
  - **Do not merge until Amir overhaul tasks 5-6 ship and QA passes on `main`**

## Next on Main

**Amir Onboarding Overhaul — Task 6 (QA) + Joiner onboarding**

Task 5 (catalog ranking) is ✅ shipped (`036c26f`). Start with Task 6.

### Task 6 — QA

Full fresh-install pass after task 5 ships:

1. **Fresh Amir onboarding** (clear `onboardingComplete_<uid>` from UserDefaults + sign out):
   - Landing → Shape Your Circle screen appears (NOT circleIdentity)
   - Pick all 3 questions → Continue enables → habits screen shows reordered catalog
   - Habits → "Build the Foundation" → circleIdentity
   - circleIdentity → "Some growth is private" transition screen
   - Tap through transition → onboarding quiz (Phase 14)
   - Complete quiz → AI generation screen (personal catalog must NOT appear)
   - Through AI gen → location → auth
   - Confirm StepIndicator advances: 1 (personalization) → 2 (habits) → 3 (identity) → 4 (AI gen) → 5 (location) → 6 (auth)

2. **Phase 14 test 2 — Fresh Member onboarding**: verify `OnboardingTransitionQuote.amirSharedToPrivate` still renders (used in Member flow).

3. **Phase 14 tests 3-6** already verified — no re-test needed.

After QA passes → move to Joiner onboarding flow testing and bug fixes (see below).

## After Task 6 — Joiner Onboarding

Before Phase 14 QA is marked complete, test and fix the Joiner onboarding flow end-to-end. Joiner = user who receives an invite link and joins an existing circle.

**Known critical bug (session 8 diagnosis)** — fix first before full QA:

`Circles/Onboarding/MemberOnboardingFlowView.swift` ~line 35, `case .transitionToAI`:

```swift
coordinator.proceedToPersonalHabits()  // ❌ loops back
// should be:
coordinator.proceedToAIGeneration()
```

Coordinator already has `proceedToAIGeneration()` at `MemberOnboardingCoordinator.swift:97`. Joiner flow is unshippable until this is fixed.

Key files:
- `Circles/Onboarding/JoinerLandingView.swift`
- `Circles/Onboarding/JoinerIdentityView.swift`
- `Circles/Onboarding/JoinerPersonalHabitsView.swift`
- `Circles/Onboarding/JoinerAIGenerationView.swift`
- `Circles/Onboarding/JoinerAuthGateView.swift`
- `Circles/Onboarding/JoinerCircleAlignmentView.swift`
- `Circles/Onboarding/Quiz/JoinerQuizStepView.swift`
- `Circles/Onboarding/MemberOnboardingCoordinator.swift`
- `Circles/Onboarding/MemberOnboardingFlowView.swift`

After Joiner bugs are fixed and verified → mark Phase 14 QA complete in STATE.md → then (separately) merge `phase-15-social-pulse`.

## Moment Mechanic — Deferred Overhaul (Session 8)

User report: "Took a moment picture yesterday (after forcing the window open). It uploaded fine but attached to the next day on the Journey calendar."

Two root causes — full diagnosis in `.planning/notes/main.md` session 8 note:

1. **UTC day-key** in `JourneyViewModel.deduplicateMomentsByDay` (`Circles/Journey/JourneyViewModel.swift:218`) slices the raw UTC prefix of `postedAt`. `JourneyDateSupport.calendar` is also UTC. Users in UTC+ (UK/EU/ME) posting late evening local time land on tomorrow's cell.
2. **Missing "window closed + not posted" UI** in `Circles/Community/CommunityView.swift`. Gate overlay and pinned own-card both hide in this state → feels broken, user had to force-open the window.

Scope next session after confirming UX direction with user.

## Integration Hotspots

- `Circles/CirclesApp.swift`
- `Circles/ContentView.swift`
- `Circles/Services/`
- `Circles/Home/`
- `Circles/Onboarding/`
