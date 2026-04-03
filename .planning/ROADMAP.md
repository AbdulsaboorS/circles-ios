# Circles v2.3 — Roadmap

**Updated:** 2026-04-02
**Direction:** Private Islamic BeReal. 14-phase execution plan.

---

## Phase 1 — Schema + Model Foundations ✓ Complete
**Scope:** All DB migrations + Swift model updates. No UI changes.
- `habits`: add `is_accountable`, `circle_id`
- `circles`: add `gender_setting`, `group_streak_days`, `core_habits`
- `profiles`: add `avatar_url`
- New tables: `comments`, `habit_plans`, `daily_moments`
- Update all Swift Codable models to match

---

## Phase 2 — Navigation Restructure + Home Cleanup ✓ Complete
**Scope:** Establish correct product feel from launch.
- App entry point → Circles tab (Global Feed)
- Home tab → Daily Intentions only, zero social feed
- Tab order/labels updated

---

## Phase 3 — Profile Photos ✓ Complete
**Scope:** Foundation for face piles, member boards, social identity.
- PHPicker → Supabase Storage `avatars` bucket → `profiles.avatar_url`
- Avatar display: ProfileView, CircleDetailView member board
- Reaction face piles (replace emoji-only display)

---

## Phase 4 — Dual-Track Habits ✓ Complete
**Scope:** Core habit architecture separation.
- `is_accountable` flag + `circle_id` on habits
- Home tab: shows both Accountable and Personal habits, labeled correctly
- Feed: only broadcasts Accountable habit completions
- Habit creation/editing: choose type + which circle (if accountable)

---

## Phase 5 — Circle Core Habits + Gender Locking ✓ Complete
**Scope:** Circle identity and membership integrity.
- Core habits stored on `circles.core_habits` (JSON array)
- Gender setting enforced at join time (confirmation + block)
- Amir settings panel in CircleDetailView: edit core habits, gender setting, member management

---

## Phase 6 — Amir Onboarding Overhaul ✓ Complete
**Scope:** Full replacement of current onboarding for circle creators.
- New flow: Circle Identity → Core Habits → Location → Soul Gate
- Soul Gate: hard lock — native share sheet must be triggered before completion
- Background 28-day plan jobs when onboarding completes (`HabitPlanService.ensureAIRoadmapForOnboarding` per habit created in session)
- Landing: Home tab (Daily Intentions)

---

## Phase 7 — Member/Joiner Flow + Rich Circle Preview ✓ Complete
**Scope:** Invite-driven onboarding for joiners.
- Unauthenticated circle preview (name, member count, group streak only)
- New join flow: Habit Alignment → Location → lands on Global Feed
- RLS policy: allow anon reads for preview fields only
- Gender-lock confirmation screen

---

## Phase 8 — Prayer of the Day + Reciprocity Gate v2 ✓ Complete
**Scope:** The core Circle Moment mechanic, properly implemented.
- `daily_moments` table: server-side cron picks one prayer globally per day
- Aladhan API: local prayer time calculation per user location
- Gate activates when window OPENS (not when it closes)
- "Unlock your circles" blur + CTA on both Global Feed and Circle feeds
- "Posted late" tag (Mercy-First logic)

---

## Phase 9 — Comment Drawer ✓ Complete
**Scope:** Primary site of private social interaction.
- `comments` table + RLS (circle-members only)
- Slide-up drawer on tap of any feed item
- Keyboard avoidance, pagination
- Comment push notifications (new Edge Function)

---

## Phase 10 — Group Streak + Face Piles ✓ Complete
**Scope:** Social layer polish.
- Group streak: UTC calendar day; DB trigger when all members post (SQL run in Supabase; not stored in repo)
- Refetch circle + My Circles after posting a Moment so flame updates
- Face pile on reactions (`FeedViewModel` + `ReactionBar`)
- Amir settings in CircleDetailView: core habits, gender, remove members; member list polish

---

## Phase 11 — AI Roadmap v2 ✓ Complete
**Scope:** 28-day habit roadmap, fully implemented.
- `habit_plans` + RPC `apply_habit_plan_refinement` (see `phases/11-ai-roadmap/migration.sql`)
- `HabitDetailView`: Generate button, calendar-aligned milestones with Today, Refine sheet
- Gemini 3 Flash preview `generate28DayRoadmap`; 3 refinements per UTC ISO week; PRD token-limit copy

---

## Phase 11.1 — Full UI Vision Pass ✓ Complete
**Scope:** Full vision redesign of every screen. Scrappy, iterative — designed live with Stitch MCP.
- Auth / onboarding flows (Amir + Member)
- Home (Daily Intentions, HabitDetailView, AI roadmap)
- Community / Feed (Global + Circle feeds, Reciprocity Gate)
- Circles (MyCirclesView, CircleDetailView, Create/Join)
- Moment (Camera, Preview, feed cards)
- Profile
- Design system tokens (colors, typography, spacing) updated to match new vision
- Navigation feel + transitions

---

## Phase 11.2 — End-to-End QA + Bug Fixes ✓ Complete
**Scope:** Full E2E test of every user flow; fix everything found + known open issues.
- Known open issues from STATE.md:
  - **A. Gemini -1011** — surface HTTP status + body; verify API key + model id
  - **C. Habit detail icon** — `Image(systemName:)` + fallback; fix `Color.textSecondary` contrast
- E2E flows to test: Amir onboarding → circle creation → invite → Member join → moment post → feed → reactions → comments → streak → AI roadmap → refine → profile
- Document all new bugs found; fix before App Store submission
- Closed in this phase:
  - Reflection Log on `HabitDetailView`
  - invite preview refresh + test-account login
  - roadmap generate/refine loading progress treatment
  - first-shot white-screen and stale-preview fixes in Moment camera flow
  - feed card consolidation (`PFP - NAME > CIRCLE`, `checking into 'habit'`)
  - feed/onboarding avatar consistency pass
  - invite preview face pile / PFP treatment
- Deferred forward:
  - re-test Moment posting only during a real prayer window
  - Moment compositing/output polish after real posting is verified

---

## Phase 11.3 — Onboarding In Depth 🔄 Next
**Scope:** Finalize onboarding flows with refined UX, animations, deep links, and data persistence.
- **Flow 1: Build My Circle (Amir Journey)**
  - Landing Sanctuary: looping video + emotive copy + Build/Join CTAs
  - The Struggle: core habit selection (max 3)
  - Circle Identity: circle name + gender setting (Mixed note)
  - Personal Intentions: secret habits (max 2, private)
  - AI Planning: animated 28-day generation with progress bar
  - Foundation: name + location for prayer time sync
  - Activation: auth gate with progress preview
- **Flow 2: Member Landing Page (Joiner Journey)**
  - High-energy video demos (top 80%)
  - Join CTA + auto-filled deep link (bottom 20%)
  - Rich Circle Preview: circle name, group streak, member faces
  - Circle Alignment: pick core habits (min 1 required)
  - Personal Habits: select private goals
  - AI Generation: sync roadmap animation
  - Identity: name + location
  - Auth Gate: save progress + preview
- **Critical Implementation Details:**
  - Push notification framing: "Enable the Adhan for your circle" (Step E)
  - Deep link logic: prefill Joiner landing and auto-submit into circle preview if deep link detected
  - Data persistence: cache pending state before auth so user can resume
  - Animation timing: 1.5-2 second transitions (skippable) unless AI gen needs time
  - Deep link fail case: fallback "Enter Invite Code" button on landing
  - UI clarity: Midnight Green for shared steps, lock icon for private habits
  - Preview value: show Evolving Heart or roadmap on auth screen to motivate save

**Plans:** 6 plans

Plans:
- [x] 11.3-01-PLAN.md — Shared infrastructure: OnboardingPendingState, OnboardingTransitionView, deep link verification
- [x] 11.3-02-PLAN.md — New Amir step views: Landing Sanctuary, AI Generation, Activation/Auth Gate
- [ ] 11.3-03-PLAN.md — Amir coordinator rewrite: 7-step auth-last state machine + FlowView wiring
- [x] 11.3-04-PLAN.md — New Joiner step views: Landing, Circle Alignment, Personal Habits, AI Gen, Identity, Auth Gate
- [ ] 11.3-05-PLAN.md — Joiner coordinator rewrite: 7-step auth-last state machine + FlowView wiring
- [ ] 11.3-06-PLAN.md — ContentView auth-last routing + HomeView post-auth nudge (Soul Gate replacement)

---

## Phase 12 — Muslim-Native UX Polish + App Store ⬜ Planned
**Scope:** Final pass before submission.
- Full copy audit across every screen
- Mercy-First language verification
- Notification tone review
- App Store metadata, screenshots, privacy manifest
- TestFlight beta, human verification, submission

---

## Phase 13 — Landing Page Web ⬜ Planned
**Scope:** Marketing landing page for web (HTML/Tailwind).
- Design system: Community/Forum pattern + Micro-interactions style
- Colors: Purple #7C3AED (primary), Light Purple #A78BFA, Green #22C55E (CTA)
- Typography: Lora (headings, calm) + Raleway (body, clean)
- Sections: Hero + Popular Topics + Active Members + Join CTA
- Responsive: 375px–1440px
- Pre-delivery: no emojis, cursor-pointer, contrast 4.5:1, haptic feedback indication

---

*Phases are executed in order. Early phases (1–2) have `SPEC.md` in-repo; later phases may ship SQL/README only.*
*Phases 1-2 implemented together. Phases 3-4 implemented together. Phase 5+ one at a time.*
