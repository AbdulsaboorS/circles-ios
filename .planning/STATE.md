# Circles iOS — State

## Current Phase

**Phase 3: Circles (Create, Join, Member View)** — COMPLETE (3/3 plans done; all 6 simulator checks passed)

## What's Done

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

Phase 4: Circle Moment (Camera, Post, Reciprocity Gate) — not yet started.

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

## Blockers

None.

---
- `import Supabase` required in every view accessing `auth.session?.user.id` — confirmed pattern, added to active decisions
- `.environment(auth)` must be passed explicitly when presenting sheets (does not propagate automatically)

*Last updated: 2026-03-24*
