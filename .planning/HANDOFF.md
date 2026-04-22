# Shared Handoff

This file is the repo-wide coordination doc for parallel workstreams.

Do not use this file as a session diary. Do not paste long narrative handoffs here.

Use this file for:
- what is merged to `main`
- which branches/worktrees are active
- merge order
- shared integration risks
- files or surfaces with likely overlap

Use branch-specific notes under `.planning/notes/` for session continuity within a single workstream.

---

## Current Repo State

### Default Branch
- `main`

### Merged To Main
- Phase 13 fully complete — all waves (1–6) signed off
- Journey tab (Phase 13A) shipped and QA'd
- Profile hero + settings card polish shipped (2026-04-20)
- Bugs C (habit icon) and F (niyyah save) resolved
- Moment gate tests 1–5 all verified
- Phase 14 — Meaningful Habits: all 6 tasks shipped and QA'd (2026-04-22). Amir onboarding routing bug found during QA — scoped for next session.
- Session bug fixes: multi-select Gemini (Bug 1), quiz re-entry delta (Bug 2), Habit Detail two-state redesign, NoorInfoSheet copy overhaul — all pushed (2026-04-22)

### Active Workstreams
- `phase-15-social-pulse` *(notifications / Social Pulse workstream)*
  - purpose: notification architecture and implementation (nudges, comment push, permission UX, real-device verification)
  - worktree: `/Users/abdulsaboorshaikh/Desktop/Circles/.claude/worktrees/phase-15-social-pulse`
  - branch note: `.planning/notes/phase-15-social-pulse.md`
  - status: Phase 15.1 and 15.2 are built pending user verification; remaining code work in this phase is 15.3 circle check-in notifications, 15.4 habit reminders, and end-of-phase hardening
  - conceptual mapping: phase numbering is now **Phase 15 — Social Pulse**. The branch name and worktree path now match that numbering.

### Next Workstream on `main`
- **Amir Onboarding Overhaul** — routing bug fix + flow reorder + shared personalization questions
  - Full scope in "Amir Onboarding Overhaul Handoff" section below
  - No new Phase 15 work until this is shipped and QA'd on `main`

### Recommended Merge Order
1. Merge the lower-risk branch first
2. Update the remaining branch from `main`
3. Resolve conflicts there
4. Rebuild and re-test
5. Merge the second branch

If one branch heavily changes shared app lifecycle code, merge that branch first so the other branch can rebase onto the final shape.

---

## Integration Hotspots

Changes in these files or areas are more likely to overlap across branches:
- `Circles/CirclesApp.swift`
- `Circles/ContentView.swift`
- `Circles/Services/`
- `Circles/Profile/`
- `Circles/Home/`
- shared models used across multiple flows
- any push / auth / session bootstrap logic

When a workstream touches one of these areas:
- keep commits small
- note the exact files in the branch-specific note
- update this shared handoff if the change affects other branches

---

## Coordination Rules

- Each active agent should work in its own `git worktree`
- Each active agent should use its own branch
- No agent should commit directly to `main`
- Avoid editing the same files in parallel unless necessary
- Before stopping a session, update the branch note in `.planning/notes/`
- Update this file only when repo-wide coordination state changes

---

## Branch Note Convention

Each active workstream should maintain a note file in `.planning/notes/` with:
- goal
- touched files
- decisions
- verified state
- next step
- blockers

Template:
- `.planning/notes/_TEMPLATE.md`

---

## Open Cross-Stream Risks

- Notification work may need app lifecycle or token-registration changes that overlap with shared services
- Final-pass testing may expose issues in shared flows that notifications also touch
- If both branches modify startup routing or shared models, expect rebase friction

---

## Update Checklist

Update this file when:
- a new branch/worktree becomes active
- a branch merges to `main`
- merge order changes
- a new integration hotspot appears
- one workstream creates a repo-wide constraint for another

Do not update this file for ordinary per-session progress. Put that in the branch note instead.

---

## Amir Onboarding Overhaul Handoff (scoped 2026-04-22)

### Context
Phase 14 added a personal habits quiz to Amir onboarding, but the routing was never cleaned up. The old `AmiirStep3PersonalView` (personal habits catalog) still appears after the quiz because `transitionToAI` in `AmiirOnboardingFlowView` routes to `proceedToPersonalIntentions()` instead of `proceedToAIGeneration()`. The steps `transitionToPersonal` and `personalIntentions` are now dead code.

Separately, the shared habits step has no personalization — users see a flat catalog with no context. Flow order also needs resequencing (shared habits before circle identity).

### Bug Fix (routing)

**Root cause:** `AmiirOnboardingFlowView`, `case .transitionToAI` — action calls `coordinator.proceedToPersonalIntentions()`. Should call `coordinator.proceedToAIGeneration()`.

**Dead code to remove:**
- `case .transitionToPersonal` in `AmiirOnboardingFlowView`
- `case .personalIntentions` in `AmiirOnboardingFlowView`
- `AmiirStep3PersonalView.swift` — the old personal catalog screen
- `proceedToTransitionToPersonal()`, `proceedToPersonalIntentions()` in coordinator (confirm nothing else calls them first)
- `.transitionToPersonal`, `.personalIntentions` cases from the `Step` enum

### New Flow Order

```
Landing →
Shared personalization (3 questions, new screen) →
Pick shared habits (AmiirStep2HabitsView, catalog ranked by answers) →
Circle identity (AmiirStep1IdentityView — name + Amir details + circle name) →
"Some growth is private" transition →
Private quiz (AmiirQuizStepView) →
AI roadmap generation (AmiirAIGenerationView) →
Location / foundation (AmiirStep3LocationView) →
Auth (AmiirActivationView)
```

**"Some growth is private" transition:** Was positioned after AI generation. Moves to between circle identity and the quiz. Update `AmiirOnboardingFlowView` routing accordingly.

### Shared Personalization Questions (new screen)

New view: `AmiirSharedPersonalizationView` — shown before `AmiirStep2HabitsView`.

Three questions, chip-select UI:

**Q1 — Where is your group spiritually?**
- Rebuilding — we've drifted, want to get back
- Grounded — we have a foundation, want to go deeper
- Mixed — different levels in our group

**Q2 — Daily time commitment?**
- Light (10–15 min)
- Moderate (30 min)
- Deep (1 hour+)

**Q3 — Heart of your Circle?**
- Salah & remembrance
- Quran & knowledge
- Growth & discipline
- A bit of everything

Store answers in `AmiirOnboardingCoordinator` (3 new properties). Pass to catalog ranking logic.

### Catalog Ranking Logic

`AmiirStep2HabitsView` reorders `curatedHabits` based on answers. Simple priority matrix:

| Focus | Top habits |
|-------|-----------|
| Salah & remembrance | Fajr, Dhuhr, Asr, Maghrib, Isha, Dhikr |
| Quran & knowledge | Quran, Tahajjud, Dhikr |
| Growth & discipline | Fasting, Sadaqah, Tahajjud |
| Everything | Default order |

Rebuilding + Light → de-prioritize Tahajjud, Fasting (too demanding for entry level).
Grounded + Deep → surface Tahajjud, Fasting at top.

No Gemini. Catalog stays static, order changes.

### Files to Touch
- `Circles/Onboarding/AmiirOnboardingFlowView.swift` — routing fix + new step wiring
- `Circles/Onboarding/AmiirOnboardingCoordinator.swift` — new properties, dead method removal, new Step cases
- `Circles/Onboarding/AmiirStep2HabitsView.swift` — add ranking logic
- `Circles/Onboarding/AmiirStep3PersonalView.swift` — **delete**
- `Circles/Onboarding/AmiirSharedPersonalizationView.swift` — **new file**

### Parked
- Gemini for shared habit suggestions — post-MVP
- "Each their own" accountability model fork — post-MVP
- Member onboarding (test 2) re-QA — after Amir flow is fixed

---

## Phase 14 Handoff — Meaningful Habits (2026-04-20)

**Status:** Built, compiling, committed in six self-contained commits. Pending user QA in a fresh Simulator session.

### Commits landed (in order)

| Commit | Title |
|--------|-------|
| `70481b7` | `docs(14): lock Noor Bead direction + phase 14 session re-entry notes` |
| `cdf3b3e` | `docs(15): sync phase 15 coordination handoff + branch note` |
| `03b97da` | `Phase 14.1 — SQL migration (niyyah + struggles)` |
| `a8bd8fc` | `Phase 14.2 — onboarding quiz coordinator + struggle screens` |
| `2b55fa8` | `Phase 14.3 — Gemini habit suggestions wiring` |
| `145cebc` | `Phase 14.4 — niyyah on habit creation + detail` |
| `f42ab0c` | `Phase 14.5 — Hamdulillah check-off micro-moment` |
| `ca32895` | `Phase 14.6 — Noor Bead streak centerpiece` |

### Database
- SQL migration was applied directly to hosted Supabase on 2026-04-20 via Dashboard → SQL Editor. File lives at `.planning/phases/14-meaningful-habits/migrations/001_niyyah_and_struggles.sql` as an archival record. It is idempotent and safe to re-run.

### What to test (test plan for fresh Simulator session)

1. **Fresh Amir onboarding (create circle path)**
   - Complete onboarding through Step 2 (Habits). "Continue" should route into the quiz.
   - Screen A: pick 1–3 Islamic struggles.
   - Screen B: pick 1–3 life struggles.
   - Screen C: processing state shows briefly (~1–2s), then
   - Screen D: 4–6 Gemini suggestions + "Custom…" row.
   - Select a suggestion → flow continues into circle creation as before.
   - Verify `profiles.struggles_islamic` / `struggles_life` and the new habit land correctly in Supabase.

2. **Fresh Member onboarding (join circle path)**
   - After `JoinerCircleAlignmentView`, "Continue" should route into the same quiz.
   - Repeat Screen A → D as above, then onboarding completes.

3. **Intercept gate on existing user (no quiz answers yet)**
   - Sign in as an account whose `profiles.struggles_islamic/life` are NULL.
   - Tap the FAB on Home → should open the quiz intercept rather than going straight to pickHabit.
   - Answer, then fall through into the normal add-private-intention flow.
   - On a second open of the FAB within the session, the quiz must NOT appear.

4. **Niyyah step**
   - Add a private habit. After pick + familiarity, the niyyah step appears.
   - Enter a one-liner → verify it is stored on the habit and renders on `HabitDetailView` as the italic parchment pull-quote.
   - Repeat, tapping "Skip for now" → verify the habit saves with `niyyah = NULL` and the quote area is hidden.

5. **Hamdulillah micro-moment**
   - On Home, check off a habit → expect a soft gold wash + "Alhamdulillah" over that row for ~1.5s, plus a `success` haptic.
   - Undo that same row → expect no overlay, no celebratory haptic, just a light impact tap.
   - Confirm the overlay respects row shape (hero, shared, personal cards).

6. **Noor Bead tier progression**
   - Hero now shows the Noor Bead + "N Day Streak" + tier caption + next-tier hint.
   - Breathing aura and slow star rotation should render (respect `reduceMotion`).
   - On checking off the *last* pending habit of the day, ignite burst fires once. Undo does not re-fire.
   - Tier table lives in `.planning/phases/14-meaningful-habits/14-CONTEXT.md` §D.

### Known non-blockers
- Pre-existing `result of 'try?' is unused` warnings in `HomeViewModel.swift`. Not introduced by this phase; leave for a later hygiene sweep.
- No new dependencies. No `project.pbxproj` edits were required; Xcode picks up the new Swift files under existing groups.

### Files touched
- Quiz: `Circles/Onboarding/Quiz/*` (coordinator, flow view, four screens, option types, hosting shims)
- Pre-auth staging: `Circles/Onboarding/OnboardingPendingState.swift`
- Coordinators: `AmiirOnboardingCoordinator.swift`, `MemberOnboardingCoordinator.swift`, their flow views and the two step views that launch the quiz
- Models: `Profile.swift`, `Habit.swift`, `HabitSuggestion.swift` + `HabitSuggestion+Fallback.swift`, `StreakMilestone.swift`
- Services: `GeminiService.swift` (new method), `HabitService.swift` (niyyah param)
- Home: `AddPrivateIntentionSheet.swift`, `HabitDetailView.swift`, `HomeView.swift`, `HomeViewModel.swift`, new `HamdulillahOverlay.swift`, new `StreakBeadView.swift`
