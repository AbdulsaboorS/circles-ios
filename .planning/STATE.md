# Circles iOS — State

## Current Phase

**Phase 1: Auth + Core Navigation Shell** — Wave 5 (human verification pending)

## What's Done

### Repo Setup (2026-03-23)
- Xcode 26.3 project created at `~/Desktop/Circles`
- SwiftUI, Swift, iOS 17+ target
- Bundle ID: `app.joinlegacy`
- Supabase Swift SDK installed via SPM
- `.gitignore` configured
- GitHub repo `circles-ios` created: https://github.com/AbdulsaboorS/circles-ios
- GSD planning structure initialized: PROJECT.md, ROADMAP.md, STATE.md, CLAUDE.md

### Files in Xcode project (from Initial Commit)
- `Circles/CirclesApp.swift` — entry point
- `Circles/ContentView.swift` — placeholder "Hello World"
- `Circles/Assets.xcassets` — default assets

## What's In Progress

**Phase 1 — Waves 1-4 complete, awaiting Wave 5 human verification in Simulator.**

Files written:
- `Circles/Services/SupabaseService.swift`
- `Circles/Auth/AuthManager.swift`
- `Circles/Auth/AuthView.swift`
- `Circles/Navigation/MainTabView.swift`
- `Circles/Home/HomeView.swift`
- `Circles/Community/CommunityView.swift`
- `Circles/Profile/ProfileView.swift`
- `Circles/Extensions/Color+Hex.swift`
- `Circles/ContentView.swift` (replaced)
- `Circles/CirclesApp.swift` (replaced)
- `Circles/Info.plist` (REVERSED_CLIENT_ID added)

Build: SUCCEEDED (iPhone 17 simulator, iOS 26)

## Phase History

| Phase | Status | Summary |
|-------|--------|---------|
| Setup | ✓ Complete | Xcode + SPM + GitHub |

## Active Decisions

- Using Supabase for auth (Google OAuth + Sign in with Apple)
- Reusing Legacy web app Supabase project and tables
- Native SwiftUI — no Capacitor/WebView
- Secrets.plist for env vars (gitignored via `.gitignore`)

## Blockers

None currently.

---
*Last updated: 2026-03-23*
