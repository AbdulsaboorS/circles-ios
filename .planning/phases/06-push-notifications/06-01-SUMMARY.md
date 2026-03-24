---
phase: 06-push-notifications
plan: 01
subsystem: ios/notifications+onboarding
tags: [push-notifications, apns, device-tokens, onboarding, location, prayer-times, swift]
dependency_graph:
  requires:
    - 05-02 (CircleDetailView, onboarding complete, ContentView routing)
  provides:
    - NotificationService singleton (requestPermission, handleToken, refreshPermissionStatus)
    - DeviceToken Codable model mapping device_tokens table
    - AppDelegate APNs token callback wired via UIApplicationDelegateAdaptor
    - LocationPickerView onboarding step (city + timezone + lat/lng)
    - OnboardingCoordinator location fields and saveLocationAndMarkComplete()
  affects:
    - 06-02 (device_tokens table populated by iOS pipeline; profiles.latitude/longitude available for prayer time calc)
    - 06-03 (NotificationService.requestPermission() called from soft-prompt modal)
tech_stack:
  added:
    - UserNotifications framework (UNUserNotificationCenter, UNAuthorizationStatus)
    - UIApplicationDelegateAdaptor pattern (UIApplicationDelegate in SwiftUI App)
  patterns:
    - nonisolated(unsafe) static weak var for AppDelegate → @MainActor bridge (AuthManager.sharedForAPNs)
    - SQL migration documented as comments in Swift files (not run by agent — developer runs via Dashboard)
    - Bundled city list (50 cities, offline, no API) for prayer time location selection
key_files:
  created:
    - Circles/Circles/Models/DeviceToken.swift
    - Circles/Circles/Services/NotificationService.swift
    - Circles/Circles/Onboarding/LocationPickerView.swift
  modified:
    - Circles/Circles/CirclesApp.swift (AppDelegate + UIApplicationDelegateAdaptor + onAppear wiring)
    - Circles/Circles/Auth/AuthManager.swift (nonisolated(unsafe) static weak var sharedForAPNs)
    - Circles/Circles/Onboarding/OnboardingCoordinator.swift (Step.locationPicker, location fields, proceedToLocation, saveLocationAndMarkComplete)
    - Circles/Circles/Onboarding/AIStepDownView.swift (Save button calls proceedToLocation after finishOnboarding)
    - Circles/Circles/ContentView.swift (locationPicker case in navigationDestination switch)
decisions:
  - "UIApplicationDelegateAdaptor used over onReceive(NotificationCenter) — required for didRegisterForRemoteNotificationsWithDeviceToken"
  - "nonisolated(unsafe) static weak var sharedForAPNs on AuthManager bridges AppDelegate (non-actor) to @MainActor session access"
  - "Bundled 50-city list (offline) preferred over CLLocationManager or geocoding API per D-15 decision"
  - "saveLocationAndMarkComplete() is separate from finishOnboarding() — habits saved from AIStepDownView, location saved from LocationPickerView as final step"
metrics:
  duration_minutes: 12
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 5
  completed_date: "2026-03-24"
---

# Phase 6 Plan 01: iOS APNs Pipeline + City Picker Onboarding — Summary

APNs device token registration pipeline wired end-to-end in iOS with NotificationService singleton, UIApplicationDelegate adaptor in CirclesApp, and Supabase device_tokens upsert; city picker added as final onboarding step storing lat/lng/timezone to Supabase profiles.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | NotificationService + DeviceToken model + APNs AppDelegate adaptor | 98550b7 | DeviceToken.swift, NotificationService.swift, AuthManager.swift, CirclesApp.swift |
| 2 | City picker onboarding step + OnboardingCoordinator location fields | 983ee25 | LocationPickerView.swift, OnboardingCoordinator.swift, AIStepDownView.swift, ContentView.swift |

## What Was Built

### Task 1: APNs Registration Pipeline

**DeviceToken.swift** — Codable struct mapping `device_tokens` table (user_id, device_token, created_at). Snake_case CodingKeys per project convention.

**NotificationService.swift** — `@Observable @MainActor` singleton with:
- `refreshPermissionStatus()` — reads current UNAuthorizationStatus without prompting
- `requestPermission()` — shows iOS system prompt, calls `registerForRemoteNotifications()` if granted
- `handleToken(_:userId:)` — converts Data to hex string, upserts to Supabase `device_tokens` table
- SQL migration for `device_tokens` table documented as comments at top of file

**CirclesApp.swift** — Added `UIApplicationDelegateAdaptor(AppDelegate.self)`. AppDelegate implements `didRegisterForRemoteNotificationsWithDeviceToken` routing to `NotificationService.shared.handleToken`. Added `.onAppear { AuthManager.sharedForAPNs = authManager }` to wire the AppDelegate → AuthManager bridge.

**AuthManager.swift** — Added `nonisolated(unsafe) static weak var sharedForAPNs: AuthManager?` to allow AppDelegate (a non-isolated class) to read the current session user ID for the APNs token upload.

### Task 2: Location Onboarding Step

**LocationPickerView.swift** — SwiftUI view with:
- Searchable `List` of 50 bundled cities (name, country, IANA timezone, lat, lng)
- Filters by city name or country code
- On selection: sets coordinator fields, calls `saveLocationAndMarkComplete(userId:)`
- Error alert for Supabase upsert failures

**OnboardingCoordinator.swift** — Extended with:
- `Step.locationPicker` enum case (final onboarding step)
- `cityName`, `cityTimezone`, `cityLatitude`, `cityLongitude` stored properties
- `proceedToLocation()` — appends `.locationPicker` to navigationPath
- `saveLocationAndMarkComplete(userId:)` — upserts location to Supabase `profiles` table (city_name, timezone, latitude, longitude) then calls `markComplete`
- SQL migration for profiles columns documented as comments
- `finishOnboarding` no longer calls `markComplete` — completion deferred to location step

**AIStepDownView.swift** — Updated "Save My Habits" button: after `finishOnboarding` succeeds (errorMessage == nil), calls `coordinator.proceedToLocation()` to push the city picker.

**ContentView.swift** — Added `case .locationPicker: LocationPickerView()` to `navigationDestination` switch.

## Deviations from Plan

### Auto-fixed Issues

None.

### Implementation Notes

1. **`requestPermission()` simplified**: Plan showed `await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }` inside an already-`@MainActor` method. Since the whole class is `@MainActor`, the inner `MainActor.run` is redundant — simplified to a direct call.

2. **`proceedToLocation()` after `finishOnboarding`**: Plan described `finishOnboardingWithLocation()` as a hypothetical method name but then clarified using a simpler `saveLocationAndMarkComplete(userId:)` approach. The final implementation uses that simpler pattern exactly.

## Known Stubs

None — all data paths are wired. Note: the `device_tokens` and `profiles` SQL migrations need to be run by the developer in the Supabase Dashboard before these features can function end-to-end.

## SQL Migrations Required (Developer Action)

Two SQL migrations must be run in Supabase Dashboard before Phase 6 is functional:

1. **device_tokens table** (documented in `NotificationService.swift`):
   ```sql
   CREATE TABLE IF NOT EXISTS device_tokens (
     id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
     user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
     device_token text NOT NULL,
     created_at   timestamptz DEFAULT now(),
     UNIQUE(user_id, device_token)
   );
   ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
   CREATE POLICY "Users manage own tokens"
     ON device_tokens FOR ALL
     USING (auth.uid() = user_id)
     WITH CHECK (auth.uid() = user_id);
   ```

2. **profiles table columns** (documented in `OnboardingCoordinator.swift`):
   ```sql
   ALTER TABLE profiles
     ADD COLUMN IF NOT EXISTS city_name text,
     ADD COLUMN IF NOT EXISTS timezone text,
     ADD COLUMN IF NOT EXISTS latitude double precision,
     ADD COLUMN IF NOT EXISTS longitude double precision;
   ```

## Self-Check: PASSED

- FOUND: Circles/Models/DeviceToken.swift
- FOUND: Circles/Services/NotificationService.swift
- FOUND: Circles/Onboarding/LocationPickerView.swift
- FOUND commit: 98550b7 (Task 1)
- FOUND commit: 983ee25 (Task 2)
- BUILD SUCCEEDED with zero errors
