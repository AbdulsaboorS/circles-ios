---
phase: 01-auth-navigation-shell
plan: 01
status: complete
completed: 2026-03-23
---

# Summary: Auth + Core Navigation Shell

## One-liner
Production-ready auth (Sign in with Apple + Google OAuth) with session persistence and styled 3-tab navigation shell — verified end-to-end in Simulator.

## What Was Built
- `SupabaseService` singleton loading credentials from `Secrets.plist`
- `AuthManager` — `@Observable @MainActor` session state, `authStateChanges` stream, `signOut()`
- `AuthView` — dark navy sign-in screen with Apple + Google buttons
- `MainTabView` — Home / Community / Profile tab bar, amber tint (#E8834B)
- `HomeView` — time-of-day Islamic greeting, firstName from userMetadata
- `CommunityView` — empty state with serif title + amber icon
- `ProfileView` — shows user email, functional Sign Out
- `ContentView` — auth router (loading → spinner, auth → MainTabView, unauth → AuthView)
- `CirclesApp` — `@State private var authManager = AuthManager()`, `.environment(authManager)`
- `Color+Hex` extension for design system colors
- `Info.plist` — `REVERSED_CLIENT_ID` URL scheme + `GIDClientID` for Google Sign-In

## Fixes Applied During Verification
- `Secrets.plist` SUPABASE_URL was missing `https://` prefix — fixed to full URL
- `Info.plist` was missing `GIDClientID` key — added `211096154573-pgqg7br0jpu9s0ngdmqhuo0dm91ft7i6.apps.googleusercontent.com`

## Verification Results (Wave 5)
- [x] App launches with spinner, no auth flash
- [x] AuthView shows Apple + Google buttons
- [x] Sign in with Apple → tab bar
- [x] Google Sign-In → tab bar
- [x] Kill + relaunch while authenticated → skips auth
- [x] Tab bar: Home / Community / Profile with styled empty states
- [x] Sign Out from Profile works
- [x] Zero build errors

## Build
Succeeded — iPhone 17 simulator, iOS 26.3
