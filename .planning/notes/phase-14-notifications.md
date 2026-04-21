# Phase 14 Notifications

## Goal

Implement the notifications phase in an isolated workstream.

## Scope

This branch owns notification-related architecture, implementation, and validation.

This branch should avoid unrelated Phase 13 follow-up fixes unless they directly block notification work.

## Touched Files

- `.planning/notes/phase-14-notifications.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/14-notifications/README.md`
- `.planning/phases/14-notifications/14-CONTEXT.md`
- `.planning/phases/14-notifications/notification_preferences.sql`
- `supabase/functions/send-moment-window-notifications/index.ts`
- `Circles/Models/NotificationPreferences.swift`
- `Circles/Services/NotificationPreferencesService.swift`
- `Circles/Notifications/AppNotificationType.swift`
- `Circles/Notifications/AppNotificationRoute.swift`
- `Circles/Notifications/NotificationPayload.swift`
- `Circles/Notifications/NotificationSettingsView.swift`
- `Circles/Services/NotificationService.swift`
- `Circles/CirclesApp.swift`
- `Circles/ContentView.swift`
- `Circles/Navigation/MainTabView.swift`
- `Circles/Notifications/NotificationPermissionModal.swift`
- `Circles/Onboarding/AmiirStep3LocationView.swift`
- `Circles/Community/CommunityView.swift`
- `Circles/Profile/ProfileView.swift`

## Decisions

- Notifications work will run in a dedicated git worktree on its own branch
- Branch-local continuity for this stream lives in this file
- Active worktree path: `/Users/abdulsaboorshaikh/Desktop/Circles/.claude/worktrees/phase-14-notifications`
- Existing notification foundation already includes permission requests, APNs registration, and `device_tokens` upsert
- Phase numbering is normalized so Notifications is now Phase 14 in planning docs
- Phase 14 docs should carry the full product spec and subphase boundaries before implementation plans are written
- Phase 14.1 stores preferences in a dedicated `notification_preferences` table
- `moment_window` routing lands on the Circles tab, not Home
- The shared `NotificationPermissionModal` is now the canonical soft-ask UI
- Phase 14.1 fully enforces `moment_window` toggles in the edge function; the other toggles are persisted now and enforced later

## Verified

- Branch note created
- Shared workflow docs created in `.planning/`
- Worktree created on branch `phase-14-notifications`
- Worktree is clean and isolated from the dirty main checkout
- Phase 14 planning docs created and linked from roadmap/state
- Phase 14.1 implementation is in progress and build-verified with:
  - typed notification payload parsing and routing
  - app-level preferences model/service
  - Notification Settings screen in Profile settings
  - authenticated notification bootstrap in `ContentView`
  - shared modal reused in Community and onboarding
  - backend filtering for `moment_window`
- `xcodebuild -quiet -project Circles.xcodeproj -scheme Circles -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' build` succeeded

## Next

- Manual simulator verification for the new settings flow and soft-ask flow
- Run the SQL helper in Supabase before relying on the new preferences table
- Decide whether to start Phase 14.2 next or polish/test 14.1 more deeply first

## Blockers

- None currently

## Notes For Re-entry

- Start every session by confirming the worktree path, active branch, and `git status`
- Existing entry points to inspect first: `NotificationService`, `CirclesApp`, onboarding permission UI, and any settings/profile notification surfaces
- Phase 14 spec now lives under `.planning/phases/14-notifications/`
- The current branch includes repo-planned but not-yet-deployed backend changes in `send-moment-window-notifications`
