# Handoff — 2026-04-14 (Session 19 — Journey Tab Vision + Moment Fixes)

## Current Build State
**BUILD VERIFIED ✅** — zero errors on `main`. Commit `a6e6e56`.

---

## What Landed This Session

### 1. Force Moment Window — Genuine Re-Post (DEBUG)
- `DailyMomentService.forceOpenWindow(userId:)` now async — deletes today's `circle_moments` + `moment_niyyahs` rows from DB before reopening the window
- `MomentService.deleteMyTodayMoments(userId:)` — new `#if DEBUG` method
- `NiyyahService.deleteTodayNiyyah(userId:)` — new `#if DEBUG` method
- ProfileView debug button wrapped in `Task { await ... }` with userId

### 2. Moment State Machine Desync Fix
- `MomentPreviewView.postMoment()` catch block now calls `DailyMomentService.shared.markPostedToday()` when error is `.alreadyPostedToday` — closes the gate/CTA instead of leaving them stuck open

### 3. BeReal-Style Random Daily Moment Timing
- `daily_moments` table: new `moment_time TEXT` column ("HH:MM" UTC)
- `seed-daily-moment` edge function: now picks a random UTC time in 13:00–03:00 range (≈ 8am–10pm ET) alongside the prayer label. Deployed v2.
- `send-moment-window-notifications` edge function: fully rewritten — fires at `moment_time`, pushes to all device tokens, no per-user Aladhan calculation. Deployed v1.
- `DailyMomentService.load()`: uses `moment_time` directly when available (skips Aladhan API); falls back to Aladhan for legacy rows without a time
- `DailyMoment` model: added `momentTime: String?` field
- pg_cron jobs live: `seed-daily-moment` at 00:05 UTC daily, `send-moment-window-notifications` every 1 minute
- `CirclesApp.AppDelegate` now conforms to `UNUserNotificationCenterDelegate` — handles `moment_window` push to refresh gate state
- pg_net extension enabled on the project

### 4. Spiritual Ledger — Always Visible
- Removed `niyyahCount > 0` condition on Profile — ledger button always shows
- Removed `.onAppear` niyyah count refresh (was added mid-session, then made redundant)

### 5. Journey Tab — Vision Finalized (NOT YET BUILT)
Full design and architecture decisions made. See "Next Session" below.

---

## DB State
- `daily_moments.moment_time` column: ✅ added
- Today's row (2026-04-14): seeded with `moment_time = '16:48'` (test value — will auto-seed correctly from tomorrow via cron)
- `moment_niyyahs` table: ✅ exists, RLS owner-only, 1 row (user tested)
- `circle_moments.has_niyyah`: ✅ exists
- pg_cron jobs: ✅ both active
- pg_net extension: ✅ enabled

---

## Files Modified This Session

| File | Change |
|------|--------|
| `Circles/Services/MomentService.swift` | Added `#if DEBUG deleteMyTodayMoments()` |
| `Circles/Services/NiyyahService.swift` | Added `#if DEBUG deleteTodayNiyyah()` |
| `Circles/Services/DailyMomentService.swift` | `forceOpenWindow(userId:)` async + DB cleanup; `load()` uses `moment_time`; new `fetchTodayDailyMoment()` + `utcTimeToDate()` helpers |
| `Circles/Models/DailyMoment.swift` | Added `momentTime: String?` |
| `Circles/Moment/MomentPreviewView.swift` | Sync `markPostedToday()` on `alreadyPostedToday` error |
| `Circles/Profile/ProfileView.swift` | Force button async; ledger always visible |
| `Circles/CirclesApp.swift` | `UNUserNotificationCenterDelegate` conformance; `moment_window` push handling |
| `supabase/functions/seed-daily-moment/index.ts` | Random `moment_time` generation |
| `supabase/functions/send-moment-window-notifications/index.ts` | Full rewrite — time-based, not prayer-based |

---

## Next Session: Build Journey Tab

### Vision
A 4th tab called **"Journey"** — a private spiritual record of the user's daily intentions across time. This is the elevated, permanent home for what `SpiritualLedgerView` was trying to be.

**Core concept:** The niyyah text is the hero, not the photo. This inverts BeReal Memories and makes the archive spiritually meaningful.

### Final UI Design
**Layer 1 — Calendar month grid (main view)**
- Month header in serif ("April 2026") + prev/next chevrons + swipe gesture
- 7-column grid, each day = rounded square
- **Gold + Noor Aura glow** = has niyyah that day
- **Neutral dim fill** = has moment, no niyyah
- **Empty** = nothing that day
- Today's date subtly highlighted (distinct from "has niyyah")

**Layer 2 — Day detail (tap a cell → sheet)**
- Large serif niyyah text, quoted, centered — the hero
- Date (Gregorian) above, small + muted
- Moment photo below as thumbnail, Noor Aura if niyyah present
- If no niyyah: photo only, no gold
- If no moment: niyyah text only, moon icon placeholder

### Core MVP Requirements
1. 4th tab "Journey", `calendar` SF symbol, between Community and Profile
2. Calendar month grid with 3 day states
3. Month navigation (swipe + chevrons)
4. Day detail sheet on tap
5. Photo URL signed on-demand (only when detail opens)
6. Empty state (no entries yet) — poetic, not generic
7. **Remove `SpiritualLedgerView.swift`** + `spiritualLedgerButton` from ProfileView
8. **Remove `niyyahCount` state** from ProfileView entirely

### Files to Create
- `Circles/Journey/JourneyView.swift` — tab root with calendar + month nav
- `Circles/Journey/JourneyViewModel.swift` — data fetching, month caching
- `Circles/Journey/JourneyDayDetailView.swift` — entry sheet (niyyah hero + photo)
- `Circles/Journey/JourneyCalendarGrid.swift` — the calendar component
- `Circles/Models/JourneyDay.swift` — combines niyyah + moment state for one day

### Files to Modify
- `Circles/Navigation/MainTabView.swift` — add Journey tab at index 2 (Home, Community, **Journey**, Profile)
- `Circles/Profile/ProfileView.swift` — remove `spiritualLedgerButton`, `niyyahCount`, `showSpiritualLedger`, ledger `fullScreenCover`

### Files to Delete
- `Circles/Profile/SpiritualLedgerView.swift` — fully replaced by Journey tab

### Reuse (no changes needed)
- `NiyyahService.fetchMyNiyyahs()` — fetch all for user, filter by month in VM
- `MomentService.fetchMomentForDate()` — for day detail photo lookup
- `NoorAuraOverlay.swift` — on detail view photo
- `IslamicGeometricPattern.swift` — background texture on detail view

### Data Model
```swift
struct JourneyDay {
    let date: Date
    let niyyah: MomentNiyyah?    // nil = no niyyah that day
    let hasPostedMoment: Bool    // true if circle_moments row exists
    // photo URL resolved on-demand when detail opens
}
```

### Fetching Strategy (performance)
- Fetch all `moment_niyyahs` for user at once (tiny table, ≤365/year) — primary dataset
- Fetch `circle_moments` for displayed month only, just `user_id` + date range, no photo URLs
- Cache both in VM — month nav is instant after first load
- Sign photo URL only on day detail tap (one call per tap, not 30)
- Prefetch adjacent month in background on current month render

### Key Concerns to Design Around
1. **`circle_moments` deduplication** — same photo posted to N circles = N rows. Deduplicate by date in VM (take first row per date, same photo path)
2. **Timezone** — `moment_niyyahs.photo_date` is DATE (UTC). `circle_moments.posted_at` is TIMESTAMPTZ. Use UTC date math consistently (same pattern as `computeHasPostedToday`)
3. **Empty state** — show full calendar grid even with no entries; overlay gentle message *"Your journey begins with your first intention"*
4. **Tab icon** — `calendar` SF symbol works; confirm all 4 tab icons read clearly together

### After Journey Tab
Next phase after Journey is fully built and QA'd: **Profile Tab Redesign** (10/10 UI/UX pass, new visual identity treatment).

---

## Simulator UDID
`AAD4DE32-6D0C-4C10-BCF1-1A4612DD9D92` (iPhone 17 Pro, OS 26.3.1)
