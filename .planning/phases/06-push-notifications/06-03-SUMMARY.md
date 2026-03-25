---
phase: 06-push-notifications
plan: 03
subsystem: ios/notifications+ui
tags: [push-notifications, permission-prompt, tab-badge, nudge, onboarding, swift]
dependency_graph:
  requires:
    - 06-01 (NotificationService singleton, requestPermission, permissionStatus, unreadCount)
    - 06-02 (send-peer-nudge Edge Function endpoint)
  provides:
    - NotificationPermissionModal soft-prompt sheet
    - CirclesViewModel.shouldShowPermissionPrompt trigger (first circle join/create)
    - MainTabView Community tab badge from NotificationService.unreadCount
    - CircleDetailView nudge buttons (Moment + Habit) + notifications-denied inline note
    - ProfileSetupView (name + gender — added during verification phase)
    - Dev tools: reset account button + test badge button in ProfileView
key_files:
  created:
    - Circles/Circles/Notifications/NotificationPermissionModal.swift
    - Circles/Circles/Onboarding/ProfileSetupView.swift
  modified:
    - Circles/Circles/Circles/CirclesViewModel.swift (shouldShowPermissionPrompt)
    - Circles/Circles/Navigation/MainTabView.swift (Community badge + clearUnread on tab switch)
    - Circles/Circles/Circles/CommunityView.swift (NotificationPermissionModal sheet)
    - Circles/Circles/Circles/CircleDetailView.swift (nudge buttons, notifications-off note, contentShape fix)
    - Circles/Circles/Services/NotificationService.swift (unreadCount, incrementUnread, clearUnread)
    - Circles/Circles/Profile/ProfileView.swift (dev reset + test badge buttons)
    - Circles/Circles/Onboarding/OnboardingCoordinator.swift (fullName, gender, Step.habitSelection, ProfileSetupView routing)
    - Circles/Circles/ContentView.swift (ProfileSetupView as root, habitSelection destination)
    - Circles/Circles/Services/HabitService.swift (upsert instead of insert — duplicate constraint fix)
decisions:
  - "NotificationPermissionModal fires only when circles.count == 1 (first circle) and permissionStatus == .notDetermined"
  - "unreadCount is local (NotificationService) — server-side unread tracking deferred post-Phase 6"
  - "ProfileSetupView added as first onboarding screen to collect name + gender before habit selection"
  - "HabitService.createHabit changed to upsert(onConflict: user_id,name) — supports onboarding re-runs without constraint violation"
  - "profiles.gender check constraint requires 'Brother'/'Sister' (capitalized) — app stores capitalized values"
  - "profiles.preferred_name is the correct column (not full_name) — mapped accordingly"
  - "contentShape(Rectangle()) added to members row button — fixes sparse tap target in SwiftUI plain button"
metrics:
  tasks_completed: 3
  tasks_total: 3
  files_created: 2
  files_modified: 9
  completed_date: "2026-03-24"
---

# Phase 6 Plan 03: Push Notification UI Layer — Summary

Notification UX wired end-to-end: soft-prompt modal on first circle join, Community tab badge, peer nudge buttons in member list, notifications-denied inline note. Onboarding extended with name/gender profile setup screen. Habit duplicate constraint bug fixed. All Supabase migrations run via MCP.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | NotificationPermissionModal + CirclesViewModel trigger + MainTabView badge | 3cb8995 | NotificationPermissionModal.swift, NotificationService.swift, CirclesViewModel.swift, MainTabView.swift, CommunityView.swift |
| 2 | Nudge buttons in CircleDetailView + notifications-off note | 48ac5e6 | CircleDetailView.swift |
| 3 (checkpoint) | Human verification + fixes | dc3d0a4, 89ced04, 6037666 | ProfileView.swift, CircleDetailView.swift, ProfileSetupView.swift, OnboardingCoordinator.swift, HabitService.swift, ContentView.swift |

## What Was Built

### NotificationPermissionModal
Full-screen soft-prompt sheet on navy (#0D1021) background. Bell icon, "Never Miss Your Moment" headline, prayer-time-aware body copy. "Enable Notifications" CTA calls `NotificationService.shared.requestPermission()`. "Not now" dismisses. Fires exactly once — after first circle join/create when `circles.count == 1` and status is `.notDetermined`.

### MainTabView Badge
`NotificationService.shared.unreadCount` drives `.badge()` on Community tab item. `.onChange(of: selectedTab)` clears badge to 0 when tab 1 is opened. `clearUnread()` also resets the system app badge via `UNUserNotificationCenter.setBadgeCount(0)`.

### CircleDetailView Nudge Buttons
"Moment" and "Habit" amber pill buttons rendered per non-self member in MembersListView. Tapping invokes `send-peer-nudge` Supabase Edge Function via `SupabaseService.shared.client.functions.invoke(...)`. 429 rate-limit errors (1 nudge/sender/target/day) handled silently. `contentShape(Rectangle())` fix applied to members row button to make full row tappable.

### Notifications-off Inline Note
`bell.slash.fill` + "Notifications off — turn on in Settings to get Moment alerts" shown in CircleDetailView when `permissionStatus == .denied`. `refreshPermissionStatus()` called in `.task` alongside member/feed load.

### ProfileSetupView (Added During Verification)
New first onboarding screen: name text field + Brother/Sister gender chips. Both required before "Continue" enables. Saves to `profiles.preferred_name` + `profiles.gender` (capitalized, matching DB check constraint) via `saveLocationAndMarkComplete`. ContentView updated: `ProfileSetupView` is now the navigation root; `HabitSelectionView` is a pushed destination via `Step.habitSelection`.

### HabitService Upsert Fix
`createHabit` changed from `.insert()` to `.upsert(onConflict: "user_id,name")` — eliminates `habits_user_name_unique` violation when user re-runs onboarding.

### Dev Tools (ProfileView)
"Reset Account (re-run onboarding)" — clears `onboardingComplete_<userId>` UserDefaults key + signs out. "Test Badge +1" — calls `NotificationService.shared.incrementUnread()` for badge testing without real APNs push. Both wrapped in `#if DEBUG`.

## Supabase Migrations Run (via MCP)

| Migration | Status |
|-----------|--------|
| CREATE TABLE device_tokens (RLS enabled) | ✅ Applied |
| CREATE TABLE nudge_log (UNIQUE sender/target/date) | ✅ Applied |
| ALTER TABLE profiles ADD city_name, timezone, latitude, longitude | ✅ Applied |

## Verification Status

| Item | Status | Notes |
|------|--------|-------|
| 1. Onboarding city picker | ✅ Passed | Tested via dev reset flow; ProfileSetupView → habits → city picker |
| 2. Soft-prompt modal | ⏳ Not retested | Requires fresh account (existing user already has circles) |
| 3. Community tab badge | ✅ Passed | "Test Badge +1" dev button confirmed badge + clear on tab switch |
| 4. Nudge buttons | ✅ Fixed | contentShape fix applied; not retested post-fix |
| 5. Notifications-off note | ⏳ Not retested | Requires denying notifications in iOS Settings |

## Self-Check: PASSED

- BUILD SUCCEEDED with zero errors
- NotificationPermissionModal.swift exists
- ProfileSetupView.swift exists
- shouldShowPermissionPrompt in CirclesViewModel
- unreadCount in MainTabView
- send-peer-nudge call in CircleDetailView
- Supabase migrations confirmed via MCP list_tables
