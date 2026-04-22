---
gsd_state_version: 1.0
milestone: v2.4
milestone_name: milestone
status: active
last_updated: "2026-04-22T00:00:00.000Z"
progress:
  total_phases: 19
  completed_phases: 14
---

# Circles iOS — State (v2.4)

## Current Focus

**Next: Amir Onboarding — Tasks 5-6** — catalog ranking + QA pass (Amir + Member). Then Joiner onboarding flow test + bug fixes. Phase 14 QA is not complete until Joiner is verified. Full spec in `.planning/HANDOFF.md`.

After Phase 14 QA is fully signed off: merge `phase-15-social-pulse` worktree → Phase 15.

## Phase Status

| Phase | Name | Status |
|-------|------|--------|
| 1–12 | Schema, Nav, Profiles, Habits, Circles, Onboarding, AI, Moments, Feed, Streak, Cleanup | ✓ Complete |
| 13 | UI/UX Pass (all waves) | ✓ Complete |
| 13A | Journey Tab | ✓ Complete |
| 13B | Profile Redesign | ✓ Complete |
| 14 | Meaningful Habits (quiz, niyyah, Hamdulillah, Noor Bead) | 🔄 QA in progress |
| 14.1 | Amir Onboarding Overhaul (tasks 1-4 done) | 🔄 Tasks 5-6 + Joiner QA pending |
| 15 | Social Pulse | 🔄 In worktree, pending merge |
| 16–19 | Naming, Videos, Landing Page, App Store | ⬜ Planned |

## What Shipped — Session 27 (2026-04-22)

- **Amir Onboarding Overhaul tasks 1-4**: flow reordered, routing bug fixed, personalization screen added, dead personal-catalog code removed
- New flow: personalization → habits → identity → "Some growth is private" → quiz → AI gen → location → auth
- `AmiirSharedPersonalizationView` added (3 chip-select questions; session-only coordinator state)
- `AmiirStep3PersonalView` deleted (quiz already captures personal habit)

## Design Decisions (permanent)

- Circle members presence row on HabitDetailView — **parked**. Nudges stay in Circles activity view.
- Gemini for shared habit suggestions — **parked post-MVP**. Catalog + ranking sufficient.
- "Together" accountability model ships first. "Each their own" fork is post-MVP.
- Personalization answers (spirituality level, time commitment, heart of circle) — **session-only**, not persisted to Supabase.

## DB State

| Table / Column | Status |
|----------------|--------|
| `habits` + `niyyah` | ✅ Active |
| `habit_logs`, `streaks` | ✅ Active |
| `circles`, `circle_members` | ✅ Active |
| `circle_moments` + `has_niyyah` | ✅ Active |
| `moment_niyyahs` | ✅ Active |
| `daily_moments` + `moment_time` | ✅ Active |
| `profiles` + `struggles_islamic/life` | ✅ Active |
| `activity_feed`, `habit_reactions`, `comments` | ✅ Active |
| `device_tokens` | ✅ Active |
| pg_cron jobs (2) | ✅ Active |

## Active Technical Decisions

- `@Observable @MainActor` throughout (Swift 6)
- Supabase client singleton: `SupabaseService.shared`
- `DATE` columns stored as `String` in Swift ("YYYY-MM-DD")
- `SwiftUI.Circle()` qualified — naming conflict with `Circle` model
- `import Supabase` required in every file accessing `auth.session?.user.id`
- `DailyMomentService` uses `moment_time` (UTC "HH:MM") as primary; Aladhan API is fallback
- Git: `main` branch, remote `origin` = GitHub (AbdulsaboorS/circles-ios)

## Open Issues

- **A. Gemini -1011 on Generate Plan** — `NSURLErrorBadServerResponse`. Verify `GEMINI_API_KEY` + model `gemini-3-flash-preview` enabled.
- **B. Habit check-in feed dedup** — `broadcastHabitCompletion` inserts unconditionally; low priority (3-toggle/day cap limits real impact).
- **D. Simulator CLI install/launch** — `simctl install`/`launch` unreliable from CLI; use Xcode directly.
