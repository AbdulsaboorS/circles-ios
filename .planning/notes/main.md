# main — Session Note (2026-04-24, Session 13 handoff)

## Goal

Close Phase 14 QA. Session 13 landed the final 5 `posted_at` → `moment_date` fixes on top of session 12's 2. All 10 audit items from the original migration are now closed in code. Session 14 is **QA only** — no more audit work needed in MomentService / FeedService for this mechanic.

## Scope (Session 14)

- Own: simulator QA pass on the Moment mechanic (all 4 gate states, cross-UTC-midnight rollover, Spiritual Ledger lookup, DEBUG force-delete, niyyah date alignment, on-time pill).
- Also: Joiner onboarding re-test (carry-over from Phase 14.1 Task 6 — still blocks Phase 14 sign-off).
- Do not change: MomentService / FeedService / DailyMomentService / FeedView / FeedItem / FeedViewModel / niyyah code — all read paths are settled.
- Out of scope: minor items #9/#10 (MomentFeedItem dedupe key) — harmless today thanks to DB unique index `circle_moments_one_per_day`. Only revisit if drift shows up.

## Touched Files (Session 13)

- `Circles/Services/MomentService.swift` — single pass, 5 fixes:
  - **#3** `deleteMyTodayMoments` (DEBUG) — `.eq("moment_date", currentWindowDate ?? todayUTC)`
  - **#4** `fetchMomentForDate` — dropped `T00:00:00Z`/`T23:59:59Z` ISO construction; `.eq("moment_date", date)`
  - **#5** `postMomentToAllCircles` niyyah save — passes local `momentDate` const (not `Self.todayDateString()`)
  - **#6** `fetchTodayMoments` — removed local-TZ `Calendar(.gregorian).startOfDay` fallback and 25h `posted_at` range; `.eq("moment_date", currentWindowDate ?? todayUTC)`
  - **#7** `computeIsOnTime` — both branches now `(0..<300).contains(elapsed)` (guards negative elapsed for pre-window posts)

## Decisions

- `moment_date` is now the only date predicate for all moment reads/writes that key on "the window's calendar day." `posted_at` remains for ordering (`.order("posted_at")`) — the insert clock is still the right thing to sort by.
- Fallback when `currentWindowDate == nil` is `Self.todayDateString()` (UTC) — never local TZ. This matches Session 12's rule and the DB's UTC-based unique index.
- Kept the deliberate scope cut: audit items **#8–#10** not shipped this session. #8 is minor (`FeedService.fetchActiveUserIdsToday`); #9/#10 require a `MomentFeedItem` schema change (add `momentDate` field) + dedupe key swap in `FeedService` + `FeedViewModel` + `CircleMomentRow` decoder. The DB unique index makes real duplicate rows impossible, so the dedupe key drift is latent, not active.

## Verified

- Build green on iPhone 17 Pro simulator (Debug).
- Diff surface: 1 file, +11 / −15 lines. No API-surface changes (all method signatures unchanged).
- **No simulator QA run this session.** Session 14 must do the live pass described in Next.

## Next (Session 14 — QA only)

### A. Moment-mechanic simulator QA (9 tests)

Use DEBUG `forceOpenWindow` button (or SQL `UPDATE daily_moments SET moment_time=...`) to drive each state. Seed / clear rows via the DEBUG delete button.

1. `.preWindow` — feed shows **yesterday's** moments (BeReal Memories), no gate.
2. `.windowOpen` — feed switches to today; gate CTA "Share your Moment".
3. Post in window → card pinned, gate dismissed, on-time pill visible (< 5 min elapsed).
4. `.missedWindow` — gate CTA "Post a late Moment", feed still today.
5. Post after 5 min → `is_on_time = false` (no pill). Also verify: pre-window post (if reachable via SQL) is now correctly **false** (audit #7).
6. **Cross-UTC-midnight test (audit #1–#6 regression):** Advance sim time so window opens at 23:50 UTC and post at 00:10 UTC. Verify:
   - Moment card appears in today's feed (moment_date = yesterday's UTC day).
   - Journey month view places the moment on yesterday's date (not today's).
   - Caption edit on that moment saves (no silent no-op).
   - Spiritual Ledger tap on yesterday's date shows that photo (fetchMomentForDate).
   - Niyyah, if entered, is stamped on yesterday's date — same as the moment.
7. DEBUG "delete today's moments" button wipes the just-posted moment (even when posted cross-midnight).
8. Caption edit persists across app relaunch.
9. Multi-circle post: photo appears in every circle feed, gate dismisses in all.

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

- `160e938 fix(moment): migrate remaining posted_at filters to moment_date` ← session 13
- `3089aaa wip: session end — context limit` ← session 12 (feed-day fallback + 2 fixes)
- `4513a3d docs(claude.md): integrate Karpathy principles, consolidate working rules`
- `8e0fb71 docs: session 10 handoff — moment redesign shipped, QA pending`

Working tree clean. 3 commits ahead of origin/main (push at session end).

## Audit Closure Table

| # | Severity | Location | Status |
|---|----------|----------|--------|
| 1 | Blocker | `MomentService.fetchMoments` | ✅ S12 |
| 2 | Blocker | `MomentService.updateCaption` | ✅ S12 |
| 3 | Blocker | `MomentService.deleteMyTodayMoments` | ✅ S13 |
| 4 | Blocker | `MomentService.fetchMomentForDate` | ✅ S13 |
| 5 | Major | `MomentService.postMomentToAllCircles` niyyah save | ✅ S13 |
| 6 | Major | `MomentService.fetchTodayMoments` | ✅ S13 |
| 7 | Major | `MomentService.computeIsOnTime` | ✅ S13 |
| 8 | Minor | `FeedService.fetchActiveUserIdsToday` | ⏸ deferred (not blocking) |
| 9 | Minor | `FeedViewModel.insertOptimisticMoment` dedupe | ⏸ deferred (DB index masks) |
| 10 | Minor | `FeedService` dedupe key + `CircleMomentRow` decoder | ⏸ deferred (DB index masks) |

## Reference

- Plan `~/.claude/plans/last-session-this-was-magical-stroustrup.md` — original D1–D5 decisions.
- Migration `supabase/migrations/20260423_moment_mechanic_redesign.sql` — already on Supabase.
- DB unique index `circle_moments_one_per_day (user_id, moment_date)`.
