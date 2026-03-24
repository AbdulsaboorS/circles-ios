---
phase: 04-circle-moment-camera-post-reciprocity-gate
plan: 02
subsystem: camera-ui
tags: [camera, avfoundation, multi-cam, swiftui, dual-viewfinder]
dependency_graph:
  requires: [04-01-data-layer]
  provides: [CameraManager, MomentCameraView, MomentPreviewView]
  affects: [04-03-reciprocity-gate]
tech_stack:
  added: [AVCaptureMultiCamSession, AVCapturePhotoOutput, UIGraphicsImageRenderer, UIViewRepresentable]
  patterns: [@Observable @MainActor NSObject, nonisolated delegate, ObjectIdentifier actor-safety, SwiftUI.Circle() disambiguation]
key_files:
  created:
    - Circles/Moment/CameraManager.swift
    - Circles/Moment/MomentCameraView.swift
    - Circles/Moment/MomentPreviewView.swift
decisions:
  - "nonisolated AVCapturePhotoCaptureDelegate callback; ObjectIdentifier used to identify which output fired across actor boundary — avoids sending non-Sendable AVCapturePhotoOutput across MainActor"
  - "CameraPreviewView (UIView subclass) overrides layoutSubviews to keep preview layer frame in sync"
  - "SwiftUI.Circle() qualified at all shutter button sites to resolve naming collision with Circle data model"
  - "Front camera inset positioned via GeometryReader with safe area awareness (padding bottom = 16 + safeAreaInsets.bottom + 120)"
metrics:
  duration: "~4 minutes"
  completed: "2026-03-24"
  tasks_completed: 2
  files_created: 3
---

# Phase 4 Plan 2: Camera Capture UI Summary

One-liner: CameraManager (AVFoundation dual-cam + single-cam fallback, compositing) + MomentCameraView (full-screen viewfinder with permission gate) + MomentPreviewView (review, caption, post CTA) in Circles/Moment/.

## What Was Built

### Task 1: CameraManager — AVFoundation dual-camera capture and compositing

Created `Circles/Moment/CameraManager.swift` — an `@Observable @MainActor` class that inherits from `NSObject` to satisfy `AVCapturePhotoCaptureDelegate` conformance.

**Session Management:**
- `checkPermission()` — uses `AVCaptureDevice.authorizationStatus(for: .video)`, requests access via async API for `.notDetermined`, sets `permissionGranted`
- `setupSession()` — branches on `AVCaptureMultiCamSession.isMultiCamSupported`:
  - Multi-cam: creates `AVCaptureMultiCamSession`, adds rear + front `AVCaptureDeviceInput` and `AVCapturePhotoOutput`, creates two `AVCaptureVideoPreviewLayer` instances
  - Single-cam: creates standard `AVCaptureSession` with rear camera and one photo output
  - Both paths start the session on a background `DispatchQueue.global(qos: .userInitiated)`
- `stopSession()` — stops running session on background queue

**Capture & Compositing:**
- `capturePhoto()` — fires `rearPhotoOutput` and `frontPhotoOutput` (multi-cam) or `singlePhotoOutput` (single-cam), tracks `pendingCaptureCount = 2` for multi-cam synchronization
- `AVCapturePhotoCaptureDelegate` `photoOutput(_:didFinishProcessingPhoto:error:)` — `nonisolated`; converts `AVCapturePhoto` to `UIImage` via `fileDataRepresentation()`, uses `ObjectIdentifier(output)` to identify rear vs front without crossing actor boundary with non-Sendable type
- `compositeImages(rear:front:)` — `UIGraphicsImageRenderer` at rear image size; front inset is 25% width × 4:3 aspect ratio, positioned bottom-left 16pt from edges, clipped to `UIBezierPath(roundedRect:cornerRadius: 12)` with 2pt white border stroke

**Commit:** `dd28a28`

### Task 2: MomentCameraView and MomentPreviewView

**MomentCameraView** (`Circles/Moment/MomentCameraView.swift`):
- Full-screen camera with `.fullScreenCover` presentation intent
- Accepts `let circleId: UUID` and `let onCapture: (UIImage) -> Void`
- `@State private var cameraManager = CameraManager()` — one instance per session
- `.task` lifecycle: calls `checkPermission()`, 500ms delay, then `setupSession()` if granted
- `.onChange(of: permissionGranted)` for late-grant case
- `.onChange(of: capturedImage)` fires `onCapture(image)` when capture completes
- Rear viewfinder: `CameraPreviewRepresentable` filling screen via `.ignoresSafeArea()`
- Front inset: `GeometryReader`, 25% width × 4:3, `cornerRadius: 12`, 2pt white stroke, bottom-left with safe area padding
- Shutter: 80pt white outer / 68pt `#0D1021` inner ring, `SwiftUI.Circle()` to avoid `Circle` model collision; `scaleEffect(isShutterPressed ? 0.92 : 1.0)` with `.spring(response: 0.2)`; white flash overlay on capture
- Cancel button: SF Symbol `xmark`, top-right, accessibility label `"Cancel camera"`
- Flip button: shown only when `!isMultiCamSupported`
- Permission denied state: `camera.slash.fill` icon, `"Camera Access Required"` heading, `"Open Settings"` button
- `CameraPreviewRepresentable` (UIViewRepresentable) + `CameraPreviewView` (UIView subclass with `layoutSubviews`)

**MomentPreviewView** (`Circles/Moment/MomentPreviewView.swift`):
- Accepts `let image: UIImage`, `let onPost: (String?) async throws -> Void`, `let onRetake: () -> Void`
- `@State private var isPosting`, `errorMessage`, `caption`
- Photo: `Image(uiImage: image)`, `aspectRatio(3/4)`, `cornerRadius: 16`
- Caption: `TextField("Add a caption...", text: $caption)`, `#1A1D35` background, `cornerRadius: 10`
- Post button: full-width, height 52pt, `#E8834B` background, `cornerRadius: 14`, `.headline.semibold`, `ProgressView` in loading state, `.opacity(0.5)` while posting
- Error: `"Failed to post. Try again."` below post button, `.red`
- `.interactiveDismissDisabled(isPosting)` prevents swipe-dismiss during post

**Commit:** `5294ef8`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift 6 actor isolation: AVCapturePhotoOutput is non-Sendable**
- **Found during:** Task 1 build
- **Issue:** Passing `output: AVCapturePhotoOutput` (non-Sendable) across MainActor boundary in `Task { @MainActor in }` causes `sending 'output' risks causing data races` error under Swift 6 strict concurrency
- **Fix:** Use `ObjectIdentifier(output)` (which is `Sendable`) in the `nonisolated` delegate callback; compare on MainActor against stored output references via `ObjectIdentifier`
- **Files modified:** `Circles/Moment/CameraManager.swift`
- **Commit:** `dd28a28`

**2. [Rule 1 - Bug] SwiftUI.Circle() naming collision**
- **Found during:** Task 2 build
- **Issue:** `Circle()` in shutter button is ambiguous — the `Circle` data model (from Plan 01) shadows `SwiftUI.Circle` shape
- **Fix:** Qualify as `SwiftUI.Circle()` at both shutter button usage sites
- **Files modified:** `Circles/Moment/MomentCameraView.swift`
- **Commit:** `5294ef8`

## Known Stubs

None — all UI is wired to CameraManager callbacks. MomentPreviewView's `onPost` closure is intentionally unimplemented here; Plan 03 provides the closure when presenting MomentPreviewView from CircleDetailView.

## Self-Check: PASSED

- [x] Circles/Moment/CameraManager.swift created (commit dd28a28)
- [x] Circles/Moment/MomentCameraView.swift created (commit 5294ef8)
- [x] Circles/Moment/MomentPreviewView.swift created (commit 5294ef8)
- [x] Build succeeded (both tasks verified with xcodebuild)
