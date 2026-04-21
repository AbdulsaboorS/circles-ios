# Phase 15 Social Pulse

## Goal

Implement the social pulse / notifications phase in an isolated workstream.

## Scope

This branch owns social pulse notification-related architecture, implementation, and validation.

This branch should avoid unrelated Phase 13 follow-up fixes unless they directly block notification work.

## Touched Files

- `.planning/notes/phase-15-social-pulse.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/15-social-pulse/README.md`
- `.planning/phases/15-social-pulse/14-CONTEXT.md`
- `.planning/phases/15-social-pulse/notification_preferences.sql`
- `supabase/functions/send-moment-window-notifications/index.ts`
- `supabase/functions/send-peer-nudge/index.ts`
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
- Active worktree path: `/Users/abdulsaboorshaikh/Desktop/Circles/.claude/worktrees/phase-15-social-pulse`
- Existing notification foundation already includes permission requests, APNs registration, and `device_tokens` upsert
- Phase numbering is normalized so Social Pulse is now Phase 15 in planning docs
- Phase 15 docs should carry the full product spec and subphase boundaries before implementation plans are written
- Phase 15.1 stores preferences in a dedicated `notification_preferences` table
- `moment_window` routing lands on the Circles tab, not Home
- The shared `NotificationPermissionModal` is now the canonical soft-ask UI
- Phase 15.1 fully enforces `moment_window` toggles in the edge function; the other toggles are persisted now and enforced later
- Phase 15.2 now normalizes the nudge payload type to `nudge` and respects target-side notification preferences before sending
- Phase 15.2 now routes nudge taps explicitly by payload, uses `preferred_name` in push copy, and includes custom nudge messages in the delivered notification body

## Verified

- Branch note created
- Shared workflow docs created in `.planning/`
- Worktree created on branch `phase-15-social-pulse`
- Worktree is clean and isolated from the dirty main checkout
- Phase 15 planning docs created and linked from roadmap/state
- Phase 15.1 implementation is in progress and build-verified with:
  - typed notification payload parsing and routing
  - app-level preferences model/service
  - Notification Settings screen in Profile settings
  - authenticated notification bootstrap in `ContentView`
  - shared modal reused in Community and onboarding
  - backend filtering for `moment_window`
- Phase 15.2 nudge foundation is in progress and build-verified with:
  - canonical `nudge` payload type support in app routing
  - target-side notification preference gating in `send-peer-nudge`
  - daily quota is only consumed when the nudge is deliverable
  - custom nudge copy now reaches APNs
  - nudge payloads can override the destination tab via `route`
- `xcodebuild -quiet -project Circles.xcodeproj -scheme Circles -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' build` succeeded

## Next

- User verification pass for Phase 15.1 and 15.2:
  - run the `notification_preferences` SQL in Supabase if not already applied
  - verify settings + soft-ask flow
  - verify received nudge push delivery, copy, badge, and tap routing
- Remaining code work for the rest of Phase 15:
  1. Phase 15.3 — Circle check-in notifications
     Add the backend producer path for circle activity push, define low-noise summary/cap rules, and send payloads with explicit route/context.
  2. Phase 15.3 — App-side handling
     Confirm `circle_check_in` payloads route cleanly into Circles/feed context and badge behavior feels correct when foregrounded or tapped.
  3. Phase 15.4 — Habit reminder scheduler
     Build local scheduling logic, prayer-aware defaults for prayer habits, simple default timing for non-prayer habits, and cancellation/reschedule on habit completion.
  4. Phase 15.4 — Preference enforcement
     Apply `habit_reminders_enabled` to scheduling paths and confirm reminders stop when the master toggle or reminder toggle is off.
  5. Phase 15 end-of-phase hardening
     Real-device verification of all active notification families, copy/tone pass across every payload, and final cleanup of any delivery/routing regressions found during testing.

## Blockers

- None currently

## Notes For Re-entry

- Start every session by confirming the worktree path, active branch, and `git status`
- Existing entry points to inspect first: `NotificationService`, `CirclesApp`, onboarding permission UI, and any settings/profile notification surfaces
- Phase 15 spec now lives under `.planning/phases/15-social-pulse/`
- The current branch includes repo-planned but not-yet-deployed backend changes in `send-moment-window-notifications`
