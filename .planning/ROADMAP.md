# Circles v2.4 — Roadmap

**Updated:** 2026-04-16
**Direction:** Private Islamic BeReal. 18-phase execution plan + 2 new feature phases.

---

## Phase 1 — Schema + Model Foundations ✓ Complete
- `habits`: add `is_accountable`, `circle_id`
- `circles`: add `gender_setting`, `group_streak_days`, `core_habits`
- `profiles`: add `avatar_url`
- New tables: `comments`, `habit_plans`, `daily_moments`
- Update all Swift Codable models to match

---

## Phase 2 — Navigation Restructure + Home Cleanup ✓ Complete
- App entry point → Circles tab (Global Feed)
- Home tab → Daily Intentions only, zero social feed
- Tab order/labels updated

---

## Phase 3 — Profile Photos ✓ Complete
- PHPicker → Supabase Storage `avatars` bucket → `profiles.avatar_url`
- Avatar display: ProfileView, CircleDetailView member board
- Reaction face piles (replace emoji-only display)

---

## Phase 4 — Dual-Track Habits ✓ Complete
- `is_accountable` flag + `circle_id` on habits
- Home tab: shows both Accountable and Personal habits, labeled correctly
- Feed: only broadcasts Accountable habit completions

---

## Phase 5 — Circle Core Habits + Gender Locking ✓ Complete
- Core habits stored on `circles.core_habits` (JSON array)
- Gender setting enforced at join time
- Amir settings panel in CircleDetailView

---

## Phase 6 — Amir Onboarding Overhaul ✓ Complete
- New flow: Circle Identity → Core Habits → Location → Soul Gate
- Soul Gate: hard lock — native share sheet must be triggered before completion
- Background 28-day plan jobs when onboarding completes

---

## Phase 7 — Member/Joiner Flow + Rich Circle Preview ✓ Complete
- Unauthenticated circle preview
- New join flow: Habit Alignment → Location → lands on Global Feed
- Gender-lock confirmation screen

---

## Phase 8 — Prayer of the Day + Reciprocity Gate v2 ✓ Complete
- `daily_moments` table: server-side cron picks one prayer + random window time globally per day
- Gate activates when window opens; 30-min window
- "Unlock your circles" blur + CTA on both Global Feed and Circle feeds
- **Updated (Session 19):** Window time is now random UTC time (BeReal-style), not anchored to prayer time. Aladhan API is fallback only.

---

## Phase 9 — Comment Drawer ✓ Complete
- `comments` table + RLS (circle-members only)
- Slide-up drawer on tap of any feed item
- Keyboard avoidance, pagination

---

## Phase 10 — Group Streak + Face Piles ✓ Complete
- Group streak: UTC calendar day; DB trigger when all members post
- Face pile on reactions
- Amir settings in CircleDetailView

---

## Phase 11 — AI Roadmap v2 ✓ Complete
- `habit_plans` + RPC `apply_habit_plan_refinement`
- `HabitDetailView`: Generate button, calendar-aligned milestones, Refine sheet
- Gemini 3 Flash preview; 3 refinements per UTC ISO week

---

## Phase 11.1 — Full UI Vision Pass ✓ Complete
- Full Midnight Sanctuary redesign of every screen

---

## Phase 11.2 — E2E QA + Bug Fixes ✓ Complete
- Camera, feed, invite preview, roadmap loading fixes

---

## Phase 11.5 — Feed Polish ✓ Complete
- Dedup, filter tabs, 30-min countdown, today-only, sequential Double Take capture, Moment pipeline restoration

---

## Wave 5.1 — Aligned Presence (Niyyah + Noor Aura) ✓ Complete
- Post-capture Niyyah ritual with dissolve animation
- Noor Aura gold breathing glow on feed cards with niyyah
- Islamic geometric pattern background component
- `SpiritualLedgerView` (paging journal — to be superseded by Journey tab)
- `moment_niyyahs` table + owner-only RLS
- `circle_moments.has_niyyah` boolean
- 32pt corners on all moment photos
- Moment state machine + Force Window bug fixes (Session 19)
- BeReal-style random daily notification timing (Session 19)

---

## Phase 12 — Codebase Cleanup ✓ Complete
- 12 dead files deleted, DesignTokens consolidated, ThemeManager simplified

---

## Phase 13 — Full UI/UX Pass 🔄 Final Pass / Final Touches

Phase 13 is now substantially built. The remaining work is no longer broad construction; it is the final redesign/polish/QA pass across the remaining surfaces.

| Wave | Screen | Status |
|------|--------|--------|
| 1 | Home | ✓ Complete |
| 2 | Habit Detail | ✓ Complete |
| 3 | Community / Feed | 🔄 Built, final latency/polish pass remaining |
| 4 | Feed Cards | 🔄 Built, final pass remaining |
| 5 | My Circles + Circle Detail | 🔄 Built, final polish/testing remaining |
| 6 | Profile | 🔄 Active via settings/profile redesign |
| 7 | Auth | ⬜ Deferred unless final pass exposes gaps |

---

## Phase 13A — Journey Tab ✓ Built, In QA / Polish
**Scope:** New 4th tab — private spiritual calendar archive. The elevated, permanent home for the user's daily intentions across time.

**Vision:** Calendar month grid where each day shows the user's niyyah + moment state. Niyyah text is the hero, not the photo. Replaces `SpiritualLedgerView`.

**Tab name:** Journey | **Icon:** `calendar` SF symbol | **Position:** Between Community and Profile (index 2)

### Layer 1 — Calendar Grid
- Month header in serif + prev/next chevrons + swipe gesture
- 7-column grid, each day = rounded square
- Gold + Noor Aura glow = has niyyah
- Neutral dim = has moment, no niyyah
- Empty = nothing that day
- Today subtly highlighted

### Layer 2 — Day Detail (sheet on tap)
- Large serif niyyah text, quoted, centered — hero
- Date above (small, muted)
- Moment photo thumbnail below with Noor Aura if niyyah present
- No niyyah: photo only. No moment: niyyah + moon placeholder.

### Status Update
- Core Journey build is shipped
- Follow-up QA fixes are implemented
- Persistent metadata cache is implemented
- Remaining work is runtime validation and final latency feel

### Files to Create
- `Circles/Journey/JourneyView.swift`
- `Circles/Journey/JourneyViewModel.swift`
- `Circles/Journey/JourneyDayDetailView.swift`
- `Circles/Journey/JourneyCalendarGrid.swift`
- `Circles/Models/JourneyDay.swift`

### Files to Modify
- `Circles/Navigation/MainTabView.swift` — add tab at index 2
- `Circles/Profile/ProfileView.swift` — remove ledger button, niyyahCount, showSpiritualLedger

### Files to Delete
- `Circles/Profile/SpiritualLedgerView.swift`

### Data Model
```swift
struct JourneyDay {
    let date: Date
    let niyyah: MomentNiyyah?
    let hasPostedMoment: Bool
    // photo URL resolved on-demand when detail opens
}
```

### Fetching Strategy
- Fetch all `moment_niyyahs` for user at once (≤365/year)
- Fetch `circle_moments` for displayed month only (no photo URLs until detail tap)
- Cache months in VM — navigation is instant after first load
- Deduplicate `circle_moments` by date (same photo posted to N circles = N rows, take first)
- Use UTC date math consistently (`photo_date` DATE vs `posted_at` TIMESTAMPTZ)

---

## Phase 13B — Profile / Settings Redesign 🔄 Active Final-Touches Work
**Scope:** Full 10/10 redesign of the Profile tab.

Key gaps in current profile:
- Flat hierarchy — avatar, stats, and buttons feel like equal-weight list items
- Stats card is generic, not spiritually resonant
- No moment history surface
- No real visual identity / presence for the user

Design direction:
- Hero avatar treatment with presence
- Islamic motifs woven into identity (Noor Aura on avatar?)
- Stats as spiritual snapshot, not dashboard
- Moment archive entry point (Journey tab handles the full view)
- Settings de-emphasized

Latest direction locked with user:
- Settings should move toward a BeReal-style structure, translated into Circles branding
- Top account/profile card becomes the main entry point for editing profile details
- Profile editing should include name, username, bio, location, and profile photo where supported
- The settings list should follow the BeReal-style information architecture, minus Audio
- A joined-date footer should sit beneath Log Out
- Dev tools remain beneath Log Out for now

---

## Phase 14 — Naming + Branding ⬜ Planned
- Finalize feature names: "Circles", "Moments", "Niyyah", "Journey"
- Logo finalized — update app icon asset in Xcode
- App display name, bundle name confirmed

---

## Phase 15 — Notifications ⬜ Planned
- Verify and deploy all Edge Functions end-to-end on real device
- Copy/tone audit — warm Islamic voice
- `send-moment-window-notifications` now deployed and live (cron active)
- Handle notification permission modal UX

---

## Phase 16 — Onboarding Videos + Animation Polish ⬜ Planned
- Replace placeholder video containers with real assets
- Animation timing polish on transitions
- Blocked on content creation

---

## Phase 17 — Web Landing Page ⬜ Planned
- App Store download CTA as primary action
- Midnight Sanctuary color palette
- No framework dependency — plain HTML/Tailwind/vanilla JS

---

## Phase 18 — App Store Submission ⬜ Planned
- App Store metadata, screenshots, privacy manifest
- TestFlight internal beta + human QA
- Submit for review

---

*Phase 13 is now in final-pass mode. Immediate next major UX build: Profile / Settings redesign, followed by final runtime QA and polish.*
