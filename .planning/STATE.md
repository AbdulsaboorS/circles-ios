---
gsd_state_version: 1.0
milestone: v2.4
milestone_name: milestone
status: active
last_updated: "2026-04-26T22:00:00.000Z"
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
- **#5 Back/forth onboarding nav smoke test.** State lives on coordinator and pops via `navigationPath.removeLast()`, so should work — needs hands-on verification across the primer/AI-gen/quiz boundaries.
- **#7 Personal-intentions habits always show the same 5 (Gemini failing).** `OnboardingQuizCoordinator.loadSuggestions()` falls back to `HabitSuggestion.fallbackSuggestions` (the 5 hardcoded names) on any throw/8 s timeout. Suspect API key, `gemini-3-flash-preview` model id, quota, or parsing. Add logging in `GeminiService.swift:204` and reproduce in sim.
- **#8 Shared-intentions habits — only 3, same 3, not personalized.** `AmiirStep2HabitsView.swift`: `.prefix(3)` caps the list, and `habitScore` is keyword scoring against the 3 shared-personalization questions only — quiz struggles unused, curated pool is 10 names. User decision pending: route through Gemini, or keep curated + rank smarter?

## Deferred QA / Rollout

- deploy `supabase/functions/send-circle-check-in`
- run one combined QA pass for Phase 15.2, 15.3, and 15.4 after the higher-priority onboarding, UI/UX, naming, branding, and landing-page work

## Scope Notes

- this file is current-state only
- historical session logs and long test plans should live outside startup docs
