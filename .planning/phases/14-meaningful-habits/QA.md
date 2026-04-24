# Phase 14 — Moment Mechanic QA Matrix

Non-startup doc. Run when doing hands-on validation of Phase 14.
All code work (10-item `posted_at` → `moment_date` audit) is closed on `main`.

## Setup

- Build Debug on iPhone 17 Pro simulator.
- Drive gate states via the DEBUG `forceOpenWindow` button or
  `UPDATE daily_moments SET moment_time = ...` in Supabase.
- Clear rows between tests via the DEBUG "delete today's moments" button.

## 9-Test Moment Matrix

1. **`.preWindow`** — feed shows **yesterday's** moments (BeReal Memories pattern), no gate visible.
2. **`.windowOpen`** — feed switches to today; gate CTA reads "Share your Moment".
3. **On-time post** — post within window → own card pinned, gate dismissed, on-time pill visible (elapsed < 5 min).
4. **`.missedWindow`** — gate CTA flips to "Post a late Moment", feed still shows today.
5. **Late + pre-window on-time check** — post > 5 min after window open → `is_on_time = false`, no pill. Also: if reachable via SQL, confirm a pre-window post is also `false` (guards audit #7 regression).
6. **Cross-UTC-midnight rollover** — advance sim so window opens 23:50 UTC; post at 00:10 UTC. Verify all five:
   - Moment card appears in today's feed (moment_date = yesterday's UTC day).
   - Journey month view places the moment on yesterday's date (not today's).
   - Caption edit on that moment saves (no silent no-op).
   - Spiritual Ledger tap on yesterday's date shows that photo.
   - Niyyah, if entered, is stamped on yesterday's date — same day as the moment row.
   - Optimistic card doesn't duplicate after pull-to-refresh (dedupe keys on `momentDate`).
7. **DEBUG force-delete** — "delete today's moments" wipes the just-posted moment, even when posted cross-midnight.
8. **Caption persistence** — edit caption, kill app, relaunch → caption persists.
9. **Multi-circle dedupe** — post to 3 circles from the camera flow. Community feed shows ONE card with 3 circle badges. Per-circle feed in each shows the same card.

## Also for Phase 14 Sign-off

- Joiner onboarding re-test (Phase 14.1 Task 6):
  - Fresh Amir onboarding pass (catalog ranking)
  - Member onboarding re-test
  - Joiner flow end-to-end

## Sign-off

When all 9 moment tests + joiner re-test pass:
- Update `.planning/STATE.md`: Phase 14 status → complete.
- Remove Phase 14 from the "awaiting hands-on validation" line in HANDOFF.md.

## Reference

- Migration: `supabase/migrations/20260423_moment_mechanic_redesign.sql`
- DB unique index: `circle_moments_one_per_day (user_id, moment_date)`
- Audit closure commits: `160e938`, `2118403`
