---
gsd_state_version: 1.0
milestone: v2.4
milestone_name: milestone
status: active
last_updated: "2026-04-24T00:00:00.000Z"
progress:
  total_phases: 19
  completed_phases: 13
  total_plans: 13
  completed_plans: 11
---

# Circles iOS — State (v2.4)

## Current Truth

- `main` contains the shipped foundation through Phase 13 plus the built Phase 14 Meaningful Habits work
- Phase 14 is built on `main` and still needs hands-on validation
- `phase-15-social-pulse` is code-complete and build-verified
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
- Phase 14 Meaningful Habits: built, QA pending
- Phase 15 Social Pulse: built in worktree, mergeable, QA deferred
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

## Deferred QA / Rollout

- merge the Phase 15 worktree when ready
- deploy `supabase/functions/send-circle-check-in`
- run one combined QA pass for Phase 15.2, 15.3, and 15.4 after the higher-priority onboarding, UI/UX, naming, branding, and landing-page work

## Scope Notes

- this file is current-state only
- historical session logs and long test plans should live outside startup docs
