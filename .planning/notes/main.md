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
1. **Quiz Screen A/B headlines and subheads** (D-15) — implementation copy
   doesn't match the locked text from `onboarding_quiz_state.md`. Options
   and CTAs are correct; only the headline + subhead drifted.
2. **Breathing scale** (D-31) — spec `0.97 ↔ 1.03`, impl `1.0 → 1.03` only
   (single-direction, not symmetric).
3. **Aura opacity** (D-31) — spec says "modulates 0.8 ↔ 1.0" (continuous);
   impl only transitions once on `todayComplete` change, no loop.
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

## Next

User to decide which (if any) drift items to fix before on-device QA.
Recommended minimum: items 1 (quiz copy) and 5 (haptic) — both are
one-file fixes that don't invalidate the rest of Phase 14.

Phase 14 QA test plan lives in `HANDOFF.md` — still the right next step
once these findings are triaged.

## Blockers

None. Build is still green from prior session; review was read-only.

## Notes For Re-entry

- If the user wants #1 fixed, the locked copy lives in
  `~/.claude/projects/-Users-abdulsaboorshaikh-Desktop-Circles/memory/onboarding_quiz_state.md`.
- If the user wants #5 fixed, change
  `UINotificationFeedbackGenerator().notificationOccurred(.success)` in
  `HomeView.swift` handleHabitToggle to a `.soft` impact generator.
- Items 2, 3, 4 are bead-visual refinements — grouped; touch only
  `StreakBeadView.swift`. Defer until after QA since the user may say
  the current feel is fine.
- Do NOT touch Phase 15 files on `main` — that workstream is in its own
  worktree.
