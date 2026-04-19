# fix-moment-gate

## Goal

Fix the moment gate (ReciprocityGateView) not appearing even when the daily window is open.

## Scope

`DailyMomentService` and `MomentService` only. No UI changes. No DB changes.

## Touched Files

- `Circles/Services/DailyMomentService.swift`
- `Circles/Services/MomentService.swift`

## Decisions

- `computeHasPostedToday` now takes `since windowStart: Date` — queries posts only from today's trigger time, not from the active cycle range (which could bleed back into yesterday).
- `MomentService.fetchTodayMoments` uses `DailyMomentService.shared.windowStart` directly instead of re-calling `fetchActiveMomentRange`.
- `iso8601String` promoted from `private` to `internal` so `MomentService` can access it.
- `fetchActiveMomentRange` itself is unchanged — still used for feed display (showing current cycle posts), which is correct behavior.
- Committed directly to `main` (pre-worktree-transition, user-approved). Future fixes should use a dedicated branch + worktree.

## Verified

- `xcodebuild` build succeeded (zero errors)
- Confirmed today's `daily_moments` row via MCP: `2026-04-19, moment_time=21:30 UTC` — cron healthy.

## Next

- Manual runtime QA: open app before 21:30 UTC → no gate (window not open) ✓, feed shows yesterday's post ✓
- After 21:30 UTC: gate CTA should appear
- Use DEBUG `forceOpenWindow` to fast-test gate open/close/repost cycle
- Verify circle-detail gate also works correctly after post

## Blockers

None.

## Notes For Re-entry

The root cause: `computeHasPostedToday` used `fetchActiveMomentRange` as its lower bound. Before today's trigger fires, the active range spans back to yesterday's trigger time, so yesterday's post matched → false positive → gate locked for the day.

Fix is purely query-anchor alignment: `hasPostedToday` and `isGateActive` now both use the same `windowStart` (today's trigger from `daily_moments.moment_time`).
