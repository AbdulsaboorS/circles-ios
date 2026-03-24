---
phase: 03-circles-create-join-member-view
plan: 01
status: complete
completed: 2026-03-23
duration_minutes: 12
tasks_completed: 2
files_created: 3
files_modified: 2
key_decisions:
  - "fetchMyCircles uses 2-step query (member rows then circle lookup by IDs) instead of PostgREST inner join to avoid SDK ambiguity"
  - "joinByInviteCode uses limit(1)+first instead of .single() for safer decoding when invite code not found"
  - "Insert rows use [String: AnyJSON] matching HabitService pattern"
  - "SwiftUI.Circle() qualified in ProfileView and HabitDetailView to resolve naming collision with new Circle model"
subsystem: circles-data-layer
tags: [circles, data-layer, supabase, codable, service]
dependency_graph:
  requires: []
  provides: [Circle, HalaqaMember, CircleService.shared]
  affects: [03-02, 03-03]
tech_stack:
  added: []
  patterns: ["@Observable @MainActor singleton", "2-step Supabase join query", "[String: AnyJSON] insert row"]
key_files:
  created:
    - Circles/Models/Circle.swift
    - Circles/Models/HalaqaMember.swift
    - Circles/Services/CircleService.swift
  modified:
    - Circles/Profile/ProfileView.swift
    - Circles/Home/HabitDetailView.swift
---

# Phase 3, Plan 01: Circle Data Layer — COMPLETE

## One-liner

Codable Circle and HalaqaMember models plus CircleService singleton with fetch/create/join/members using `[String: AnyJSON]` insert pattern and 2-step membership query.

## What Was Built

- `Circle.swift` — Codable, Identifiable, Hashable, Sendable struct mirroring `halaqas` table with full CodingKeys for snake_case columns (created_by, prayer_time, invite_code, created_at)
- `HalaqaMember.swift` — Codable, Identifiable, Sendable struct mirroring `halaqa_members` table (halaqa_id, user_id, role, joined_at)
- `CircleService.swift` — @Observable @MainActor singleton with four async methods: fetchMyCircles, createCircle, joinByInviteCode, fetchMembers; uses computed `client` property pattern from HabitService

## Key Decisions

- `fetchMyCircles` uses a 2-step query (fetch member rows first, then `.in("id", values:)` on halaqas) instead of PostgREST `!inner` join to avoid SDK filter scoping ambiguity on joined tables
- `joinByInviteCode` uses `limit(1)` + `.first` instead of `.single()` for safer decoding — returns `URLError(.resourceUnavailable)` if code not found rather than crashing on empty result
- Insert rows use `[String: AnyJSON]` with `.string()` / `.bool()` constructors, matching the established HabitService pattern exactly

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Resolved naming collision between `Circle` model and SwiftUI's `Circle` shape**
- **Found during:** First build attempt after creating Circle.swift
- **Issue:** The new `Circle` struct shadows SwiftUI's built-in `Circle` shape type. `ProfileView.swift` (line 15) and `HabitDetailView.swift` (line 74) both called `Circle()` expecting the SwiftUI shape, which now resolved to the data model — causing two compile errors ("missing argument for parameter 'from' in call", "value of type 'Circle' has no member 'fill'")
- **Fix:** Qualified both call sites as `SwiftUI.Circle()` — minimal targeted fix that preserves the model name and requires no renaming elsewhere
- **Files modified:** `Circles/Profile/ProfileView.swift`, `Circles/Home/HabitDetailView.swift`
- **Commit:** a67d7c4

## Build Result

BUILD SUCCEEDED — zero errors, zero warnings from new files.

## Self-Check

Files created:
- Circles/Models/Circle.swift — FOUND
- Circles/Models/HalaqaMember.swift — FOUND
- Circles/Services/CircleService.swift — FOUND

Commit: a67d7c4 — FOUND

## Self-Check: PASSED
