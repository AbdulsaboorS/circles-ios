---
gsd_state_version: 1.0
milestone: v2.4
milestone_name: milestone
status: active
last_updated: "2026-04-27T19:00:00.000Z"
progress:
  total_phases: 19
  completed_phases: 15
  total_plans: 15
  completed_plans: 13
---

# Circles iOS — State (v2.4)

## Current Truth

- `main` now contains the shipped foundation through Phase 15
- Phase 14 Meaningful Habits is built and still needs hands-on validation
- Phase 15 Social Pulse is merged to `main`, code-complete, and build-verified
- Phase 15 rollout work and combined notification QA are intentionally deferred

## Product Priority Order

1. Test onboarding bugs and fix them
2. Do the full UI/UX pass
3. Finalize the name
4. Finalize the logo
5. Work on landing-page video animations and onboarding animations if needed

## Phase Snapshot

- Phase 13 UI/UX pass: complete
- Phase 13A Journey: shipped
- Phase 14 Meaningful Habits: built, QA in progress (matrix: `.planning/phases/14-meaningful-habits/QA.md`). Session 2026-04-24 fixed 4 moment-mechanic bugs found during QA: (1) per-circle unique index, (2) feed-vs-gate cold-start race, (3) camera countdown tracking wrong cutoff, (4) camera top/bottom control centering. Camera-side fixes pending in-sim visual verification by user.
- Phase 15 Social Pulse: merged to `main`, QA deferred
- Phase 16 Naming + Branding: planned
- Phase 17 Animation Polish: planned
- Phase 18 Web Landing Page: planned
- Phase 19 App Store Submission: planned

## Phase 15 Summary

- Phase 15.1 foundation and moment-window preferences are user-smoke-tested
- Phase 15.2 nudge notifications are code-reviewed and build-verified
- Phase 15.3 circle check-in notifications are code-complete and build-verified
- Phase 15.4 local habit reminders are code-complete and build-verified
- `circle_check_in_notifications.sql` already ran successfully in Supabase
- `send-circle-check-in` still needs deployment later

## Onboarding QA — 2026-04-26

User-flagged 8 issues during end-to-end onboarding test. Fixes shipped to `main`, build green on iPhone 17 Pro sim, awaiting hands-on QA:
- #1 Prayer Sync screen reframed away from Moment-anchoring → "prayer times + Adhan notifications" (kept for TestFlight MVP).
- #2 AI-gen → Moment primer transition softened: 2-phase reveal in `AmiirAIGenerationView` + `JoinerAIGenerationView` (~1.6 s spinner → checkmark.seal + "Your plan is ready. It'll be waiting on your dashboard." → primer).
- #3 Daily Moment primer: "Your Daily Moment" capitalized, em dashes scrubbed from beats 1 + 2, **new beat 3** clarifying niyyah-vs-photo dichotomy (photo for circle, niyyah for the Creator). Beat 4 keyframes added.
- #4 Prayer Sync double back button — `AmiirStep3LocationView` was missing `.navigationBarBackButtonHidden()`.
- #6 `QuizProcessingView` copy: "Building your intentions…" → "Personalizing habits from your struggles…"

Carry-forward:
- #5 remains closed; step-by-step back-nav is sufficient for MVP.
- Old AI-specific bug work for #7/#8 is now superseded by the catalog migration below. Current risk is end-to-end QA of the deterministic onboarding flow, not provider tuning.

## Onboarding rework — 2026-04-27 (catalog architecture locked)

Session pivoted from per-bug QA into a structural fix. After testing both flows, the onboarding suggestion path was moved off AI entirely and onto a deterministic 44-entry `HabitCatalog`.

**Architecture now in use (build green):**
- `HabitCatalog` is the single onboarding source of truth for Amir shared habits and both personal quiz flows.
- `OnboardingQuizCoordinator` now ranks the catalog deterministically from struggle answers, with no Groq/Gemini dependency in onboarding.
- Amir shared habits also read directly from the catalog using spirituality/time/heart inputs and render the catalog rationale text immediately.
- `GeminiService` remains the roadmap generator; the old onboarding AI suggestion/rationale path is superseded.

**Locked decisions:**
- 44-entry hand-curated `HabitCatalog` becomes single source of truth for both Amir and Joiner suggestion paths. AI removed entirely from onboarding suggestion path.
- Surfacing layout: 4 personalized + 3 common starters = 7 total, no overlap (set partition).
- Selection caps: shared (Amir) = 2, personal (Joiner / private intentions) = 3.
- 8 entries get per-spirituality rationale variants (gentle for J, ambitious for D); other 36 use one default.
- Custom-habit chip UX (inline "+ Add your own" → chips in same list, multi-add) — user explicitly called this "the biggest moat."
- Amir Step 1 (3 questions on one scrolling page) splits into 3 separate pages.

Decision context and rationale also saved to memory at `project_habit_catalog_decision.md`. Detailed catalog content still lives in `.planning/notes/habit-catalog-draft.md`.

**Build progress (2026-04-27 session 3):**
- ✅ Step 1 — `Circles/Models/HabitCatalog.swift` shipped: `HabitEntry` struct, all 44 entries, 8 per-spirituality variants (#1, #7, #10, #12, #20, #33, #42, #43), tag enums (`CatalogSpirituality`, `CatalogHeart`, `CatalogTimeWeight`) with answer-string mappers.
- ✅ Step 2 — `HabitCatalog.recommendations(for:)` shipped: `RankInput` struct + `Recommendations { top, starters }` partition. Scoring: heart +3, struggle slugs +1 each, time-fit ±. Deterministic FNV-1a seed jitter for stable per-user tiebreak.
- ✅ Step 3 — Amir shared-habits flow now uses `HabitCatalog` directly. `AmiirOnboardingCoordinator` no longer owns the Groq rationale/cache path; Step 2 renders the catalog's 4 personalized + 3 starter partition and uses per-spirituality rationale variants inline.
- ✅ Step 4 — Joiner/personal quiz now uses `HabitCatalog` deterministically. `OnboardingQuizCoordinator` no longer runs the Groq race/cache path; both Amir and Joiner wrappers seed the quiz from staged state and write back plain habit names.
- ✅ Step 5 — Amir Step 1 is split into 3 screens (`AmiirSpiritualityStepView`, `AmiirTimeCommitmentStepView`, `AmiirHeartOfCircleStepView`) and the Amir flow step indicators were updated to the 10-step sequence.
- ✅ Step 6 — Custom-habit chip UX shipped on both active selection surfaces: Amir shared habits and the personal quiz. "+ Add your own" now creates removable chips inline and supports multiple custom entries up to the cap.
- ✅ Step 7 — Selection caps dropped to the locked values: shared = 2, personal = 3. Joiner's old dead `personalHabits` route was removed from the active flow. `AddPrivateIntentionSheet` was also updated to the new multi-select callback shape so the guided intercept still compiles.
- ✅ Build verification — `xcodebuild -quiet -project Circles.xcodeproj -scheme Circles -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' build` passed on 2026-04-27. Only warning observed was pre-existing async/no-async noise in `FeedService.swift:99`.

**Bugs #7 and #8 superseded** — the "always same 3 habits" symptom was a catalog-narrowness problem, not an AI problem. Catalog rework solves both.

## Onboarding habit-card UX pass — 2026-04-27 session 4

Hands-on QA of the catalog flow surfaced 3 layout issues. Fixes shipped, build green:

- **Unified card style.** Shared habits screen (`AmiirStep2HabitsView`) was using a 2-col `LazyVGrid` of `HabitTile`s — uneven row heights with mixed-length rationales. Refactored to single-column rows matching the personal quiz screen's pattern. Both screens now use a shared `OnboardingHabitRow` (full-width card, leading icon block, name + serif rationale, trailing checkmark/remove).
- **Custom-habit slot.** Replaced the pill+TextField+chip-grid pattern on both screens with a card-shaped `OnboardingCustomHabitSlot` that expands inline (collapsed `+ Add your own` → editing TextField → committed row in same list geometry). Customs commit *unselected* — user must tap the row to select, consistent with catalog rows.
- **Personal/shared overlap fix.** `HabitCatalog.RankInput` now takes `excludedNames: Set<String>`; filtered before scoring. `OnboardingQuizCoordinator.excludedHabitNames` plumbs through. Amir personal quiz excludes `coordinator.selectedHabits`; Joiner personal quiz excludes `circle.coreHabitsSafe`. Personal recommendations no longer duplicate shared circle habits.
- **Files touched:** `Models/HabitCatalog.swift`, `Onboarding/Quiz/OnboardingQuizCoordinator.swift`, `Onboarding/Quiz/AmiirQuizStepView.swift`, `Onboarding/Quiz/JoinerQuizStepView.swift`, `Onboarding/Quiz/QuizHabitSelectionView.swift`, `Onboarding/AmiirStep2HabitsView.swift`. New: `Onboarding/OnboardingHabitCards.swift`. Deleted: `Onboarding/OnboardingCustomHabitChip.swift` (superseded by the new slot+row combo).
- **Build verification.** `xcodebuild` on iPhone 17 sim (OS 26.3.1) passed; only warnings are pre-existing `FeedService.swift` and `AuthManager.swift` async/no-async noise.

## Deferred QA / Rollout

- deploy `supabase/functions/send-circle-check-in`
- run one combined QA pass for Phase 15.2, 15.3, and 15.4 after the higher-priority onboarding, UI/UX, naming, branding, and landing-page work

## Scope Notes

- this file is current-state only
- historical session logs and long test plans should live outside startup docs
