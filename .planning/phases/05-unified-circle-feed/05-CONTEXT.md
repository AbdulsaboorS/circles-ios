# Phase 5: Unified Circle Feed — Context

**Gathered:** 2026-03-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Single scroll view showing all activity in a circle. Users can scroll through Circle Moments (photo + caption + on-time star), habit check-ins, and streak milestones. Each item is reactable with 6 reactions. Feed is reverse-chronological, paginated with infinite scroll. Today's Moment posts respect the reciprocity gate from Phase 4. This phase does NOT add comments.

Requirements: [PHASE5-FEED-ITEMS, PHASE5-REACTIONS, PHASE5-PAGINATION, PHASE5-RECIPROCITY-LOCK, PHASE5-OPTIMISTIC-REACTIONS]

</domain>

<decisions>
## Implementation Decisions

### Feed Location
- **D-01:** Feed lives inside `CircleDetailView` — scroll past members section into activity feed. No new tab added.
- **D-02:** Tab bar stays at 3 tabs (Home / Community / Profile) — unchanged from Phases 1-4.

### Members Section Redesign
- **D-03:** Members section collapses to a compact summary row (e.g., "5 members — 3 checked in today →"). Feed becomes the dominant content.
- **D-04:** Tapping the summary row navigates to a dedicated full member list (sheet or pushed view — Claude's discretion).

### Feed Item Card Design (3 distinct types)
- **D-05:** Item types are visually distinct — not a uniform card shell.
- **D-06:** **Moment card** — full-width photo (rear+front composited as in Phase 4), header row with name + ⭐ (if on-time) + timestamp, optional caption below photo, reaction bar at bottom.
- **D-07:** **Habit check-in row** — compact: "[Name] checked in [Habit name]" + timestamp + reaction bar. No avatar, no habit icon/color.
- **D-08:** **Streak milestone card** — highlight card: "[Name] hit a [N]-day streak on [Habit]!" + 🔥 icon + timestamp + reaction bar. Visually elevated vs check-in rows (e.g., slightly taller, amber accent).
- **D-09:** Names only throughout — no user avatars anywhere in the feed.

### Reaction Interaction
- **D-10:** All 6 reactions (❤️ 🤲 💪 🌟 🫶 ✨) are always visible in a horizontal row below each item — no long-press picker.
- **D-11:** Tap to toggle your reaction on/off. Only one reaction per user per item.
- **D-12:** Selected reaction highlights with amber (`#E8834B`) background pill. Count shown next to each emoji.
- **D-13:** All 3 item types get reactions — Moments, habit check-ins, and streak milestones.
- **D-14:** Reaction updates are optimistic — UI updates immediately, Supabase write happens in background.

### Pagination
- **D-15:** Infinite scroll — auto-load next page when user reaches ~last 3 items in the list.
- **D-16:** Loading indicator (`ProgressView`) shown at bottom of list while fetching next page.
- **D-17:** Page size: 20 items per load (initial and subsequent pages).
- **D-18:** Feed is reverse-chronological (newest first).

### Reciprocity Lock in Feed
- **D-19:** Moment cards that are locked (user hasn't posted today) show the same blur + 🔒 + "Post to see theirs" CTA pattern defined in Phase 4.
- **D-20:** Habit check-in rows and streak milestones are never locked — only Moment photo cards trigger the gate.

### Claude's Discretion
- Pull-to-refresh behavior (whether to reset to page 1 or prepend new items)
- Empty feed state copy and illustration
- Error state handling for failed page loads
- Exact spacing, typography scale, and corner radii for each card type
- Whether to use `List` or `LazyVStack` inside `ScrollView` for the feed

</decisions>

<specifics>
## Specific Ideas

- The reaction bar visual: `[❤️ 3] [🤲 1] [💪 2] [🌟 0] [🫶 1] [✨ 0]` — each emoji+count in its own tappable chip. Selected chip gets amber background.
- Members summary row modeled after "5 members — 3 checked in today →" pattern — compact single line above the feed.
- Streak milestones should feel celebratory — the 🔥 icon and amber accent should make them pop relative to routine check-in rows.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 5 Requirements
- `.planning/ROADMAP.md` §Phase 5 — Official requirements list (PHASE5-FEED-ITEMS through PHASE5-OPTIMISTIC-REACTIONS)

### Phase 4 Decisions (reciprocity gate, Moment model, camera)
- `.planning/phases/04-circle-moment-camera-post-reciprocity-gate/04-CONTEXT.md` — Reciprocity gate design (blur + lock + CTA), CircleMoment model fields, Supabase Storage bucket (`circle-moments`), on-time ⭐ indicator logic

### Database Schema
- `CLAUDE.md` §Database — Existing tables: `activity_feed`, `habit_reactions`, `circle_moments` (Phase 4 addition), `habits`, `habit_logs`, `streaks`, `halaqas`, `halaqa_members`

### Existing Code Patterns
- `Circles/Circles/CirclesViewModel.swift` — `@Observable @MainActor` pattern for service-backed view models
- `Circles/Circles/Services/CircleService.swift` — Service singleton pattern
- `Circles/Circles/Circles/CircleDetailView.swift` — Current CircleDetailView structure being extended

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CircleDetailView` (`Circles/Circles/Circles/CircleDetailView.swift`): Currently a `List` with sections (info, invite, members). Phase 5 restructures this — members collapses to summary, feed sections appended. May need to migrate from `List` to `ScrollView + LazyVStack` for feed performance.
- `CircleService.shared` (`Circles/Circles/Services/CircleService.swift`): Extend with `fetchFeedItems(circleId:page:pageSize:)` and reaction CRUD methods.
- `Color(hex:)` extension (`Circles/Circles/Extensions/Color+Hex.swift`): Use `#E8834B` for amber reaction highlight pills.

### Established Patterns
- `@Observable @MainActor` view models (not `ObservableObject`) — all new view models must follow this pattern.
- Service singletons accessed via `.shared` — new `FeedService` or extension to `CircleService` follows same pattern.
- Optimistic UI already used in HomeViewModel habit toggles — same pattern applies to reaction toggling.
- No `UIKit` — all feed UI in pure SwiftUI.

### Integration Points
- `CircleDetailView` is the entry point — the members-to-feed restructure happens here.
- `activity_feed` and `habit_reactions` Supabase tables are the data sources — need Codable models if not already defined.
- `circle_moments` table (Phase 4) provides photo URL + on-time flag for Moment cards.
- Reciprocity lock state comes from Phase 4's `MomentService` — feed must query whether current user has posted today's Moment.

</code_context>

<deferred>
## Deferred Ideas

- **Comments on Moments** — explicitly v1.1 post-launch (in ROADMAP.md v1.1 section).
- **Cross-circle aggregate feed tab** — a 4th tab showing activity from all joined circles combined. Not needed for Phase 5; kept at 3 tabs.
- **Notification badge on feed** — show unread count on Community tab. Belongs in Phase 6 (Push Notifications).

</deferred>

---

*Phase: 05-unified-circle-feed*
*Context gathered: 2026-03-24*
