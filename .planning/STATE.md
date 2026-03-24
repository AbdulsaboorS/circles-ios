# Circles iOS — State

## Current Phase

**Phase 2: Habits + Daily Check-in** — COMPLETE (3/3 plans done; all verified in Simulator)

## What's Done

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

Phase 3: Circles (Create, Join, Member View) — not yet started.

## Phase History

| Phase | Status | Summary |
|-------|--------|---------|
| Setup | ✓ Complete | Xcode + SPM + GitHub |
| Phase 1 | ✓ Complete | Auth + 3-tab nav shell, verified in Simulator |
| Phase 2, Plan 01 | ✓ Complete | Habit/HabitLog/Streak models, HabitService, GeminiService |
| Phase 2, Plan 02 | ✓ Complete | Onboarding flow: HabitSelection, RamadanAmount, AIStepDown, ContentView routing |
| Phase 2, Plan 03 | ✓ Complete | HomeViewModel + HomeView + HabitDetailView; verified in Simulator |

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

## Blockers

None.

---
*Last updated: 2026-03-23*
