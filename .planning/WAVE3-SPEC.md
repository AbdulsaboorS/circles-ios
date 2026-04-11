# Wave 3 — Community Feed Redesign (BeReal-Inspired)

**North star:** Replicate BeReal's feed UX and layout exactly, but with Circles' own visual identity (dark green palette, gold accents, serif typography).

**Reference images:** BeReal app screenshot + Stitch mockup — both reviewed with user. BeReal is the authoritative reference for layout, behavior, and interaction patterns.

---

## Locked Design Decisions

| # | Decision | Value |
|---|----------|-------|
| 1 | PiP content | Real dual-camera secondary photo (`secondaryPhotoUrl`) |
| 2 | PiP tap behavior | Tap-to-swap in feed card AND full-screen view |
| 3 | Card side margins | Zero — edge-to-edge, no horizontal padding on the photo |
| 4 | Avatar position | Fully above card, no overlap (BeReal style) |
| 5 | Card aspect ratio | 3:4 portrait (matches BeReal) |
| 6 | Card corner radius | 16pt |
| 7 | PiP position | Top-left of photo |
| 8 | PiP border | Gold (`msGold`), 2pt stroke |
| 9 | PiP size | ~30% card width, matching 3:4 ratio (~118x157pt on 393pt screen) |
| 10 | Identity row | Floating above card on bare `msBackground`, no card/material behind it |
| 11 | Identity subtitle | `"Circle Name • On Time"` if on-time, `"Circle Name • Xh ago"` if late |
| 12 | "On Time" styling | Gold pill badge (Capsule, `msGold` fill, dark text) — inline in subtitle |
| 13 | "..." menu | Right side of identity row. MVP actions: "Report" + "Hide post" (stubs with toast) |
| 14 | Actions below card | Reactions row + comment button, floating on bare background (no card behind) |
| 15 | Caption below actions | If present, below the reaction row, on bare background |
| 16 | Divider between posts | Thin gold-tinted line (`msGold.opacity(0.15)`), 1px, full width |
| 17 | Background color | `msBackground` (dark green `#1A2E1E`) — NOT pure black |
| 18 | Font style | Serif for identity (username), sans-serif for subtitle/meta — Circles brand |
| 19 | Own-moment card | Compact horizontal strip at top (BeReal style), NOT a full feed card |
| 20 | Own-moment strip | Two side-by-side thumbnails + "Add a caption..." — "Shared with X Circles" pill shown here |
| 21 | Full-screen open | Tap main photo (not PiP) opens full-screen expanded view |
| 22 | Full-screen transition | Zoom-in from card (matchedGeometryEffect or similar) |
| 23 | Full-screen layout | Photo top ~60%, inline comments scrolling below (NOT a sheet drawer) |
| 24 | Full-screen scope | Works for both own posts AND others' posts |
| 25 | Tab switcher | Centered bold text, no underline/capsule/indicator. Active = bold `msTextPrimary`, inactive = regular `msTextMuted` |
| 26 | Tab font | Serif, matching Circles brand |
| 27 | Tab tiers | Same treatment for both Tier 1 ("Feed / Circles") and Tier 2 ("Posts / Check-ins") |
| 28 | Swap animation | BeReal-style scale+position: PiP zooms up to fill card, main shrinks into PiP slot |
| 29 | Locked state | Non-posters see blurred photo + lock icon + "Post your Moment to see theirs" (unchanged from current) |
| 30 | GroupedCheckinCard | NOT touched in this wave — separate lighter refresh later |
| 31 | Late posts | No special "Late" label — just show timestamp instead of "On Time" pill |

---

## Batch Plan

### Batch 1 — MomentFeedCard Core Redesign

**Goal:** The main feed card matches BeReal's layout exactly, with Circles branding.

**Files to touch:**
- `Circles/Feed/MomentFeedCard.swift` — full rewrite of card layout
- `Circles/Feed/FeedIdentityHeader.swift` — update to support subtitle with inline "On Time" pill + "..." menu
- `Circles/Community/CommunityView.swift` — update card call site (remove old container padding, add edge-to-edge layout, add divider between posts)

**What changes:**

#### MomentFeedCard.swift — NEW layout structure:
```
[Identity row — floating on msBackground, no card]
  [Avatar 36pt] [Name (serif bold 14pt)]  [...spacing...]  [... menu]
               [Circle Name • ON TIME pill]    (subtitle line)

[Photo card — zero side margins, 3:4 ratio, cornerRadius 16]
  [Main photo — scaledToFill, clipped]
  [PiP — top-left, 118x157pt, cornerRadius 12, gold 2pt border]
    → tap PiP to swap (scale+position animation)

[Actions row — floating on msBackground below card]
  [ReactionBar] [spacer] [comment bubble button]

[Caption — if present, below actions, msTextPrimary, serif italic]

[Gold divider — msGold.opacity(0.15), 1px, full width]
```

#### Key structural changes from current:
1. **Remove the outer card container** — no more `RoundedRectangle(cornerRadius: 32).fill(Color(hex: "243828"))`. The identity row, photo, and actions all float independently on the screen background.
2. **Photo goes edge-to-edge** — remove `.padding(.horizontal, 14)` and any horizontal padding on the photo. The photo's only horizontal constraint is the screen width.
3. **PiP moves to top-left** (currently bottom-left). Size increases to ~118x157pt. Border changes from white to gold (`msGold`).
4. **Identity row** becomes a separate floating element above the photo. Avatar shrinks from 42pt to 36pt. Subtitle changes to show circle name + on-time status instead of just timestamp.
5. **"On Time" pill** goes inline in subtitle (gold capsule, dark text, 11pt semibold).
6. **"..." menu** appears right-aligned in the identity row. MVP: "Report" + "Hide post" stubs.
7. **Swap animation** — BeReal-style: when user taps PiP, the PiP scales up to fill the card while the main photo scales down into the PiP slot. Use `matchedGeometryEffect` or manual `withAnimation` on frame/position/zIndex.
8. **Actions row** floats below the photo on bare background (no card surface behind it).
9. **Caption** below actions, full-width.
10. **Gold divider** at the bottom of each post.

#### FeedIdentityHeader.swift — updates:
- Accept new parameter: `isOnTime: Bool?` (nil = don't show badge)
- Accept new parameter: `onMenuTap: (() -> Void)?` (nil = no menu)
- Subtitle line becomes: `[circleName] • [ON TIME pill]` or `[circleName] • [timestamp]`
- Avatar size parameter (default 36pt)
- "..." button right-aligned when `onMenuTap` is provided

#### CommunityView.swift — call site changes:
- Remove `.padding(.horizontal, 16)` on feed content — cards go edge-to-edge
- Add gold divider between posts in the LazyVStack

**What does NOT change:**
- `FeedViewModel` — no changes
- `ReactionBar` — no changes
- `FeedView.swift` — minimal changes (just remove horizontal padding on moment cards, add divider)
- Locked/blur state — same visual, just adapts to new edge-to-edge layout
- `GroupedCheckinCard` — NOT touched

**Build verification:** After Batch 1, the feed should show moment cards in BeReal layout with tap-to-swap working inline. Full-screen view and own-moment strip are NOT yet changed.

---

### Batch 2a — Full-Screen Moment View (Photo + Swap)

**Goal:** Tapping the main photo opens a full-screen view with zoom transition and swap.

**Files to touch:**
- `Circles/Feed/MomentFullScreenView.swift` — NEW file (replaces `OwnMomentFullView` for all posts)
- `Circles/Feed/MomentFeedCard.swift` — add tap gesture on main photo, matchedGeometryEffect source
- `Circles/Feed/OwnMomentFullView.swift` — DELETE (replaced by unified `MomentFullScreenView`)
- `Circles/Community/CommunityView.swift` — update fullScreenCover to use new view

**What the full-screen view looks like:**
```
[Close button — top-left, X in circle, material background]

[Photo — fills top ~60% of screen, 3:4 ratio, cornerRadius 16]
  [PiP — top-left, same size as feed card, gold border]
    → tap to swap (same animation as feed card)

[Identity row below photo — name, circle, on-time]
[Reactions row]
[Caption if present]

[Comments section — scrollable list filling remaining space]
  [Comment rows: avatar + name + text]

[Comment input — pinned to bottom, text field + send button]
```

**Zoom transition:** Use `matchedGeometryEffect` with a shared namespace between the feed card photo and the full-screen photo. When the full-screen cover appears, the photo zooms from its card position to fill the top portion of the screen.

**Swap in full-screen:** Same swap state as the card — if user already swapped in the card, the full-screen opens with the swapped state. Swap works independently in full-screen too.

**Build verification:** After Batch 2a, tapping any moment photo (own or others') opens the full-screen view with zoom transition and swap. Comments are NOT yet inline — this is just the photo + swap + identity.

---

### Batch 2b — Inline Comments (Replacing Drawer)

**Goal:** Comments appear inline below the photo in the full-screen view, not as a sheet.

**Files to touch:**
- `Circles/Feed/MomentFullScreenView.swift` — add inline comment list + input field
- `Circles/Feed/CommentDrawerView.swift` — keep for now (GroupedCheckinCard still uses it), but moment cards no longer open it

**What changes:**
1. Full-screen view gets a `ScrollView` with comments `LazyVStack` below the photo/identity/reactions section.
2. Comment input bar pinned at bottom of screen (same design as current `CommentDrawerView` input, just embedded in the full-screen view instead of a sheet).
3. Comment loading, sending, deleting — reuse exact same logic from `CommentDrawerView` (extract shared functions if needed).
4. `MomentFeedCard`'s comment button now opens the full-screen view scrolled to comments section (instead of opening `CommentDrawerView` as a sheet).

**Build verification:** After Batch 2b, tapping the comment button or the photo opens full-screen with inline comments. Sheet drawer is no longer used for moments.

---

### Batch 3 — Own-Moment Top Strip

**Goal:** The pinned "your post" card at the top of the feed becomes a compact BeReal-style strip.

**Files to touch:**
- `Circles/Community/CommunityView.swift` — replace `ownMomentCard` with compact strip

**What the strip looks like (BeReal reference):**
```
[Two thumbnails side by side, centered horizontally]
  [Front camera — ~140x187pt, cornerRadius 12, thin gold border]
  [Back camera — ~140x187pt, cornerRadius 12, thin gold border]
  (If only one photo, show single centered thumbnail)

[Below thumbnails:]
  "Add a caption..." (gray muted text, centered)

[Below caption:]
  "Shared with X Circle(s)" gold pill (centered)
```

**Tap behavior:** Tapping the strip opens the full-screen view (same `MomentFullScreenView` from Batch 2).

**Strip height:** Compact — roughly 260-280pt total (thumbnails + caption + pill + padding).

**What does NOT change:**
- The strip only appears when `momentService.hasPostedToday` is true
- ReciprocityGate overlay stays as-is

**Build verification:** After Batch 3, your own post at the top is a compact strip. Tapping it opens the full-screen view.

---

### Batch 4 — Tab Header

**Goal:** Clean, centered bold text tabs with no underline/capsule/indicator.

**Files to touch:**
- `Circles/Community/CommunityView.swift` — replace `stickyHeader`, `tier1Button`, `tier2Button`

**What the header looks like:**
```
Tier 1:        Feed          Circles
               (bold)        (regular gray)

Tier 2:        Posts         Check-ins
               (bold)        (regular gray)
```

- Active: `.system(size: 15, weight: .semibold, design: .serif)`, `msTextPrimary`
- Inactive: `.system(size: 15, weight: .regular, design: .serif)`, `msTextMuted`
- Tier 2: `.system(size: 12, ...)` — same weight rules
- No underline, no capsule, no fill, no material background
- Centered in the row (equal flex space)
- Row heights: Tier 1 = 44pt, Tier 2 = 34pt
- Thin divider at bottom: `msGold.opacity(0.15)`, 0.5pt

**Build verification:** After Batch 4, the header is clean text-only tabs.

---

## Execution Rules

1. **One batch at a time.** Build must succeed after each batch.
2. **Do NOT mark any batch complete.** Status stays "Built — pending user QA" until user explicitly approves.
3. **Do NOT start the next batch** until the user approves the current one.
4. **If a batch requires iteration** (user feedback), iterate within that batch until approved before moving on.
5. **Commit after each approved batch**, not before.

---

## Files Summary

| File | Batch | Action |
|------|-------|--------|
| `Circles/Feed/MomentFeedCard.swift` | 1, 2a | Rewrite layout, add fullscreen tap |
| `Circles/Feed/FeedIdentityHeader.swift` | 1 | Add isOnTime, menu, avatar size params |
| `Circles/Feed/FeedView.swift` | 1 | Remove horizontal padding on moments, add dividers |
| `Circles/Community/CommunityView.swift` | 1, 3, 4 | Edge-to-edge layout, own strip, tab header |
| `Circles/Feed/MomentFullScreenView.swift` | 2a, 2b | NEW — unified full-screen view |
| `Circles/Feed/OwnMomentFullView.swift` | 2a | DELETE — replaced by MomentFullScreenView |
| `Circles/Feed/CommentDrawerView.swift` | 2b | Keep for checkins, moments stop using it |
| `Circles/Feed/ReactionBar.swift` | — | No changes |
| `Circles/Feed/FeedViewModel.swift` | — | No changes |
| `Circles/Services/FeedService.swift` | — | No changes (D1 concurrent URLs deferred) |

---

## Design Token Reference (for the executing agent)

| Token | Value | Usage |
|-------|-------|-------|
| `msBackground` | `#1A2E1E` | Screen background, behind floating elements |
| `msCardShared` | `#243828` | NOT used for card surfaces anymore (cards are edge-to-edge photos) |
| `msGold` | `#D4A240` | PiP border, On Time pill, dividers, accents |
| `msTextPrimary` | `#F0EAD6` | Username, caption text |
| `msTextMuted` | `#8FAF94` | Subtitle text, inactive tabs, comment button |
| `msBorder` | `#D4A240` @ 18% | Subtle borders (not used on photo cards anymore) |
| Card corner radius | 16pt | Photo card corners |
| PiP corner radius | 12pt | PiP inset corners |
| PiP border | `msGold`, 2pt | Gold stroke around PiP |
| Avatar size (feed) | 36pt | Identity row avatar |
| Divider | `msGold.opacity(0.15)` | Between posts |
