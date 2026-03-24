---
phase: 05-unified-circle-feed
plan: 02
subsystem: Feed UI Layer
tags: [feed, swiftui, reactions, reciprocity-gate, pagination, infinite-scroll]
dependency_graph:
  requires: [05-01]
  provides: [FeedViewModel, FeedView, MomentFeedCard, HabitCheckinRow, StreakMilestoneCard, ReactionBar]
  affects: [CircleDetailView]
tech_stack:
  added: []
  patterns: [LazyVStack-infinite-scroll, optimistic-reaction-toggle, @Bindable-viewmodel, ScrollView-refreshable]
key_files:
  created:
    - Circles/Circles/Feed/FeedViewModel.swift
    - Circles/Circles/Feed/FeedView.swift
    - Circles/Circles/Feed/MomentFeedCard.swift
    - Circles/Circles/Feed/HabitCheckinRow.swift
    - Circles/Circles/Feed/StreakMilestoneCard.swift
    - Circles/Circles/Feed/ReactionBar.swift
  modified:
    - Circles/Circles/Circles/CircleDetailView.swift
decisions:
  - FeedViewModel holds @Bindable reactions dict keyed by item UUID — passed into all card views via @Bindable
  - MomentFeedCard.isLocked logic: !hasPostedToday && item.userId != currentUserId (own posts always visible)
  - CircleDetailView removes all separate moment/member state — FeedViewModel is the single source of truth
  - checkedInCount hardcoded to 0 for Phase 5; activity_feed-based count deferred to future phase
metrics:
  duration: "3 minutes"
  completed_date: "2026-03-24"
  tasks_completed: 3
  files_changed: 7
---

# Phase 5 Plan 02: Feed UI Layer Summary

**One-liner:** SwiftUI feed UI with @Bindable FeedViewModel, 3 card types, 6-emoji ReactionBar, reciprocity blur gate, infinite scroll, and CircleDetailView restructured around ScrollView + FeedView.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | FeedViewModel with pagination, reaction state, hasPostedToday | 7019999 | FeedViewModel.swift (139 lines) |
| 2 | Feed item card views and ReactionBar | 1628686 | FeedView.swift (71), MomentFeedCard.swift (91), HabitCheckinRow.swift (45), StreakMilestoneCard.swift (52), ReactionBar.swift (44) |
| 3 | Restructure CircleDetailView | 02a2a66 | CircleDetailView.swift (305 lines, -171/+144) |
| 4 | Checkpoint: human-verify | — | Awaiting Simulator verification |

## What Was Built

### FeedViewModel (139 lines)
- `@Observable @MainActor` singleton-per-view pattern
- `loadInitial`: parallel fetch of first feed page + today's moments for reciprocity gate determination
- `loadNextPage`: appends new page to `items`, loads reactions for new batch
- `refresh`: resets state and reloads from page 0
- `toggleReaction`: optimistic update mirroring `HomeViewModel.toggleHabit` — add/replace/remove semantics
- `reactionCount` and `userHasReacted` helpers used by ReactionBar

### Feed Card Views
- **ReactionBar**: 6 emoji chips (`FeedReaction.validEmojis`), amber `#E8834B` background when selected, counts shown inline, `@Bindable` binding to FeedViewModel
- **MomentFeedCard**: full-width 280pt photo with `.blur(radius: 20)` + lock overlay when `isLocked`; `isLocked = !hasPostedToday && item.userId != currentUserId`; on-time star badge
- **HabitCheckinRow**: compact `"[Name] checked in [Habit]"` text + relative timestamp + ReactionBar
- **StreakMilestoneCard**: amber-accented card (`opacity(0.12)` fill + `opacity(0.3)` border) with 🔥 and streak count
- **FeedView**: `LazyVStack` inside ScrollView with `onAppear` trigger at `index >= items.count - 3`; bottom `ProgressView` during next-page load; empty state text

### CircleDetailView Restructure
- Replaced `List { Section... }` layout with `ScrollView { LazyVStack }`
- Members section: single summary row `"[N] members · [M] checked in today →"` — taps open `MembersListView` sheet (private struct at file bottom)
- `Activity` label followed by embedded `FeedView`
- `.refreshable` resets FeedViewModel to page 0
- `.task` loads members and feed in parallel using `async let`
- Moment post callback now calls `feedViewModel.refresh(...)` instead of separate moments array refresh
- Window timer and camera/preview fullScreenCover preserved unchanged
- `import Supabase` present (required for `auth.session?.user.id`)

## Deviations from Plan

None — plan executed exactly as written.

## Build Result

BUILD SUCCEEDED — zero errors, one appintentsmetadataprocessor warning (pre-existing, unrelated to this plan).

## Checkpoint: Human Verify

**Status:** Awaiting verification in Simulator.

**Verification steps:**
1. Build and run in Simulator (iPhone 17 Pro, iOS 26.3)
2. Sign in → Community tab → open a circle
3. Verify members summary row shows "[N] members · [M] checked in today →"
4. Tap members row → MembersListView sheet opens → dismiss
5. Scroll down → "Activity" label → FeedView (empty state or items)
6. Confirm "No activity yet" empty state if no feed data
7. If habit check-in rows exist: "[Name] checked in [Habit]" + 6 emoji chips
8. If Moment cards exist: photo or blur+lock if not posted today
9. Tap emoji chip → count increments optimistically, amber highlight appears
10. Tap same emoji → count decrements, highlight removed
11. Pull down → ProgressView → feed reloads

## Known Stubs

- `checkedInCount` is hardcoded to `0` in CircleDetailView. The members summary row shows "0 checked in today" for all circles. This stub is intentional for Phase 5 — actual per-member check-in counts require a separate query against `activity_feed` that is deferred to a future phase. The stub does not block the plan's goal (unified feed) — it only affects the secondary counter in the member summary row.

## Self-Check: PASSED

Files confirmed created:
- Circles/Circles/Feed/FeedViewModel.swift: exists
- Circles/Circles/Feed/FeedView.swift: exists
- Circles/Circles/Feed/MomentFeedCard.swift: exists
- Circles/Circles/Feed/HabitCheckinRow.swift: exists
- Circles/Circles/Feed/StreakMilestoneCard.swift: exists
- Circles/Circles/Feed/ReactionBar.swift: exists
- Circles/Circles/Circles/CircleDetailView.swift: modified

Commits confirmed:
- 7019999: FeedViewModel
- 1628686: feed card views
- 02a2a66: CircleDetailView restructure
