# Handoff — 2026-04-14 (Session 21 — Journey QA Fixes Implemented)

## Current Build State
**BUILD VERIFIED ✅** via:

```bash
xcodebuild -quiet -project Circles.xcodeproj -scheme Circles -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' build
```

### Runtime verification gap
- Simulator boot succeeded for `iPhone 17 Pro` (`AAD4DE32-6D0C-4C10-BCF1-1A4612DD9D92`).
- `open -a Simulator` succeeded.
- `simctl install` still did not return promptly.
- A follow-up `xcrun simctl get_app_container ... app.joinlegacy` returned `No such file or directory`, so the app never finished installing.
- Result: there is still no screenshot-level/manual runtime proof for the new Journey fixes.

---

## What Landed This Session

### 1. Journey correctness after posting
- `JourneyViewModel` now invalidates today’s month cache on a successful moment post instead of trusting the previously loaded month snapshot.
- Journey now refreshes its archive summary on re-entry and reloads the current month when returning to the tab.
- Same-day dedupe now prefers the newest `posted_at`, not the oldest.
- `MomentService.fetchMoments(userId:from:toExclusive:)` now fetches newest-first to match that newest-wins behavior.

### 2. Journey detail paging + PiP parity
- Journey detail is no longer a single-day sheet.
- `JourneyDayDetailView` now pages horizontally across the populated days in the visible month via `TabView` page style.
- Double Take moments now resolve both primary and secondary photos.
- PiP now renders consistently in Journey detail and swaps main/PiP on tap, matching feed/fullscreen behavior.

### 3. Journey media latency improvements
- Signed moment URLs are now cached in-memory by stable storage path inside `MomentService`.
- `CachedAsyncImage` now accepts a caller-supplied `cacheKey`, so Journey detail can cache images by storage path instead of volatile signed URL.
- Journey detail now prefetches media for the selected day plus adjacent days when the sheet opens/pages.

### 4. Cross-surface post refresh
- `MomentService.postMomentToAllCircles` now publishes a `momentPostRefresh` notification after any successful post.
- `JourneyView`, `CommunityView`, and `CircleDetailView` now listen for that notification and refresh their relevant state.
- This closes the stale-UI gap where posting from `CircleDetailView` could leave Community circle cards behind until a manual refresh.
- Partial-success post errors now name the failed circles when those names are available, making backend partial success easier to distinguish from stale UI.

---

## Files Modified

- `Circles/Journey/JourneyView.swift`
- `Circles/Journey/JourneyDayDetailView.swift`
- `Circles/Journey/JourneyViewModel.swift`
- `Circles/Services/MomentService.swift`
- `Circles/Feed/CachedAsyncImage.swift`
- `Circles/Community/CommunityView.swift`
- `Circles/Circles/CircleDetailView.swift`

---

## Root-Cause Status vs Prior Handoff

### A. Journey detail should page between days
**Status:** fixed in code.

- The detail sheet now takes a day dataset plus selected day key.
- Horizontal paging is handled in the sheet itself, not by dismiss/reopen.

### B. Journey detail lacked PiP parity
**Status:** fixed in code.

- Secondary photo signing/loading now exists in Journey detail.
- PiP visibility and tap-to-swap now mirror feed/fullscreen behavior.

### C. Journey detail open latency was too high
**Status:** mitigated in code; still needs runtime feel-check.

- Stable cache identity is now the storage path.
- Signed URLs are reused in-memory until near expiry.
- Selected + adjacent days prefetch on open/page change.

### D. Journey could show stale / wrong current-day detail after repost
**Status:** fixed in code for the traced high-confidence causes.

- Current month cache is explicitly invalidated after post.
- Journey refreshes on tab re-entry.
- Same-day dedupe now prefers the newest moment.

**Residual risk:**
- `saveNiyyah` is still intentionally non-fatal if Supabase fails to save the private niyyah row. That path was not reproduced this session.

### E. Mixed circle-card timestamps after a fresh post
**Status:** stale-UI cause addressed in code; backend partial success remains the likely explanation if it still reproduces.

- Community now refreshes after any successful post event, even when the post originated from Circle Detail.
- Partial-success errors now identify failed circles when the app has their names.

---

## Recommended Next Tests

1. Post a fresh moment from the global Community flow, then open Journey:
   today should show the newest photo and newest niyyah without killing the app.
2. Repost on the same UTC day after forcing the window:
   Journey should prefer the newest same-day post, not the older one.
3. Open a Double Take day in Journey detail:
   PiP should always appear when a secondary image exists, and tap-to-swap should work.
4. Swipe left/right inside Journey detail:
   paging should move between populated days without dismissing the sheet.
5. Open the same Journey day twice in a row:
   the second open should be meaningfully faster because the signed URL and image cache are reused.
6. Post from `CircleDetailView`, then return to Community:
   circle cards should refresh without requiring manual pull-to-refresh.
7. If a post partially succeeds:
   confirm the failure banner names the circles that stayed stale.

---

## Code Review Status
Code review was performed on the final diff before handoff.

### Findings
- No new blocking findings were found in the Journey fix set after build verification.

### Remaining risks
- Manual runtime verification is still missing because `simctl install/launch` remains unreliable from CLI on this simulator.
- The non-fatal `saveNiyyah` fallback still exists, so a Supabase niyyah-write failure could still leave a post with a stale private niyyah.

---

## Recommended Next Work

1. Finish manual runtime QA for the Journey fixes on simulator/device.
2. If runtime QA passes, close the Journey follow-up and move on to the Profile redesign.
