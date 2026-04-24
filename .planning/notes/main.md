# main — Session Note (2026-04-24, Session 13 handoff)

## Goal

Close Phase 14 QA. Session 13 landed **all 10 remaining audit items** from the `posted_at` → `moment_date` migration. Session 14 is **QA only** — no remaining code work on the moment mechanic.

## Scope (Session 14)

- Own: simulator QA pass on the Moment mechanic (all 4 gate states, cross-UTC-midnight rollover, Spiritual Ledger lookup, DEBUG force-delete, niyyah date alignment, on-time pill, feed dedupe with multi-circle posts).
- Also: Joiner onboarding re-test (carry-over from Phase 14.1 Task 6 — still blocks Phase 14 sign-off).
- Do not change: MomentService / FeedService / DailyMomentService / FeedView / FeedItem / FeedViewModel / niyyah code — all read/write paths are settled.

## Touched Files (Session 13)

### Commit 1 — `160e938` fix(moment): migrate remaining posted_at filters to moment_date

`Circles/Services/MomentService.swift` — 5 fixes in one file:
- **#3** `deleteMyTodayMoments` (DEBUG) — `.eq("moment_date", currentWindowDate ?? todayUTC)`
- **#4** `fetchMomentForDate` — dropped `T00:00:00Z`/`T23:59:59Z` ISO construction; `.eq("moment_date", date)`
- **#5** `postMomentToAllCircles` niyyah save — passes local `momentDate` const (not `Self.todayDateString()`)
- **#6** `fetchTodayMoments` — removed local-TZ `Calendar(.gregorian).startOfDay` fallback and 25h `posted_at` range; `.eq("moment_date", currentWindowDate ?? todayUTC)`
- **#7** `computeIsOnTime` — both branches now `(0..<300).contains(elapsed)` (guards negative elapsed for pre-window posts)

### Commit 2 — `2118403` fix(feed): close audit items #8-#10

6 files, +24/−13 lines:
- **#8** `FeedService.fetchActiveUserIdsToday` — moments filtered by `.eq("moment_date", activeFeedDate)` (was `posted_at` range via `fetchActiveMomentRange`). Activity_feed still keys on `created_at` — correct, not a moment concept.
- **#9** `Models/FeedItem.swift` — added `momentDate: String` to `MomentFeedItem`. Propagated through all 5 construction sites:
  - `FeedService.fetchFeedPage` — from `first.momentDate`
  - `FeedViewModel.updateMomentCaption` — preserve via `m.momentDate`
  - `CircleDetailView.makeOptimisticMoment` — `DailyMomentService.shared.currentWindowDate ?? MomentService.todayDateString()`
  - `CommunityView.makeOptimisticMoment` — same formula
  - `MomentFeedCard.swift` preview — literal `"2026-04-24"`
- **#10** Dedupe keys:
  - `FeedService.fetchFeedPage` page dedupe: `"\(userId)|\(row.momentDate)"` (was `postedAt.prefix(10)`)
  - `FeedViewModel.insertOptimisticMoment`: compare on `moment.momentDate == item.momentDate`
  - `FeedService.CircleMomentRow` decoder: added `moment_date` CodingKey with `postedAt.prefix(10)` fallback for legacy-row safety

## Decisions

- `moment_date` is now the **only** date predicate for moment reads, writes, and in-memory dedupe. `posted_at` remains only for `.order(...)` — the insert clock is still the right sort key.
- Fallback when `currentWindowDate == nil` is always `Self.todayDateString()` (UTC) — never local TZ. Matches Session 12's rule and the DB's UTC-based unique index.
- CircleMomentRow decoder keeps `postedAt.prefix(10)` fallback for `momentDate` despite the migration backfilling all rows. Defense-in-depth; effectively dead code today.
- `MomentService.todayDateString()` is exposed as internal (no access modifier) to view-layer optimistic constructors. Acceptable — it's a pure UTC date formatter, no state. Revisit if we want stricter boundaries later.

## Verified

- Build green on iPhone 17 Pro simulator (Debug) after both commits.
- Remaining warnings (`no 'async' operations occur within 'await'` at FeedService:99/267/309) are pre-existing Swift 6 quirks with Supabase's `async let` pattern — not caused by these edits.
- Diff surface this session: 7 files, 2 commits (+35/−28 lines total). No API-surface changes on any public method signature.
- **No simulator QA run this session.** Session 14 must do the live pass described in Next.

## Next (Session 14 — QA only)

### A. Moment-mechanic simulator QA (9 tests)

Use DEBUG `forceOpenWindow` button (or SQL `UPDATE daily_moments SET moment_time=...`) to drive each state. Seed / clear rows via the DEBUG delete button.

1. `.preWindow` — feed shows **yesterday's** moments (BeReal Memories), no gate.
2. `.windowOpen` — feed switches to today; gate CTA "Share your Moment".
3. Post in window → card pinned, gate dismissed, on-time pill visible (< 5 min elapsed).
4. `.missedWindow` — gate CTA "Post a late Moment", feed still today.
5. Post after 5 min → `is_on_time = false` (no pill). Also verify: pre-window post (if reachable via SQL) is now correctly **false** (audit #7).
6. **Cross-UTC-midnight test (regression for #1–#6, #9, #10):** Advance sim time so window opens at 23:50 UTC and post at 00:10 UTC. Verify:
   - Moment card appears in today's feed (moment_date = yesterday's UTC day).
   - Journey month view places the moment on yesterday's date (not today's).
   - Caption edit on that moment saves (no silent no-op).
   - Spiritual Ledger tap on yesterday's date shows that photo (`fetchMomentForDate`).
   - Niyyah, if entered, is stamped on yesterday's date — same as the moment.
   - Optimistic card doesn't duplicate after refresh (dedupe key uses `momentDate`).
7. DEBUG "delete today's moments" button wipes the just-posted moment (even when posted cross-midnight).
8. Caption edit persists across app relaunch.
9. **Multi-circle post dedupe:** post to 3 circles. Verify community feed shows ONE card (not three) with all 3 circle badges. Verify per-circle feed in each shows the same card.

### B. Joiner onboarding re-test (Phase 14.1 Task 6)

Covered in `.planning/HANDOFF.md`. Verify:
- Fresh Amir onboarding pass (catalog ranking)
- Member onboarding re-test
- Joiner flow end-to-end
- Bug fixes as needed

### C. Sign-off

When A + B pass:
- Update `.planning/STATE.md`: mark Phase 14 & 14.1 complete.
- Merge `phase-15-social-pulse` worktree → main.

## Blockers

- None. All code fixes for the moment mechanic are landed.
- Pre-existing open issues (Gemini -1011, habit check-in dedup) unchanged — not on Phase 14's critical path.

## On-main state after S13

- `2118403 fix(feed): close audit items #8-#10 — moment_date in dedupe + active users` ← session 13b
- `160e938 fix(moment): migrate remaining posted_at filters to moment_date` ← session 13a
- `3089aaa wip: session end — context limit` ← session 12 (feed-day fallback + 2 fixes)
- `4513a3d docs(claude.md): integrate Karpathy principles, consolidate working rules`

Working tree clean. 4 commits ahead of origin/main (push at session end).

## Audit Closure Table — ALL CLOSED ✅

| # | Severity | Location | Status |
|---|----------|----------|--------|
| 1 | Blocker | `MomentService.fetchMoments` | ✅ S12 |
| 2 | Blocker | `MomentService.updateCaption` | ✅ S12 |
| 3 | Blocker | `MomentService.deleteMyTodayMoments` | ✅ S13 |
| 4 | Blocker | `MomentService.fetchMomentForDate` | ✅ S13 |
| 5 | Major | `MomentService.postMomentToAllCircles` niyyah save | ✅ S13 |
| 6 | Major | `MomentService.fetchTodayMoments` | ✅ S13 |
| 7 | Major | `MomentService.computeIsOnTime` | ✅ S13 |
| 8 | Minor | `FeedService.fetchActiveUserIdsToday` | ✅ S13 |
| 9 | Minor | `MomentFeedItem` + optimistic dedupe | ✅ S13 |
| 10 | Minor | `FeedService` dedupe + `CircleMomentRow` decoder | ✅ S13 |

## Reference

- Plan `~/.claude/plans/last-session-this-was-magical-stroustrup.md` — original D1–D5 decisions.
- Migration `supabase/migrations/20260423_moment_mechanic_redesign.sql` — already on Supabase.
- DB unique index `circle_moments_one_per_day (user_id, moment_date)`.
