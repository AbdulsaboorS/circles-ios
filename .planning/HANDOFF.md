# Handoff — 2026-04-09 (Session End: Context Limit)

## What Was Done This Session

### Phase 13 — Wave 1 (Home) — CONTINUED

Three sets of changes were implemented and built successfully (zero errors).

---

## Changes Shipped This Session

### 1. Undo Check-In (HomeViewModel.swift + HabitService.swift + HomeView.swift)

**HomeViewModel.swift:**
- Removed once-per-day lock guard (`guard !isCompleted`)
- Added `private var checkInCount: [UUID: Int] = [:]` — tracks per-habit check-in count this session
- Added `var toastMessage: String? = nil` — observed by HomeView to show toast
- Rewrote `toggleHabit` to handle both check-in and undo paths:
  - **Undo path:** allowed if `checkInCount < 3`; removes activity_feed entry for accountable habits
  - **Check-in path:** increments count; at count==2 shows cheeky toast; at count>=3 shows lock toast + no further undos

**HabitService.swift:**
- Added `removeHabitCompletion(habitName:circleId:userId:)` — deletes today's activity_feed row on undo

**HomeView.swift:**
- Added `@State private var toastVisible` + `displayedToastMessage`
- Added `.onChange(of: viewModel.toastMessage)` — shows toast, auto-dismisses after 2.5s
- Added toast overlay (`.overlay(alignment: .bottom)`) with gold-bordered card style, padding above tab bar

### 2. Edit Mode Cleanup (HomeView.swift)

Partial cleanup already shipped:
- Removed `import UniformTypeIdentifiers`
- Removed `draggingId: UUID?` state
- Removed all `.onDrag` / `.onDrop` from `habitGrid` and `personalSection`
- Removed `HabitDropDelegate` struct
- Removed `CompactHabitTile` struct
- Added star ★ badge in edit mode on grid cards + `promoteToHero` function
- Fixed hero long-press by moving `.simultaneousGesture` inside NavigationLink label

**⚠️ USER REJECTED CURRENT EDIT MODE — see next steps below.**

### 3. Undo Button UX (HomeView.swift)

- `HeroHabitCard`: completed button re-enabled, relabeled "Undo" with muted style (undo icon + muted colors)
- `SharedHabitCard`: completed button re-enabled, relabeled "↩ Undo" with ghost capsule style
- `PersonalHabitCard`: completed button re-enabled, relabeled "Undo" with muted style
- All three: removed `.disabled(isCompleted)`

---

## What's NOT Done — Critical Next Steps

### PRIORITY 1 — Edit Mode Full Redesign (user explicitly rejected current edit mode)

**User's requirement:**
- Remove ALL current edit mode: no long-press, no wobble, no isEditMode state, no star badge, no edit mode bar
- Replace with an "Edit" button (pencil icon or text) on the far right of the "Shared Intentions" section header
- Tapping opens a **full-screen sheet** (`EditLayoutSheet`)
- Sheet layout:
  - Section 1: "Lead Intention" — the hero (first shared habit). Drag it or drag others above it to change hero.
  - Section 2: "Shared Intentions" — remaining shared habits, drag handles to reorder
  - Section 3: "Personal Intentions" — personal habits, drag handles to reorder + swipe-to-delete
- Native SwiftUI `List` with `.onMove` for all reordering (reliable, no gesture conflicts)
- Save button: persists new order to `sharedHabits`/`personalHabits` + calls `saveSharedOrder()`
- Cancel button: discards changes, dismisses sheet
- The × delete badge on `PersonalHabitCard` (currently `isEditMode`-gated) should be removed and replaced by swipe-to-delete inside the sheet

**What to remove completely:**
- `@State private var isEditMode: Bool`
- `WobbleModifier` struct + `.wobble()` View extension
- `isEditMode` star badge (`if isEditMode { Button { promoteToHero } ... }`) from `habitGrid`
- `promoteToHero(_:)` function
- Long-press gesture on hero card (`.simultaneousGesture` inside NavigationLink)
- Long-press + `isEditMode = true` in grid card `onDrag` (already removed drag, but remove the pattern)
- Edit mode control bar in `habitsSection` (`if isEditMode { HStack { Text("Tap ★...") ... } }`)
- `isEditMode` checks in `onTapGesture` guards on grid/personal cards
- `isEditMode` parameter on `PersonalHabitCard` + the × delete badge inside it
- `isEditMode` passed to `PersonalHabitCard` call sites

**What to add:**
- `@State private var showEditLayout = false` in HomeView
- "Edit" button (pencil SF Symbol, muted gold, small) at the trailing end of the "Shared Intentions" section header HStack
- `EditLayoutSheet` — a new private struct (or file) implementing the full-screen sheet as described
- `@State` copies of shared/personal order inside the sheet for cancel support

**Implementation note:** The sheet should work with copies of `sharedHabits` and `personalHabits`. On Save, copy back to HomeView state and call `saveSharedOrder()`. On Cancel, discard. `deleteHabit` in HomeViewModel should be called from swipe-to-delete in the sheet (needs the auth userId — pass it in or use `@Environment(AuthManager.self)`).

---

### PRIORITY 2 — Test and Verify Wave 1

Once edit mode redesign is done, user needs to test:
1. Undo check-in flow (3-step progressive lock)
2. Edit Layout sheet (reorder shared → hero changes, reorder personal, delete personal via swipe)
3. Completed habits sort to bottom of grid (Option 3)
4. All other Wave 1 items from original commit (heart state, card depth, etc.)

After user sign-off on Wave 1 → move to Wave 2 (Habit Detail screen).

---

## Current Build State

**BUILD SUCCEEDED — zero errors.**

Files changed this session:
- `Circles/Services/HabitService.swift`
- `Circles/Home/HomeViewModel.swift`
- `Circles/Home/HomeView.swift`

---

## Open Issues (carried from previous sessions)

- RLS bug for `circle_moments` INSERT — pre-existing, unresolved
- Gemini API `-1011` error — key/quota/model issue, unresolved
- Two `withAnimation` unused-result warnings in HomeView (cosmetic, no impact)

## Simulator UDID
`AAD4DE32-6D0C-4C10-BCF1-1A4612DD9D92` (iPhone 17 Pro, OS 26.3.1)
