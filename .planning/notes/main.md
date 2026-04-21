# main — Session Note (2026-04-21)

## Goal

Close all 8 Phase 14 drift items identified in the retroactive code review,
commit them as clean named commits, and push the full backlog to `origin/main`.
Prepare handoff for on-device QA of Phase 14 before Phase 15 begins in a new
worktree.

## Scope

`main` branch only. Drifts #1–#8 against the locked spec in
`.planning/phases/14-meaningful-habits/14-CONTEXT.md`. Phase 15
(`phase-15-social-pulse` worktree) is untouched.

Explicitly out of scope: intention arcs, end_dates, past-intentions archive,
photo evidence, per-user streak seeding.

## Touched Files

- `Circles/Onboarding/Quiz/QuizIslamicStrugglesView.swift` — drift #1 (copy)
- `Circles/Onboarding/Quiz/QuizLifeStrugglesView.swift` — drift #1 (copy)
- `Circles/Home/StreakBeadView.swift` — drifts #2 (breath), #3 (aura), #4 (star)
- `Circles/DesignSystem/IslamicGeometricPattern.swift` — drift #4 (star)
- `Circles/Home/HomeView.swift` — drift #5 (haptic)
- `Circles/Onboarding/Quiz/OnboardingQuizCoordinator.swift` — drift #6 (min display)
- `Circles/Home/AddPrivateIntentionSheet.swift` — drifts #7 (UX skip) + #8 (cache)

## Decisions

- **Drift #4 (star geometry):** `EightPointStar` promoted to
  `IslamicGeometricPattern.swift` as the canonical internal type. Both the
  tiling background and the bead core now draw from it. Duplicate private
  struct in `StreakBeadView.swift` deleted.
- **Drift #5 (haptic):** `UIImpactFeedbackGenerator(.soft)` — single gentle
  pulse. Undo path retains `.light`.
- **Drift #6 (processing screen):** 1.6 s floor (matches the existing
  `pulseOpacity` animation cycle in `QuizProcessingView`). Elapsed-time
  approach — no extra sleep on slow Gemini calls.
- **Drift #7 (intercept gate UX):** `onFinish` in `configureInterceptQuiz`
  routes to `.niyyah` directly when a habit name is resolved. Defensive
  fallback to `.pickHabit` if both suggestion and custom are empty.
- **Drift #8 (cache + errors):** UserDefaults key
  `phase14.quiz.completed.<userId>` scoped per user. Set only on successful
  `saveStrugglesToProfile`. Hydrated from server truth on first gate check
  when struggles are non-empty. Save errors now routed to `coord.errorMessage`
  so the existing sheet alert fires.

## Verified

- Build green: `xcodebuild -scheme Circles -destination 'generic/platform=iOS
  Simulator' build` — zero errors after every drift fix.
- All 8 drift commits pushed to `origin/main` (20 total commits published this
  session including the Phase 14 phase commits + Session 2 wips + Session 3
  named fixes).
- On-device QA **not yet done** — this is the next step before Phase 15.

## Next

**On-device QA of Phase 14 (all drifts):**

1. **Drifts #1 (quiz copy)** — Trigger the quiz intercept by opening the FAB
   sheet with a fresh account (no struggles in profile). Screen A headline
   should read "What do you find hardest in your deen?" / subhead "Be honest —
   this shapes your journey". Screen B should read "What holds you back day to
   day?" / "Your deen doesn't live in a vacuum".

2. **Drift #2 (bead breath)** — Home screen, user with streak > 0. Bead should
   pulse symmetrically 0.97 ↔ 1.03. No static size before animation starts.

3. **Drift #3 (aura pulse)** — Same bead. Gold aura rings should breathe
   0.8 ↔ 1.0 opacity, in phase with the bead breath.

4. **Drift #4 (star geometry)** — Star core inside bead should rotate; Niyyah
   overlay and Journey screen backgrounds should show the tiling geometric
   pattern unchanged.

5. **Drift #5 (haptic)** — Tap a habit to complete: should feel like a single
   gentle tap, not a tri-tone buzz.

6. **Drift #6 (processing screen)** — With airplane mode on, run the intercept
   quiz through Screen B → processing screen should linger ~1.6 s before
   suggestions appear.

7. **Drift #7 (intercept gate UX)** — Complete the quiz, pick a Gemini
   suggestion → should land on Niyyah screen with the habit name and derived
   icon in the title. No pickHabit detour.

8. **Drift #8 (cache)** — Complete the quiz successfully. Force-quit the app.
   Relaunch → tap FAB → sheet should open at pickHabit instantly (no spinner
   from the gate check). Try with Wi-Fi off to confirm no network dependency.

After QA passes → Phase 15 in a new worktree (`phase-15-social-pulse`).

## Blockers

None. All code is on `main`, build is green.

## Notes For Re-entry

- All 8 Phase 14 drifts are closed. No uncommitted changes on `main`.
- `phase-15-social-pulse` worktree exists; Phase 15 should start there, not
  on `main`.
- If QA reveals a regression on the bead animations, the breath fix is
  `StreakBeadView.startBreathing()` (pre-kick to `0.97`) and the aura is
  `startAuraPulse()` (pre-kick to `0.8`). Both functions are in
  `Circles/Home/StreakBeadView.swift`.
- UserDefaults cache key for debugging drift #8:
  `"phase14.quiz.completed.<userId-UUID>"` — can be cleared via Instruments
  or a short one-liner in a Playground to force the quiz gate to re-check.
