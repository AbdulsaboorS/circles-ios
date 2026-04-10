# Handoff — 2026-04-10 (Session 7 — Wave 3 Stage 1 partial)

## Current Build State
**BUILD SUCCEEDED — zero errors.**

---

## What Was Done This Session

### Stage 1 Performance — PARTIAL (commit `c96915b`)

**Done:**
- `FeedService.fetchFeedPage`: activity_feed + circle_moments now fetched with `async let` (parallel, saves ~300-500ms per load)
- `CachedAsyncImage.swift` (new): NSCache-backed image view, 60MB/80-image limit, auto-cancels on disappear — drop-in for `AsyncImage`
- `CommunityView`: removed duplicate `.onAppear` load + `onChange(of: viewModel.circles)` load trigger (was causing 3× load on every community tab open)
- `CommunityView`: join/create sheet `onDismiss` now explicitly triggers feed reload (safe, intentional)

**Not done — blocked:**
- URL resolution concurrency: `resolveMomentPhotoURLsConcurrent` attempted with `withThrowingTaskGroup` but Swift 6 region-isolation checker rejects `@MainActor in` closures calling `@MainActor`-isolated `MomentService`. Reverted to serial loop with comment explaining the blocker. Fix path: make `MomentService.resolveMomentPhotoURL` `nonisolated` and call Supabase client directly (no MainActor hop needed for storage URL signing).

---

## Stage 2 + 3 — NOT STARTED

Everything below is fully designed and planned, ready to implement in the next session. All design decisions are confirmed by the user.

### Stage 2 — Architecture

**A. Double-tier sticky header in `CommunityView`**
- Remove current capsule `pageSelector`
- Tier 1: `Feed | Circles` — two full-width buttons, gold `Rectangle(height: 2)` underline for active, `.ultraThinMaterial` background, 0.5pt bottom divider
- Tier 2: `Posts | Check-ins` — 12pt font, gold underline, `padding(.horizontal, 20)`, only visible when `selectedPage == 0`
- Lift `@State private var activeFilter: FeedFilter = .posts` to `CommunityView`
- `navigationTitle("")` — empty, nav bar only holds the `+` toolbar button

**B. Pinned 'Me' moment card**
- Helper: `ownMomentItem(for: userId) -> MomentFeedItem?` — finds own moment in `feedViewModel.items`
- Card: `ZStack(alignment: .topTrailing)` with `CachedAsyncImage`, `frame(height: 120)`, `cornerRadius(24)`, gold border
- Gold pill top-right: `"Shared with X Circle(s)"`
- `@State private var expandedOwnMoment: MomentFeedItem? = nil`
- `.fullScreenCover(item: $expandedOwnMoment)` → `OwnMomentFullView`
- Card shown above `FeedView` in `globalFeedPage`

**C. `FeedView` changes**
- `FeedFilter` enum: remove `private` keyword (needs to be visible in `CommunityView`)
- Two custom inits:
  - `init(circleIds:currentUserId:viewModel:activeFilter:Binding<FeedFilter>:excludeUserId:)` — CommunityView path, `showFilterTabs = true`
  - `init(circleIds:currentUserId:viewModel:excludeUserId:)` — CircleDetailView path, `showFilterTabs = false`, uses `.constant(.posts)`
- `excludeUserId: UUID?` param — filters own moment from main feed list (shown in pinned card instead)
- Remove `feedFilterPicker` from `FeedView.body` (now in CommunityView header)
- Grouped check-ins: when `showFilterTabs && activeFilter == .checkins`, group by user using `checkinGroups` computed prop

**D. New types (in `FeedView.swift`)**
```swift
struct UserCheckinGroup: Identifiable {
    let id: UUID // userId
    let userName: String
    let avatarUrl: String?
    let circleName: String
    let habitCheckins: [HabitCheckinFeedItem]
    let streakMilestones: [StreakMilestoneFeedItem]
}
struct GroupedCheckinCard: View { ... }
```
- `GroupedCheckinCard`: avatar + name + "in [Circle]", "Completed X intentions" summary, horizontal scroll of habit name pills (gold), streak milestone rows, `ReactionBar` for first checkin

**E. New file: `OwnMomentFullView.swift`**
- Full-screen dark view: close X button, `FeedIdentityHeader`, gold "Shared with X circles" pill, `CachedAsyncImage` photo (3:4 ratio, 20pt corners, 12pt padding), on-time badge, caption

### Stage 3 — Visual (cards + gate + typography)

**F. `MomentFeedCard.swift`**
- Corner radius: 16 → 32pt (both `background` and `clipShape`)
- Replace `AsyncImage` → `CachedAsyncImage`
- Display name font: `.system(size: 14, weight: .semibold, design: .serif)` (in `FeedIdentityHeader`)
- Padding: `FeedView` already uses `.padding(.horizontal, 12)` in the rewrite

**G. `FeedIdentityHeader.swift`**
- `displayName` Text: add `design: .serif` to font

**H. `ReciprocityGateView.swift`**
- Button: `"Unlock Your Circles"` → `"Share your Pause"`
- Body: `"Post your Moment to unlock your circles."` → `"Your circle is waiting. Share this moment to unlock."`

**I. Dual camera tap-to-toggle — BLOCKED on DB migration**
User wants: tap the PiP secondary image to swap with primary. Currently the app bakes both shots into ONE JPEG (no separate URLs stored).
Required before building:
1. User runs in Supabase SQL editor: `ALTER TABLE circle_moments ADD COLUMN secondary_photo_url TEXT;`
2. Then next agent updates: `CircleMomentRow`, `CircleMoment`, `MomentFeedItem`, `FeedService`, `MomentService.postMomentToAllCircles` (upload second image, store second path), `CameraManager` (preserve both UIImages before compositing), `MomentFeedCard` (PiP tap-to-toggle using `@State private var swapped = false`)

---

## Wave Status

| Wave | Screen | Status |
|------|--------|--------|
| 1 | Home | ✓ Complete |
| 2 | Habit Detail | ✓ Complete |
| 3+4 | Community/Feed + Cards | 🔄 Stage 1 partial — Stage 2+3 next |
| 5 | Circles | ⬜ |
| 6 | Profile | ⬜ |
| 7 | Auth | ⬜ |

## Simulator UDID
`AAD4DE32-6D0C-4C10-BCF1-1A4612DD9D92` (iPhone 17 Pro, OS 26.3.1)

## Key Files Changed
- `Circles/Feed/CachedAsyncImage.swift` — new
- `Circles/Services/FeedService.swift` — parallel DB fetches
- `Circles/Community/CommunityView.swift` — triple-load fix
