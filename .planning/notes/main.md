# main — Session Note (2026-04-24, Session 12 handoff)

## Goal

Continue hardening the **Moment Mechanic Redesign** (BeReal parity). Session 12 landed the feed-day fallback + two moment_date correctness fixes. Session 13 should clean up the remaining `posted_at`-filter bugs documented in the audit below, then close Phase 14 QA.

## Scope

- Own: `Circles/Moment/`, `Circles/Feed/`, `Circles/Services/DailyMomentService.swift`, `Circles/Services/MomentService.swift`, `Circles/Services/FeedService.swift`, `Circles/Journey/*` moment-read paths.
- Do not change: Niyyah write schema, `circle_moments` table schema, pg_cron seed logic.

## Touched Files (Session 12)

- `Circles/Services/DailyMomentService.swift` — added `activeFeedDate` computed var (yesterday when `preWindow`, else today).
- `Circles/Services/FeedService.swift` — `fetchFeedPage` + `fetchLatestMomentPerCircle` anchor on `activeFeedDate`; moments filtered by `.eq("moment_date", feedDate)`; activity_feed scoped to same UTC day.
- `Circles/Feed/FeedView.swift` — empty-state copy: "Your circle is quiet. / Moments from your circle will appear here." (old copy was "No moments yet. Be the first to post today." which contradicted BeReal Memories behavior).
- `Circles/Services/MomentService.swift` — fix #1: `fetchMoments(userId, from, toExclusive)` now filters by `moment_date` range (was `posted_at`). Fix #2: `updateCaption` now filters by `.eq("moment_date", currentWindowDate)` (was `posted_at` today range).

## Decisions

- **BeReal Memories pattern** confirmed by user: yesterday's posts remain visible until today's window pops. `activeFeedDate` flips the moment `gateMode` leaves `.preWindow`. No fallback when today has zero non-own moments (e.g. posted + silent circle) — empty state is acceptable there.
- All moment reads keyed on `moment_date` (DB stamp), not `posted_at`. `posted_at` is insert clock; `moment_date` is the window's UTC calendar day. These diverge whenever a user posts across UTC midnight.
- `currentWindowDate` from `DailyMomentService` is the single source of truth for the "which day am I posting/editing" question.

## Verified

- Build green on iPhone 17 Pro simulator (Debug).
- 4-state gate matrix walked through:
  - `preWindow` → yesterday's feed, no gate ✓
  - `windowOpen` → today's feed, gate CTA "Share your Moment" ✓
  - `missedWindow` → today's feed, gate CTA "Post a late Moment" ✓
  - `posted` → today's feed + pinned own card, no gate ✓
- No simulator QA run this session — shipped unverified. Session 13 must do a live pass.

## Next

1. Verify Session 12 changes in simulator (tests 2–6 from prior QA list, specifically #6 cross-TZ and next-day rollover). Use `forceOpenWindow` DEBUG button or SQL `UPDATE daily_moments SET moment_time=...`.
2. **Fix remaining moment_date bugs from audit (priority order):**
   - **#3 `deleteMyTodayMoments`** (`MomentService.swift:407-416`) — change `.gte/.lt posted_at` → `.eq("moment_date", currentWindowDate)`. DEBUG path only, but inconsistent with #2.
   - **#4 `fetchMomentForDate`** (`MomentService.swift:38-57`) — Spiritual Ledger lookup. Swap `posted_at` range for `.eq("moment_date", date)`. Drop the T00:00:00Z / T23:59:59Z ISO string construction.
   - **#5 Niyyah date mismatch** (`MomentService.swift:229-238`, inside `postMomentToAllCircles`) — pass `momentDate` (the local const already computed at line 180), not `Self.todayDateString()`. Misaligns Journey when user posts near UTC midnight.
   - **#6 `fetchTodayMoments` local-calendar fallback** (`MomentService.swift:20-35`) — when `windowStart == nil`, replace `Calendar(identifier: .gregorian).startOfDay(for:)` with UTC startOfDay. Better: rewrite to `.eq("moment_date", currentWindowDate ?? todayUTC)`.
   - **#7 `computeIsOnTime`** (`MomentService.swift:435-445`) — tighten `< 300` to `(0..<300).contains(elapsed)` so pre-window posts don't falsely qualify.
3. **Minor cleanup (optional):**
   - **#8 `FeedService.fetchActiveUserIdsToday`** (`FeedService.swift:297-332`) — still uses `posted_at` range. Migrate to `.eq("moment_date", activeFeedDate)`.
   - **#9 + #10** — add `momentDate` to `MomentFeedItem` (`Models/FeedItem.swift:5-19`); update `FeedService.swift:164-174` + `FeedViewModel.swift:102-110` dedupe keys to use it instead of `postedAt.prefix(10)`. Also add `moment_date` to private `CircleMomentRow` decoder in `FeedService.swift:27-58`. Harmless today thanks to DB unique index, but drift-prone.
4. **Once all audit items closed** → run full Session 11 QA list (9 moment tests + 3 onboarding carry-overs) → close Phase 14 QA in `STATE.md` → merge `phase-15-social-pulse` worktree.

## Blockers

- None. All fixes are local to `MomentService` / `FeedService` / one model.
- Pre-existing open issues (Gemini -1011, habit check-in dedup) unchanged.

## Notes For Re-entry

### Audit Summary — Moment Mechanic `posted_at` → `moment_date` migration

Session 10 stamped `moment_date` on new rows and swapped a few callers, but several read/write paths still key on `posted_at` ranges. The column mismatch is silently broken whenever a user posts across UTC midnight (window opens 23:50 UTC, user posts 00:05 UTC next day).

| # | Severity | Location | Symptom |
|---|----------|----------|---------|
| 1 | Blocker | `MomentService.fetchMoments` | ✅ **Fixed S12** — Journey month misplacing cross-midnight posts |
| 2 | Blocker | `MomentService.updateCaption` | ✅ **Fixed S12** — caption edits silently no-op'd |
| 3 | Blocker | `MomentService.deleteMyTodayMoments` | DEBUG force button can miss just-posted moment |
| 4 | Blocker | `MomentService.fetchMomentForDate` | Spiritual Ledger lookup misses cross-midnight posts |
| 5 | Major | `MomentService.postMomentToAllCircles` niyyah save | Niyyah stamped on wrong day vs moment |
| 6 | Major | `MomentService.fetchTodayMoments` | Local-calendar fallback when `windowStart` nil |
| 7 | Major | `MomentService.computeIsOnTime` | Returns true for negative elapsed (pre-window) |
| 8 | Minor | `FeedService.fetchActiveUserIdsToday` | Still uses `posted_at` — undercounts |
| 9 | Minor | `FeedViewModel.insertOptimisticMoment` | Dedupes on `postedAt.prefix(10)`, not `momentDate` |
| 10 | Minor | `FeedService` dedupe key + `CircleMomentRow` decoder | Same as #9; `CircleMomentRow` also doesn't decode `moment_date` |

### Where to start

Open `Circles/Services/MomentService.swift` and do #3 → #4 → #5 → #6 → #7 in one pass (all in the same file). Each is 3–8 lines. Build, then simulator QA.

### On-main state after S12

Session 12 ended mid-commit due to context limit — changes staged via `wip:` commit for session 13 to inspect/amend/split. Commit preceding that: `5777c7a docs: session 10 handoff — moment redesign shipped, QA pending`.

### Reference

- Plan `~/.claude/plans/last-session-this-was-magical-stroustrup.md` — original D1–D5 decisions for Phase A–D of Moment Redesign.
- Migration file: `supabase/migrations/20260423_moment_mechanic_redesign.sql` (already run on Supabase).
- DB unique index `circle_moments_one_per_day (user_id, moment_date)` — prevents actual duplicate rows, masking several of the minor bugs above.
