---
phase: 03-circles-create-join-member-view
plan: 03
status: complete
completed: 2026-03-24
---

# Phase 3, Plan 03: Deep Links + Human Verification — COMPLETE

## What Was Built

- `CirclesApp.swift` — PendingInviteCodeKey EnvironmentKey, .onOpenURL parsing circles://join/CODE
- `MainTabView.swift` — selectedTab binding, .onChange switches to Community tab on pending code
- `CommunityView.swift` — reacts to pendingInviteCode, pre-fills JoinCircleView and opens sheet
- `Info.plist` — circles:// URL scheme registered alongside Google Sign-In scheme

## Key Decisions / Fixes During Verification

- Switched from Legacy `halaqas`/`halaqa_members` tables to new clean `circles`/`circle_members` tables — Legacy schema had too many unknown constraints (gender NOT NULL, check constraints, etc.)
- Removed `prayerTime` from Circle model — moment timing is platform-wide (BeReal-style), not per-circle
- Fixed RLS infinite recursion using SECURITY DEFINER function `auth_user_circle_ids()`
- Renamed `HalaqaMember` → `CircleMember`, `halaqa_id` → `circle_id` throughout

## Human Verification Results

All 6 checks passed:
1. ✓ Community tab shows empty state with Create/Join buttons
2. ✓ Create circle — circle appears in list
3. ✓ CircleDetailView shows invite code, Invite Friends, Admin badge
4. ✓ ShareLink shows joinlegacy.app/join/... URL
5. ✓ Invalid join code shows error message
6. ✓ Deep link circles://join/TESTCODE pre-fills join sheet and switches to Community tab

## Build Result

BUILD SUCCEEDED, zero errors
