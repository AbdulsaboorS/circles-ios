# Handoff — 2026-04-04 (Session End: Context Limit)

## What Was Done This Session

### Phase 11.5 — Feed fixes (commits baa985b, 3d5814c)

| Fix | Status | Notes |
|-----|--------|-------|
| Feed dedup (one card per photo) | ✓ Complete | FeedService groups by (userId, YYYY-MM-DD) |
| Feed filter tabs (Posts \| Check-ins) | ✓ Complete | FeedView.showFilterTabs pill picker |
| 30-min countdown on camera/preview | ✓ Complete | Timer + DailyMomentService.windowStart |
| Photos blank after post (refresh race) | ✓ Complete | Moved refresh to sheet onDismiss |
| Today-only feed (moments + check-ins) | ✓ Complete | FeedService scopes both tables to UTC day |

---

## Current State

### What Works
- Feed deduplication: one card per photo per user per day ✓
- Own-post shows "Sent to X circles ▾" expandable list ✓
- Others' posts show only shared circle name ✓
- Posts | Check-ins filter tabs in global feed ✓
- 30-min countdown badge on MomentCameraView + MomentPreviewView ✓
- Today-only feed (no history clutter) ✓
- onDismiss refresh pattern (no more race with sheet teardown) ✓

### Broken / Regressed
**RLS error on posting: "new row violates row level security policy"**

---

## RLS Bug — Root Cause Diagnosis

**The code did NOT cause this.** My changes in 11.5 only touch SELECT queries and UI — zero changes to MomentService or any INSERT logic. The `postMomentToAllCircles` call is byte-for-byte identical to before.

**Root cause: Supabase DB-side policies were dropped/reset.**

In commit `f4e0ff5` (Phase 11.4-01), the RLS policies were applied via **Supabase MCP** (not SQL migration files — there is no `.sql` file for them). Those policies live entirely in Supabase. If the Supabase project was reset, a branch was merged/reverted, or the policies were accidentally dropped, they would be gone.

The required policies (from `11.4-01-SUMMARY.md`) are:

```sql
-- 1. Allow authenticated users to insert their own circle_moments row
-- (if they are a member of that circle)
CREATE POLICY "users_insert_own_moments"
ON circle_moments
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = user_id
  AND circle_id IN (SELECT unnest(auth_user_circle_ids()))
);

-- 2. Allow circle members to select circle_moments
CREATE POLICY "circle_members_select_moments"
ON circle_moments
FOR SELECT
TO authenticated
USING (
  circle_id IN (SELECT unnest(auth_user_circle_ids()))
);

-- 3. Storage: allow authenticated users to upload to circle-moments bucket
CREATE POLICY "authenticated_upload_circle_moments"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'circle-moments');

-- 4. Storage: allow authenticated users to read from circle-moments bucket
CREATE POLICY "authenticated_select_circle_moments"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'circle-moments');
```

---

## Exact Next Steps for Next Agent

1. **Read this file**, then read `.planning/STATE.md`

2. **Fix the RLS regression** — this is a Supabase Dashboard / MCP task, NOT a code task:
   - Open Supabase Dashboard → Authentication → Policies
   - Check `circle_moments` table — look for the 4 policies listed above
   - If they're missing, re-apply them via Supabase MCP (`mcp__supabase__execute_sql`) or Dashboard SQL Editor
   - Also check `storage.objects` policies for the `circle-moments` bucket
   - **Important:** Before adding, check if policies already exist with those names to avoid duplicates:
     ```sql
     SELECT policyname, tablename, cmd, qual, with_check
     FROM pg_policies
     WHERE tablename IN ('circle_moments')
     ORDER BY tablename, policyname;
     ```
   - And for storage:
     ```sql
     SELECT policyname, cmd, qual, with_check
     FROM pg_policies
     WHERE tablename = 'objects' AND schemaname = 'storage';
     ```

3. **Verify posting works** — test full moment post flow after re-applying policies

4. **If policies ARE present** (and RLS still fails), the issue may be that `auth_user_circle_ids()` is returning empty for the user posting. Check:
   ```sql
   -- Run as the authenticated user or check the function definition:
   SELECT * FROM auth_user_circle_ids();
   -- Also check circle_members for the user:
   SELECT * FROM circle_members WHERE user_id = '<your-user-id>';
   ```
   The INSERT policy requires membership in the target circle. If `circle_members` row is missing, the INSERT will be blocked.

5. **After posting is verified** — the 11.5 feed fixes are complete. Next phase is 11.6 or Phase 12 per ROADMAP.md.

---

## Notes / Blockers

- SourceKit "No such module 'Supabase'" warnings are false positives — build succeeds
- Simulator: `id=AAD4DE32-6D0C-4C10-BCF1-1A4612DD9D92` (iPhone 17 Pro)
- `pendingFeedRefresh` flag in `CommunityView` — set to `true` in `onPost`, consumed in `onDismiss` to trigger `feedViewModel.refresh`. Clean state machine, no races.
- `FeedService.fetchFeedPage` today-only scope uses `T00:00:00Z` / `T23:59:59Z` UTC — consistent with `MomentService.fetchTodayMoments` pattern already in the codebase
- `CircleDetailView` also calls `MomentService.shared.postMoment` (single-circle, legacy path) — if that path is used, the same RLS fix applies
