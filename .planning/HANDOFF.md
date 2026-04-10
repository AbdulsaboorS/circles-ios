# Handoff — 2026-04-10 (Session 8 — Wave 3 Stage 2+3 complete; Stage I partially started)

## Current Build State
**BUILD SUCCEEDED — zero errors.**

---

## What Was Done This Session

### Stage 2 — Architecture ✓ COMPLETE
- Double-tier sticky header (Feed|Circles tier 1 + Posts|Check-ins tier 2) in `CommunityView`
- Pinned own-moment card above feed (120pt, gold border, "Shared with X Circles" pill)
- `OwnMomentFullView.swift` — new full-screen view for tapping own pinned card
- `FeedView` refactored: `FeedFilter` public, two custom inits, `excludeUserId`, grouped check-ins with `GroupedCheckinCard`

### Stage 3 — Visual ✓ COMPLETE
- `MomentFeedCard`: cornerRadius 16→32, `AsyncImage`→`CachedAsyncImage`
- `FeedIdentityHeader`: display name uses `design: .serif`
- `ReciprocityGateView`: "Share your Pause" button + updated body copy

### Stage I — Dual Camera Tap-to-Toggle — PARTIALLY STARTED (build still green, no functional change yet)

**DB migration: DONE** — `secondary_photo_url TEXT` column added to `circle_moments`.

**CameraManager: DONE** — `capturedPrimaryImage: UIImage?` and `capturedSecondaryImage: UIImage?` added as observable state; set alongside `capturedImage` after compositing; cleared in `resetCapture()`.

**Remaining work for Stage I (start here next session):**

---

## Stage I — Exact Next Steps

The goal: tap the PiP inset in `MomentFeedCard` to swap primary ↔ secondary photo.

### Step 1 — `MomentPreviewView.swift` (`MomentDraft` struct)
Add `primaryImage` and `secondaryImage` to `MomentDraft`:
```swift
struct MomentDraft: Identifiable {
    let id = UUID()
    let image: UIImage          // composited for preview (unchanged)
    let primaryImage: UIImage   // raw primary for upload
    let secondaryImage: UIImage // raw secondary for upload
}
```

### Step 2 — `MomentCameraView.swift`
Change `onCapture` signature from `(UIImage) -> Void` to `(UIImage, UIImage, UIImage) -> Void`:
```swift
let onCapture: (UIImage, UIImage, UIImage) -> Void  // (composited, primary, secondary)
```
Update `onChange(of: cameraManager.capturedImage)`:
```swift
.onChange(of: cameraManager.capturedImage) { _, image in
    if let image,
       let primary = cameraManager.capturedPrimaryImage,
       let secondary = cameraManager.capturedSecondaryImage {
        onCapture(image, primary, secondary)
    }
}
```

### Step 3 — `MomentService.swift`
Add `suffix: String = ""` param to `uploadPhoto`:
```swift
func uploadPhoto(image: UIImage, userId: UUID, suffix: String = "") async throws -> String {
    let suffixPart = suffix.isEmpty ? "" : "_\(suffix)"
    let filename = "shared/\(userId.uuidString.lowercased())_\(Self.todayDateString())\(suffixPart).jpg"
    ...
}
```
Change `postMomentToAllCircles` params from `image: UIImage` to `primaryImage: UIImage, secondaryImage: UIImage?`:
- Upload primary with `suffix: "primary"`
- Upload secondary with `suffix: "secondary"` (if non-nil)
- Add `secondary_photo_url` to each row dict if secondary upload succeeded

### Step 4 — `CircleMoment.swift`
Add `secondaryPhotoUrl: String?` field + CodingKey `secondary_photo_url`.

### Step 5 — `FeedItem.swift` (`MomentFeedItem`)
Add `secondaryPhotoUrl: String?` field.

### Step 6 — `FeedService.swift`
- `CircleMomentRow` private struct: add `secondaryPhotoUrl: String?` (CodingKey `secondary_photo_url`)
- `resolveMomentPhotoURLsConcurrent` return type: `[UUID: (primary: String, secondary: String?)]`
  - Resolve secondary URL if `row.secondaryPhotoUrl` is non-nil (using `try? await` — don't fail whole fetch)
- In `fetchFeedPage` when building `MomentFeedItem`: pass `secondaryPhotoUrl: resolved?.secondary`

### Step 7 — `MomentService.swift` — `resolveMomentPhotoURLs`
Update `CircleMoment` init calls in `resolveMomentPhotoURLs` to pass `secondaryPhotoUrl`:
```swift
CircleMoment(
    id: moment.id, circleId: moment.circleId, userId: moment.userId,
    photoUrl: renderableURL,
    secondaryPhotoUrl: moment.secondaryPhotoUrl, // pass through (not resolved here — only used for hasPostedToday check)
    caption: moment.caption, postedAt: moment.postedAt, isOnTime: moment.isOnTime
)
```

### Step 8 — `MomentFeedCard.swift`
Add `@State private var swapped = false`.
Add computed props:
```swift
private var mainPhotoUrl: String {
    swapped ? (item.secondaryPhotoUrl ?? item.photoUrl) : item.photoUrl
}
private var pipPhotoUrl: String? {
    guard let secondary = item.secondaryPhotoUrl else { return nil }
    return swapped ? item.photoUrl : secondary
}
```
Update `momentImage` to a `ZStack(alignment: .bottomLeading)`:
- Main: `CachedAsyncImage(url: mainPhotoUrl)` full 3:4
- PiP (if `pipPhotoUrl != nil && !isLocked`): `CachedAsyncImage(url: pipUrl)`, `frame(width: 80, height: 107)`, `clipShape(RoundedRectangle(cornerRadius: 12))`, `overlay(stroke white 0.9, lineWidth: 2)`, `padding(10)`, `onTapGesture { withAnimation(.easeInOut(duration: 0.25)) { swapped.toggle() } }`

### Step 9 — `CommunityView.swift`
Update `MomentCameraView` closure:
```swift
MomentCameraView(circleId: circleId) { composited, primary, secondary in
    showGlobalCamera = false
    Task { @MainActor in
        await Task.yield()
        draftMoment = MomentDraft(image: composited, primaryImage: primary, secondaryImage: secondary)
    }
}
```
Update `postMomentToAllCircles` call:
```swift
let result = try await MomentService.shared.postMomentToAllCircles(
    primaryImage: draft.primaryImage,
    secondaryImage: draft.secondaryImage,
    circleIds: circleIds,
    userId: userId,
    caption: caption,
    windowStart: viewModel.circles.first?.momentWindowStart
)
```

### Step 10 — `CircleDetailView.swift`
Same two updates as Step 9 (MomentCameraView closure + postMomentToAllCircles call).

---

## Wave Status

| Wave | Screen | Status |
|------|--------|--------|
| 1 | Home | ✓ Complete |
| 2 | Habit Detail | ✓ Complete |
| 3+4 | Community/Feed + Cards | ✓ Stage 1–3 complete; Stage I dual camera in progress |
| 5 | Circles | ⬜ |
| 6 | Profile | ⬜ |
| 7 | Auth | ⬜ |

## Simulator UDID
`AAD4DE32-6D0C-4C10-BCF1-1A4612DD9D92` (iPhone 17 Pro, OS 26.3.1)

## Key Files Changed This Session
- `Circles/Feed/FeedView.swift` — FeedFilter public, two inits, excludeUserId, GroupedCheckinCard
- `Circles/Feed/OwnMomentFullView.swift` — new file
- `Circles/Community/CommunityView.swift` — double-tier header, pinned own-moment card
- `Circles/Feed/MomentFeedCard.swift` — cornerRadius 32, CachedAsyncImage
- `Circles/Feed/FeedIdentityHeader.swift` — serif display name
- `Circles/Feed/ReciprocityGateView.swift` — copy updates
- `Circles/Moment/CameraManager.swift` — capturedPrimaryImage + capturedSecondaryImage exposed
