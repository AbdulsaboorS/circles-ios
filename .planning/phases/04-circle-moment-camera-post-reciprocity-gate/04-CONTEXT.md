---
phase: 4
name: "Circle Moment (Camera, Post, Reciprocity Gate)"
status: context_captured
---

# Phase 4 Context

## Domain

The core BeReal-style mechanic. User gets a visual signal when their circle's 30-minute Moment window is open, opens a dual camera capture, composites the photo, posts with optional caption, and is gated from seeing peer Moments until they post their own.

---

## Decisions

### 1. Camera: Dual capture (front + back simultaneously)
**Decision:** Use `AVCaptureMultiCamSession` to capture both front and rear cameras at the same time. The result is a composited photo — full rear camera image with a small front camera inset (face in corner). This is the BeReal signature look.

**Implication for planner:**
- Use `AVCaptureMultiCamSession` (requires iPhone XS or later — document minimum hardware requirement)
- Capture two `AVCapturePhotoOutput` streams simultaneously
- Composite into a single `UIImage` before upload (rear camera fills frame, front camera as corner inset ~25% size)
- Single photo upload to Supabase Storage (one composited image per Moment post)

---

### 2. Active window detection: `moment_window_start` column on `halaqas`
**Decision:** Add `moment_window_start TIMESTAMPTZ` column to the existing `halaqas` table. Phase 4 reads this column from the circle record. If `now() − moment_window_start < 30 minutes`, the window is active and the "Post Your Moment" UI is shown with a countdown.

**Implication for planner:**
- Supabase migration: `ALTER TABLE halaqas ADD COLUMN moment_window_start TIMESTAMPTZ;`
- `Circle` Swift model (`halaqas` row) gains `momentWindowStart: Date?`
- `CircleDetailViewModel` (or extended `CirclesViewModel`) computes `isWindowActive` and `secondsRemaining` from this field
- No prayer time library needed in Phase 4 — that's Phase 6's job. Phase 6 will write to `moment_window_start` via Edge Function.
- For testing during Phase 4: manually insert a timestamp via Supabase Dashboard to simulate an active window.

---

### 3. Camera entry point: "Post Your Moment" banner in CircleDetailView
**Decision:** When the 30-minute window is active, `CircleDetailView` shows a prominent "POST YOUR MOMENT ★ 28:42 remaining" banner at the top. Tapping it opens the Moment camera. When the window is closed, the banner is hidden (or shows "Next Moment: [prayer name] · [time]" placeholder — planner's discretion).

**Implication for planner:**
- No new tab in `MainTabView` — tab bar stays at 3 tabs (Home / Circles / Profile) for Phase 4
- `CircleDetailView` is extended, not a new screen
- Camera presented as a full-screen modal sheet from `CircleDetailView`
- Navigation: `CircleDetailView` → `MomentCameraView` (modal) → `MomentPreviewView` (push or modal) → post → dismiss back to `CircleDetailView`

---

### 4. Reciprocity gate: Blur + lock icon + "Post to see theirs" CTA, tap opens camera
**Decision:** Peer Moments that exist today but haven't been unlocked yet are shown as blurred photo thumbnails with a 🔒 lock icon overlay and the text "Post your Moment to see theirs." Tapping the blurred card opens the Moment camera (same entry as the banner above). Once the user posts, all blurred Moments unblur in place.

**Implication for planner:**
- Blur applied client-side using `.blur(radius: 20)` SwiftUI modifier or `UIVisualEffectView` equivalent — we don't serve a blurred image from storage, we blur the loaded image in the view
- Tap gesture on a locked Moment card → same sheet presentation as the banner tap
- After successful post: reload peer Moments, remove blur
- `circle_moments` DB query returns all circle members' posts for today — Swift model includes a flag the gate logic can use (`isOwnPost: Bool` computed from `userId == currentUserId`)

---

## DB Changes Required (Before Phase 4 Executes)

1. **Supabase migration — `halaqas` table:**
   ```sql
   ALTER TABLE halaqas ADD COLUMN moment_window_start TIMESTAMPTZ;
   ```

2. **Supabase migration — new `circle_moments` table:**
   ```sql
   CREATE TABLE circle_moments (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     circle_id UUID NOT NULL REFERENCES halaqas(id) ON DELETE CASCADE,
     user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
     photo_url TEXT NOT NULL,
     caption TEXT,
     posted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
     is_on_time BOOLEAN NOT NULL DEFAULT false,
     UNIQUE(circle_id, user_id, (posted_at::date))
   );
   ```
   *(The UNIQUE constraint prevents duplicate posts per user per circle per day.)*

3. **Supabase Storage bucket:** `circle-moments` (create if not already existing)

---

## Canonical Refs

- `.planning/PROJECT.md` — product vision, core mechanics (Circle Moment section), key decisions table
- `.planning/ROADMAP.md` — Phase 4 requirements: PHASE4-MOMENT-NOTIFICATION, PHASE4-CAMERA, PHASE4-ACTIVE-WINDOW, PHASE4-POST-MOMENT, PHASE4-RECIPROCITY-GATE, PHASE4-ON-TIME-INDICATOR, PHASE4-STORAGE
- `.planning/STATE.md` — active decisions (Swift 6 patterns, Supabase SDK version, date-as-string convention)
- `.planning/phases/02-habits-daily-check-in/02-01-PLAN.md` — HabitService pattern to follow for MomentService
- `Circles/Services/SupabaseService.swift` — singleton pattern
- `Circles/Services/HabitService.swift` — @Observable @MainActor service pattern
- `Circles/Navigation/MainTabView.swift` — tab structure (do NOT add 4th tab in Phase 4)
- `Circles/CirclesApp.swift` — app entry, environment setup

---

## Deferred Ideas

- Tap-to-retake: after posting a Moment, allow retake within the window — deferred to v1.1
- Dual camera toggle (let user swap which camera is inset) — deferred to v1.1
- Front-only capture mode for devices that don't support multi-cam — planner should add device capability check + graceful fallback (single rear cam if `AVCaptureMultiCamSession` unsupported)

---

## What's NOT in Phase 4

- Prayer time calculation (Phase 6)
- APNs token registration or push delivery (Phase 6)
- Moment reactions (Phase 5)
- Moment in the unified circle feed (Phase 5)
- Notification deep-link → camera (Phase 6 wires this up)

---
*Context captured: 2026-03-23*
