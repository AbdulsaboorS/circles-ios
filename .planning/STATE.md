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

**Next: Amir Onboarding Overhaul** — routing bug fix, flow reorder, 3 shared-personalization questions, catalog ranking. Full spec in `.planning/notes/main.md`.

After that: Phase 15 — Social Pulse (merge `phase-15-social-pulse` worktree after Amir overhaul ships).

## Phase Status

| Phase | Name | Status |
|-------|------|--------|
| 1–12 | Schema, Nav, Profiles, Habits, Circles, Onboarding, AI, Moments, Feed, Streak, Cleanup | ✓ Complete |
| 13 | UI/UX Pass (all waves) | ✓ Complete |
| 13A | Journey Tab | ✓ Complete |
| 13B | Profile Redesign | ✓ Complete |
| 14 | Meaningful Habits (quiz, niyyah, Hamdulillah, Noor Bead) | ✓ Complete + QA'd |
| 15 | Social Pulse | 🔄 In worktree, pending merge |
| 16–19 | Naming, Videos, Landing Page, App Store | ⬜ Planned |

## What Shipped — Session 26 (2026-04-22)

- Phase 14 QA: tests 3–6 verified; test 1 routing bug found and scoped; test 2 pending after fix
- **NoorInfoSheet**: "HOW IT WORKS" section (3 bullets), Sanctuary dead-end fix, sparkle ladder on tier rows
- **Bug 1**: Multi-select Gemini in intercept quiz — verified
- **Bug 2**: Quiz re-entry delta screen — verified
- **Habit Detail two-state redesign**: CheckInOrb + HabitMonthCalendar — verified

## Design Decisions (permanent)

- Circle members presence row on HabitDetailView — **parked**. Nudges stay in Circles activity view.
- Gemini for shared habit suggestions — **parked post-MVP**. Catalog + ranking sufficient.
- "Together" accountability model ships first. "Each their own" fork is post-MVP.
- `AmiirStep3PersonalView` (old personal catalog) to be deleted — quiz replaced it.

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
