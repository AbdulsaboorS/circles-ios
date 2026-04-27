---
gsd_state_version: 1.0
milestone: v2.4
milestone_name: milestone
status: active
last_updated: "2026-04-27T22:00:00.000Z"
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

Carry-forward (next session):
- **#5 closed (2026-04-26 session 2).** Step-by-step back-nav confirmed sufficient for MVP. Full back-to-start deferred — kill+relaunch is a clean reset and avoids state-restoration cost.
- **#7 partially shipped (2026-04-26 session 2).** Diagnostic logs surfaced root cause: 8 s race losing to cold-network second attempts (not a Gemini error). Shipped: (a) per-fingerprint cache so back-then-forward without changes reuses last successful result instead of re-firing the API, (b) Tier A reliability — timeout 8→15s + `maxOutputTokens: 400` cap on the Gemini request + elapsed-time logging on success/error/timeout. **Tier B (streaming via `streamGenerateContent`)** still open for next session, naturally bundled with #8 since both touch `GeminiService` + suggestions UI.
- **#8 shipped (2026-04-26 session 3), pending hands-on QA.** Curated pool of 10 + ranking + `.prefix(3)` cap kept as-is. Each tile now renders a one-sentence rationale: baked-in default (per-habit static map) renders instantly; Gemini-personalized rationale swaps in within 1–15 s. New `GeminiService.generateHabitRationales` (additive — roadmap path untouched). Coordinator gains `habitRationales` state, fingerprint cache (`(spirituality, time, heart, top3)`), 15 s race + dedupe via in-flight `Task` handle, only-cache-on-success — same pattern as `OnboardingQuizCoordinator`. `HabitTile` expanded with 12 pt serif italic rationale row mirroring `QuizHabitSelectionView.swift:183-188`. Ranking moved out of view into `coordinator.rankedTopHabits()` (single source of truth for tile list + Gemini fetch). On timeout, defaults stay — no spinner, no error UI.

## Onboarding rework — 2026-04-27 (catalog architecture locked)

Session pivoted from per-bug QA into a structural fix. After testing both flows, decided the AI-rationale path is the wrong abstraction for onboarding suggestions. Locked a catalog-driven architecture, ready to build next session.

**Shipped this session (build green, on `main`):**
- New `Circles/Services/GroqService.swift` — Llama 3.3 70B Versatile via Groq, OpenAI-compatible JSON mode, 8 s timeout. `GROQ_API_KEY` added to `Secrets.plist`.
- `OnboardingQuizCoordinator.loadSuggestions` swapped Gemini → Groq (sub-second latency vs Gemini's 5–15 s cold).
- `AmiirOnboardingCoordinator.fetchRationales` swapped Gemini → Groq.
- `GeminiService` retained for `generate28DayRoadmap` only (latency-tolerant async).

**Locked for next session (build spec at `.planning/notes/habit-catalog-draft.md`):**
- 44-entry hand-curated `HabitCatalog` becomes single source of truth for both Amir and Joiner suggestion paths. AI removed entirely from onboarding suggestion path.
- Surfacing layout: 4 personalized + 3 common starters = 7 total, no overlap (set partition).
- Selection caps: shared (Amir) = 2, personal (Joiner / private intentions) = 3.
- 8 entries get per-spirituality rationale variants (gentle for J, ambitious for D); other 36 use one default.
- Custom-habit chip UX (inline "+ Add your own" → chips in same list, multi-add) — user explicitly called this "the biggest moat."
- Amir Step 1 (3 questions on one scrolling page) splits into 3 separate pages.

**Build order (7 steps) listed at bottom of `.planning/notes/habit-catalog-draft.md`.** Steps are sequential; step 1 (`HabitCatalog.swift`) unlocks 2–4. Decision context and rationale also saved to memory at `project_habit_catalog_decision.md`.

**Build progress (2026-04-27 session 2):**
- ✅ Step 1 — `Circles/Models/HabitCatalog.swift` shipped: `HabitEntry` struct, all 44 entries, 8 per-spirituality variants (#1, #7, #10, #12, #20, #33, #42, #43), tag enums (`CatalogSpirituality`, `CatalogHeart`, `CatalogTimeWeight`) with answer-string mappers.
- ✅ Step 2 — `HabitCatalog.recommendations(for:)` shipped: `RankInput` struct + `Recommendations { top, starters }` partition. Scoring: heart +3, struggle slugs +1 each, time-fit ±. Deterministic FNV-1a seed jitter for stable per-user tiebreak.
- ⏳ Steps 3–7 NOT started: Amir Step 2 wiring, joiner quiz wiring, Amir Step 1 split, custom-habit chips, cap drop. AmiirOnboardingCoordinator still has the Groq rationale path intact — must be removed in step 3. No call sites have been migrated to the catalog yet.

**Bugs #7 and #8 superseded** — the "always same 3 habits" symptom was a catalog-narrowness problem, not an AI problem. Catalog rework solves both.

## Deferred QA / Rollout

- deploy `supabase/functions/send-circle-check-in`
- run one combined QA pass for Phase 15.2, 15.3, and 15.4 after the higher-priority onboarding, UI/UX, naming, branding, and landing-page work

## Scope Notes

- this file is current-state only
- historical session logs and long test plans should live outside startup docs
