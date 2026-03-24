---
phase: 05-unified-circle-feed
plan: 01
subsystem: feed-data-layer
tags: [feed, models, service, supabase, pagination, reactions]
dependency_graph:
  requires: [04-03]
  provides: [FeedItem, FeedReaction, FeedService]
  affects: [05-02-feed-ui]
tech_stack:
  added: []
  patterns: [@Observable @MainActor singleton, private raw DB row types, display name fallback]
key_files:
  created:
    - Circles/Models/FeedItem.swift
    - Circles/Models/FeedReaction.swift
    - Circles/Services/FeedService.swift
  modified: []
decisions:
  - fetchFeedPage fetches all rows client-side then slices (max ~200/circle is manageable; avoids complex server-side UNION)
  - Display name fallback to UUID prefix when profiles table unavailable
  - toggleReaction uses explicit fetch+delete+insert (not upsert) for full add/replace/remove control
  - Private row structs scoped to FeedService file to avoid polluting Models namespace
metrics:
  duration: 162s
  completed: 2026-03-24
  tasks_completed: 3
  files_created: 3
---

# Phase 5 Plan 01: Feed Data Layer Summary

**One-liner:** FeedItem enum (3 typed cases) + FeedReaction Codable model + FeedService singleton with paginated merge-fetch and reaction toggle CRUD.

## Files Created

| File | Lines | Purpose |
|------|-------|---------|
| `Circles/Models/FeedItem.swift` | 58 | FeedItem enum + 3 associated value structs |
| `Circles/Models/FeedReaction.swift` | 24 | FeedReaction Codable model + validEmojis |
| `Circles/Services/FeedService.swift` | 237 | Paginated feed fetch + reaction CRUD |

## Public API Signatures

```swift
// FeedService.swift
@Observable @MainActor final class FeedService {
    static let shared: FeedService

    func fetchFeedPage(circleId: UUID, page: Int, pageSize: Int = 20) async throws -> [FeedItem]
    func fetchReactions(itemIds: [UUID]) async throws -> [FeedReaction]
    func toggleReaction(itemId: UUID, itemType: String, userId: UUID, emoji: String) async throws
}
```

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 — FeedItem enum | 23ae788 | feat(05-01): define FeedItem enum with 3 associated value types |
| 2 — FeedReaction model | ff4d37d | feat(05-01): define FeedReaction model mapping habit_reactions table |
| 3 — FeedService | 2db012e | feat(05-01): build FeedService with paginated fetch and reaction CRUD |

## Decisions Made

1. **Client-side merge for pagination:** `fetchFeedPage` fetches all activity_feed + circle_moments rows then merges, sorts, and slices. Max ~200 rows per circle is manageable without server-side UNION complexity.

2. **Display name fallback:** `fetchDisplayNames` gracefully falls back to `userId.prefix(8)` if profiles table is missing or throws — ensures service is resilient to backend state.

3. **toggleReaction uses fetch+delete+insert:** The explicit 3-step approach (check existing → delete old → insert new) gives full control over add/replace/remove semantics. More readable than a complex upsert with ON CONFLICT.

4. **Private row types scoped to FeedService:** `ActivityFeedRow`, `CircleMomentRow`, `ProfileRow` are all `private struct` inside FeedService.swift — they are decode-only helpers that should never escape to the UI layer. The UI only ever sees the `FeedItem` enum.

## Deviations from Plan

None — plan executed exactly as written.

## Build Result

**BUILD SUCCEEDED** — zero errors, zero warnings (xcodebuild -scheme Circles -destination 'iPhone 17' -configuration Debug)

## Self-Check: PASSED

- [x] `Circles/Models/FeedItem.swift` exists (58 lines)
- [x] `Circles/Models/FeedReaction.swift` exists (24 lines)
- [x] `Circles/Services/FeedService.swift` exists (237 lines)
- [x] Commit 23ae788 exists
- [x] Commit ff4d37d exists
- [x] Commit 2db012e exists
- [x] Build SUCCEEDED with zero errors
