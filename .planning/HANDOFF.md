# Handoff — 2026-04-14 (Session 20 — Journey MVP Built + QA Follow-Ups)

## Current Build State
**BUILD VERIFIED ✅** — zero errors on `main` via:

```bash
xcodebuild -quiet -project Circles.xcodeproj -scheme Circles -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' build
```

**Runtime verification gap:** simulator boot succeeded, but `simctl launch` hung in-session, so there is no screenshot-level proof of the Journey flow yet.

---

## What Landed This Session

### 1. Journey Tab MVP
- Added a new 4-tab app shell flow: `Home` → `Circles` → `Journey` → `Profile`
- Built `JourneyView`, `JourneyCalendarGrid`, `JourneyDayDetailView`, `JourneyViewModel`, `JourneyDateSupport`, and `JourneyDay`
- Journey uses **stored UTC day consistency** for now, not local-day reinterpretation
- Calendar uses **device locale** weekday ordering
- Day states:
  - gold / niyyah-dominant
  - neutral / moment-only
  - empty
- Day detail is **read-only** for MVP
- Photo signing is **on-demand** when detail opens

### 2. Profile Ledger Removal
- Removed the old Profile entry path for Spiritual Ledger
- Deleted `SpiritualLedgerView.swift`
- Removed `niyyahCount`, `showSpiritualLedger`, and ledger button wiring from `ProfileView`

### 3. Journey Data Plumbing
- `MomentService.fetchMoments(userId:from:toExclusive:)` added for month-range unresolved moment fetches
- `MomentService.hasAnyMoments(userId:)` added for archive empty-state detection
- Journey month model caches deduplicated same-day moments and all niyyahs for the user

### 4. Review Fixes Applied In-Session
- Fixed a loader-state bug where a failed month fetch could leave stale visible days
- Refreshed the Journey niyyah summary when Journey re-enters its own load path

---

## Files Added / Removed

### Added
- `Circles/Journey/JourneyView.swift`
- `Circles/Journey/JourneyCalendarGrid.swift`
- `Circles/Journey/JourneyDayDetailView.swift`
- `Circles/Journey/JourneyViewModel.swift`
- `Circles/Journey/JourneyDateSupport.swift`
- `Circles/Models/JourneyDay.swift`

### Modified
- `Circles/Navigation/MainTabView.swift`
- `Circles/Profile/ProfileView.swift`
- `Circles/Services/MomentService.swift`

### Deleted
- `Circles/Profile/SpiritualLedgerView.swift`

---

## User-Tested Issues Found After Ship

### A. Journey detail should page between days
**Observed:** once inside a day detail sheet, user wants left/right swiping to move across adjacent days without dismissing the sheet.

**Current cause:** `JourneyDayDetailView` is opened with a single `JourneyDay` item, not a selected index / paged dataset.

**Files involved:**
- `Circles/Journey/JourneyView.swift`
- `Circles/Journey/JourneyDayDetailView.swift`

### B. Journey detail lacks PiP parity
**Observed:** some detail views show only the main image; PiP behavior is inconsistent or absent.

**Current cause:** Journey detail only resolves and displays `day.moment?.photoUrl`. It does **not** resolve `secondaryPhotoUrl`, and there is no `swapped` state or PiP renderer.

**Reference implementation to mirror:**
- `Circles/Feed/MomentFeedCard.swift`
- `Circles/Feed/MomentFullScreenView.swift`

### C. Journey detail open latency is too high
**Observed:** opening detail feels slow.

**Likely root cause:**
1. open detail
2. request signed URL from Storage
3. download image
4. cache keyed by signed URL string, not stable storage path

So the current cache strategy has weak reuse if signed URLs change.

**Files involved:**
- `Circles/Journey/JourneyDayDetailView.swift`
- `Circles/Feed/CachedAsyncImage.swift`
- `Circles/Services/MomentService.swift`

### D. Journey can show stale / wrong current-day detail after repost
**Observed:** after posting again, Journey detail for today can show the wrong niyyah or wrong moment.

**High-confidence causes:**
- Journey is mounted under `TabView`; simply switching back to the tab does not guarantee the `.task` reruns
- current month cache is sticky once loaded
- same-day moment dedupe currently chooses the **first** row seen
- month fetch is ordered ascending by `posted_at`, so dedupe can prefer the **oldest** same-day moment instead of the newest

**Possible additional cause:**
- `saveNiyyah` is intentionally non-fatal in `MomentService.postMomentToAllCircles`; if it fails, the post can succeed while the niyyah remains stale

**Files involved:**
- `Circles/Journey/JourneyView.swift`
- `Circles/Journey/JourneyViewModel.swift`
- `Circles/Services/MomentService.swift`

### E. Mixed circle-card timestamps after a fresh post
**Observed:** user saw some circles showing the newest post age and some circles showing older ages after a fresh moment post.

**Most likely causes to investigate next:**
1. **Partial-success insert scenario** across circles
   - `postMomentToAllCircles` permits succeeded + failed circles and surfaces a partial-success warning
2. **Stale card-data refresh path** when posting from some surfaces
   - especially if the post originated from `CircleDetailView`, which only refreshes that circle’s feed directly

**Important nuance:**
- If the post definitely came from the global `Community` camera flow, `viewModel.loadCircles(userId:)` does run afterward, so stale global card data is less likely there than a partial-success insert or stale viewing surface elsewhere.

**Files involved:**
- `Circles/Services/MomentService.swift`
- `Circles/Community/CommunityView.swift`
- `Circles/Circles/CircleDetailView.swift`
- `Circles/Circles/CirclesViewModel.swift`
- `Circles/Services/FeedService.swift`

---

## Recommended Fix Order

### 1. Journey correctness first
- invalidate and reload current month + niyyah state after successful post
- make same-day dedupe prefer the newest `posted_at`, not the oldest
- ensure Journey refreshes when returning to the tab, not only on first mount

### 2. Journey detail parity
- switch from “single day sheet” to “selected index in a day dataset”
- add left/right paging across populated days
- add PiP rendering and swap behavior in detail view

### 3. Journey media performance
- cache by storage path, not signed URL
- pre-sign / prefetch selected day plus adjacent days when detail opens
- optionally retain resolved URLs in Journey VM while the session is alive

### 4. Cross-surface post consistency
- verify whether mixed timestamps were caused by partial-success inserts
- if not, strengthen post-success refresh so `Community` / `My Circles` / `CircleDetail` all converge on the newest moment state immediately

---

## Code Review Status
Code review was performed in-session.

### Findings
- No remaining blocking findings on the shipped Journey MVP itself
- One stale-month loader issue was found and fixed before final build
- One same-session niyyah refresh gap was found and fixed before final build

### Remaining risk areas
- runtime behavior still needs direct simulator/device verification
- Journey tab freshness under `TabView` lifecycle
- signed-URL image caching strategy
- cross-circle insert consistency after repost / debug reopen scenarios

---

## Recommended Next Tests After Fixes

1. Open Journey, post a new moment with niyyah, return to Journey without killing the app:
   today should show the new niyyah and newest photo.
2. Open a day detail with Double Take:
   PiP should always show when a secondary image exists, and swap should work.
3. Swipe left/right between adjacent days from inside detail view.
4. Re-open the same day detail twice:
   second open should feel meaningfully faster.
5. Post from global Community flow:
   all circle cards should show the same fresh age if inserts succeeded everywhere.
6. If a partial-post warning appears:
   note exactly which circles remained stale.

---

## Simulator UDID
`AAD4DE32-6D0C-4C10-BCF1-1A4612DD9D92` (iPhone 17 Pro, OS 26.3.1)
