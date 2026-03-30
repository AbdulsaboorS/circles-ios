# Circles v2.3 — Roadmap

**Updated:** 2026-03-30
**Direction:** Private Islamic BeReal. 12-phase execution plan.

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
- Gemini `generate28DayRoadmap`; 3 refinements per UTC ISO week; PRD token-limit copy

---

## Phase 12 — Muslim-Native UX Polish + App Store 🔄 Active
**Scope:** Final pass before submission.
- Full copy audit across every screen
- Mercy-First language verification
- Notification tone review
- App Store metadata, screenshots, privacy manifest
- TestFlight beta, human verification, submission

---

*Phases are executed in order. Early phases (1–2) have `SPEC.md` in-repo; later phases may ship SQL/README only.*

**Manual QA:** `.planning/MANUAL_QA.md`
*Phases 1-2 implemented together. Phases 3-4 implemented together. Phase 5+ one at a time.*
