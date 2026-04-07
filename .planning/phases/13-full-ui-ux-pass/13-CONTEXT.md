# Phase 13 — Full UI/UX Pass
# CONTEXT — Implementation Decisions

**Gathered:** 2026-04-05
**Status:** Ready for planning
**Source:** Conversation alignment session

---

<domain>
## Phase Boundary

Every screen in the app redesigned and confirmed at 10/10 quality — iterative back-and-forth between user and Claude per screen until satisfied. This is not a GSD plan+execute phase; it is an interactive refinement phase. Documentation is maintained for handoff continuity.

**What's in scope:**
- Home (Dashboard)
- Habit Detail
- Community / Feed views
- Feed cards (MomentFeedCard, HabitCheckinRow)
- My Circles + Circle Detail
- Profile
- Auth screen
- Full copy audit (inline, per screen)
- Simulator QA on iPhone 15 + iPhone 16 Pro (per screen, as each is finalized)

**What's out of scope:**
- Onboarding flows — excluded. Phase 11.3 handles the full rebuild. Real visual polish (video assets, animation) deferred to Phase 16.
- MomentFeedCard full-width redesign — already scoped and built in Phase 11.4. Phase 13 confirms/polishes that result only.
- Any new features or capabilities.

</domain>

<decisions>
## Implementation Decisions

### Execution Model — Interactive, Not GSD Execute
- This phase runs as iterative back-and-forth: user provides feedback per screen, Claude refines, repeat until 10/10.
- No GSD plan+execute cycle. No plan files required.
- One screen at a time — fully complete each screen before moving to the next.
- Documentation maintained here and in STATE.md for handoff continuity.

### Wave Order (Screen Priority)
Screens are worked in this fixed priority sequence:

| Wave | Screen | Files |
|------|--------|-------|
| 1 | Home (Dashboard) | `HomeView.swift`, `HomeViewModel.swift` |
| 2 | Habit Detail | `HabitDetailView.swift` |
| 3 | Community / Feed | `CommunityView.swift`, `FeedView.swift`, `ReciprocityGateView.swift` |
| 4 | Feed cards | `MomentFeedCard.swift`, `HabitCheckinRow.swift`, `StreakMilestoneCard.swift` |
| 5 | My Circles + Circle Detail | `MyCirclesView.swift`, `CircleDetailView.swift` |
| 6 | Profile | `ProfileView.swift` |
| 7 | Auth screen | `Auth/AuthView.swift` |

### Design Methodology — User-Driven Iteration
- No Stitch MCP. No pre-designed mockups.
- User provides verbal/written feedback on each screen. Claude refines the code directly.
- Process repeats per screen until user is satisfied (10/10).
- Claude may proactively suggest improvements but never advances to the next screen without user sign-off.

### Copy Audit — Inline, Per Screen
- No standalone copy document.
- Copy is reviewed and refined as part of each screen's iteration cycle.
- Standard: Mercy-First language, Islamic tone, no generic system alerts.
- Claude proposes copy inline; user approves or adjusts per screen.

### Design System — Phase 12 Must Run First
- Phase 12 (Codebase Cleanup) consolidates MS tokens and simplifies ThemeManager. Phase 13 assumes that cleanup is complete.
- All styling uses the consolidated `DesignTokens` extension (not per-file `private extension Color` copies).
- Dark mode enforced directly (ThemeManager simplified in Phase 12).

### Known Fixes to Close Per Screen
These are documented bugs that must be resolved as their respective wave runs:

- **Wave 2 (Habit Detail):**
  - Icon fix: `Text(habit.icon)` → `Image(systemName: habit.icon)` (SF Symbol names, not raw text)
  - Contrast fix: `Color.textSecondary` static token → adaptive `AppColors.resolve(colorScheme).textSecondary` on light cards

- **Wave 1 (Home):**
  - Drag-to-reorder confirmed working
  - Any residual layout issues from Phase 11.1 scrappy pass

### Simulator QA
- Each screen signed off on iPhone 15 Pro simulator AND iPhone 16 Pro simulator before moving to the next wave.
- No Xcode UI test automation required — manual visual confirmation per wave.

### Claude's Discretion
- Spacing and layout micro-decisions (padding values, corner radius choices)
- Animation duration and easing for interactive elements
- SF Symbol choices for icons not explicitly specified
- SwiftUI modifier ordering and view decomposition

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before working on any wave.**

### Design System
- `Circles/DesignSystem/DesignTokens.swift` — MS color + font tokens (post-Phase-12 consolidated version)
- `Circles/DesignSystem/ThemeManager.swift` — dark mode enforcement (simplified in Phase 12)
- `Circles/DesignSystem/AvatarView.swift` — reusable avatar component

### Wave 1 — Home
- `Circles/Home/HomeView.swift`
- `Circles/Home/HomeViewModel.swift`

### Wave 2 — Habit Detail
- `Circles/Home/HabitDetailView.swift`

### Wave 3 — Community / Feed
- `Circles/Community/CommunityView.swift`
- `Circles/Feed/FeedView.swift`
- `Circles/Feed/FeedViewModel.swift`
- `Circles/Feed/ReciprocityGateView.swift`

### Wave 4 — Feed Cards
- `Circles/Feed/MomentFeedCard.swift`
- `Circles/Feed/HabitCheckinRow.swift`
- `Circles/Feed/StreakMilestoneCard.swift`
- `Circles/Feed/FeedIdentityHeader.swift`
- `Circles/Feed/ReactionBar.swift`

### Wave 5 — Circles
- `Circles/Community/MyCirclesView.swift`
- `Circles/Circles/CircleDetailView.swift`

### Wave 6 — Profile
- `Circles/Profile/ProfileView.swift`

### Wave 7 — Auth
- `Circles/Auth/AuthView.swift`

### Planning Context
- `.planning/ROADMAP.md` — Phase 13 scope definition
- `.planning/STATE.md` — What's built, open issues
- `.planning/phases/11.4-circle-moment/11.4-CONTEXT.md` — MomentFeedCard decisions (Phase 11.4 owns the full-width redesign)

</canonical_refs>

<deferred>
## Deferred Ideas

- Onboarding visual polish — deferred to Phase 16 (blocked on real video assets)
- Universal Links (`joinlegacy.app/join/CODE`) — deferred to when web landing page ships (Phase 17)
- Memories / past moments in Profile tab — post-MVP
- Activity center / notification bell — post-Phase 13 (before App Store)

</deferred>

---

*Phase: 13-full-ui-ux-pass*
*Context gathered: 2026-04-05 via conversation alignment session*
