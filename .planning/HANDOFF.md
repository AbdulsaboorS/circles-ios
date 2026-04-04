# Handoff — 2026-04-04 (Session End: Context Limit)

## What Was Done This Session

### Phase 11.4 — Completed (all 4 plans executed + committed)

| Plan | Status | Notes |
|------|--------|-------|
| 11.4-01 RLS + edge function | ✓ Complete | f4e0ff5 |
| 11.4-02 Multi-circle MomentService + preview | ✓ Complete | 9f16e27 |
| 11.4-03 Feed card full-width + profile gear | ✓ Complete | 95033af |
| 11.4-04 Wire callers + pin own moment | ✓ Complete | 95033af |

### Polish / Bug Fixes (this session, same commit 95033af)

- **Late badge removed** from `MomentFeedCard` entirely — timestamp in header tells the story
- **Profile page cleaned up** — only shows avatar + stats card; settings section removed from inline scroll view
- **Settings gear (ProfileView)** — fixed: rows were not clickable because nested `.sheet` inside `settingsSection` was inside another sheet. Fix: `settingsSheetContent` is now its own `NavigationStack`; `.sheet(isPresented: $showEditProfile)` moved to NavigationStack level
- **`DailyMomentService.forceOpenWindow()`** — `#if DEBUG` method added for prayer window testing without waiting for real prayer time. Debug button added to ProfileView dev tools section
- **Habit feed deduplication** — documented in `STATE.md` issue F (deferred to Phase 12)

---

## Current State

### What Works
- Full multi-circle moment posting (one photo → inserted into all circles)
- Feed card full-width 3:4 photo, no badges
- Profile gear → Settings sheet with clickable rows
- Own moment pinned to top of circle feed
- `#if DEBUG` force-open window button in Profile dev tools

### Known Issues / Next Work Items

**1. Photos not appearing in feed after post (diagnose first)**
- Likely cause: `FeedViewModel.loadInitial` has `guard !isLoadingInitial` — if called while a load is in flight (immediately after post), it silently no-ops and the new rows don't show
- Confirm by: pull-to-refresh after posting — if photos appear on pull-to-refresh, that's the bug
- Fix: in `CommunityView.onPost` and `CircleDetailView.onPost`, add a small yield or reset `isLoadingInitial = false` before calling refresh, OR call `feedViewModel.refresh` instead of `loadInitial`

**2. Multiple post cards (one per circle) → should show ONE card**
- `FeedService.fetchFeedPage` fetches all `circle_moments` rows — one per circle → N cards for same photo
- Fix: deduplicate in `FeedService` — group rows by `(userId, date)`, keep first row but collect all `circleIds`/`circleNames` into a list on `MomentFeedItem`
- Display logic:
  - Own post: expandable "Sent to X circles ▾" showing all circle names
  - Other user's post: show only the circle name you share with them (already have `circleId` on the row)
- `MomentFeedItem` needs: `circleIds: [UUID]`, `circleNames: [String]` (replacing single `circleId`/`circleName`)

**3. Feed filter tabs (Posts | Check-ins)**
- Add pill tabs at top of the global feed in `CommunityView` (same style as Feed|Circles selector)
- Tab 0: "Posts" — shows only `.moment` FeedItems
- Tab 1: "Check-ins" — shows only `.habitCheckin` + `.streakMilestone` FeedItems
- Filter in `FeedView` or pass a filter param down from `CommunityView`

**4. 30-min countdown on posting**
- `CircleDetailView` already has `windowSecondsRemaining` countdown on the moment banner
- Extend: show the same countdown on `MomentCameraView` and/or `MomentPreviewView` so user sees time pressure while composing
- Pass `windowSecondsRemaining` (or compute from `DailyMomentService.windowStart`) into those views

---

## Exact Next Steps for Next Agent

1. **Read this file first**, then read `.planning/STATE.md`
2. **Fix #1 (photos not appearing)** — pull-to-refresh to confirm diagnosis, then fix the refresh no-op in `CommunityView` + `CircleDetailView` post closures
3. **Fix #2 (one post card + expandable circles)** — deduplicate in `FeedService`, update `MomentFeedItem`, update `MomentFeedCard`
4. **Fix #3 (feed filter tabs)** — pill tabs in `CommunityView` global feed
5. **Fix #4 (countdown on camera/preview)** — pass countdown into `MomentCameraView` / `MomentPreviewView`
6. After all fixes build clean — commit as `feat(11.5): feed dedup + filter tabs + countdown`

---

## Notes / Blockers

- SourceKit "No such module 'Supabase'" warnings are **false positives** — build succeeds fine
- Simulator for builds: `id=AAD4DE32-6D0C-4C10-BCF1-1A4612DD9D92` (iPhone 17 Pro)
- `send-moment-window-notifications` edge function is **not deployed** to Supabase — only `seed-daily-moment` is deployed
- `#if DEBUG` `forceOpenWindow()` is in `DailyMomentService` + button in `ProfileView` dev tools — remove after real prayer window testing is verified
- `daily_moments` table uses column `moment_date` (not `date`) — confirmed in `DailyMomentService.fetchTodayPrayer()`
