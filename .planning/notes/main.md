# main — Session Note (2026-04-23, Session 11 handoff)

## Session 11 Goal

**Manual QA pass.** All code for the Moment Mechanic Redesign is shipped + pushed. Next session: record test results, file bug reports as they surface, then either fix or defer. After QA green-lights, close Phase 14 QA in STATE.md and unblock the `phase-15-social-pulse` worktree merge.

## Status Going In

- Moment Mechanic Redesign: **code complete, build green, pushed to `origin/main`**.
- Phase A migration: **user confirmed run** on Supabase.
- Pending: manual simulator verification (9 moment tests + 3 carried-over Phase 14 QA items).

## On-Main State (commits shipped session 10)

| Commit | Phase | What |
|--------|-------|------|
| `79bc28b` | A + partial B | Migration SQL + `CircleMoment.momentDate` + 2 MomentService call-sites (WIP) |
| `01ca7f9` | B (services) | `DailyMomentService` strip Aladhan + `GateMode` enum + `currentWindowDate`; `MomentService` stamps `moment_date` + `1800→300` on-time threshold |
| `75e796e` | C | `JourneyViewModel` day-key → `moment.momentDate` |
| `5777c7a` | D | `ReciprocityGateView.Mode` (`.open` / `.missed`) + both call sites (`CommunityView`, `CircleDetailView`) map `gateMode` |

Phase E (timestamp audit) was a verified no-op — `FeedIdentityHeader` + `MomentFeedCard` were already clean (on-time pill when `isOnTime`, else `Xm/Xh ago`, no late badge).

Plan reference: `~/.claude/plans/last-session-this-was-magical-stroustrup.md`. Decisions D1–D5 all implemented as written.

## QA Scope for Session 11

### A. Moment redesign tests (new this session — 9 items)

Run in order. Each has fast-path method so no waiting for random window.

1. **pg_cron seed check**
   `SELECT * FROM daily_moments WHERE moment_date = CURRENT_DATE;`
   → one row, `moment_time` populated (13:00–02:59 UTC).

2. **Window opens, on-time post (≤5 min)**
   Fast-path: `UPDATE daily_moments SET moment_time = 'HH:MM' WHERE moment_date = CURRENT_DATE;` (pick ~1 min from UTC now). Relaunch app. Post within 5 min.
   → **"On Time"** gold pill in feed, moment on Journey today cell, gate lifts.

3. **Window open + late post (5–30 min) — still windowOpen**
   Post between 5–30 min after windowStart.
   → feed shows `"Xm ago"` (no pill, no late badge), gate copy = open mode ("Time to share your Moment").

4. **Missed-window gate (>30 min, unposted)**
   Fast-path: `UPDATE daily_moments SET moment_time = '<UTC-35min-ago>' WHERE moment_date = CURRENT_DATE;`. Relaunch.
   → blurred feed + gate shows **"You missed today's Moment" / "Post a late one to unlock everyone else's Moments." / "Post a late Moment"**. CTA opens camera, post succeeds, feed shows `"Xh ago"`, gate lifts.

5. **Cross-timezone stamp**
   Simulator: Settings → General → Date & Time → off auto → Europe/London. Post at 23:30 local (22:30 UTC).
   → Journey cell lands on today's UTC `moment_date`, no next-day drift.

6. **Next-day rollover**
   Wait past next 00:05 UTC (or set sim clock forward).
   → yesterday's post stays on yesterday's Journey cell, new window opens, `hasPostedToday` resets.

7. **Unique constraint (DB guard)**
   Post once. Try to post again same UTC day.
   → rejected cleanly, "already posted" toast fires (`MomentError.alreadyPostedToday`).

8. **APNs window-open push**
   `send-moment-window-notifications` edge fn fires at `moment_time` ±2 min.
   → device receives push. **If not firing**, flag as bug — unknown whether scheduled on Supabase scheduler or needs `pg_cron http_post` wrapper.

9. **Pre-migration backfill sanity**
   `SELECT COUNT(*) FROM circle_moments WHERE moment_date IS NULL;` → **0**.
   Spot-check historical Journey cells on an older month → moments land on correct days.

### B. Phase 14 QA still open (carried from HANDOFF.md)

10. **Amir Onboarding Overhaul — Task 6 fresh install**
    Clear `onboardingComplete_<uid>` + sign out. Expected flow:
    - Landing → **Shape Your Circle** (3 personalization Qs) → habits with **reordered catalog** → "Build the Foundation" → circleIdentity → "Some growth is private" → quiz → AI gen (**no personal catalog screen**) → location → auth.
    - StepIndicator: 1 → 2 → 3 → 4 → 5 → 6.

11. **Phase 14 test 2 — Fresh Member onboarding**
    Verify `OnboardingTransitionQuote.amirSharedToPrivate` still renders in Member flow.

12. **Joiner flow end-to-end**
    Session 9 fixed `transitionToAI → proceedToAIGeneration` routing — needs full user-verified pass through:
    `JoinerLandingView → JoinerIdentityView → JoinerPersonalHabitsView → Joiner quiz → JoinerAIGenerationView → JoinerCircleAlignmentView → JoinerAuthGateView`.
    Nothing stuck; AI gen completes; post-auth lands on circle.

## Known Open Issues (not new bugs)

- **A. Gemini -1011 on Generate Plan** — `NSURLErrorBadServerResponse`. If it fires, it's the pre-existing STATE.md item A (check `GEMINI_API_KEY`, model `gemini-3-flash-preview`).
- **B. Habit check-in feed dedup** — `broadcastHabitCompletion` inserts unconditionally. Low priority, don't fix this session.

## Fast-Path Reference

**See today's moment window time (UTC):**
```sql
SELECT moment_date, moment_time FROM daily_moments WHERE moment_date = CURRENT_DATE;
```

**Force a window state by overriding moment_time:**
```sql
-- fire in 1 min
UPDATE daily_moments SET moment_time = '<UTC+1min HH:MM>' WHERE moment_date = CURRENT_DATE;

-- already past on-time window, within missed-window gate
UPDATE daily_moments SET moment_time = '<UTC-35min HH:MM>' WHERE moment_date = CURRENT_DATE;
```
App must be killed + relaunched; `DailyMomentService.load()` only re-fetches on first load per day.

**DEBUG force button** — Profile tab has a `forceOpenWindow` button (`ProfileView.swift:335`). Deletes today's moments + opens window immediately. Good for test #2 and replays.

## Bug-Report Template (paste into next session)

For each test that fails, capture:

```
### Test #<n> — <short title>
- What I did: ...
- Expected: ...
- Actual: ...
- Console/DB state: ...
- Screenshot path (if any): ...
- Severity: blocker / major / minor
```

## Next (Session 11 in order)

1. Run QA tests 1–9 (moment redesign). Record bugs as they surface using template above.
2. Run QA tests 10–12 (Phase 14 carry-overs). Record bugs.
3. Agent fixes any blockers/major bugs immediately; files minor bugs as backlog.
4. When all tests green → update STATE.md: Phase 14 QA ✓ closed, Moment Mechanic Redesign ✓ shipped.
5. Then: merge `phase-15-social-pulse` worktree into `main`.

## Notes For Re-entry

- **Do not re-plan** unless a failing test reveals an architectural issue. Plan + decisions D1–D5 are locked and shipped.
- If test #3 or #4 behave wrong, check `DailyMomentService.gateMode` 30-min pivot constant (`Services/DailyMomentService.swift:19` — `missedWindowCutoff`). If test #2 on-time pill doesn't fire, check `MomentService.computeIsOnTime` (`Services/MomentService.swift:431`, 300s threshold).
- If migration/pg_cron problems surface (test #1 or #8), the migration file is `supabase/migrations/20260423_moment_mechanic_redesign.sql` — user already ran it. Re-verifiable via `SELECT * FROM cron.job WHERE jobname = 'seed_todays_daily_moment';`.
- `CircleMoment.momentDate` has a decoder fallback (`String(postedAt.prefix(10))`) — so old rows without the column still decode. Post-migration all rows have the column populated, so the fallback is dormant but safe.
