# Plan — Revert Last Session, Adopt BeReal Regional Window Model

## Context

Last session attempted bug fixes (commit `0a75a5d`) for (1) false "something went wrong" flash on pull-to-refresh and (2) stale circle timing in `CircleDetailView`. User tested — fixes did not resolve the actual reported bugs.

User now wants:
- **Step 1**: Revert that work to a known-good baseline.
- **Step 2**: Re-scope this session to **moment correctness only**. Pull-to-refresh / CancellationError work is deferred.
- **Step 3**: Echo-back understanding before any code changes.
- **Step 4**: Adopt **Option A = copy BeReal exactly**: anchor moment windows to **regional groups** (Americas / Europe / East Asia / West Asia), not UTC. One window per region per day, random within 9am–11pm region-local time, same time for everyone in that region.

This redesign should also fix Bug 1 (yesterday's-moment preview / wrong timestamp) as a side effect, because `activeFeedDate` and a posted moment's `moment_date` will both anchor to **region-local day** instead of disagreeing across the UTC boundary.

---

## BeReal Reference Model (verified via web research)

- **Regions** (4): `americas`, `europe`, `east_asia`, `west_asia`.
- **One notification per region per day** at a randomized local time between 9:00 and 23:00 region-local.
- **Same fire time** for every user in a region.
- **2-minute on-time window**, late posts allowed thereafter (mirrors what we already have via `missedWindowCutoff = 30 min`; we keep ours).
- **Region is user-selectable** in profile settings (default = install region inferred from device locale / TZ).

---

## Phase A — Revert (no behavior changes pending user echo-back)

**Revert commit `0a75a5d`** ("fix: eliminate false error flash on pull-to-refresh and stale circle timing"). Files touched:
- `Circles/Circles/CircleDetailView.swift` (windowObserverTask, reordered `.task`)
- `Circles/Circles/CircleDetailViewModel.swift` (CancellationError guards)
- `Circles/Circles/CirclesViewModel.swift` (CancellationError guard)
- `Circles/Feed/FeedViewModel.swift` (CancellationError guards, reaction error swallow)
- `Circles/Home/HomeViewModel.swift` (CancellationError guard)

**Revert commit `5b995fd`** (`.planning/STATE.md` bookkeeping; harmless, but user said "whatever was committed").

**Method**: `git revert --no-edit 5b995fd 0a75a5d` — two new revert commits on `main`. Non-destructive.

**Post-revert verification**:
1. `git status` clean.
2. `git log --oneline -7` shows two new revert commits.
3. Xcode build (Circles target, simulator) compiles green.
4. Quick grep for `windowObserverTask`, `CancellationError` in the five files — must be absent.

---

## Phase B — Echo-Back to User (no code changes, post and wait)

Post the following understanding and wait for user confirm/correct.

### Bug 1 — Wrong moment preview & wrong timestamp on circles list

**What you see**: After posting a moment that shows correctly on Feed, the **circles list card** (StoryHeroPanel preview + "Nm ago" pill in `MyCirclesView`) briefly shows **yesterday's** image and/or a timestamp that doesn't match when you actually posted today.

**Why I think it happens**: `activeFeedDate` (used to filter `circle_moments` for the preview) is computed from `gateMode`, which uses UTC day boundaries. When the UTC day boundary doesn't align with your local day, the preview can pull yesterday's UTC-day moments while your post sits in the new UTC day's row. Will be fully verified in Phase C.

### Bug 2 — Two windows in one day

**What you see**: Window/notification fires in the morning, you post, then a second window fires ~7 hours later same calendar day (your local time), even though you already posted.

**Why it happens (confirmed)**: Server seeds **one row per UTC date** in `daily_moments`. A user's local calendar day can span two UTC dates. If late on UTC-day-N's window happens at, say, 18:00 UTC and early on UTC-day-N+1 happens at 02:00 UTC, that's ~8 hours apart but **both occur inside the same local day** for many users. The "have I posted today?" guard keys on `moment_date`, so the new UTC day's row doesn't see the prior post → gate reopens → second push.

### Fix direction (your call → BeReal model)

Adopt BeReal's regional model: 4 regions (Americas / Europe / East Asia / West Asia). One window per region per day, random within 9am–11pm region-local. Region inferred from user TZ at signup, changeable in settings. This makes "today" = region-local day everywhere → both bugs resolve.

---

## Phase C — Investigate & Confirm Plan (read-only, after user confirms B)

Read in order:
- `Circles/Services/DailyMomentService.swift` (full)
- `Circles/Services/MomentService.swift` lines 150–250 (post path)
- `Circles/Services/FeedService.swift` lines 240–320 (latest-moment-per-circle, active-users-today)
- `Circles/Models/CircleCardData.swift` (LatestMomentInfo, relativeTimestamp)
- `Circles/Circles/CirclesViewModel.swift` (loadCardData)
- `Circles/Community/CommunityView.swift` (handleMomentPostRefresh)
- `supabase/migrations/20260423_moment_mechanic_redesign.sql` (current pg_cron + table)
- `supabase/migrations/20260424_circle_moments_per_circle_unique.sql`
- `supabase/functions/send-moment-window-notifications/index.ts`
- `Circles/Onboarding/*` (where to ask region during onboarding)
- `Circles/Profile/ProfileView.swift` (where to add region setting)

Output of Phase C: a concrete patch list with line-level edits, posted back to the user before Phase D.

---

## Phase D — Implement BeReal Regional Model (after Phase C signoff)

### D1. DB schema changes (new migration)

`supabase/migrations/<date>_moment_regions.sql`:

```sql
-- 1. Region enum
CREATE TYPE moment_region AS ENUM ('americas','europe','east_asia','west_asia');

-- 2. profiles.region (nullable for backfill, default inferred client-side)
ALTER TABLE profiles ADD COLUMN region moment_region;

-- 3. daily_moments: one row per (region, region-local date)
ALTER TABLE daily_moments ADD COLUMN region moment_region;
ALTER TABLE daily_moments DROP CONSTRAINT daily_moments_pkey;
ALTER TABLE daily_moments ADD PRIMARY KEY (region, moment_date);
-- moment_date now means "region-local date"
-- moment_time stays UTC (precomputed from random region-local time)

-- 4. circle_moments.moment_date semantics shift to region-local date.
--    No schema change required (still a DATE column), but seeding/guard logic
--    must use the user's region-local day going forward.

-- 5. Backfill profiles.region from existing profiles.timezone (best-effort SQL).
UPDATE profiles SET region = CASE
  WHEN timezone LIKE 'America/%' OR timezone LIKE 'US/%' OR timezone LIKE 'Canada/%' THEN 'americas'::moment_region
  WHEN timezone LIKE 'Europe/%' OR timezone LIKE 'Africa/%' OR timezone LIKE 'Atlantic/%' THEN 'europe'::moment_region
  WHEN timezone LIKE 'Asia/Tok%' OR timezone LIKE 'Asia/Seoul' OR timezone LIKE 'Asia/Shang%'
       OR timezone LIKE 'Asia/Hong%' OR timezone LIKE 'Asia/Taipei' OR timezone LIKE 'Asia/Singap%'
       OR timezone LIKE 'Australia/%' OR timezone LIKE 'Pacific/%' THEN 'east_asia'::moment_region
  WHEN timezone LIKE 'Asia/%' OR timezone LIKE 'Indian/%' THEN 'west_asia'::moment_region
  ELSE 'americas'::moment_region
END WHERE region IS NULL;
```

### D2. pg_cron seed rewrite

Replace the single-row daily seed with a 4-row seed (one per region). Each row: pick random local-time within 9:00–23:00 for that region's representative TZ, convert to UTC, store in `moment_time`. `moment_date` = region-local date.

Representative TZs:
- americas → `America/New_York` (or `America/Los_Angeles` — needs decision; BeReal seems to use Eastern)
- europe → `Europe/Paris`
- west_asia → `Asia/Dubai`
- east_asia → `Asia/Tokyo`

### D3. Edge function `send-moment-window-notifications`

Accept (or query) per-region rows. For each region row whose `moment_time` is within ±2 min of `now()`, fetch device tokens of users whose `profiles.region = <that region>` and dispatch APNs.

### D4. Client `DailyMomentService` rewrite (surgical)

- New `region: MomentRegion` derived from `profiles.region` (cached).
- `fetchTodayDailyMoment` filters `WHERE region = <user.region>` AND `moment_date = todayInRegion()`.
- `todayInRegion()` returns the region-local calendar date as `YYYY-MM-DD`.
- `activeFeedDate` becomes region-local date instead of UTC date.
- `currentWindowDate` becomes region-local date.
- `computeHasPostedToday(momentDate:)` unchanged signature — but `momentDate` is now region-local. Same query.
- Remove `lastLoadedDate` UTC reset; use region-local today instead.

### D5. `MomentService.postMomentToAllCircles`

Line 178: `let momentDate = DailyMomentService.shared.currentWindowDate ?? Self.todayDateString()`. `Self.todayDateString()` must change to region-local. No other change.

### D6. `FeedService` queries

- `fetchLatestMomentPerCircle`: still filters by `moment_date == activeFeedDate` — works automatically once `activeFeedDate` is region-local.
- `fetchActiveUserIdsToday`: same.

### D7. Onboarding & Profile UI

- Onboarding: after TZ detection, infer region; show a small "We've placed you in {Americas/Europe/...}" confirmation step (1 sheet, ~30 lines). Allow change.
- ProfileView: add "Region" row that opens a 4-option picker.

### D8. UX microcopy for window state

Confirm we don't need to change copy for "Yesterday's window" / "Today's window" — the regional anchor should make this naturally consistent.

---

## Phase E — Verify

1. Build green on simulator.
2. **Repro Bug 2** (cross-UTC-day): set device TZ to `America/Los_Angeles`, set region = americas, force-open window via `forceOpenWindow` in DEBUG, post, then advance system clock past UTC midnight, observe — no second window prompts.
3. **Repro Bug 1** (preview match): post in region A, navigate to circles list immediately — preview matches exactly (image + timestamp).
4. Manual region-switch test: profile → change region → daily_moments query updates → no crash.
5. Schema migration applied via Dashboard; backfill query result spot-checked.

---

## Confirmed Product Calls

- **Scope**: Inline this session — full BeReal regional redesign after revert.
- **Region picker**: Both onboarding (auto-detect from TZ → quick confirm step) and Profile (editable row).
- **Americas TZ**: Single fixed TZ — `America/New_York` (Eastern). Same fire moment for every Americas user, true BeReal copy.

Representative TZ per region (single fixed each):
- americas → `America/New_York`
- europe → `Europe/Paris`
- west_asia → `Asia/Dubai`
- east_asia → `Asia/Tokyo`

---

## Critical Files (reference)

- `Circles/Services/DailyMomentService.swift`
- `Circles/Services/MomentService.swift`
- `Circles/Services/FeedService.swift`
- `Circles/Models/CircleCardData.swift`
- `Circles/Circles/CirclesViewModel.swift`
- `Circles/Community/CommunityView.swift`
- `Circles/Onboarding/*`
- `Circles/Profile/ProfileView.swift`
- `supabase/migrations/20260423_moment_mechanic_redesign.sql`
- `supabase/functions/send-moment-window-notifications/index.ts`
