---
gsd_state_version: 1.0
milestone: v2.4
milestone_name: milestone
status: active
last_updated: "2026-04-23T00:00:00.000Z"
progress:
  total_phases: 19
  completed_phases: 14
---

# Circles iOS — State (v2.4)

## Current Focus

**Next: Task 6 (QA) + Joiner onboarding** — fresh Amir onboarding pass (verify catalog ranking), Member onboarding re-test, then full Joiner flow test + bug fixes. Phase 14 QA is not complete until Joiner is verified. Full spec in `.planning/HANDOFF.md`.

After Phase 14 QA is fully signed off: merge `phase-15-social-pulse` worktree → Phase 15.

## Phase Status

| Phase | Name | Status |
|-------|------|--------|
| 1–12 | Schema, Nav, Profiles, Habits, Circles, Onboarding, AI, Moments, Feed, Streak, Cleanup | ✓ Complete |
| 13 | UI/UX Pass (all waves) | ✓ Complete |
| 13A | Journey Tab | ✓ Complete |
| 13B | Profile Redesign | ✓ Complete |
| 14 | Meaningful Habits (quiz, niyyah, Hamdulillah, Noor Bead) | 🔄 QA in progress |
| 14.1 | Amir Onboarding Overhaul (tasks 1-5 done) | 🔄 Task 6 QA + Joiner pending |
| 15 | Social Pulse | 🔄 In worktree, pending merge |
| 18 | Web Landing Page (Astro + Tailwind, local-only v1) | 🔄 In progress (parallel, `/landing`) |
| 16, 17, 19 | Naming, Videos, App Store | ⬜ Planned |

## What Shipped — Session 29 (2026-04-23, PM)

- **Moment Mechanic Redesign (BeReal parity) — full stack shipped.** Commits `79bc28b → 5777c7a` on `main`.
  - Schema: `circle_moments.moment_date DATE NOT NULL` + unique index `(user_id, moment_date)` + pg_cron `seed_todays_daily_moment` @ 00:05 UTC (migration `20260423_moment_mechanic_redesign.sql`, run on Supabase).
  - `DailyMomentService`: stripped Aladhan, added `GateMode` enum (`preWindow/windowOpen/missedWindow/posted`), `currentWindowDate` accessor, filter by `moment_date` (not `posted_at` range).
  - `MomentService`: stamps `moment_date` on insert, on-time threshold `1800 → 300` (5-min pill).
  - `JourneyViewModel`: day-key → `moment.momentDate` (fixes UTC+ next-day drift).
  - `ReciprocityGateView.Mode` (`.open` / `.missed`) with late-post CTA; wired in `CommunityView` + `CircleDetailView`.
  - Build green. Manual QA pending (session 11 handoff block in `.planning/notes/main.md`).

## What Shipped — Session 28 (2026-04-23, AM)

- **Amir Onboarding Overhaul task 5**: `AmiirStep2HabitsView` ranks habit tiles via `habitScore(_:)` + `rankedHabits` computed var; scoring based on spiritualityLevel, heartOfCircle, timeCommitment

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
- `DailyMomentService` uses `moment_time` (UTC "HH:MM") — Aladhan fully removed session 29; `GateMode` enum drives gate copy with 30-min open→missed pivot
- Git: `main` branch, remote `origin` = GitHub (AbdulsaboorS/circles-ios)

## Open Issues

- **A. Gemini -1011 on Generate Plan** — `NSURLErrorBadServerResponse`. Verify `GEMINI_API_KEY` + model `gemini-3-flash-preview` enabled.
- **B. Habit check-in feed dedup** — `broadcastHabitCompletion` inserts unconditionally; low priority (3-toggle/day cap limits real impact).
- **D. Simulator CLI install/launch** — `simctl install`/`launch` unreliable from CLI; use Xcode directly.
