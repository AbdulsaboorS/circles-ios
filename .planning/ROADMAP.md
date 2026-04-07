# Circles v2.3 — Roadmap

**Updated:** 2026-04-07
**Direction:** Private Islamic BeReal. 18-phase execution plan.

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

## Phase 11.4 — Circle Moment (BeReal Mechanic) ⬜ Planned
**Scope:** Finalize the core Circle Moment feature end-to-end.
- Fix RLS bug blocking `circle_moments` insert (blocker)
- Prayer-time notification trigger: 30-min window, randomized across daily prayers
- Dual camera capture polish: shutter UX, front/back composited preview
- Preview screen: "Share to all circles" disclaimer, Post CTA
- Post flow: Storage upload + DB insert + error handling
- Feed card: dual image layout, late badge (🕰, not shaming), reactions
- Late posting: always allowed, encouraged, badge only
- No retake tracking, no hard window block

**Plans:** 4 plans

Plans:
- [ ] 11.4-01-PLAN.md — RLS SQL migration (circle_moments INSERT + storage bucket) + edge function rewrite (daily_moments as prayer source)
- [ ] 11.4-02-PLAN.md — MomentService multi-circle postMomentToAllCircles + MomentPreviewView "share to all circles (N)" disclaimer
- [ ] 11.4-03-PLAN.md — MomentFeedCard full-width redesign + late badge only + MomentCardView remove star + ProfileView gear icon
- [ ] 11.4-04-PLAN.md — CommunityView + CircleDetailView wired to multi-circle post + FeedViewModel own-moment pinning

---

## Phase 12 — Codebase Cleanup ✓ Complete
**Scope:** Delete dead code, consolidate design tokens, remove legacy onboarding files. No new features — just cut the fat.
- Delete confirmed dead files: `HalaqaMember.swift`, `OnboardingCoordinator.swift` (v1 only), `RamadanAmountView.swift`, `ProfileSetupView.swift`, `MomentCardView.swift`, `JoinFromLinkView.swift`, `AppIconView.swift`
- Delete dead step views (confirmed no live references): `AmiirStep4SoulGateView`, `MemberStep1HabitsView`, `MemberStep2LocationView`; also `AIStepDownView`, `HabitSelectionView` (old v1 cluster)
- Note: `AmiirStep1IdentityView`, `AmiirStep2HabitsView`, `AmiirStep3LocationView` are still live — used by `AmiirOnboardingFlowView`; NOT deleted this phase
- Audit and remove remaining dead references (`AppBackground`, `Components.swift` AppCard/PrimaryButton, `RoadmapGenerationFlag.swift`)
- Consolidate duplicated `private extension Color` MS tokens across all files into a single shared `DesignTokens` extension
- Simplify `ThemeManager` — remove NOAA auto-switch, enforce dark mode directly
- Verify build compiles clean after each deletion
- Completed outcomes:
  - 12 dead Swift files removed
  - `HalaqaMember.swift` correctly renamed to `CircleMember.swift`
  - `ShareSheet` extracted to `Circles/Extensions/ShareSheet.swift`
  - `LocationPickerView` reduced to a cities-list holder with `EmptyView()` body
  - `Components.swift` pruned to `SectionHeader` only
  - `AppBackground.swift` deleted
  - `RoadmapGenerationFlag.swift` inlined into `HabitPlanService`
  - 29 per-file Midnight Sanctuary `Color` blocks consolidated into `DesignTokens.swift`
  - `ThemeManager` simplified to dark-mode-only and `scheduleAutoSwitch()` removed from `CirclesApp.swift`

**Plans:** 3/3 plans complete

Plans:
- [x] 12-01-PLAN.md — Safe file deletions: 4 isolated dead files + OnboardingCoordinator cluster (8 files total)
- [x] 12-02-PLAN.md — Components.swift pruning, AppBackground.swift deletion, RoadmapGenerationFlag inline into HabitPlanService
- [x] 12-03-PLAN.md — DesignTokens shared MS token consolidation + ThemeManager simplification (dark-mode only)

---

## Phase 13 — Full UI/UX Pass 🔄 Active
**Scope:** Every screen redesigned and confirmed working. The biggest phase.
- **Dashboard (Home):** final state — 1-2 known fixes, drag-to-reorder confirmed working
- **Habit Detail:** icon fix (`Image(systemName:)` not `Text`), contrast fix, roadmap layout polish
- **Moments feed view:** `MomentFeedCard` full redesign — full-width image, late badge only, no star, clean layout
- **Check-in view:** `HabitCheckinRow` polish — copy, layout, reactions
- **Circles Overview (`MyCirclesView`):** card layout, group streak, CTAs
- **Circle Detail (`CircleDetailView`):** member board, feed section, Amir settings access
- **Community view:** tab switching, gate UX, filter tabs
- **Onboarding flows:** visual polish on all Amir + Joiner steps (placeholder for video assets — wire empty containers)
- **Profile:** stats layout, avatar picker, settings
- **Auth screen:** visual polish
- Full copy audit — Mercy-First language, Islamic tone, no generic alerts
- Consistent spacing, typography, and color token usage across all screens
- Confirm every screen renders correctly on iPhone 15 + 16 Pro simulators
- Execution mode:
  - Interactive screen-by-screen iteration
  - Claude reads files first, surfaces issues, then refines based on user + collaborating agent feedback
  - No plan files and no execute phase for Phase 13

---

## Phase 14 — Naming + Branding ⬜ Planned
**Scope:** Lock all product names and visual identity before submission.
- Finalize feature names: confirm "Circles", "Moments" and any other named concepts
- Logo finalized — update app icon asset in Xcode
- App display name, bundle name confirmed
- Splash / launch screen updated if needed

---

## Phase 15 — Notifications ⬜ Planned
**Scope:** Every push notification flow working end-to-end, correct tone.
- Verify and deploy all Edge Functions: moment-window, member-posted, streak-milestone, peer-nudge, comment
- Test each notification type on a real device (not just Simulator)
- Copy/tone audit on all notification bodies — warm Islamic voice, not generic alerts
- `send-moment-window-notifications` Edge Function deployment (currently skipped in UAT 11.4)
- Handle notification permission modal UX

---

## Phase 16 — Onboarding Videos + Animation Polish ⬜ Planned
**Scope:** Wire real video/animation assets into onboarding. Blocked on content creation.
- Replace placeholder video containers in `AmiirLandingSanctuaryView` + `JoinerLandingView` with real assets
- Animation timing polish on transitions between onboarding steps
- Confirm onboarding flow feels complete end-to-end on device

---

## Phase 17 — Web Landing Page ⬜ Planned
**Scope:** Marketing landing page (HTML/Tailwind) where people can download the app.
- App Store download CTA as primary action
- Sections: hero, what it is, how it works, download CTA
- Responsive: 375px–1440px
- Midnight Sanctuary color palette (consistent with app)
- No framework dependency — plain HTML/Tailwind/vanilla JS

---

## Phase 18 — App Store Submission ⬜ Planned
**Scope:** Final submission checklist.
- App Store metadata: title, subtitle, description, keywords
- Screenshots for all required device sizes
- Privacy manifest (PrivacyInfo.xcprivacy)
- TestFlight internal beta + human QA pass
- Submit for review

---

*Phases are executed in order. Early phases (1–2) have `SPEC.md` in-repo; later phases may ship SQL/README only.*
*Phases 1-2 implemented together. Phases 3-4 implemented together. Phase 5+ one at a time.*
