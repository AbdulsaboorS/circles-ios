# Phase 15 — Social Pulse
# CONTEXT — Product + Codebase Plan

**Gathered:** 2026-04-19
**Status:** Ready for detailed implementation planning
**Source:** Conversation alignment session + current codebase audit

**Roadmap note:** Notifications was intentionally renumbered into Phase 15 during the parallel-worktree setup. The previous Naming + Branding phase moved to Phase 14 so future agents do not plan against stale numbering.

---

<domain>
## Phase Boundary

Phase 15 owns the app's notification system.

This phase includes:
- notification permissions UX
- APNs registration reliability
- notification type modeling
- notification settings
- remote push handling
- local habit reminder scheduling
- notification tap routing

This phase does not yet include:
- notification inbox / history UI
- manual per-habit reminder setup
- very granular notification preference controls

</domain>

<current_state>
## What Already Exists

### Notification Foundation Already In Repo

`Circles/Services/NotificationService.swift`
- tracks `permissionStatus`
- requests notification permission
- registers for remote notifications after grant
- uploads device tokens to Supabase `device_tokens`
- maintains a local `unreadCount` and badge clear path

`Circles/CirclesApp.swift`
- installs `UNUserNotificationCenter` delegate
- handles APNs token success/failure callbacks
- forwards token upload through `NotificationService`
- handles remote notifications with type `moment_window`
- refreshes `DailyMomentService` when `moment_window` is received in foreground or on tap

`Circles/Onboarding/AmiirStep3LocationView.swift`
- already includes a soft-ask path for notifications
- already supports denied-state recovery via iOS Settings deep-link

`Circles/Notifications/NotificationPermissionModal.swift`
- polished permission prompt UI already exists
- needs confirmation on whether it should remain, replace onboarding soft-ask UI, or be reused elsewhere

### Notification-Adjacent Surfaces Already In Repo

`Circles/Circles/CirclesViewModel.swift`
- refreshes notification permission state when a user's first circle is created or joined
- sets `shouldShowPermissionPrompt` when authorization is `notDetermined`

`Circles/Circles/CircleDetailView.swift`
- already renders a denied-notification note when permission is denied

### Existing Backend / Infra State

- `device_tokens` table exists and is active
- moment-window edge function and cron are already deployed
- `daily_moments.moment_time` already exists and is used for the global daily window timing

</current_state>

<gaps>
## Major Gaps To Close

### 1. Notification Product Model Is Incomplete
- only `moment_window` is concretely recognized in app code
- no formal app-level notification type enum or payload model yet

### 2. Settings Surface Is Missing
- no full user-facing notification settings screen exists yet
- current notification UX is mostly onboarding-time or inline recovery copy

### 3. Tap Routing Is Too Narrow
- only `moment_window` behavior is handled
- no centralized router for future notification types

### 4. Preference Storage Is Missing
- no app-level persisted per-user notification preference model yet

### 5. Nudge / Circle Activity / Habit Reminder Flows Are Not Built
- no complete notification pipeline exists yet for:
  - nudges
  - circle check-in summaries
  - personalized habit reminders

</gaps>

<codebase_plan>
## Concrete Codebase Plan

### Existing Files Likely To Be Modified

Foundation / lifecycle:
- `Circles/Services/NotificationService.swift`
- `Circles/CirclesApp.swift`
- `Circles/ContentView.swift` if centralized routing needs app-root integration

Notification UI:
- `Circles/Notifications/NotificationPermissionModal.swift`
- `Circles/Profile/ProfileView.swift` for settings entry or notification controls
- `Circles/Circles/CircleDetailView.swift` if denied-state messaging is refined

Onboarding / permission soft ask:
- `Circles/Onboarding/AmiirStep3LocationView.swift`
- `Circles/Circles/CirclesViewModel.swift`

Feature integration:
- `Circles/Home/`
- `Circles/Community/`
- `Circles/Circles/`
- `Circles/Feed/`
- `Circles/Services/NudgeService.swift`
- habit-related services and views for reminder scheduling / suppression

### Likely New Files

Notification model / routing:
- `Circles/Notifications/AppNotificationType.swift`
- `Circles/Notifications/AppNotificationRoute.swift`
- `Circles/Notifications/NotificationPayload.swift`

Settings / preferences:
- `Circles/Notifications/NotificationSettingsView.swift`
- `Circles/Services/NotificationPreferencesService.swift`
- possibly a `NotificationPreferences` model under `Circles/Models/`

Habit reminder logic:
- `Circles/Services/HabitReminderScheduler.swift`
- possibly helper reminder rule types / policy models

</codebase_plan>

<implementation_order>
## Recommended Build Order

### First
Finish Phase 15.1 foundation before adding more notification families.

Why:
- all later notification families depend on common permission, preference, payload, and routing behavior
- without settings and routing, feature-specific notifications will fragment the codebase

### Then
1. `moment_window`
2. notification settings foundation
3. `nudge`
4. `circle_check_in`
5. `habit_reminder`

This order prioritizes core product value and minimizes rework.

</implementation_order>

<subphases>
## Subphase Requirements

### 15.1 — Foundation + Moment Window
- create formal notification type and payload modeling
- centralize remote notification handling
- stabilize APNs token lifecycle and permission state refresh behavior
- define and wire app-level notification preferences
- add the first notification settings surface
- complete `moment_window` end-to-end behavior against the new foundation

### 15.2 — Nudge
- emit notifications when a user receives a nudge
- ensure payload routing lands in the right app surface
- use shared preference checks

### 15.3 — Circle Check-In
- define low-noise motivation rules
- avoid one-notification-per-check-in behavior
- prefer summary or capped delivery

### 15.4 — Habit Reminder
- define app-owned reminder policies by habit type
- use prayer-aware timing for prayer habits where possible
- use simple non-manual defaults for non-prayer habits
- suppress reminders after completion

</subphases>

<technical_questions>
## Questions Already Resolved In Planning

### Should users manually configure habit reminders?
No.

Reminder personalization should be app-owned and initially simple.

### Should prayer and non-prayer habits both be supported?
Yes.

Initial approach:
- prayer habits -> prayer-aware defaults
- non-prayer habits -> simple app-defined defaults

</technical_questions>

<canonical_refs>
## Canonical References

### Current Notification Code
- `Circles/Services/NotificationService.swift`
- `Circles/CirclesApp.swift`
- `Circles/Notifications/NotificationPermissionModal.swift`
- `Circles/Onboarding/AmiirStep3LocationView.swift`
- `Circles/Circles/CirclesViewModel.swift`
- `Circles/Circles/CircleDetailView.swift`

### Current Moment Infrastructure
- `Circles/Services/DailyMomentService.swift`
- moment-window edge function / Supabase cron infrastructure

### Planning Docs
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/15-social-pulse/README.md`
- `.planning/phases/15-social-pulse/notification_preferences.sql`

</canonical_refs>

---

*Phase: 15-social-pulse*
*Context gathered: 2026-04-19 via conversation alignment session and code audit*
> Deep implementation reference for Phase 15 only. Do not read this at session start unless you are actively working on notification internals.
