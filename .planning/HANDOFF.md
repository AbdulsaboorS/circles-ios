# Handoff — 2026-04-13 (Session 13 — loading, caption, preview fixes)

## Current Build State
**BUILD SUCCEEDED — zero errors.**
Commit: `40ff85f`

---

## What Was Done This Session

### Fix 1 — Own-moment strip: BeReal-style PiP (not side-by-side)
- `CommunityView.ownMomentStrip`: replaced 2 side-by-side thumbnails with main photo (160x213) + PiP overlay (52x69) at top-left, matching feed card style

### Fix 2 — Caption editing (3 root causes fixed)
1. **Missing UPDATE RLS policy** — `circle_moments` had no UPDATE policy → caption silently never saved. Added via Supabase MCP: `"Users can update own moments"` policy.
2. **Swift Codable nil omission** — `CaptionUpdate(caption: String?)` encodes nil as absent key (not JSON null). Fixed `updateCaption()` to use `["caption": AnyJSON]` with explicit `.null`.
3. **Stale UI after save** — was calling `viewModel.refresh()` (async network). Fixed with `FeedViewModel.updateMomentCaption(momentId:caption:)` — optimistic in-memory update, instant.

### Fix 3 — Loading latency & gate flicker
- Spinner only shows when `feedViewModel.items.isEmpty` (not on every background reload)
- `DailyMomentService.load()` now has a daily cache (`lastLoadedDate`) — Aladhan API called once per day max
- Gate flicker fixed: `hasPostedToday` set BEFORE `windowStart` in batched state update
- `.task` in `CommunityView`: `loadGlobalFeed` and `DailyMomentService.load` now run concurrently with `async let`
- `FeedViewModel.refresh()` no longer clears `items = []` before reload (shows stale data)

### Fix 4 — Mock moments
- Added UPDATE RLS (Supabase MCP)
- Inserted 3 mock profiles (Omar, Yusuf, Fatima) and circle_members via replica role bypass
- First insert was UTC April 12 → FeedService today window was April 13 UTC → invisible
- Re-inserted for April 13 UTC (now visible in feed)

### Fix 5 — MomentPreviewView: PiP top-left + tap-to-swap
- `MomentDraft` struct: removed `image` (composited) field, `secondaryImage` is now `UIImage?`
- `MomentPreviewView`: replaced single composited `Image` with SwiftUI ZStack — main photo + PiP overlay at top-left (matches feed card)
- Added `@State var swapped = false` + `onTapGesture` on PiP
- `onPost` signature changed from `(String?)` → `(String?, Bool)` where Bool = swapped
- `CommunityView` and `CircleDetailView` both updated — swap Bool passed to `postMomentToAllCircles` with primary/secondary order flipped accordingly

---

## Status: Pending User QA

All fixes built. User needs to test:
- [ ] Caption edits save and show immediately on strip (no tab switch needed)
- [ ] 3 mock moments visible in feed (Omar, Yusuf, Fatima) — pull to refresh
- [ ] MomentPreviewView shows PiP at top-left (not bottom-left)
- [ ] Tap PiP in preview to swap before posting
- [ ] No gate flicker when app loads (hasPostedToday preserved)
- [ ] No blank screen when feed reloads (stale data stays visible)

---

## Mock Data in Supabase
3 mock moments in circle `07d62410-f160-4fc3-9928-dca465300c01` (April 13 UTC):
- Omar Abdullah — dual cam, on-time, caption "Alhamdulillah for this morning"
- Yusuf Ibrahim — single cam, late, no caption
- Fatima Al-Rashid — dual cam, on-time, caption "Barakallahu feek"

Using real photo_url from the user's own moment (images load correctly).

Cleanup SQL (run after testing):
```sql
DELETE FROM circle_moments WHERE user_id IN (
  'aaaaaaaa-0001-0001-0001-000000000001',
  'aaaaaaaa-0002-0002-0002-000000000002',
  'cccccccc-0001-0001-0001-000000000001'
);
DELETE FROM circle_members WHERE user_id IN (
  'aaaaaaaa-0001-0001-0001-000000000001',
  'aaaaaaaa-0002-0002-0002-000000000002',
  'cccccccc-0001-0001-0001-000000000001'
);
DELETE FROM profiles WHERE id IN (
  'aaaaaaaa-0001-0001-0001-000000000001',
  'aaaaaaaa-0002-0002-0002-000000000002',
  'cccccccc-0001-0001-0001-000000000001'
);
```

---

## Files Changed This Session

| File | Change |
|------|--------|
| `CommunityView.swift` | Strip → BeReal PiP style; parallel .task; spinner guard; new MomentDraft init |
| `FeedViewModel.swift` | `updateMomentCaption()` added; `refresh()` no longer clears items |
| `MomentFullScreenView.swift` | `saveCaption()` → optimistic update; error shown in UI |
| `MomentService.swift` | `updateCaption()` → AnyJSON with `.null`; logging added |
| `DailyMomentService.swift` | Daily cache; batched state update (hasPostedToday before windowStart) |
| `MomentPreviewView.swift` | PiP top-left overlay + swap; `MomentDraft` simplified; `onPost(caption:swapped:)` |
| `CircleDetailView.swift` | Updated to new MomentDraft + MomentPreviewView signatures |

## Simulator UDID
`AAD4DE32-6D0C-4C10-BCF1-1A4612DD9D92` (iPhone 17 Pro, OS 26.3.1)
