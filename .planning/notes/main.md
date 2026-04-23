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
