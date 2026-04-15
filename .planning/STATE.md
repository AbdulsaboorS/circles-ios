---
gsd_state_version: 1.0
milestone: v2.4
milestone_name: milestone
status: active
last_updated: "2026-04-14T22:00:00.000Z"
progress:
  total_phases: 18
  completed_phases: 12
  total_plans: 13
  completed_plans: 10
---

# Circles iOS — State (v2.4)

## Current Focus

**Next: Journey Runtime QA** — the Journey follow-up fixes are now implemented and build-verified. Manual simulator/device validation is still pending because `simctl install/launch` remains unreliable from CLI.

**Then: Profile Redesign** — 10/10 UI/UX pass. Queued after Journey.

**Phase 13 (UI/UX Pass)** — paused mid-wave to prioritize Journey Tab and Profile redesign as higher-value work.

### Phase 13 Wave Status

| Wave | Screen | Status |
|------|--------|--------|
| 1 | Home (Dashboard) | ✓ Complete |
| 2 | Habit Detail | ✓ Complete |
| 3 | Community / Feed | 🔄 Built — pending user QA |
| 4 | Feed Cards | ⬜ Queued |
| 5 | My Circles + Circle Detail | 🔄 My Circles built — testing in progress |
| 6 | Profile | ⬜ Queued (will be done as full redesign, not just polish) |
| 7 | Auth | ⬜ Queued |

---

## What's Built — Session 21 (2026-04-14)

### Journey QA Fixes

- Journey now invalidates and reloads the current month after a successful moment post instead of trusting stale cached month data
- Same-day Journey dedupe now prefers the newest `posted_at`
- Journey detail now pages horizontally across populated days in the visible month
- Journey detail now supports Double Take PiP consistently, including tap-to-swap parity with the feed/fullscreen viewer
- Signed moment URLs are cached by storage path, and Journey detail now prefetches selected/adjacent day media
- Community and Circle Detail now refresh from a shared post-success notification, reducing stale card/feed state after posting
- Partial-success post warnings now name failed circles when the app has those names available

### Review / Verification Notes

- `xcodebuild` build verified after the Journey QA fix pass
- Simulator boot succeeded for `iPhone 17 Pro`
- CLI runtime verification is still incomplete because `simctl install` did not return and the app never finished installing

### Remaining QA Checks

- Manually verify same-day repost freshness in Journey without killing the app
- Manually verify Journey detail paging and PiP swap behavior
- Manually verify that reopening the same Journey day feels faster
- Re-test cross-surface circle-card timestamps after both global and circle-detail posting flows

---

## What's Built — Session 20 (2026-04-14)

### Journey MVP

- New `Journey` tab added between Community and Profile
- Journey calendar archive built with month navigation, locale weekday ordering, and 3 day states
- Journey detail sheet built as read-only niyyah-first view with on-demand photo signing
- `SpiritualLedgerView` removed from Profile entirely
- `MomentService` extended with month-range unresolved moment fetches and archive empty-state support

### Review / Verification Notes

- `xcodebuild` build verified after Journey ship
- Runtime simulator verification was not completed in-session because `simctl launch` hung after boot/install attempts
- In-session review fixed a stale-month loader bug and improved Journey same-session niyyah refresh behavior

### Current QA Follow-Ups

- Runtime/manual Journey verification is still pending because simulator CLI install/launch is unreliable
- Same-day repost freshness, Journey paging/PiP, and repeat-open latency still need hands-on validation
- Cross-surface timestamp consistency still needs one explicit re-test after the new refresh wiring

---

## What's Built — Session 19 (2026-04-14)

### Moment System Fixes

- **Force Moment Window** now genuinely allows re-posting — deletes today's DB rows (`circle_moments` + `moment_niyyahs`) before reopening. `DailyMomentService.forceOpenWindow(userId:)` is now async.
- **State machine desync fixed** — `MomentPreviewView` calls `markPostedToday()` on `alreadyPostedToday` error so the gate/CTA close instead of staying stuck open after a DB rejection.

### BeReal-Style Random Daily Timing

- `daily_moments.moment_time` column added (TEXT, "HH:MM" UTC)
- `seed-daily-moment` edge function picks a random UTC time 13:00–03:00 (≈ 8am–10pm ET) each day. Deployed v2.
- `send-moment-window-notifications` fully rewritten — time-based, not prayer-based. Sends to all device tokens when `now` is within ±2 min of `moment_time`. Deployed v1.
- `DailyMomentService` uses `moment_time` directly when available; Aladhan API only as fallback for legacy rows.
- pg_cron: `seed-daily-moment` at 00:05 UTC daily, notifications check every minute. Both active.
- `CirclesApp.AppDelegate` now conforms to `UNUserNotificationCenterDelegate` — refreshes gate on `moment_window` push.

### Spiritual Ledger / Journey Decisions

- `SpiritualLedgerView` ledger button on Profile now **always visible** (removed `niyyahCount > 0` guard).
- **Journey tab vision finalized** — full design, architecture, data model, and build plan documented in HANDOFF.md. This vision is now shipped as an MVP and in QA follow-up.

---

## What's Built — v2.3 Phases

### Phase 1 — Schema + Model Foundations ✓
- DB: `habits` (is_accountable, circle_id), `circles` (gender_setting, group_streak_days, core_habits), `profiles` (avatar_url)
- New tables: `comments`, `habit_plans`, `daily_moments`
- Swift models: `Circle`, `Habit`, `HabitLog` updated; `Comment`, `HabitPlan`, `DailyMoment`, `Profile` created

### Phase 2 — Navigation Restructure ✓
- App entry → Circles tab (tag 1)
- Tab label "Community" → "Circles"
- Home tab = Daily Intentions only (no social feed)

### Phase 3 — Profile Photos ✓
- `AvatarView` component (AsyncImage + initials fallback, configurable size)
- `AvatarService`: upload to `avatars` Storage bucket, save URL to profiles, fetch profiles + impact stats
- `ProfileView`: full redesign — PHPicker avatar picker, name, member-since, stats AppCard, settings
- `CircleDetailView` member strip: uses AvatarView, loads member profiles, role = "Amir"

### Phase 4 — Dual-Track Habits ✓
- `HabitService.createAccountableHabit` (is_accountable=true, circle_id linked)
- `HabitService.broadcastHabitCompletion` → inserts into `activity_feed`
- `HomeViewModel.toggleHabit` broadcasts accountable completions (fire-and-forget)
- `HomeView`: "Shared Intentions" + "Personal Intentions" sections

### Phase 5 — Circle Core Habits + Gender Locking ✓
- `CircleService.createCircleForAmir` (genderSetting + coreHabits JSONB)
- `CircleService.fetchCircleByCode` for preview + join
- `CreateCircleView`: design system + Brothers/Sisters/Mixed picker
- `JoinCircleView`: design system + gender check + confirmation alert on mismatch
- `MyCirclesView`: group streak flame displayed on cards

### Phase 6 — Amir Onboarding Overhaul ✓
- `AmiirOnboardingCoordinator`: 4-step state machine, Soul Gate hard lock
- Steps: Circle Identity → Core Habits (max 3, curated list) → Location → Soul Gate
- Soul Gate: `ShareSheet` UIActivityViewController bridge
- On completion: background `HabitPlanService.ensureAIRoadmapForOnboarding` per habit

### Phase 7 — Member/Joiner Flow + Rich Circle Preview ✓
- `CirclePreviewView`: unauthenticated landing — circle name, core habits, group streak, inline Sign in with Apple/Google
- `MemberOnboardingCoordinator`: join circle + create accountable habits + save location

### Phase 8 — Prayer of the Day + Reciprocity Gate v2 ✓
- `DailyMomentService`: fetches `daily_moments`, calls Aladhan API (fallback), checks if user posted
- Gate activates when window opens
- `ReciprocityGateView`: frosted blur overlay with "Unlock Your Circles" CTA
- Now supports `moment_time` (random UTC time) as primary timing source

### Phase 9 — Comment Drawer ✓
- `CommentService`: fetchComments, addComment, deleteComment (RLS: circle members only)
- `CommentDrawerView`: slide-up `.medium/.large` sheet

### Phase 10 — Group Streak + Face Piles + Amir settings ✓
- UTC group streak DB trigger
- Face pile on reactions (`FeedViewModel` + `ReactionBar`)
- `AmirCircleSettingsView`: edit core habits, gender, remove members

### Phase 11 — AI Roadmap v2 ✓
- `GeminiService`: `gemini-3-flash-preview`, 28-day roadmap generation
- `HabitPlanService`: fetch/upsert plan, `applyRefinement` via RPC, 3 refinements/week cap
- `HabitDetailView`: Generate button, calendar-aligned milestones, Refine sheet

### Phase 11.1 — Full UI Vision Pass ✓
- Full Midnight Sanctuary redesign across all screens

### Phase 11.2 — E2E QA + Bug Fixes ✓
- Camera, feed, invite preview, roadmap loading fixes

### Phase 11.5 — Feed Polish ✓
- Feed dedup, filter tabs, 30min countdown, today-only, sequential Double Take capture

### Wave 5.1 — Aligned Presence (Niyyah + Noor Aura) ✓
- `NiyyahCaptureOverlay` — post-capture intention ritual
- `NiyyahDissolveView` — particle dissolve animation
- `NoorAuraOverlay` — breathing gold glow on feed cards
- `IslamicGeometricPattern` — 8-pointed star Canvas background
- `SpiritualLedgerView` — paging journal (now removed; superseded by Journey tab)
- `NiyyahService` + `MomentNiyyah` model — owner-only private storage
- `moment_niyyahs` table + RLS; `circle_moments.has_niyyah` column
- 32pt corner radius on all moment photos

### Phase 12 — Codebase Cleanup ✓
- 12 dead files deleted, DesignTokens consolidated, ThemeManager simplified

---

## DB State (current)

| Table / Column | Status |
|----------------|--------|
| `habits`, `habit_logs`, `streaks` | ✅ Active |
| `circles`, `circle_members` | ✅ Active |
| `circle_moments` + `has_niyyah` | ✅ Active |
| `moment_niyyahs` | ✅ Active (owner-only RLS) |
| `daily_moments` + `moment_time` | ✅ Active |
| `profiles` | ✅ Active |
| `activity_feed`, `habit_reactions`, `comments` | ✅ Active |
| `device_tokens` | ✅ Active |
| `circle_moments_one_per_day` unique index | ✅ Active |
| pg_cron jobs (2) | ✅ Active |
| pg_net extension | ✅ Enabled |

---

## Active Technical Decisions

- `@Observable @MainActor` pattern throughout (Swift 6)
- Service singletons via `@Observable` (not ObservableObject)
- `DATE` columns stored as String in Swift models
- `import Supabase` required in every file accessing `auth.session?.user.id`
- `SwiftUI.Circle()` qualified to avoid naming conflict with `Circle` model
- `circles` + `circle_members` custom tables (RLS via `auth_user_circle_ids()` SECURITY DEFINER)
- `DailyMomentService` uses `moment_time` (UTC "HH:MM") as primary window source; Aladhan API is fallback only
- One commit per build session — push to `origin main` after each commit
- Git: `main` branch, remote `origin` = GitHub (AbdulsaboorS/circles-ios)

---

## Open Issues (carry-forward)

### A. Gemini -1011 on Generate Plan
- `NSURLErrorBadServerResponse` — Gemini returned non-200. Verify `GEMINI_API_KEY` + model `gemini-3-flash-preview` enabled.

### B. Habit check-in feed deduplication
- `broadcastHabitCompletion` inserts unconditionally → duplicate feed cards if habit toggled multiple times/day.
- Fix: guard with existing row check before insert.

### C. Habit detail icon
- `HabitDetailView` uses `Text(habit.icon)` — should be `Image(systemName:)`.

### D. Journey runtime verification gap
- The Journey follow-up fixes are implemented and build-verified, but manual runtime validation is still outstanding.

### E. Simulator CLI install / launch
- `simctl boot` succeeds, but `simctl install` / `simctl launch` remain unreliable from CLI on the configured simulator.

### F. Niyyah save fallback
- `MomentService.postMomentToAllCircles` still treats `saveNiyyah` as non-fatal after a successful photo post, so a Supabase niyyah-write failure could still leave a stale private niyyah.

---

## Blockers

None. Journey follow-up fixes are local app work with no external dependency.

---

*Last updated: 2026-04-14 — Session 21. Journey QA fixes are implemented and build-verified. Next: manual Journey runtime QA, then Profile redesign.*
