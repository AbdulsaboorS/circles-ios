# main — Session Note (2026-04-23, Session 9)

## What Shipped This Session

1. **`fix(onboarding): Joiner transitionToAI advances to AI generation`** — `MemberOnboardingFlowView.swift:36` now calls `coordinator.proceedToAIGeneration()` instead of `proceedToPersonalHabits()`. Joiner flow no longer loops back to personal habits from the "Some growth is private" transition.

Build verified: `** BUILD SUCCEEDED **` (zero errors, iPhone 17 Pro simulator target).

## Pending — Manual User QA (Sessions 8 + 9)

User will run this pass manually after remaining bugs are fixed. Document below is the consolidated checklist.

### QA Pass A — Fresh Amir Onboarding
Reset: delete app from simulator OR sign out + clear `onboardingComplete_<uid>` from UserDefaults.

1. Landing → **Shape Your Circle** (personalization) screen appears — NOT old circleIdentity.
2. Pick all 3 chips (spirituality level / time commitment / heart of circle) → Continue enables.
3. Habits screen — catalog order should reflect `habitScore(_:)` ranking for picked answers (Session 7 task 5). E.g. "More than an hour" + high spirituality → Tahajjud/Fasting float near top; "5–10 min" → they sink.
4. Tap "Build the Foundation" → circleIdentity screen (Session 8 fix: gold chevron back button visible, StepIndicator + Continue pinned to bottom, not scrolling).
5. Tap back chevron → returns to habits (Session 8 fix verification).
6. Continue → "Some growth is private" transition quote.
7. Transition → onboarding quiz (Phase 14).
8. Finish quiz → AI generation directly (dead `AmiirStep3PersonalView` catalog must NOT appear).
9. AI gen → location → auth.
10. **StepIndicator sequence**: 1 personalization → 2 habits → 3 identity → 4 AI gen → 5 location → 6 auth.

### QA Pass B — Fresh Joiner (Member) Onboarding
Use an invite code from an existing circle. Same reset procedure.

1. Joiner landing → enter invite → `transitionToCircle` ("amirSharedToPrivate" quote renders).
2. Continue → `circleAlignment` (rich circle preview + habit selection, min 1).
3. Continue → `onboardingQuiz` (Phase 14 quiz).
4. Finish quiz → `personalHabits` (max 2).
5. Continue → `transitionToAI` ("amirPrivateToAI" quote).
6. **Session 9 fix check**: tap Continue → `aiGeneration` (NOT back to personalHabits).
7. AI gen → `identity` (name + location).
8. Continue → `authGate` → sign in.
9. Post-auth → `flushToSupabase` writes profile + joins circle + creates habits + fires plan gen.
10. Land on main app feed.

### QA Pass C — Phase 14 Meaningful Habits (spot re-check)
Tests 3–6 already verified in Session 5, no re-test needed. Only rerun if Pass A surfaces quiz regressions.

### Bugs Found During QA
For anything that surfaces: add to "Deferred" section below with file:line + repro, then fix in its own focused commit.

### Sign-off Steps (after all passes green)
1. Update `.planning/STATE.md` — Phase 14 row → ✓ Complete; Phase 14.1 row → ✓ Complete.
2. Update `.planning/HANDOFF.md` "On Main" — Phase 14 done, next = merge `phase-15-social-pulse` worktree.
3. Commit the doc updates.
4. Merge `phase-15-social-pulse` (after 15.3/15.4 hardening done on that branch).

---

# main — Session Note (2026-04-23, Session 8)

## What Shipped This Session

1. **`fix(onboarding): Amir identity step layout + back button`** — `AmiirStep1IdentityView` now matches the pattern used by the other Amir steps.

## Amir Identity Step Fix

`AmiirStep1IdentityView.swift` was out of pattern with the rest of the flow:

- System back button was visible (every other step hides it + renders a gold chevron).
- `StepIndicator` + Continue button were in the scrolling content, not pinned — they'd scroll away with the keyboard.

Changes:
- Added `.navigationBarBackButtonHidden()` + custom toolbar chevron calling `coordinator.navigationPath.removeLast()`.
- Split into `VStack(spacing: 0) { ScrollView {...}; VStack { StepIndicator; Button }.background(Color.msBackground) }` to pin the footer.
- Extracted `continueDisabled` computed var.

No behavior change — pure layout/nav parity with `AmiirSharedPersonalizationView` and `AmiirStep2HabitsView`.

## Joiner Routing Bug — ✅ Fixed in Session 9 (`MemberOnboardingFlowView.swift:36`)

## Deferred — Moment Mechanic Overhaul

User reported: "took a moment picture yesterday (after forcing the window open), it uploaded fine but attached to the next day on the Journey calendar." Two root causes diagnosed:

### Bug 1 — UTC day-key in Journey
`Circles/Journey/JourneyViewModel.swift:218` in `deduplicateMomentsByDay`:

```swift
let dayKey = String(moment.postedAt.prefix(10))  // raw UTC prefix
```

`postedAt` is an ISO8601 string with UTC offset. Slicing `.prefix(10)` gives the UTC date. For a user in UTC+ (e.g. UK in BST, Europe, Middle East) who posts late evening local time, the moment lands on tomorrow's calendar cell.

`Circles/Journey/JourneyDateSupport.swift` — the `calendar` uses `TimeZone(identifier: "UTC")`, so calendar cells are also UTC. Mismatch is baked into both sides.

**Fix plan** (next session):
- Switch `JourneyDateSupport.calendar` to `TimeZone.current`.
- Parse `moment.postedAt` as `Date` via `ISO8601DateFormatter` with fractional seconds + `withInternetDateTime`, then extract the day via the local calendar.
- Widen `MomentService.fetchMoments` DB query bounds by ±1 UTC day so boundary moments aren't missed.

### Bug 2 — "Window closed" UI state missing
`Circles/Community/CommunityView.swift`:
- Gate overlay: shown only when `momentService.isGateActive == true`.
- Pinned own-moment card: shown only when `hasPostedToday == true` AND feed contains user's moment.
- **Gap**: window closed + user didn't post → no UI, feels broken. That's why user had to "force it open."

**Fix plan** (next session): Add a third state — countdown card to next prayer window, OR a "you missed today's window — see yesterday's moment" affordance. Confirm with user which direction to go.

### `DailyMomentService` (reference)
- `isGateActive` requires `windowStart != nil && Date() >= start && !hasPostedToday`.
- `computeHasPostedToday` uses `windowStart` → `windowStart + 25hr` range.

## Phase 14 QA — Still Pending

| Test | Status |
|------|--------|
| 1. Fresh Amir onboarding (new identity + ranked catalog) | ⏳ Pending |
| 2. Fresh Member onboarding | ⏳ Pending |
| 3–6. All other Phase 14 tests | ✅ Verified (Session 5) |

## Next Session — Priority Order

1. **Joiner one-line fix** (`MemberOnboardingFlowView.swift:35`) — 2 min.
2. **Task 6 Amir QA** — fresh install pass, full flow including new identity layout.
3. **Member onboarding re-test** — Phase 14 test 2.
4. **Joiner onboarding full flow test + any additional bug fixes.**
5. **Moment mechanic overhaul** — Journey UTC bug + closed-window UI. Confirm UX direction with user before building step 5.
6. After Phase 14 QA signed off → merge `phase-15-social-pulse` worktree → Phase 15.

---

# main — Session Note (2026-04-23, Session 7)

## What Shipped This Session

All commits pushed to `origin/main` (branch is clean):

1. **`feat(onboarding): catalog ranking in AmiirStep2HabitsView`** (`036c26f`) — Task 5 of Amir overhaul

## Amir Onboarding Overhaul — Task 5 Done

`AmiirStep2HabitsView` now ranks the curated habits tile grid based on the three personalization answers stored on the coordinator:

- `habitScore(_:)` private helper: +1 per matching spirituality/heart-of-circle rule, ±1 for time commitment ("5–10 min" deprioritises Tahajjud/Fasting; "More than an hour" boosts them)
- `rankedHabits` computed var: sorts by score descending, index ascending for ties (stable)
- `ForEach` changed from `curatedHabits` → `rankedHabits`

## Phase 14 QA — Still Pending

| Test | Status |
|------|--------|
| 1. Fresh Amir onboarding (incl. ranked catalog) | ⏳ Pending — Task 6 next session |
| 2. Fresh Member onboarding | ⏳ Pending |
| 3–6. All other Phase 14 tests | ✅ Verified (Session 5) |

## Next Session — Task 6 + Joiner

Full spec in `.planning/HANDOFF.md`.

1. **Task 6 — QA**: fresh Amir onboarding full pass + Member onboarding re-test
2. **Joiner onboarding**: full flow test, find + fix bugs
3. After Joiner passes: mark Phase 14 QA complete → merge `phase-15-social-pulse`

---

# main — Session Note (2026-04-22, Session 6)

## What Shipped This Session

All commits pushed to `origin/main` (branch is clean):

1. **`refactor(onboarding): Amir onboarding overhaul — flow reorder + personalization screen`** (`e982259`) — tasks 1-4 of Amir overhaul

## Amir Onboarding Overhaul — Tasks 1-4 Done

### New flow
```
Landing → Shape Your Circle (3 questions) → shared habits → circle identity
       → "Some growth is private" → quiz → AI gen → location → auth
```

### Changes shipped
- **`AmiirSharedPersonalizationView`** (new): 3 chip-select questions — spirituality level, time commitment, heart of circle. All 3 required before Continue. Stores to coordinator (session-only, not persisted to Supabase).
- **`AmiirStep3PersonalView`** deleted — quiz already writes the picked habit into `selectedPersonalHabits`; catalog was redundant and causing the Phase 14 QA bug.
- **Routing bug fixed**: `transitionToAI` now routes to `proceedToOnboardingQuiz()` (was `proceedToPersonalIntentions()`).
- **Dead code removed**: `Step.transitionToPersonal`, `Step.personalIntentions`, `proceedToTransitionToPersonal()`, `proceedToPersonalIntentions()`.
- **Step indicators renumbered**: personalization=1, habits=2, identity=3; AI gen/location/activation unchanged at 4/5/6.

### Coordinator state added (session-only)
```swift
var spiritualityLevel: String? = nil
var timeCommitment: String? = nil
var heartOfCircle: String? = nil
```

## Phase 14 QA — Pending

QA deferred until tasks 5-6 are complete (next session).

| Test | Status |
|------|--------|
| 1. Fresh Amir onboarding | ⏳ Pending — overhaul done, QA next session |
| 2. Fresh Member onboarding | ⏳ Pending |
| 3–6. All other Phase 14 tests | ✅ Verified (Session 5) |

## Next Session — Tasks 5-6

Full spec in `.planning/HANDOFF.md`.

### Tasks:
1. **Catalog ranking** (task 5): `AmiirStep2HabitsView` reorders `curatedHabits` based on coordinator's `spiritualityLevel`, `timeCommitment`, `heartOfCircle`.
2. **QA** (task 6): fresh Amir onboarding full pass + Member onboarding re-test + Phase 14 test 2.
3. After QA passes: merge `phase-15-social-pulse` worktree → Phase 15.
