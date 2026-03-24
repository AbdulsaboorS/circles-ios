---
phase: 04-circle-moment-camera-post-reciprocity-gate
plan: 01
subsystem: data-layer
tags: [models, services, supabase-storage, circle-moments]
dependency_graph:
  requires: []
  provides: [CircleMoment model, MomentService singleton, Circle.momentWindowStart]
  affects: [04-02-camera-ui, 04-03-reciprocity-gate]
tech_stack:
  added: [UIKit (UIImage/JPEG), Supabase Storage, ISO8601DateFormatter]
  patterns: [@Observable @MainActor singleton, AnyJSON row insert, Storage.from().upload()]
key_files:
  created:
    - Circles/Models/CircleMoment.swift
    - Circles/Services/MomentService.swift
  modified:
    - Circles/Models/Circle.swift
decisions:
  - "momentWindowStart typed as String? (not Date?) per project date-as-string convention for TIMESTAMPTZ columns"
  - "Storage upsert=true allows retakes without duplicate storage files"
  - "computeIsOnTime checks < 1800 seconds (30 minutes) from windowStart"
  - "File path format: {circleId}/{userId}_{date}.jpg — scoped by circle and user, deduped by date"
metrics:
  duration: "~3 minutes"
  completed: "2026-03-24"
  tasks_completed: 2
  files_created: 2
  files_modified: 1
---

# Phase 4 Plan 1: Circle Moment Data Layer Summary

One-liner: CircleMoment Codable model + MomentService with Supabase Storage upload, `circle_moments` insert, today-fetch, and 30-minute on-time computation.

## What Was Built

### Task 1: CircleMoment model and Circle model update

Created `Circles/Models/CircleMoment.swift` — a `Codable, Identifiable, Sendable` struct mapping all 7 `circle_moments` table columns:

- `id: UUID`
- `circleId: UUID` (→ `circle_id`)
- `userId: UUID` (→ `user_id`)
- `photoUrl: String` (→ `photo_url`)
- `caption: String?`
- `postedAt: String` (→ `posted_at`, TIMESTAMPTZ stored as String per project convention)
- `isOnTime: Bool` (→ `is_on_time`)

Updated `Circles/Models/Circle.swift` to add `momentWindowStart: String?` with CodingKey `moment_window_start`. This maps to the `moment_window_start TIMESTAMPTZ` column added to the `circles` table.

**Commit:** `804a9b2`

### Task 2: MomentService singleton

Created `Circles/Services/MomentService.swift` following the exact `@Observable @MainActor` singleton pattern from `HabitService`:

- `fetchTodayMoments(circleId:)` — filters `circle_moments` by today's UTC date range using `gte`/`lt` on `posted_at`
- `uploadPhoto(image:circleId:userId:)` — converts `UIImage` to JPEG (0.8 quality), uploads to `circle-moments` storage bucket with upsert enabled, returns public URL
- `postMoment(image:circleId:userId:caption:windowStart:)` — orchestrates upload + row insert, computes `isOnTime`
- `computeIsOnTime(windowStart:)` — static helper, parses ISO8601 string with/without fractional seconds, checks if `now - windowStart < 1800s`
- `todayDateString()` — UTC YYYY-MM-DD helper
- `MomentError.imageConversionFailed` — `LocalizedError` for upload failures

**Commit:** `1abc8a8`

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

One minor clarification applied per `<critical_context>`: the comment in `computeIsOnTime` references `circles.moment_window_start` (not `halaqas.moment_window_start` as the plan text said). This is a comment-only change with no behavioral impact.

## Self-Check: PASSED

- [x] Circles/Models/CircleMoment.swift created (commit 804a9b2)
- [x] Circles/Models/Circle.swift modified with momentWindowStart (commit 804a9b2)
- [x] Circles/Services/MomentService.swift created (commit 1abc8a8)
- [x] Build succeeded (both tasks verified with xcodebuild)
