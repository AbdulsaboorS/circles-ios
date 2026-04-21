# main — Session Note (2026-04-21)

## Goal

Retroactive code review of Phase 14 (Meaningful Habits) against the locked
spec in `.planning/phases/14-meaningful-habits/14-CONTEXT.md` + build order in
`.planning/notes/phase14-start.md`. No code written this session — findings
only, for user to act on before on-device QA.

## Scope

Read-only review of the six Phase 14 commits on `main`:
- 03b97da 14.1 SQL
- a8bd8fc 14.2 quiz
- 2b55fa8 14.3 Gemini suggestions
- 145cebc 14.4 niyyah
- f42ab0c 14.5 Hamdulillah overlay
- ca32895 14.6 Noor Bead

No changes to Phase 15 work (lives in `phase-15-social-pulse` worktree).

## Touched Files

None (review session). Files read for the review:
- `.planning/phases/14-meaningful-habits/migrations/001_niyyah_and_struggles.sql`
- `Circles/Onboarding/Quiz/*` (all 10 files)
- `Circles/Onboarding/{Amiir,Member}OnboardingCoordinator.swift`
- `Circles/Onboarding/OnboardingPendingState.swift`
- `Circles/Models/{Profile,Habit,HabitSuggestion,HabitSuggestion+Fallback,StreakMilestone}.swift`
- `Circles/Services/GeminiService.swift` (generateHabitSuggestions only)
- `Circles/Services/HabitService.swift` (niyyah param only, line 100-120)
- `Circles/Home/{AddPrivateIntentionSheet,HomeView,HomeViewModel,HamdulillahOverlay,StreakBeadView}.swift`

Not yet verified: `Circles/Home/HabitDetailView.swift` niyyah render,
full body of `HabitService.createPrivateHabit`.

## Decisions

No decisions made this session. Review output is advisory — user has not
yet approved any fix.

## Verified

### Strong — ship-ready
- SQL migration idempotent, column comments, `NOTIFY pgrst` reload
- `StreakMilestone` math matches spec (diameters, sparkle counts, saturation)
- Gemini prompt defensive (markdown strip, empty-array throw, cap at 6)
- Pre-auth struggle flushing via `OnboardingPendingState` + `saveLocation`
- Bead `igniteTrigger` guarded by `todayComplete` on receiver side
- `wasAllDone` guard in `toggleHabit` prevents re-fire on same complete day

### Drifts from locked spec
1. ✅ **Fixed (Session 2, 2026-04-21)** — **Quiz Screen A/B headlines and
   subheads** (D-15). Copy aligned with `onboarding_quiz_state.md`:
   - `QuizIslamicStrugglesView.swift` lines 3, 18, 23 — now reads
     *"What do you find hardest in your deen?"* / *"Be honest — this shapes
     your journey"*.
   - `QuizLifeStrugglesView.swift` lines 3, 18, 23 — now reads
     *"What holds you back day to day?"* / *"Your deen doesn't live in a
     vacuum"*.
2. ✅ **Fixed (Session 2, 2026-04-21)** — **Breathing scale** (D-31). Now
   symmetric `0.97 ↔ 1.03` via a pre-animation `breathScale = 0.97` kick in
   `startBreathing()` (`StreakBeadView.swift` lines 165–171). `@State` default
   stays `1.0` so `reduceMotion` / `lapsed` guard paths keep resting size.
3. ✅ **Fixed (Session 2, 2026-04-21)** — **Aura opacity** (D-31). Continuous
   `0.8 ↔ 1.0` pulse on a 4s `.easeInOut(autoreverses: true).repeatForever`
   cycle, in-phase with the bead breath. New `@State auraPulse: Double = 1.0`
   multiplied into each non-lapsed opacity in `auraLayer`
   (`StreakBeadView.swift` lines 60, 65, 70). Kicked by `startAuraPulse()`
   (lines 177–183) called alongside `startBreathing()` from `onAppear`
   (lines 44–47). Lapsed / `reduceMotion` stay static.
4. **8-point star** (D-29) — spec "matching `IslamicGeometricPattern.starPath`
   geometry"; impl defines fresh `EightPointStar` shape in `StreakBeadView.swift`.
5. **Check-off haptic** (D-24) — spec "subtle gold haptic pulse"; impl uses
   `.success` notification haptic (strong tri-tone, not subtle).
6. Processing screen (C) has no minimum display time — instant fallback or
   fast Gemini return causes a flash.
7. Intercept gate post-quiz UX — lands on `pickHabit` step with custom name
   pre-filled; user must manually tap Continue to reach niyyah. Minor
   redundancy.
8. Intercept gate has no local-session cache — re-fetches profile on every
   sheet open. If `saveStrugglesToProfile` silently fails, quiz re-appears
   on next FAB tap.

## Session 2 — Fixes Applied (2026-04-21)

Scope: drifts #1, #2, and #3 per user direction (added #3 mid-session before
cutoff). Build green on iOS Simulator (Xcode 26.3, `iphonesimulator26.2`
SDK). Not yet committed — awaiting user sign-off on the edits before commit
+ on-device QA.

### Touched files
- `Circles/Onboarding/Quiz/QuizIslamicStrugglesView.swift` — 3 line edits
  (doc comment, headline, subhead).
- `Circles/Onboarding/Quiz/QuizLifeStrugglesView.swift` — 3 line edits (same
  shape as above).
- `Circles/Home/StreakBeadView.swift` — 5 edits total:
  - Breath fix (#2): pre-animation `breathScale = 0.97` inside
    `startBreathing()`.
  - Aura pulse (#3): new `@State auraPulse`, `auraPulse` multiplier on all
    three non-lapsed opacity sites in `auraLayer`, `onAppear` closure now
    calls both `startBreathing()` + `startAuraPulse()`, and new
    `startAuraPulse()` helper mirroring `startBreathing`.

### Decision log
- Breathing fix: chose the "pull to `0.97` in `startBreathing`" approach over
  changing the `@State` default so `reduceMotion` + `lapsed` users keep the
  resting size of `1.0`. Single-frame batch on `onAppear` — no visible pop.
- Aura pulse fix: same pattern as breath (pre-animation kick to `0.8`,
  `@State` default `1.0` so reduceMotion/lapsed rest at full brightness).
  Same 4s `.easeInOut.repeatForever(autoreverses: true)` duration, **in
  phase** with the bead breath — bead inhales + aura brightens together.
  Applied as a multiplicative factor on top of the existing
  `todayComplete ? 1.0 : 0.6` multiplier so aura still dims on incomplete
  days, just pulses within that dim baseline.
- Scope held to 1 + 2 + 3; drifts #4, #5, #6, #7, #8 untouched.
- Commits not yet created — user to approve after diff/QA review.

## Next

Drifts #4–#8 remain open. User to triage after on-device QA of 1 + 2 + 3:
- #4 star geometry — isolated to `StreakBeadView.swift`; should swap
  `EightPointStar` shape for `IslamicGeometricPattern.starPath`. Defer if the
  current star reads correctly on device.
- #5 haptic — one-line change in `HomeView.swift` handleHabitToggle.
- #6/#7/#8 — UX polish, no one-liners; scope each separately.

Phase 14 QA test plan still lives in `HANDOFF.md`.

## Blockers

None. Build green. Three fixes staged but not yet committed — user requested
a plan-and-execute pass; commits are the user's call.

## Notes For Re-entry

- Fixes 1 + 2 + 3 are on `main` working tree, unstaged. Recommended commits
  (keep 2 + 3 separate so the user can revert the aura pulse alone if QA
  feels "too busy"):
  1. `fix(quiz): align Screen A/B copy with locked spec` (2 quiz files)
  2. `fix(bead): symmetric breathing 0.97 ↔ 1.03 per spec`
     (`StreakBeadView.swift` — breath-only portion)
  3. `feat(bead): continuous aura opacity pulse 0.8 ↔ 1.0`
     (`StreakBeadView.swift` — aura portion)
  Because #2 and #3 both touch `StreakBeadView.swift` and are entangled at
  the `onAppear` closure, splitting them cleanly may require `git add -p`
  or a single combined `fix(bead): symmetric breathing + aura pulse per
  D-31` commit. Combined is acceptable if splitting is painful.
- Locked quiz copy lives in
  `~/.claude/projects/-Users-abdulsaboorshaikh-Desktop-Circles/memory/onboarding_quiz_state.md`.
- If the user wants #5 fixed next, change
  `UINotificationFeedbackGenerator().notificationOccurred(.success)` in
  `HomeView.swift` handleHabitToggle to a `.soft` impact generator.
- #4 is still inside `StreakBeadView.swift` — defer until after on-device QA
  confirms the new breath + aura pulse feel right.
- Do NOT touch Phase 15 files on `main` — that workstream is in its own
  worktree.
