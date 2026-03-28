---
version: 2.3
last_updated: "2026-03-26"
current_phase: "Phase 1 — Schema + Model Foundations"
status: "In Progress"
---

# Circles iOS — State (v2.3)

## Current Focus

**Phase 1 + 2**: Schema foundations + navigation restructure.
See ROADMAP.md for full 12-phase plan.

---

## What's Built (Foundation — carried into v2.3)

These are the working pieces of the codebase as of the v2.3 pivot on 2026-03-26.

### Auth
- Sign in with Apple + Google OAuth via Supabase
- `AuthManager` (@Observable @MainActor) with session persistence
- `ContentView` routes authenticated vs unauthenticated users

### Design System (Phase 06.1 — complete)
- `DesignTokens.swift`: color tokens (#0E0B08 dark, #F5F0E8 light, #E8834B accent, #1A3A2A darkBlob, #EDE0C8 lightBlob), semantic aliases
- `AppColors` resolver (light/dark adaptive)
- Font tokens: New York serif (appHeroTitle/appTitle/appHeadline) + SF Pro (appBody/appSubheadline/appCaption)
- `ThemeManager.shared`: @Observable singleton, ThemeMode (auto/light/dark), NOAA solar auto-switch
- `AppBackground.swift`: dual animated ellipse blobs
- `Components.swift`: AppCard, PrimaryButton, ChipButton, SectionHeader
- `AppIconView.swift`: Islamic tessellation canvas icon

### Habits
- `Habit`, `HabitLog`, `Streak` Codable models (snake_case CodingKeys)
- `HabitService`: fetchActiveHabits, fetchTodayLogs, toggleHabitLog, fetchStreak, createHabit, updateAcceptedAmount, updateLogNote, updatePlanNotes
- `HabitLog.notes: String?` — daily note field (DB column: `habit_logs.notes`)
- `Habit.planNotes: String?` — plan annotation (DB column: `habits.plan_notes`)
- `HomeViewModel`: @Observable @MainActor, parallel fetch, optimistic toggle
- `HomeView`: habit list, streak banner, NavigationLink to HabitDetailView
- `HabitDetailView`: 28-day dot calendar, stat badges

### AI
- `GeminiService`: fetchSuggestion (step-down plan), refinePlan (contextual re-generation)
- `AISuggestion` struct: suggestedAmount, motivation, tip

### Circles
- `Circle` model: id, name, description, createdBy, inviteCode, momentWindowStart, createdAt
- `HalaqaMember` / `CircleMember` models
- `CircleService`: fetchMyCircles, createCircle, joinByInviteCode, fetchMembers
- `CirclesViewModel`: loadCircles, createCircle, joinCircle
- `CommunityView`: Feed | Circles segmented + swipeable TabView
- `MyCirclesView`: featured 1+2 card layout with organic card design (Variation 4)
- `CreateCircleView`, `JoinCircleView`
- Deep links: `circles://join/CODE` → `JoinCircleView`

### Circle Moment
- `CircleMoment` model
- `MomentService`: fetchTodayMoments, uploadPhoto, postMoment, computeIsOnTime
- `CameraManager`: AVCaptureSession, dual camera, compositing
- `MomentCameraView`: full-screen camera, permission handling
- `MomentPreviewView`: photo review, caption, post CTA
- `MomentCardView`: locked (blur) / unlocked / own-unposted states
- Reciprocity gate in `CircleDetailView` (currently per-circle, post-window only — will be upgraded in Phase 8)

### Feed
- `FeedItem` enum: moment, habitCheckin, streakMilestone
- `FeedReaction` model
- `FeedService`: fetchFeedPage(circleIds: [UUID], ...) — multi-circle aware
- `FeedViewModel`: loadInitial, loadNextPage, refresh — all accept [UUID]
- `FeedView`: LazyVStack, infinite scroll, pagination
- `MomentFeedCard`, `HabitCheckinRow`, `StreakMilestoneCard`, `ReactionBar`
- Global feed in CommunityView aggregates across all user circles

### Push Notifications
- `NotificationService`: APNs permission, device token management
- `DeviceToken` model — `device_tokens` table
- Edge Functions deployed: send-moment-window-notifications (cron), send-member-posted-notification (webhook), send-streak-milestone-notification, send-peer-nudge
- `NotificationPermissionModal`: soft-prompt on first circle join

### Onboarding (v1 — to be replaced in Phase 6-7)
- `OnboardingCoordinator`: step enum, flow logic
- `ProfileSetupView`: name + gender chips
- `HabitSelectionView`: preset habit tiles
- `RamadanAmountView`: habit amounts
- `AIStepDownView`: AI plan display
- `LocationPickerView`: 50 bundled cities, saves lat/lng to profiles

### Profile
- `ProfileView`: basic layout, dev tools (#if DEBUG)

---

## Active Technical Decisions

- `@Observable @MainActor` pattern throughout (Swift 6)
- Service singletons via `@Observable` (not ObservableObject)
- `DATE` columns stored as String in Swift models
- `import Supabase` required in every file accessing `auth.session?.user.id`
- `SwiftUI.Circle()` qualified to avoid naming conflict with `Circle` model
- `circle_members` table (not legacy `halaqas`)
- `circles` + `circle_members` custom tables (RLS via `auth_user_circle_ids()` SECURITY DEFINER)
- AVFoundation work on dedicated `nonisolated let sessionQueue`
- `@preconcurrency import AVFoundation` for Sendable warnings
- `Timer.scheduledTimer` callback uses `MainActor.assumeIsolated`
- AppBackground uses `@Environment(\.colorScheme)` directly (not ThemeManager)
- `FeedService.fetchFeedPage(circleIds: [UUID])` — multi-circle unified feed
- FeedViewModel accepts `[UUID]` throughout; single-circle calls pass `[circle.id]`

---

## Phase History (v1 foundations)

| Phase | Completion | Summary |
|-------|-----------|---------|
| Setup | ✓ 2026-03-23 | Xcode 26.3, SPM, GitHub |
| Auth + Nav Shell | ✓ 2026-03-23 | Auth, 3-tab shell, Simulator verified |
| Habits Data Layer | ✓ 2026-03-24 | Habit/HabitLog/Streak models, HabitService, GeminiService |
| Onboarding v1 | ✓ 2026-03-24 | HabitSelection, RamadanAmount, AIStepDown, LocationPicker |
| HomeView | ✓ 2026-03-24 | HomeViewModel, HomeView, HabitDetailView, Simulator verified |
| Circles Data + UI | ✓ 2026-03-24 | Circle model, CircleService, CommunityView, CreateCircle, JoinCircle |
| Circle Moment | ✓ 2026-03-24 | CameraManager, MomentCameraView, MomentPreviewView, reciprocity gate |
| Unified Feed | ✓ 2026-03-24 | FeedService, FeedViewModel, all feed cards, Simulator verified |
| Push Notifications | ✓ 2026-03-24 | NotificationService, APNs pipeline, 4 Edge Functions deployed |
| Design System (06.1) | ✓ 2026-03-25 | DesignTokens, ThemeManager, AppBackground, Components, AppIconView |
| Core Screens (06.2) | ✓ 2026-03-25 | HomeView, CommunityView, CircleDetailView, FeedView redesigned |
| Community v2 pivot | ✓ 2026-03-26 | Feed\|Circles swipeable, MyCirclesView organic cards, explore removed |

---

## Blockers

None.

---

*v2.3 pivot: 2026-03-26. All old phase plans deleted. New 12-phase roadmap active.*
