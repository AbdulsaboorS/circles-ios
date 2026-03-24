---
phase: 02-habits-daily-check-in
plan: 03
subsystem: ui
tags: [swift, swiftui, observable, optimistic-ui, habit-tracking, calendar-grid]

# Dependency graph
requires:
  - phase: 02-habits-daily-check-in
    plan: 01
    provides: HabitService.shared, Habit/HabitLog/Streak models
  - phase: 01-auth-core-nav-shell
    provides: AuthManager, SupabaseService.shared, MainTabView
affects: [daily check-in flow, habit detail screen, HomeView tab]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@Observable @MainActor ViewModel owning optimistic toggle state"
    - "async let parallel fetch (habits + logs + streak in parallel)"
    - "Optimistic UI with revert-on-error for habit toggle"
    - "NavigationLink(value:) + navigationDestination(for:) for type-safe navigation"
    - "Direct Supabase client query in detail view (documented exception to Services/ pattern)"
    - "LazyVGrid 7-column dot calendar for 28-day history"

key-files:
  created:
    - Circles/Home/HomeViewModel.swift
    - Circles/Home/HabitDetailView.swift
  modified:
    - Circles/Home/HomeView.swift
    - Circles/Models/Habit.swift

key-decisions:
  - "HomeViewModel owns all home state — habits, todayLogs, streak; drives HomeView purely"
  - "Optimistic toggle: flip local state first, revert on Supabase error"
  - "HabitDetailView queries Supabase client directly for 28-day range — HabitService has no date-range-by-habitId method; adding one would be premature abstraction for a single use case"
  - "Habit: Codable, Identifiable, Equatable, Hashable — Hashable required for NavigationLink(value:) type-safe navigation"

requirements-completed: [PHASE2-DAILY-CHECKIN, PHASE2-STREAKS, PHASE2-HABIT-DETAIL]

# Metrics
duration: ~5min
completed: 2026-03-24
---

# Phase 2 Plan 03: HomeViewModel + HomeView + HabitDetailView Summary

**HomeViewModel with parallel fetch and optimistic toggle + HomeView habit list with streak banner + HabitDetailView 28-day dot calendar**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-24T02:22:53Z
- **Completed:** 2026-03-24T02:27:38Z
- **Tasks:** 3 complete (including human verification)
- **Files modified:** 2 created, 2 modified

## Accomplishments

- `HomeViewModel`: `@Observable @MainActor` class with parallel `async let` fetch of habits + today's logs + streak; optimistic `toggleHabit` that reverts local state on Supabase failure
- `HomeView`: full daily check-in screen — greeting, streak banner (fire emoji + currentStreak/longestStreak), habit list with checkbox toggle buttons, `NavigationLink(value:)` routing to HabitDetailView, pull-to-refresh, `.task` on-appear load, error alert
- `HabitDetailView`: 28-day completion dot grid (7-column `LazyVGrid`), hero card with icon/name/goal/stat badges, direct Supabase date-range query (documented intentional exception)
- `Habit` model: added `Hashable` conformance for type-safe `navigationDestination`
- BUILD SUCCEEDED, zero errors, Swift 6 clean

## Task Commits

1. **Task 1: HomeViewModel + HomeView** - `fcbdc65` (feat)
2. **Task 2: HabitDetailView with 28-day calendar grid** - `4f14324` (feat)
3. **Task 3: Human verification** - APPROVED (all 9 simulator checks passed)

## Files Created/Modified

- `Circles/Home/HomeViewModel.swift` — `@Observable @MainActor final class HomeViewModel`; parallel fetch; optimistic toggle with revert; `isCompleted(habitId:)` derived state
- `Circles/Home/HomeView.swift` — Daily check-in screen replacing Phase 1 stub; `HabitRow` private struct; streak banner; navigationDestination wired
- `Circles/Home/HabitDetailView.swift` — 28-day LazyVGrid dot calendar; StatBadge; `fetchLogs()` direct Supabase query; `dayNumber(from:)` helper
- `Circles/Models/Habit.swift` — Added `Hashable` to protocol conformance list

## Decisions Made

- Used `async let` parallel fetch in `loadAll(userId:)` — habits, logs, streak all fetched concurrently rather than sequentially. Reduces load time proportionally with network latency.
- `HabitDetailView` queries `SupabaseService.shared.client` directly for the 28-day range rather than adding `fetchRecentLogs(habitId:startDate:)` to `HabitService`. This is an intentional, documented exception — the query is read-only, local to one view, and would not benefit from abstraction at this stage.
- Revert pattern in `toggleHabit`: `todayLogs[idx].completed = !newCompleted` in the catch block — restores the exact pre-toggle state without a full network reload.

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### Context Notes

The parallel 02-02 agent had already written `HomeView.swift` as a Rule 3 pre-fix (to unblock the build for `HabitDetailView` stub). When this agent ran, `HomeView.swift` was already at the correct implementation — our `Write` call matched the existing content exactly. No re-work needed; the 02-02 agent's pre-write aligned with 02-03's plan spec.

## Human Verification Result

**Task 3** (`checkpoint:human-verify`) — PASSED. User confirmed all 9 simulator checks pass:
- Onboarding → HomeView routing works
- Habit checkboxes toggle with optimistic UI
- HabitDetailView 28-day grid renders correctly
- App relaunches to HomeView (not onboarding) for existing users

## Known Stubs

None — HabitDetailView replaces the stub created by the 02-02 agent. All rendered data comes from live Supabase queries.

---
*Phase: 02-habits-daily-check-in*
*Completed: 2026-03-24 (Tasks 1-2; Task 3 pending human verify)*
