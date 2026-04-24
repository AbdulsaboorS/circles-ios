# Phase 15 — Social Pulse

> Archival phase snapshot only. Do not treat this file as required startup context.

**Status:** Built, Build-Verified, QA Deferred
**Workstream branch:** `phase-15-social-pulse`

## What Phase 15 Shipped

- app-level notification preference modeling and settings UI
- centralized payload parsing and tap routing
- remote push support for `moment_window`, `nudge`, and `circle_check_in`
- local scheduling for `habit_reminder`

## Subphase Status

- Phase 15.1: user-smoke-tested
- Phase 15.2: code-reviewed and build-verified
- Phase 15.3: code-complete and build-verified
- Phase 15.4: code-complete and build-verified

## Notification Families

- `moment_window`
- `nudge`
- `circle_check_in`
- `habit_reminder`

## Important Decisions

- remote push is used for social/accountability events
- local notifications are used first for habit reminders
- reminder timing is app-owned, not user-configured in this phase
- prayer habits use prayer-aware timing when location/timezone data is available
- non-prayer habits use simple app-defined defaults
- tap routing stays centralized

## Deferred Work

- deploy `supabase/functions/send-circle-check-in`
- run one combined QA pass for Phases 15.2, 15.3, and 15.4
- do that work after the higher-priority onboarding, UI/UX, naming, branding, and landing-page polish tasks

## Reference Files

- `.planning/phases/15-social-pulse/14-CONTEXT.md`
- `.planning/phases/15-social-pulse/notification_preferences.sql`
- `.planning/phases/15-social-pulse/circle_check_in_notifications.sql`
- `Circles/Services/NotificationService.swift`
- `Circles/Services/HabitReminderScheduler.swift`
- `Circles/Services/HabitToggleService.swift`
