# main — Session Note (2026-04-22, Session 5)

## What Shipped This Session

All commits pushed to `origin/main` (branch is clean):

1. **`feat(intention): multi-select Gemini suggestions in intercept quiz`** (`e47ebad`) — from previous session, verified this session
2. **`feat(intention): quiz delta re-entry screen for returning users`** (`2691dbf`) — from previous session, verified this session
3. **`refactor(habit-detail): two-state check-in redesign with monthly calendar`** (`eca8761`) — from previous session, verified this session
4. **`fix(noor): clarify NoorInfoSheet copy`** (`6deb3be`) — this session

## Phase 14 QA Results

| Test | Status |
|------|--------|
| 1. Fresh Amir onboarding | ⚠️ Routing bug — old personal catalog shows after quiz |
| 2. Fresh Member onboarding | ⏳ Pending re-test after Amir routing fix |
| 3. Intercept gate (existing user, no quiz) | ✅ Verified |
| 4. Niyyah step | ✅ Verified |
| 5. Hamdulillah micro-moment | ✅ Verified |
| 6. Noor Bead tier progression | ✅ Verified |

## NoorInfoSheet Overhaul

- Added "HOW IT WORKS" labeled section with 3 bullets: all-habits rule, glow mechanic, personal vs group streak separation
- Fixed Sanctuary dead-end (nil nextHint now shows encouragement line)
- Added sparkle string (✦) to each ladder row keyed to `sparkleCount` — ghosted for unreached, gold for current/reached

## Design Decisions Made

- **Circle members presence row** — permanently parked. Nudges stay in Circles activity view.
- **Gemini for shared habit suggestions** — parked post-MVP. Catalog + ranking sufficient.
- **"Together" accountability model** — ships first. "Each their own" fork deferred.
- **Amir onboarding reorder** — shared personalization → shared habits → circle identity → "Some growth is private" → private quiz → AI gen → location → auth

## Next Session — Amir Onboarding Overhaul

Full spec in `.planning/HANDOFF.md` under "Amir Onboarding Overhaul Handoff".

### Tasks in order:

1. **Routing bug fix** — `AmiirOnboardingFlowView` `transitionToAI` → change action to `proceedToAIGeneration()`
2. **Dead code removal** — `transitionToPersonal`, `personalIntentions` steps + `AmiirStep3PersonalView.swift` + dead coordinator methods
3. **New `AmiirSharedPersonalizationView`** — 3 questions (spirituality level, time commitment, heart of circle), chip-select UI, stores to coordinator
4. **Flow reorder** — wire new screen before `coreHabits`; move "Some growth is private" transition between `circleIdentity` and `onboardingQuiz`
5. **Catalog ranking** — `AmiirStep2HabitsView` reorders `curatedHabits` based on personalization answers
6. **QA** — fresh Amir onboarding full pass + Member onboarding re-test

### Key files:
- `Circles/Onboarding/AmiirOnboardingFlowView.swift`
- `Circles/Onboarding/AmiirOnboardingCoordinator.swift`
- `Circles/Onboarding/AmiirStep2HabitsView.swift`
- `Circles/Onboarding/AmiirStep3PersonalView.swift` (delete)
- `Circles/Onboarding/AmiirSharedPersonalizationView.swift` (new)
