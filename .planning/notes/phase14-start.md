# Phase 14 — Session Re-entry (Meaningful Habits)

## Status
**Ready to build.** Discuss-phase complete, CONTEXT.md locked, Noor Bead streak direction locked, no code shipped yet.

## Goal
Make habit creation emotionally anchored, replace generic habit catalog with AI-personalized suggestions, make check-off feel like a small dua, and upgrade the streak visual to a living "Noor Bead" hero element.

## Scope
This branch owns Phase 14 features only. Out of scope: arcs, end_dates, past-intentions archive, photo evidence on check-ins, per-user streak seeding, quiz v2 AI synthesis, hold-to-complete, pattern-based nudges, any notification work (Phase 15 owns that).

---

## Decisions locked this session (2026-04-20)

### Streak visual direction — CHANGED from original spec
- Original direction (girih tessellation behind header) was rejected after design review — too busy, off-brand
- **New direction: "Noor Bead"** — a single luminous gold bead as the centered hero element, upgrading the existing `heartSection` in `HomeView.swift`
- See `14-CONTEXT.md` D-26 → D-35 for full spec
- Visual reference: `.planning/phases/14-meaningful-habits/references/streak-bead-reference.png`

### Noor Bead locked specifics
- **Composition:** gold radial-gradient sphere (#E8B84F → #D4A240 → #8B6A28), 8-point star core (reuses `IslamicGeometricPattern.starPath` geometry) in parchment #F0EAD6, multi-layer noor aura, drifting sparkles
- **Two scaling axes (MERGED — this is the one non-obvious call):**
  1. **Streak tier (days)** drives bead size, gradient saturation, aura radius, sparkle count
  2. **Today's completion** (`allHabitsCompleted` from `HomeViewModel`) drives aura opacity — dimmed to ~0.6× of tier default until today is complete, ramps to full on the last check-off
  - On the completing check-off: brief ignite burst (scale 1.08 → 1.0 over 400ms + small sparkle burst)
  - This folds the existing `heartSection` ignite logic into the tier system — no separate "all done today" behavior
- **Named milestone tiers** (captions shown as italic parchment 70% opacity under the "X Day Streak" text):
  - Day 0 — *Lapsed* (cracked dim bead, only after full streak break — not same-day grace)
  - Day 1 — *First light*
  - Day 3 — *Three Fajrs*
  - Day 7 — *One week*
  - Day 14 — *Two weeks*
  - Day 21 — *Three weeks*
  - Day 28 — *Sanctuary*
  - Day 28+ continues with daily glow-up only; no new named tier in v1
- **Next-milestone hint:** small italic parchment 60% opacity text below the tier caption — "3 days to One week". Drops when at Sanctuary.
- **Bead diameter curve:** ~60px (Lapsed) → 72px (Day 1) → 112px (Day 28). ~1.5px per-day bump between milestones.
- **Sparkle count per tier:** 0 / 1 / 2 / 3 / 5 / 7 / 10+
- **Animations:** breathing scale 0.97↔1.03 over 4s, aura opacity modulates 0.8↔1.0, star rotates ~360° / 600s (imperceptible), sparkles drift + twinkle on loop, Lapsed static

### Quiz + niyyah + micro-moment
- Unchanged from `14-CONTEXT.md` — see D-01 → D-25 and D-36 → D-37
- Screen content confirmed in `~/.claude/projects/-Users-abdulsaboorshaikh-Desktop-Circles/memory/onboarding_quiz_state.md`

---

## Build Order (chat-mode — no GSD executor)

Work through in order. Each is a self-contained commit. Confirm with user before Task 1 (SQL).

1. **SQL migration** — `habits.niyyah TEXT` nullable + `profiles.struggles_islamic JSONB` + `profiles.struggles_life JSONB`. Run via Supabase Dashboard → SQL Editor. **Confirm with user before running.** Write the migration file under `.planning/phases/14-meaningful-habits/` so the SQL is checked in.

2. **Quiz screens A+B + coordinator** — New `OnboardingQuizCoordinator` with 4 steps (Islamic struggles → Life struggles → Processing/Gemini call → Habit selection). Wire into `AmiirOnboardingCoordinator` (after Step 2) and `MemberOnboardingCoordinator` (after Habit Alignment). Add intercept gate to `AddPrivateIntentionSheet`. Screen content is confirmed in `onboarding_quiz_state.md`. Rows use gold left-border/fill highlight matching existing familiarity step. Persist answers to `profiles` before advancing.

3. **GeminiService — habit suggestions** — New method `generateHabitSuggestions(islamicStruggles: [String], lifeStruggles: [String]) async throws -> [HabitSuggestion]`. Returns max 6 items (name + "why this fits you"). Static fallback if API fails (Fajr / Quran daily / morning dhikr / gratitude / exercise or similar).

4. **Niyyah field** — Optional `niyyah: String?` step in `AddPrivateIntentionSheet` between pick and familiarity. Pass to `HabitService.createPrivateHabit`. Display as emotional header on `HabitDetailView` beneath the habit name. Feed into Gemini roadmap prompt.

5. **Check-off micro-moment** — On habit completion in `HomeView` habit rows: "الحمد لله" Arabic text fades in, dissolves after 1.5s. Subtle gold haptic pulse. Tap gesture unchanged. Undo (tap again) plain, no animation.

6. **Streak Noor Bead** — New `StreakBeadView(streakDays: Int, todayComplete: Bool)` (or in-place upgrade of `heartSection`). Implements all spec from "Noor Bead locked specifics" above. Reuse `IslamicGeometricPattern.starPath` for the 8-point star core. Reuse `NoorRingView` stroke + shadow language where applicable. Milestone mapping in a small `StreakMilestone` enum with the 7 named tiers. Canvas for sparkles + aura. On completing check-off, fire ignite burst from parent view.

---

## Touched Files (anticipated)

**SQL:**
- `.planning/phases/14-meaningful-habits/migrations/XX_niyyah_and_struggles.sql` (to create)

**Swift (new):**
- `Circles/Onboarding/OnboardingQuizCoordinator.swift`
- `Circles/Onboarding/QuizStructurallyAQuestionView.swift` + B + C + D
- `Circles/Home/StreakBeadView.swift`
- `Circles/Models/StreakMilestone.swift`
- `Circles/Models/HabitSuggestion.swift`

**Swift (edit):**
- `Circles/Services/GeminiService.swift` — add `generateHabitSuggestions`
- `Circles/Services/HabitService.swift` — `createPrivateHabit` gains `niyyah: String?`
- `Circles/Services/ProfileService.swift` — struggle fields persistence
- `Circles/Models/Habit.swift` — add `niyyah`
- `Circles/Models/Profile.swift` — add struggle fields
- `Circles/Home/AddPrivateIntentionSheet.swift` — quiz intercept + niyyah step
- `Circles/Home/HomeView.swift` — replace `heartSection` with `StreakBeadView`, wire ignite burst on check-off
- `Circles/Home/HomeViewModel.swift` — expose `todayComplete` cleanly to header
- `Circles/Home/HabitDetailView.swift` — display niyyah
- `Circles/Onboarding/AmiirOnboardingCoordinator.swift` — insert quiz step
- `Circles/Onboarding/MemberOnboardingCoordinator.swift` — insert quiz step

---

## SuperDesign (reference only — HTML output is rough, trust the spec text)

Project: `Circles Streak Geometric Pattern` → https://app.superdesign.dev/teams/4d645940-b0b5-42a6-8b89-86847333903f/projects/e060bb8a-5f28-4a0d-9eeb-05eda93009fc

Drafts live on canvas but the user explicitly flagged them as "horrible" visually. The actual SwiftUI should be built against the spec in `14-CONTEXT.md` D-26 → D-35 and the reference PNG at `.planning/phases/14-meaningful-habits/references/streak-bead-reference.png`, **not** against the HTML output. The reference PNG is the north star for the bead visual feel.

---

## Key Files to Read First (new session)

1. `.planning/phases/14-meaningful-habits/14-CONTEXT.md` — full phase context, all decisions (now includes updated Noor Bead direction)
2. This file — session continuation and build order
3. `~/.claude/projects/-Users-abdulsaboorshaikh-Desktop-Circles/memory/onboarding_quiz_state.md` — confirmed quiz screen content
4. `.planning/phases/14-meaningful-habits/references/streak-bead-reference.png` — visual north star for the bead
5. `Circles/Home/HomeView.swift:424:515` — existing `headerSection` + `heartSection` to upgrade
6. `Circles/Home/AddPrivateIntentionSheet.swift` — creation flow to extend
7. `Circles/DesignSystem/IslamicGeometricPattern.swift` — `starPath` geometry to reuse
8. `Circles/DesignSystem/NoorRingView.swift` — stroke + blur language to reuse
9. `Circles/DesignSystem/DesignTokens.swift` — MS color tokens (`msGold`, `msBackground`, `msCardShared`, `msTextPrimary`)
10. `Circles/Onboarding/AmiirOnboardingCoordinator.swift` — coordinator pattern to mirror

---

## Verified this session
- `14-CONTEXT.md` D-26 → D-35 + specifics section rewritten to reflect Noor Bead direction
- `phase14-start.md` build order Task 6 rewritten
- Reference image saved to `.planning/phases/14-meaningful-habits/references/streak-bead-reference.png`
- No code changes, no SQL run, no commits

## Next
Start Build Order **Task 1 — SQL migration**. Draft the SQL file under `.planning/phases/14-meaningful-habits/migrations/`, show it to user, confirm before running via Supabase Dashboard.

## Blockers
- Confirm SQL migration file name convention with user (existing phase migrations are under `.planning/phases/XX-*/` — pick a consistent path)
- After SQL applied, may need `NOTIFY pgrst, 'reload schema'` if PostgREST cache misses — see `CLAUDE.md` troubleshooting table

## Notes For Re-entry
- User prefers **chat-mode**, not GSD plan-phase / execute-phase orchestrators
- User is sensitive to design drift → spec text in `14-CONTEXT.md` and the reference PNG are the truth, not SuperDesign HTML
- Existing `heartSection` in `HomeView.swift` is ~80% of the Noor Bead already (gold medallion + star ring + bloom + heart icon) — Task 6 is an evolution of that, not a from-scratch rebuild
- Do NOT touch `PROJECT.md` (user explicitly deferred)
- Do NOT reopen scope (no arcs, end_dates, hold-to-complete, photo evidence, per-user seeding — these were explicitly parked)
