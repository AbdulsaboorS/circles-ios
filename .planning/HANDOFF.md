# Shared Handoff

Repo-wide coordination only. Session detail lives in `.planning/notes/`.

---

## On Main (2026-04-23)

- Phases 1–14 complete (pending user QA pass)
- Amir Onboarding Overhaul tasks 1-5 shipped
- Session 8: Amir identity step layout/nav parity fix
- Session 9: Joiner `transitionToAI → proceedToAIGeneration` fix + moment-mechanic BeReal alignment
- **Phase 14 QA tests 1-2 deferred to manual user pass** — checklist in `.planning/notes/main.md` session 9 block
- **Next work target: Moment Mechanic Redesign (BeReal parity)** — alignment locked, scope below. Not yet planned/executed.

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

Joiner routing bug (`MemberOnboardingFlowView.swift:36`) ✅ fixed in Session 9. Full Joiner flow still needs manual user pass — see "QA Pass B" in `.planning/notes/main.md` session 9 block.

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

## Moment Mechanic — Redesign (next session target)

**Rule**: exact BeReal copy. Prayer anchoring is dropped from the mechanic. See `CLAUDE.md` Product Rules + memory `project_moment_mechanic.md`.

**Why**: user report "posted a moment, it attached to the next day on Journey" surfaced two bugs that are both symptoms of the mechanic having drifted from BeReal.

**Aligned scope** (design locked 2026-04-23, not yet planned):

1. **Drop prayer anchoring** — `DailyMomentService` stops using Aladhan prayer times. `daily_moments.moment_time` is repurposed to a random UTC window-open time, picked by a pg_cron job. Global drop (all circles fire at the same UTC instant, BeReal-style).
2. **Stamp `moment_date` at insert** — add `circle_moments.moment_date DATE`, written at post time from the active window's date. Journey cells key off this column, not `postedAt` UTC prefix. Fixes Bug 1 structurally.
3. **Missed-window UX** — extend `ReciprocityGateView` (`Circles/Community/CommunityView.swift`) to cover the "closed + !hasPostedToday" state. Blurred others' feed + "Post a late moment" CTA. No pinned-yesterday-own.
4. **Soft gate** — can post until next window opens (replaces current 25hr hard cap).
5. **Timestamps** — "on time" if within window, else "Xh ago" / "Xm ago". No late badge.
6. **Schema**: `circle_moments.moment_date DATE` (new). `daily_moments.moment_time` semantics change — no schema change, just cron logic. Existing rows left alone; optional historical `moment_date` backfill via `postedAt::date`.

**Not in scope (v2 future)**: region/calendar-aware random windows to avoid iftar/tarawih/jumu'ah overlap. Pure BeReal first; constrain range later if users complain.

**Key files**:
- `Circles/Services/DailyMomentService.swift` — strip prayer math, read randomized `moment_time`
- `Circles/Services/MomentService.swift` — stamp `moment_date` at insert
- `Circles/Journey/JourneyViewModel.swift:218` — swap `postedAt.prefix(10)` for `moment.momentDate`
- `Circles/Journey/JourneyDateSupport.swift` — calendar timezone decision (local vs stay UTC — probably local now that day-key is DB-stamped)
- `Circles/Community/CommunityView.swift` — third gate state (missed window blur)
- `Circles/Feed/ReciprocityGateView.swift` — extend for missed-window copy
- `Circles/Models/CircleMoment.swift` — add `momentDate` property + CodingKeys
- pg_cron job for `daily_moments.moment_time` (Supabase SQL Editor)
- APNs push scheduling — now fires at random `moment_time`, not prayer time

**Discussion history**: session 9 note in `.planning/notes/main.md` captures the full discussion on direction (BeReal parity, why pure copy beats prayer-hybrid, niyyah as differentiator, Ramadan v2 mitigation).

## Integration Hotspots

- `Circles/CirclesApp.swift`
- `Circles/ContentView.swift`
- `Circles/Services/`
- `Circles/Home/`
- `Circles/Onboarding/`
