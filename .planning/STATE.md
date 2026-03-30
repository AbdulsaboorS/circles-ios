---
version: 2.3
last_updated: "2026-03-29"
current_phase: "Phase 11 — AI Roadmap v2"
status: "In Progress"
---

# Circles iOS — State (v2.3)

## Current Focus

**Next: Phase 11 (AI Roadmap v2)** — then Phase 12 (Polish + App Store).

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
- `ProfileView`: full redesign — PHPicker avatar picker, name, member-since, stats AppCard (Total Days / Best Streak / Circles), settings
- `CircleDetailView` member strip: uses AvatarView, loads member profiles, role = "Amir"

### Phase 4 — Dual-Track Habits ✓
- `HabitService.createAccountableHabit` (is_accountable=true, circle_id linked)
- `HabitService.broadcastHabitCompletion` → inserts into `activity_feed`
- `HomeViewModel.toggleHabit` broadcasts accountable completions (fire-and-forget)
- `HomeView`: "Shared Intentions" + "Personal Intentions" sections with descriptive sub-labels

### Phase 5 — Circle Core Habits + Gender Locking ✓
- `CircleService.createCircleForAmir` (genderSetting + coreHabits JSONB)
- `CircleService.fetchCircleByCode` for preview + join
- `CreateCircleView`: design system + Brothers/Sisters/Mixed picker
- `JoinCircleView`: design system + gender check + confirmation alert on mismatch
- `MyCirclesView`: group streak flame displayed on cards

### Phase 6 — Amir Onboarding Overhaul ✓
- `AmiirOnboardingCoordinator`: 4-step state machine, Soul Gate hard lock
- Steps: Circle Identity → Core Habits (max 3, curated list) → Location → Soul Gate
- Soul Gate: `ShareSheet` UIActivityViewController bridge; "Begin My Journey" disabled until share initiated
- Background AI roadmap generation fires on completion (fire-and-forget)
- `StepIndicator` component (animated pill progress)
- `ContentView`: routes new users to Amir flow; Amir lands on Home tab

### Phase 7 — Member/Joiner Flow + Rich Circle Preview ✓
- `CirclePreviewView`: unauthenticated landing — circle name, core habits, group streak, inline Sign in with Apple/Google
- `MemberOnboardingCoordinator`: join circle + create accountable habits + save location
- Steps: Habit Alignment (must pick ≥ 1 core habit) → Location → joins circle on city select
- `ContentView`: anon + invite code → preview; new user + invite code (post-auth) → member flow

### Phase 8 — Prayer of the Day + Reciprocity Gate v2 ✓
- `DailyMomentService`: fetches today's prayer from `daily_moments`, calls Aladhan API for exact prayer time, checks if user posted today across all circles
- Gate activates when window OPENS (not after it closes)
- `ReciprocityGateView`: frosted blur overlay with "Unlock Your Circles" CTA
- `CommunityView`: global feed wrapped in gate, camera opens for first circle
- `CircleDetailView`: feed section wrapped in gate
- `MomentFeedCard`: "Posted at [Prayer]" badge for on-time, "Posted late" for late
- `FeedItem`: Equatable conformance + `circleId` / `postType` computed properties

### Phase 9 — Comment Drawer ✓
- `CommentService`: fetchComments, addComment, deleteComment (RLS: circle members only)
- `CommentDrawerView`: slide-up `.medium/.large` sheet — avatars, comment list, text input, send, delete own, empty state
- `MomentFeedCard`, `HabitCheckinRow`, `StreakMilestoneCard`: comment bubble icon added
- `FeedView`: manages `commentingOnItem` state, presents `CommentDrawerView` as sheet

### Phase 10 — Group Streak + Face Piles + Amir settings ✓
- DB (Supabase): UTC group streak trigger + `group_streak_last_complete_utc_date` (applied in your project; no SQL files in repo)
- `CircleService`: `fetchCircle`, `updateCircleSettings`, `removeMember`
- After a Moment post: `CircleDetailView` refetches circle; `CommunityView` calls `loadCircles` so My Circles streak updates
- `FeedViewModel` + `ReactionBar`: batch reactor profiles, overlapping face pile (max 5 + “+N”)
- `AmirCircleSettingsView`: Amir gear on circle detail — edit core habits (≤3), gender; remove members
- `CircleDetailView` member strip cap 14 + overflow badge; `MembersListView` avatars + Amir label

---

## What's Built — v1 Foundation (carried into v2.3)

### Auth
- Sign in with Apple + Google OAuth via Supabase
- `AuthManager` (@Observable @MainActor) with session persistence

### Design System
- `DesignTokens.swift`: color + font tokens, semantic aliases, AppColors resolver
- `ThemeManager.shared`: ThemeMode (auto/light/dark), NOAA solar auto-switch
- `AppBackground.swift`: dual animated blob background
- `Components.swift`: AppCard, PrimaryButton, ChipButton, SectionHeader
- `AvatarView.swift`: reusable circular avatar component

### Habits
- `Habit`, `HabitLog`, `Streak`, `HabitPlan` models
- `HabitService`: fetchActiveHabits, toggleHabitLog, updateLogNote, updatePlanNotes, createAccountableHabit, broadcastHabitCompletion
- `GeminiService`: fetchSuggestion (Phase 11 adds roadmap / refine generation)
- `HomeViewModel` + `HomeView` + `HabitDetailView`

### Circles
- `Circle`, `CircleMember` models (with genderSetting, coreHabits, groupStreakDays)
- `CircleService`: fetchMyCircles, fetchCircle, createCircle, createCircleForAmir, joinByInviteCode, fetchCircleByCode, fetchMembers, updateCircleSettings, removeMember
- `CirclesViewModel`: loadCircles, createCircle, joinCircle
- `CommunityView`: Feed|Circles swipeable TabView
- `MyCirclesView`: organic card layout (featured + stacked), group streak, CTAs
- `CreateCircleView`, `JoinCircleView` (gender enforcement)
- `CircleDetailView`: member board (AvatarView), Amir settings sheet, feed, moment banner, nudge

### Circle Moment
- `CircleMoment` model
- `MomentService`: fetchTodayMoments, uploadPhoto, postMoment, computeIsOnTime
- `CameraManager`, `MomentCameraView`, `MomentPreviewView`, `MomentCardView`
- Reciprocity gate v2 via `DailyMomentService` (full-feed blur)

### Feed
- `FeedItem` enum (moment, habitCheckin, streakMilestone) — Identifiable, Sendable, Equatable
- `FeedService.fetchFeedPage(circleIds: [UUID], ...)` — multi-circle aware
- `FeedViewModel`: loadInitial, loadNextPage, refresh — all accept [UUID]
- `FeedView`: LazyVStack, pagination, comment drawer; `FeedViewModel` reaction face piles
- `MomentFeedCard`, `HabitCheckinRow`, `StreakMilestoneCard`, `ReactionBar`
- `ReciprocityGateView`, `CommentDrawerView`

### Onboarding (v2.3)
- `AmiirOnboardingCoordinator` + 4 step views (Circle Identity, Habits, Location, Soul Gate)
- `MemberOnboardingCoordinator` + 2 step views (Habit Alignment, Location)
- `CirclePreviewView` — unauthenticated invite landing
- `StepIndicator`, `ShareSheet`

### Push Notifications
- `NotificationService`: APNs permission, device token management
- Edge Functions: moment-window cron, member-posted trigger, streak-milestone, peer nudge

### Profile
- `ProfileView`: avatar picker (PHPicker), stats, settings, sign out
- `AvatarService`: upload, fetch profiles, fetch stats

### Services
- `DailyMomentService`: prayer of day + Aladhan API + gate state
- `CommentService`: CRUD on `comments` table

---

## Active Technical Decisions

- `@Observable @MainActor` pattern throughout (Swift 6)
- Service singletons via `@Observable` (not ObservableObject)
- `DATE` columns stored as String in Swift models
- `import Supabase` required in every file accessing `auth.session?.user.id`
- `SwiftUI.Circle()` qualified to avoid naming conflict with `Circle` model
- `circles` + `circle_members` custom tables (RLS via `auth_user_circle_ids()` SECURITY DEFINER)
- `FeedService.fetchFeedPage(circleIds: [UUID])` — multi-circle unified feed
- `FeedViewModel` accepts `[UUID]` throughout; single-circle calls pass `[circle.id]`
- `AvatarService` used for profile fetch + stats (not a separate ProfileService)
- `DailyMomentService.shared` is a singleton read by CommunityView + CircleDetailView
- Aladhan API method=3 (MWL) matches Edge Function prayer time calculations
- `ShareSheet` is a `UIViewControllerRepresentable` wrapper for `UIActivityViewController`
- Soul Gate hard lock: `hasSharedInvite = true` set when share button tapped (share sheet opened)
- One commit per build session (phase group) — not per individual file change
- Git: `main` branch, remote `origin` = GitHub (AbdulsaboorS/circles-ios)

---

## Phase History

| Phase | Status | Summary |
|-------|--------|---------|
| 1 — Schema + Models | ✓ Complete | DB migrations + all Swift models updated/created |
| 2 — Navigation | ✓ Complete | App entry → Circles tab, Home = Daily Intentions |
| 3 — Profile Photos | ✓ Complete | AvatarService, AvatarView, ProfileView redesign |
| 4 — Dual-Track Habits | ✓ Complete | is_accountable, broadcastHabitCompletion, HomeView sections |
| 5 — Core Habits + Gender | ✓ Complete | createCircleForAmir, gender enforcement, streak on cards |
| 6 — Amir Onboarding | ✓ Complete | 4-step flow, Soul Gate hard lock, background AI |
| 7 — Member Flow + Preview | ✓ Complete | CirclePreviewView (anon), MemberOnboardingCoordinator |
| 8 — Prayer Gate v2 | ✓ Complete | DailyMomentService, Aladhan API, full-feed blur gate |
| 9 — Comment Drawer | ✓ Complete | CommentService, CommentDrawerView, comment buttons on all cards |
| 10 — Group Streak + Face Piles | ✓ Complete | UTC trigger SQL, refetch after moment, face piles, Amir settings |
| 11 — AI Roadmap v2 | 🔄 Next | habit_plans table, 28-day timeline UI, refinement guardrail |
| 12 — Polish + App Store | ⏳ Pending | Muslim-native copy audit, App Store submission |

---

## Blockers

None.

---

*v2.3 pivot: 2026-03-26. Phases 1-10 complete. Phases 11-12 remaining.*
