---
gsd_state_version: 1.0
milestone: v2.4
milestone_name: milestone
status: active
last_updated: "2026-04-27T02:36:00.000Z"
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

## Deferred QA / Rollout

- deploy `supabase/functions/send-circle-check-in`
- run one combined QA pass for Phase 15.2, 15.3, and 15.4 after the higher-priority onboarding, UI/UX, naming, branding, and landing-page work

## Scope Notes

- this file is current-state only
- historical session logs and long test plans should live outside startup docs
