# Circles v2.4 — Roadmap

**Updated:** 2026-04-22
**Direction:** Private Islamic BeReal. Phases 1–14 complete. Personalization Era done. Next: Social Pulse (Phase 15) → Shipping Era (16–19).

---

## Completed Phases ✓

| Phase | Name | Notes |
|-------|------|-------|
| 1 | Schema + Model Foundations | habits, circles, profiles, comments, habit_plans, daily_moments |
| 2 | Navigation Restructure | Circles tab entry, Home = Daily Intentions only |
| 3 | Profile Photos | PHPicker → Supabase avatars bucket, AvatarView component |
| 4 | Dual-Track Habits | is_accountable flag, Shared + Personal sections on Home |
| 5 | Circle Core Habits + Gender Locking | core_habits JSONB, gender enforcement at join |
| 6 | Amir Onboarding v1 | Circle Identity → Core Habits → Location → Soul Gate |
| 7 | Member/Joiner Flow | Unauthenticated preview, gender-lock confirmation |
| 8 | Prayer of the Day + Reciprocity Gate | BeReal-style random window time, blur gate |
| 9 | Comment Drawer | circle-member RLS, slide-up sheet |
| 10 | Group Streak + Face Piles | UTC trigger, face pile on reactions, Amir settings |
| 11 | AI Roadmap v2 | Gemini 3 Flash, 28-day plans, weekly refinement cap |
| 11.1 | Full UI Vision Pass | Midnight Sanctuary redesign across all screens |
| 11.2 | E2E QA + Bug Fixes | Camera, feed, invite preview, roadmap loading |
| 11.5 | Feed Polish | Dedup, filter tabs, 30-min countdown, Double Take |
| 5.1 | Aligned Presence (Niyyah + Noor Aura) | Post-capture niyyah ritual, dissolve, aura on feed |
| 12 | Codebase Cleanup | 12 dead files removed, DesignTokens consolidated |
| 13 | Full UI/UX Pass | All 6 waves complete and QA'd |
| 13A | Journey Tab | Calendar archive, day detail sheet, PiP support |
| 13B | Profile Redesign | Hero treatment, settings card, Nudges Sent rename |
| 14 | Meaningful Habits | Quiz, niyyah on creation, Hamdulillah micro-moment, Noor Bead streak |

---

## Phase 15 — Social Pulse 🔄 In Progress

**Goal:** Give circles real-time social tug.

- Nudge push notifications (tap member who hasn't posted → friendly push)
- Comment push notifications
- Permission modal UX — warm Islamic framing, retry-friendly
- Real-device E2E verification of all edge functions
- Copy/tone audit across all notification strings

**Note:** `send-moment-window-notifications` already live via cron. This phase adds the social-interactive push layer.
**Worktree:** `phase-15-social-pulse` — 15.1 + 15.2 built, pending user verification.

---

## Shipping Era

### Phase 16 — Naming + Branding ⬜
Finalize feature names, logo, app display name, bundle name. (~1–2 days)

### Phase 17 — Onboarding Videos + Animation Polish ⬜
Real video assets, animation timing polish. Blocked on content creation.

### Phase 18 — Web Landing Page ⬜
App Store CTA, Midnight Sanctuary palette, plain HTML/Tailwind.

### Phase 19 — App Store Submission ⬜
Metadata, screenshots, Privacy Manifest, TestFlight beta, review submission.

---

## Parking Lot — Post-MVP

Validate with real TestFlight usage before investing:

- Intention arcs — goal + end_date + baseline/ending reflections
- Photo evidence on habit check-ins
- Streak personalization with niyyah seeding
- Habit check-in photo → Circle Moment promotion
- Quiz v2 — AI-generated suggestions beyond simple branching
- Pattern-based nudges — "You haven't done Quran for 3 days"
- Gemini for shared habit suggestions
- "Each their own" accountability model fork
