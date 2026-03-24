---
phase: 04-circle-moment-camera-post-reciprocity-gate
plan: 03
subsystem: ui-integration
tags: [circle-detail, reciprocity-gate, moment-card, countdown-timer, camera-presentation]
dependency_graph:
  requires: [04-01-data-layer, 04-02-camera-ui]
  provides: [MomentCardView, CircleDetailView-with-moment-flow]
  affects: [phase-5-feed, phase-6-notifications]
tech_stack:
  added: [ISO8601DateFormatter, Timer.scheduledTimer, MainActor.assumeIsolated, LazyVGrid, AsyncImage]
  patterns: [computed-property-reciprocity-gate, timer-countdown-MainActor, fullScreenCover-camera, sheet-preview]
key_files:
  created:
    - Circles/Moment/MomentCardView.swift
  modified:
    - Circles/Circles/CircleDetailView.swift
decisions:
  - "MainActor.assumeIsolated used in Timer callback (not Task @MainActor) — Timer fires on main run loop, no actor boundary crossing needed; avoids sending non-Sendable Timer across isolation"
  - "windowTimer?.invalidate() via stored reference (not timer closure param) — avoids sending non-Sendable Timer param into MainActor.assumeIsolated"
  - "Peer members with no Moment are omitted from grid — only own-unposted slot and members who have posted are shown"
  - "MomentCardData struct used as local value type to drive ForEach in momentsContent — avoids recomputing per-card logic inside ForEach body"
metrics:
  duration: "~3 minutes"
  completed: "2026-03-24"
  tasks_completed: 1
  files_created: 1
  files_modified: 1
---

# Phase 4 Plan 3: Reciprocity Gate + CircleDetailView Integration Summary

One-liner: MomentCardView (3-state: locked/unlocked/own-unposted) + CircleDetailView wired with countdown banner, 2-column Moments grid, camera/preview presentation, and reciprocity gate unlocking on post.

## What Was Built

### Task 1: MomentCardView and updated CircleDetailView

**MomentCardView** (`Circles/Moment/MomentCardView.swift`):

Three rendering states based on `moment`, `isOwnPost`, and `hasPostedToday`:

- **Unlocked card** (own post or peer after user has posted): `AsyncImage` filling 3:4 ratio card, `cornerRadius: 12`. On-time star badge: white circle background + `star.fill` amber, top-right 6pt inset.
- **Locked card** (peer, user hasn't posted yet): same `AsyncImage` with `.blur(radius: 20)`, `Color.black.opacity(0.4)` scrim overlay, `lock.fill` + `"Post to unlock"` centered. `.onTapGesture { onTapLocked() }`. Accessibility label includes "locked. Tap to post your Moment first."
- **Own unposted** (`moment == nil && isOwnPost`): `LinearGradient([#1A1D35, #0D1021])` placeholder with same lock overlay. Member label shows `"You — tap to post"` in amber. `.onTapGesture { onTapLocked() }`.

**CircleDetailView** (`Circles/Circles/CircleDetailView.swift`) — full rewrite preserving existing members/invite sections:

- `import Supabase` added for `auth.currentSession?.user.id`
- New state: `moments`, `showCamera`, `capturedImage`, `showPreview`, `windowSecondsRemaining`, `windowTimer`
- `currentUserId` and `hasPostedToday` computed properties
- `countdownText` formatted as `MM:SS remaining` (monospaced)
- **Countdown banner**: amber `#E8834B` full-width HStack with `star.fill`, "POST YOUR MOMENT", spacer, countdown. Hidden when `!isWindowActive`. Tap opens camera.
- **Moments Section**: placed above Invite section in the List. 2-column `LazyVGrid` via `MomentCardData` array. Empty states: window active ("Be the first...") / window closed ("No Moments yet...").
- **Camera presentation**: `.fullScreenCover(isPresented: $showCamera)` presenting `MomentCameraView`; `onCapture` sets `capturedImage`, dismisses camera, sets `showPreview = true`.
- **Preview presentation**: `.sheet(isPresented: $showPreview)` presenting `MomentPreviewView`. `onPost` calls `MomentService.shared.postMoment` then refreshes `moments` array. `onRetake` returns to camera. `.interactiveDismissDisabled(true)`.
- **Reciprocity unlock animation**: `.animation(.easeOut(duration: 0.4), value: hasPostedToday)` on Moments section.
- **Window timer**: `startWindowTimer()` parses `circle.momentWindowStart` (ISO8601 with/without fractional seconds), computes remaining seconds, starts `Timer.scheduledTimer`. `.onDisappear { windowTimer?.invalidate() }` for cleanup.

**Commit:** `ccd8ee0`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift 6 actor isolation: Timer closure parameter non-Sendable**
- **Found during:** Task 1 build
- **Issue:** The plan suggested `Task { @MainActor in ... timer.invalidate() }` inside the Timer callback. Under Swift 6, sending `timer: Timer` (non-Sendable) into a `Task { @MainActor in }` produces `sending 'timer' risks causing data races`. `MainActor.assumeIsolated` also fails if `timer` is passed as a parameter.
- **Fix:** Use `_ in` (ignore closure parameter), and call `self.windowTimer?.invalidate()` via the stored `@State` reference instead. Timer fires on the main run loop already, so `MainActor.assumeIsolated` is safe without capturing `timer`.
- **Files modified:** `Circles/Circles/CircleDetailView.swift`
- **Commit:** `ccd8ee0`

## Known Stubs

None — all data paths are wired. `MomentCardView.onTapLocked` opens the camera. `CircleDetailView` posts through `MomentService.postMoment` and refreshes the moments array. The `hasPostedToday` gate is live data from the `moments` array.

## Checkpoint Reached

Task 2 is `type="checkpoint:human-verify"` — execution paused for human verification of the full Circle Moment flow in Simulator.

## Self-Check: PASSED

- [x] Circles/Moment/MomentCardView.swift created (commit ccd8ee0)
- [x] Circles/Circles/CircleDetailView.swift modified (commit ccd8ee0)
- [x] Build succeeded: zero errors (iPhone 17, iOS 26.3.1)
- [x] MomentCardView contains: `struct MomentCardView`, `.blur(radius: 20)`, `"Post to unlock"`, `lock.fill`, `star.fill`, `LinearGradient`
- [x] CircleDetailView contains: `"POST YOUR MOMENT"`, `countdownText`, `fullScreenCover`, `MomentCameraView`, `MomentPreviewView`, `MomentService.shared.fetchTodayMoments`, `MomentService.shared.postMoment`, `hasPostedToday`, `windowSecondsRemaining`, `LazyVGrid`, `"Be the first to post your Moment."`, `"No Moments yet. Come back when the window opens."`, `import Supabase`
