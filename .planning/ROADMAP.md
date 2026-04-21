# Circles v2.4 — Roadmap

**Updated:** 2026-04-20
**Direction:** Private Islamic BeReal. Phases 1–13 built. The Personalization Era (14–15) inserts between the completed UI/UX pass and the Shipping Era (16–19).

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

# Personalization Era

The next two phases make existing surfaces feel personal and rewarding, without introducing new product concepts. Decided 2026-04-20 after user + investor critique of a larger "Personalization Era" proposal. Arcs, end_dates, per-user streak seeding, photo evidence on check-ins, and a past-intentions archive are **parked** until real TestFlight usage data informs them.

---

## Phase 14 — Meaningful Habits ⬜ Planned

**Goal:** Make habit creation emotionally anchored, narrow the generic catalog, make check-off feel like a small dua, and make the streak feel alive.

**Scope:**
1. **Niyyah prompt on habit creation.** Single text field ("What's your niyyah for this?") asked when creating any habit — personal or shared. Shows on Habit Detail as the emotional header. Fed into AI plan generation. Works as the struggle lens for shared habits too — no separate field.
2. **Catalog expansion.** Grow from the current 10 items to ~30 items across 5 categories: Worship, Character, Knowledge, Health, Service. Revisit salah-as-habit framing — likely collapse to "Pray 5 daily" or lift to a separate consistency tracker (SPEC-level decision).
3. **Onboarding quiz — 2 screens.**
   - Screen 1 — Islamic struggles (multi-select): consistent prayer, Quran connection, dhikr, guarding tongue, lowering gaze, waking for Fajr, voluntary fasting, seeking knowledge
   - Screen 2 — Life struggles (multi-select): discipline, sleep, physical health, family ties, restlessness/anxiety, time management, phone & media, patience
   - Simple branching rules map the combination to **max 3 suggested habits** from the expanded catalog
   - Skippable. Redoable anytime from Profile → Settings → "My Focus Areas"
   - Answers stored on `profiles` as JSONB arrays (`struggles_islamic`, `struggles_life`) — private, never visible to circle members
   - Wired into Amir onboarding (after Step 2 Core Habits), Joiner onboarding (after Habit Alignment), and in-app new-intention creation
4. **Check-off ritual upgrade.** Hold-to-complete → Niyyah-style gold-dust animation → brief "Alhamdulillah" micro-moment. Reuses NiyyahDissolve / NoorAura / IslamicGeometricPattern components.
5. **Single master geometric pattern streak visual.** Always-on from day 1. Intensity scales continuously with streak length. Starts from the existing 8-pointed IslamicGeometricPattern vocabulary and grows in layered complexity. **One master pattern for all users** — no per-user niyyah seeding in v1. Retires the static star. In-flight streak glow work pauses and folds into this.

**Schema deltas:**
- `habits` gains nullable `niyyah TEXT`
- `profiles` gains nullable `struggles_islamic JSONB`, `struggles_life JSONB`

**Out of scope (parked):** arcs, end_dates, past-intentions archive, photo evidence on check-ins, per-user streak seeding, quiz v2 AI synthesis.

**Timeline:** ~2.5–3 weeks.

---

## Phase 15 — Social Pulse ⬜ Planned

**Goal:** Give circles real-time social tug. Absorbs and completes the old "Notifications" phase.

**Scope:**
- **Nudge push notifications** (PRD requirement, not yet built) — tap nudge icon on a member who hasn't posted → friendly push ("Humza is waiting for your moment")
- **Comment push notifications** (PRD requirement, not yet built)
- **Permission modal UX** — warm Islamic framing, retry-friendly
- **Real-device end-to-end verification** of all edge functions (`send-moment-window-notifications`, nudges, comments)
- **Copy/tone audit** — warm Islamic voice across every notification string

**Note:** `send-moment-window-notifications` is already deployed and live via cron (Session 19). This phase adds the **social-interactive** push layer on top.

**Existing worktree:** `phase-15-social-pulse` holds the in-progress notifications scaffolding and maps to this phase. See HANDOFF.md.

**Timeline:** ~1–1.5 weeks.

---

## Shipping Era

---

## Phase 16 — Naming + Branding Finalization ⬜ Planned
- Finalize feature names: "Circles", "Moments", "Niyyah", "Journey"
- Logo finalized — update app icon asset in Xcode
- App display name, bundle name confirmed

*Small phase (1–2 days). Can run in parallel with earlier work if needed — design system is already locked from Phase 11.1 / 13.*

---

## Phase 17 — Onboarding Videos + Animation Polish ⬜ Planned
- Replace placeholder video containers with real assets
- Animation timing polish on transitions
- Blocked on content creation

---

## Phase 18 — Web Landing Page ⬜ Planned
- App Store download CTA as primary action
- Midnight Sanctuary color palette
- No framework dependency — plain HTML/Tailwind/vanilla JS

---

## Phase 19 — App Store Submission ⬜ Planned
- App Store metadata, screenshots, privacy manifest
- TestFlight internal beta + human QA
- Submit for review

---

## Parking Lot — Post-MVP

Validate with real TestFlight usage before investing in any of these:

- **Intention arcs** — goal + end_date + baseline/ending reflections; past-intentions archive; AI-extended roadmaps across arcs
- **Photo evidence on habit check-ins** — optional photo per check-in with its own timeline on Habit Detail; separate storage bucket
- **Streak personalization with niyyah seeding** — pattern variant per user based on their stated niyyah
- **Habit check-in photo → Circle Moment promotion** — let a habit evidence photo be the day's Moment
- **Quiz v2** — AI-generated suggestions beyond simple branching rules
- **Pattern-based nudges** — "You haven't done Quran for 3 days — want help?"

---

*Phase 13 complete. Personalization Era (14–15) scope locked 2026-04-20. Shipping Era resumes at Phase 16.*
