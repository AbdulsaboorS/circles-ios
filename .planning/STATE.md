---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: milestone
status: Executing Phase 06.2
last_updated: "2026-03-25T18:09:25.400Z"
progress:
  total_phases: 10
  completed_phases: 7
  total_plans: 22
  completed_plans: 20
---

# Circles iOS — State

## Current Phase

**Phase 6: Push Notifications** — COMPLETE (3/3 plans done; Supabase migrations applied via MCP).
**Next: Phase 06.1 (UI Design System Foundation) or Phase 7 (App Store Polish).**
**Phase 5: Unified Circle Feed** — COMPLETE (2/2 plans done, human-verified).

## What's Done

### Phase 06.1, Plan 01: Design Tokens + ThemeManager (2026-03-25) ✓

- DesignTokens.swift: primitive Color tokens (#0E0B08 dark, #F5F0E8 light, #E8834B accent, #1A3A2A darkBlob, #EDE0C8 lightBlob, text variants, lightCardSurface)
- AppColors semantic resolver: AppColors.resolve(_ scheme: ColorScheme) returns adaptive token set
- D-07 static alias extensions: Color.appBackground, cardSurface, textPrimary, textSecondary, blobPrimary, blobSecondary
- Font tokens: appHeroTitle/appTitle/appHeadline (New York serif, D-04) + appBody/appSubheadline/appCaption/appCaptionMedium (SF Pro, D-05)
- ThemeManager.shared: @Observable @MainActor singleton with colorScheme: ColorScheme and ThemeMode enum (auto/alwaysLight/alwaysDark)
- ThemeManager.scheduleAutoSwitch(): reads cityLatitude/cityLongitude from UserDefaults; NOAA solar algorithm for sunrise/sunset; 6am-8pm heuristic fallback
- Deviation: Adhan not in iOS SPM (only in TS Edge Functions); replaced with pure Swift SolarCalculator (NOAA algorithm)
- BUILD SUCCEEDED, zero errors

### Phase 06.1, Plan 03: Reusable Components + ThemeManager Wiring (2026-03-25) ✓

- Components.swift: AppCard (.ultraThinMaterial dark / white+shadow light, cornerRadius 16), PrimaryButton (Color.accent fill, 52pt, loading state, cornerRadius 14), ChipButton (Capsule pill, filled/outlined variants), SectionHeader (New York serif headline, adaptive text colors)
- AppIconView.swift: Canvas-based 8-pointed Islamic star tessellation on #0E0B08 background with #E8834B amber stars, Apple icon corner radius
- CirclesApp.swift: @State themeManager = ThemeManager.shared; .environment(themeManager) injected; scheduleAutoSwitch() called in .onAppear
- ContentView.swift: @Environment(ThemeManager.self); .preferredColorScheme(themeManager.colorScheme) at root Group
- MainTabView.swift: .tint(Color.accent) — hardcoded Color(hex: "E8834B") replaced
- BUILD SUCCEEDED, zero errors — Phase 06.1 design system foundation complete

### Phase 06.1, Plan 02: AppBackground — Animated Blob Background (2026-03-25) ✓

- AppBackground.swift: standalone SwiftUI View; two Ellipse blobs with Gaussian blur at opposite corners
- Primary blob: top-left, 75% screen width, 4s easeInOut animation, blur radius 100
- Secondary blob: bottom-right, 55% screen width, 5s easeInOut animation with 1.2s delay (inverted scale for organic feel), blur radius 80
- Dark mode: #0E0B08 background, #1A3A2A blobs; Light mode: #F5F0E8 background, #EDE0C8 blobs
- Uses @Environment(\\.colorScheme) directly — no ThemeManager dependency (safe for Wave 1 parallel development)
- BUILD SUCCEEDED, zero errors

### Phase 6, Plan 03: Push Notification UI + Onboarding Profile Setup (2026-03-24) ✓

- NotificationPermissionModal: navy soft-prompt sheet, fires once after first circle join/create (circles.count == 1)
- CirclesViewModel: shouldShowPermissionPrompt triggers modal after createCircle/joinCircle
- MainTabView: Community tab badge from NotificationService.unreadCount; clears on tab open
- CircleDetailView: "Moment" + "Habit" amber pill nudge buttons for non-self members → send-peer-nudge Edge Function; notifications-denied inline note; contentShape(Rectangle()) fix on members row
- ProfileSetupView: NEW first onboarding screen — name + Brother/Sister gender chips; saves to profiles.preferred_name + profiles.gender
- HabitService: createHabit now upserts (onConflict: user_id,name) — fixes duplicate constraint on onboarding re-run
- ProfileView dev tools (#if DEBUG): "Reset Account" clears onboarding flag + signs out; "Test Badge +1" increments unreadCount
- Supabase migrations applied via MCP: device_tokens table (RLS), nudge_log table, profiles location columns (city_name, timezone, latitude, longitude)
- Onboarding flow order: ProfileSetupView → HabitSelectionView → RamadanAmountView → AIStepDownView → LocationPickerView
- BUILD SUCCEEDED, zero errors

### Phase 6, Plan 01: iOS APNs Pipeline + City Picker Onboarding (2026-03-24) ✓

- DeviceToken.swift: Codable struct mapping device_tokens table (user_id, device_token, created_at)
- NotificationService.swift: @Observable @MainActor singleton with requestPermission(), handleToken (token → Supabase device_tokens upsert), refreshPermissionStatus(); SQL migration documented in comments
- CirclesApp.swift: UIApplicationDelegateAdaptor(AppDelegate.self) + didRegisterForRemoteNotificationsWithDeviceToken → NotificationService.shared.handleToken
- AuthManager.swift: nonisolated(unsafe) static weak var sharedForAPNs bridges AppDelegate → @MainActor session access
- OnboardingCoordinator: Step.locationPicker, cityName/cityTimezone/cityLatitude/cityLongitude, proceedToLocation(), saveLocationAndMarkComplete() with profiles upsert; SQL migration in comments
- LocationPickerView: searchable list of 50 bundled cities (offline, no API); selects city → saveLocationAndMarkComplete()
- AIStepDownView: "Save My Habits" now calls proceedToLocation() after finishOnboarding() succeeds
- ContentView: .locationPicker case added to navigationDestination switch
- BUILD SUCCEEDED, zero errors

### Phase 6, Plan 02: Supabase Edge Functions for Push Notifications (2026-03-24) ✓

- `_shared/apns.ts`: ES256 JWT APNs HTTP/2 helper using Web Crypto API (ECDSA P-256) — no third-party library
- `_shared/prayer_times.ts`: Pure TS Adhan port (Muslim World League, MWL_FAJR_ANGLE=18, MWL_ISHA_ANGLE=17) — no npm
- `send-moment-window-notifications`: Cron Edge Function, ±2 min prayer time window, queries circle_members + profiles
- `send-member-posted-notification`: DB webhook on circle_moments INSERT, post-reciprocity-gate delivery to already-posted members
- `send-streak-milestone-notification`: Milestones [7, 30, 100]; Islamic copy "MashAllah! 🌟"
- `send-peer-nudge`: HTTP POST, rate-limited via nudge_log UNIQUE(sender_id, target_id, nudge_date), 23505 → 429
- Deployment notes: nudge_log migration SQL documented in send-peer-nudge/index.ts; deploy as cron + DB webhook

### Phase 5, Plan 02: Feed UI Layer (2026-03-24) ✓

- FeedViewModel.swift: @Observable @MainActor; loadInitial (parallel feed+moments fetch), loadNextPage, refresh, toggleReaction (optimistic), reactionCount, userHasReacted
- FeedView.swift: LazyVStack infinite scroll, onAppear trigger at last-3 items, ProgressView during next-page load, empty state
- MomentFeedCard.swift: full-width 280pt photo, .blur(radius:20) + lock overlay when isLocked (!hasPostedToday && not own post), on-time star badge
- HabitCheckinRow.swift: compact "[Name] checked in [Habit]" + relative timestamp
- StreakMilestoneCard.swift: amber-accented 🔥 card with streak count and habit name
- ReactionBar.swift: 6 emoji chips, amber background when selected, optimistic toggle via FeedViewModel
- CircleDetailView restructured: List replaced with ScrollView+LazyVStack, members collapsed to summary row with MembersListView sheet, FeedView embedded below Activity label, pull-to-refresh, parallel .task load
- Post-checkpoint fix: .frame(maxWidth:.infinity, maxHeight:.infinity, alignment:.top) on VStack inside ZStack — fixes ScrollView height collapse (2971c26)
- BUILD SUCCEEDED, zero errors
- Stub: checkedInCount hardcoded to 0 (deferred to future phase)
- Human verified in Simulator: feed working, scrolling works, all items visible

### Phase 5, Plan 01: Feed Data Layer (2026-03-24) ✓

- FeedItem.swift: enum FeedItem with 3 cases (moment, habitCheckin, streakMilestone); MomentFeedItem, HabitCheckinFeedItem, StreakMilestoneFeedItem structs; Identifiable + Sendable; sortTimestamp computed property
- FeedReaction.swift: Codable + Identifiable + Sendable; maps habit_reactions table via CodingKeys; static validEmojis [❤️, 🤲, 💪, 🌟, 🫶, ✨]
- FeedService.swift: @Observable @MainActor singleton; fetchFeedPage (merges activity_feed + circle_moments, resolves display names, sorts desc, paginates); fetchReactions (batch by item_id array); toggleReaction (add/replace/remove semantics)
- Private row types: ActivityFeedRow, CircleMomentRow, ProfileRow scoped to FeedService.swift
- Display name fallback: UUID prefix when profiles table unavailable
- BUILD SUCCEEDED, zero errors

### Phase 4, Plan 03: Reciprocity Gate + CircleDetailView Integration (2026-03-24) ✓

- MomentCardView: 3 states (locked with blur/lock.fill, unlocked with AsyncImage, own-unposted LinearGradient)
- Locked state: blur(radius:20) + lock.fill + "Post to unlock", onTapGesture opens camera
- On-time star badge: star.fill amber on top-right of unlocked cards where isOnTime == true
- CircleDetailView: import Supabase, Moment state (moments, showCamera, capturedImage, showPreview, windowSecondsRemaining, windowTimer)
- Amber "POST YOUR MOMENT" banner with MM:SS monospaced countdown, hidden when window not active
- Moments Section: 2-column LazyVGrid, reciprocity gate via hasPostedToday computed prop
- fullScreenCover -> MomentCameraView; sheet -> MomentPreviewView -> MomentService.postMoment -> refresh moments
- Window timer: ISO8601 parse, 1800s countdown, MainActor.assumeIsolated (Swift 6 safe)
- Auto-fixed: Timer closure param non-Sendable — use stored windowTimer ref instead
- BUILD SUCCEEDED, zero errors
- Known issue tabled: camera permission denied → "Open Settings" → return crashes (iOS 26.3 UIKit main-thread enforcement in re-entry path); affects edge case only; full fix deferred post-Phase 5

### Phase 4, Plan 02: Camera Capture UI (2026-03-24) ✓

- CameraManager: @Observable @MainActor NSObject, AVCaptureMultiCamSession + AVCaptureSession fallback
- checkPermission, setupSession, capturePhoto, compositeImages (25% front inset), stopSession
- AVCapturePhotoCaptureDelegate: nonisolated; ObjectIdentifier for Swift 6 actor-safe cross-actor dispatch
- MomentCameraView: full-screen camera, dual viewfinder, permission denied state, flash animation, shutter spring
- MomentPreviewView: photo review 3:4, caption input, Post Moment CTA with loading state, error handling
- CameraPreviewRepresentable (UIViewRepresentable) + CameraPreviewView (UIView with layoutSubviews)
- Auto-fixed: SwiftUI.Circle() qualification; ObjectIdentifier for non-Sendable actor-boundary crossing
- BUILD SUCCEEDED, zero errors
- **Post-checkpoint fix (2026-03-24):** Crash on first camera permission grant fixed:
  - Root cause 1: `setupSession()` called twice (from both `.onChange` and `.task` post-sleep) → AVFoundation abort on double session start
  - Root cause 2: Session config (`beginConfiguration`/`addInput`/`commitConfiguration`) was on `@MainActor`; `startRunning()` on background
  - Fix: moved ALL AVFoundation work to dedicated `sessionQueue` (nonisolated DispatchQueue); added `isSessionSetUp` guard; `checkPermission()` now calls `setupSession()` internally; `@preconcurrency import AVFoundation` for Swift 6 Sendable warnings
  - BUILD SUCCEEDED, zero errors (commit 2f282cd)

### Phase 4, Plan 01: Circle Moment Data Layer (2026-03-24) ✓

- CircleMoment.swift: Codable, Identifiable, Sendable — maps all 7 circle_moments table columns
- Circle.swift: added momentWindowStart: String? (→ moment_window_start TIMESTAMPTZ on circles table)
- MomentService.swift: @Observable @MainActor singleton — fetchTodayMoments, uploadPhoto, postMoment, computeIsOnTime
- Storage bucket: circle-moments, file path {circleId}/{userId}_{date}.jpg with upsert=true
- BUILD SUCCEEDED, zero errors

### Phase 3, Plan 02: Circles UI Layer (2026-03-24) ✓

- CirclesViewModel: @Observable @MainActor with loadCircles, createCircle, joinCircle, pendingCode
- CommunityView rewritten: My Circles list, empty state with Create/Join buttons, NavigationLink to detail, pull-to-refresh
- CreateCircleView: sheet form with name, description, prayer time wheel picker
- JoinCircleView: 8-char monospaced code entry, auto-uppercase, error display, pendingCode pre-fill
- CircleDetailView: circle info, invite code + ShareLink, async member list with Admin badge
- Auto-fixed: missing `import Supabase` in all views accessing auth.session?.user.id
- BUILD SUCCEEDED, zero errors

### Phase 3, Plan 01: Circle Data Layer (2026-03-24) ✓

- Circle.swift: Codable, Identifiable, Hashable, Sendable — mirrors halaqas table with invite_code and prayer_time
- HalaqaMember.swift: Codable, Identifiable, Sendable — mirrors halaqa_members table
- CircleService.swift: @Observable @MainActor singleton — fetchMyCircles (2-step query), createCircle, joinByInviteCode, fetchMembers
- Auto-fixed: qualified SwiftUI.Circle() in ProfileView and HabitDetailView to resolve naming collision
- BUILD SUCCEEDED, zero errors

### Phase 2, Plan 03: HomeViewModel + HomeView + HabitDetailView (2026-03-24) ✓

- HomeViewModel: @Observable @MainActor, parallel fetch habits/logs/streak, optimistic toggleHabit with revert
- HomeView: habit list with checkboxes, streak banner, NavigationLink to HabitDetailView, pull-to-refresh
- HabitDetailView: 28-day LazyVGrid dot calendar, direct Supabase date-range query, stat badges
- Habit model: added Hashable conformance for navigationDestination
- BUILD SUCCEEDED, zero errors
- Human verified: all 9 simulator checks passed

### Phase 2, Plan 02: Onboarding Flow (2026-03-24) ✓

- OnboardingCoordinator @Observable with step navigation and habit selection enforcement
- HabitSelectionView, RamadanAmountView, AIStepDownView
- ContentView routing: new users → onboarding, returning users → MainTabView
- UserDefaults flag for onboarding completion

### Phase 2, Plan 01: Habits Data Layer (2026-03-24) ✓

- Habit, HabitLog, Streak Codable models with full snake_case CodingKeys
- HabitService @Observable singleton: fetchActiveHabits, fetchTodayLogs, toggleHabitLog, fetchStreak, createHabit, updateAcceptedAmount
- GeminiService singleton: Gemini 2.0 Flash REST, AISuggestion decode, Secrets.plist key
- BUILD SUCCEEDED, zero errors
- Key fix: @Observable (not ObservableObject) — matches Swift 6 SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor

### Phase 1: Auth + Core Navigation Shell (2026-03-23) ✓

- Sign in with Apple + Google OAuth via Supabase
- AuthManager (@Observable @MainActor) with session persistence
- 3-tab navigation shell: Home / Community / Profile
- Styled empty states with Circles design system (#0D1021 navy, #E8834B amber)
- Verified end-to-end in Simulator (iPhone 17, iOS 26.3)
- Info.plist: REVERSED_CLIENT_ID + GIDClientID

### Repo Setup (2026-03-23) ✓

- Xcode 26.3 project at `~/Desktop/Circles`
- Bundle ID: `app.joinlegacy`
- Supabase Swift SDK v2.42.0 via SPM
- GitHub: https://github.com/AbdulsaboorS/circles-ios

## What's In Progress

Phase 06.1: UI Design System Foundation — COMPLETE (3/3 plans done). Next: Phase 06.2 (Core Screens Redesign).

## Phase History

| Phase | Status | Summary |
|-------|--------|---------|
| Setup | ✓ Complete | Xcode + SPM + GitHub |
| Phase 1 | ✓ Complete | Auth + 3-tab nav shell, verified in Simulator |
| Phase 2, Plan 01 | ✓ Complete | Habit/HabitLog/Streak models, HabitService, GeminiService |
| Phase 2, Plan 02 | ✓ Complete | Onboarding flow: HabitSelection, RamadanAmount, AIStepDown, ContentView routing |
| Phase 2, Plan 03 | ✓ Complete | HomeViewModel + HomeView + HabitDetailView; verified in Simulator |
| Phase 3, Plan 01 | ✓ Complete | Circle + HalaqaMember models, CircleService singleton, naming collision fix |
| Phase 3, Plan 02 | ✓ Complete | CirclesViewModel, CommunityView rewrite, CreateCircleView, JoinCircleView, CircleDetailView with ShareLink |
| Phase 3, Plan 03 | ✓ Complete | Deep links (circles://join/CODE), tab selection wiring, human verification passed |
| Phase 4, Plan 01 | ✓ Complete | CircleMoment model, Circle.momentWindowStart, MomentService singleton with Storage upload |
| Phase 4, Plan 02 | ✓ Complete | CameraManager (multi-cam + fallback), MomentCameraView, MomentPreviewView, compositing |
| Phase 4, Plan 03 | ✓ Complete | MomentCardView + CircleDetailView wired; camera permission edge case tabled |
| Phase 5, Plan 01 | ✓ Complete | FeedItem enum, FeedReaction model, FeedService (paginated fetch + reaction CRUD) |
| Phase 5, Plan 02 | ✓ Complete | FeedViewModel + all feed UI + CircleDetailView restructure; human-verified in Simulator |
| Phase 6, Plan 01 | ✓ Complete | NotificationService singleton, AppDelegate APNs adaptor, DeviceToken model, LocationPickerView onboarding step |
| Phase 6, Plan 02 | ✓ Complete | Supabase Edge Functions: APNs helper, Adhan prayer times, moment-window cron, member-posted trigger, streak-milestone, peer nudges |
| Phase 6, Plan 03 | 📋 Planned | Soft-prompt modal, Community tab badge, nudge buttons, notifications-denied note, human verification |
| Phase 06.1, Plan 01 | ✓ Complete | DesignTokens.swift (color + font tokens, semantic aliases) + ThemeManager (NOAA solar algorithm, ThemeMode enum) |
| Phase 06.1, Plan 02 | ✓ Complete | AppBackground.swift — dual-blob breathing background; @Environment colorScheme; BUILD SUCCEEDED |
| Phase 06.1, Plan 03 | ✓ Complete | AppCard, PrimaryButton, ChipButton, SectionHeader + AppIconView + ThemeManager wired into CirclesApp/ContentView/MainTabView; BUILD SUCCEEDED |

## Active Decisions

- Using Supabase for auth (Google OAuth + Sign in with Apple)
- Reusing Legacy web app Supabase project and tables
- Native SwiftUI — no Capacitor/WebView
- Secrets.plist for env vars (gitignored)
- @Observable @MainActor pattern (Swift 6 / iOS 17+)
- Service singletons use @Observable (not ObservableObject) — required by SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor
- Optional single-row fetch: limit(1).first (maybeSingle() absent from Supabase Swift SDK v2.42)
- DATE columns stored as String in Swift models to avoid timezone issues
- Capture @MainActor coordinator state before withTaskGroup (Swift 6 actor isolation — task closures are non-isolated)
- import Supabase required in every file accessing session?.user.id (Auth module not re-exported by SwiftUI)
- Circle model name shadows SwiftUI's Circle shape — qualify as SwiftUI.Circle() at all shape call sites
- New `circles` + `circle_members` tables (not Legacy `halaqas` — too many unknown constraints)
- Moment timing is platform-wide (BeReal-style) — no prayer_time on circles
- RLS recursion avoided via SECURITY DEFINER function `auth_user_circle_ids()`
- TIMESTAMPTZ columns (momentWindowStart, postedAt) stored as String in Swift models per date-as-string convention
- MomentService uses circle-moments storage bucket; file path: {circleId}/{userId}_{date}.jpg, upsert=true
- computeIsOnTime: checks now - windowStart < 1800 seconds (30 min); parses ISO8601 with/without fractional seconds
- AVCapturePhotoCaptureDelegate is nonisolated; ObjectIdentifier used to identify output across MainActor boundary (non-Sendable AVCapturePhotoOutput cannot be sent across actors)
- CameraPreviewView (UIView subclass) overrides layoutSubviews to keep AVCaptureVideoPreviewLayer frame in sync with bounds
- All AVFoundation session work runs on dedicated `nonisolated let sessionQueue = DispatchQueue(label:)` — never on MainActor/main thread; properties updated back to MainActor via `Task { @MainActor in }`
- `@preconcurrency import AVFoundation` used in CameraManager to treat AVFoundation Sendable errors as warnings (Apple hasn't fully annotated AVFoundation for Sendable yet)
- Timer.scheduledTimer callback uses MainActor.assumeIsolated (fires on main run loop) + windowTimer stored ref for invalidate — avoids sending non-Sendable Timer across actor boundary
- AppBackground uses @Environment(\\.colorScheme) directly (not ThemeManager) — works before ThemeManager is wired in; safe for Wave 1 parallel execution
- AppCard/SectionHeader/ChipButton use @Environment(\\.colorScheme) directly (not ThemeManager) — consistent pattern; avoids requiring ThemeManager in environment for isolated component use
- Blob animation: two ellipses with different durations (4s/5s) + 1.2s delay offset — never in sync, produces organic meditative feel
- Peer members with no Moment omitted from grid; own-unposted slot always shown
- MomentCardData local struct used in momentCards computed property to drive ForEach
- FeedViewModel per-view @State (not singleton) — each CircleDetailView owns its feed state
- @Bindable FeedViewModel passed to all feed card views for optimistic reaction updates
- MomentFeedCard.isLocked: !hasPostedToday && item.userId != currentUserId (own posts always visible)
- checkedInCount hardcoded to 0 in CircleDetailView Phase 5; activity_feed-based count deferred
- ZStack + VStack requires .frame(maxWidth:.infinity, maxHeight:.infinity, alignment:.top) to prevent ScrollView height collapse (confirmed pattern)
- Phase 6 push notifications: full server-side APNs via Supabase Edge Functions (no local notifications)
- APNs JWT built with Web Crypto API ECDSA P-256 (ES256) — no third-party APNs library in Deno
- Prayer time server-side: pure TS Adhan port, Muslim World League constants (MWL_FAJR_ANGLE=18.0, MWL_ISHA_ANGLE=17.0)
- Moment-window cron runs every minute; fires push only within ±2 min of user's prayer time
- Member-posted notification: post-reciprocity-gate — only notifies users who already posted today
- Peer nudge rate limit: nudge_log UNIQUE(sender_id, target_id, nudge_date); 23505 unique violation → 429 response
- APNs device tokens stored in new `device_tokens` Supabase table (user_id, device_token, created_at)
- Prayer time calculation: Adhan Swift library (batoulapps/adhan-swift) via SPM — offline, no API key
- Location stored server-side (city + timezone + lat/lng) — set in onboarding city picker, no CLLocationManager
- Notification permission: soft-prompt modal on first circle join → then iOS system requestAuthorization()
- Community tab badge: local unreadCount in NotificationService, clears on tab open
- Peer nudge rate limit: nudge_log table UNIQUE(sender_id, target_id, nudge_date) — 1 nudge/sender/recipient/day
- Adhan Swift SPM NOT in iOS project — only TS Adhan port used in Edge Functions; ThemeManager uses pure Swift NOAA solar calculator
- DesignTokens.swift uses static Color extensions + AppColors resolver (no xcassets Color Sets — incompatible with programmatic switching)
- ThemeManager uses .preferredColorScheme() at root ContentView; D-07 semantic static aliases default to dark, adaptive via AppColors.resolve(colorScheme)

## Accumulated Context

### Roadmap Evolution

- Phase 06.1 inserted after Phase 6: UI Design System Foundation — color tokens, typography (New York serif + SF Pro), reusable components, app icon, sunrise/sunset auto dark mode
- Phase 06.2 inserted after Phase 6: Core Screens Redesign — HomeView, CommunityView (My Circles + Public Explore), CircleDetailView, FeedView; adds is_public to circles schema
- Phase 06.3 inserted after Phase 6: Secondary Screens Redesign — Profile, Onboarding, Camera/Moment, HabitDetailView (heatmap + notes journal + AI plan), loading/empty/error states, polish pass
- Phase 7 (App Store Polish + Submission) remains as final phase, to be executed after 06.3

### UI Redesign Design Direction (2026-03-24)

- Dark mode: deep near-black background + forest green organic blob shapes + glassmorphism cards + amber/gold CTA accent
- Light mode: warm cream background + warm beige blob shapes + white cards + same amber accent
- Typography: New York serif for greeting headers, SF Pro for body
- Habit detail chip → 28-day heatmap + notes journal + AI step-down plan (notes field on habit_logs)
- Community tab: My Circles + Public Explore (is_public flag on circles, bubble/card browse layout)
- Dark/light mode: auto-switch at user's sunrise/sunset (using Adhan + stored lat/lng from Phase 6), manual toggle in Settings
- Islamic illustrations: to be sourced by user before Phase 06.2; SF Symbol placeholders until then
- App icon redesign: part of Phase 06.1

## Blockers

None.

---
- `import Supabase` required in every view accessing `auth.session?.user.id` — confirmed pattern, added to active decisions
- `.environment(auth)` must be passed explicitly when presenting sheets (does not propagate automatically)

*Last updated: 2026-03-24 (Phase 6 Plan 02 complete — Edge Functions built; Plan 06-03 UI integration remains)*
