# Handoff — 2026-04-07 (Session End: Context Limit)

## What Was Done This Session

### Phase 13 — Wave 1 (Home) — IMPLEMENTATION IN PROGRESS

User provided comprehensive feedback from an AI-agent UX audit. All changes except Item 4 (Bento compact tiles) were implemented and committed as one commit. Item 4 is queued as a **separate second commit** (git strategy: user can revert Item 4 without losing all other changes).

---

## Changes Shipped This Session

### HabitService.swift
- `broadcastHabitCompletion`: added dedup guard — queries `activity_feed` for existing `(user_id, habit_name, event_type, created_at >= today)` before inserting. Prevents duplicate feed cards on toggle-on/toggle-off/toggle-on within same day.
- Added `archiveHabit(habitId:)` — soft-delete via `is_active = false`, preserves logs/plans.

### HomeViewModel.swift
- `toggleHabit`: added once-per-day lock — `guard !isCompleted(habitId: habit.id) else { return }` at top. Users can no longer uncheck a habit after checking in.
- Added `allHabitsCompleted: Bool` computed property — `!habits.isEmpty && habits.allSatisfy { isCompleted }`. Used by heart glow logic.
- Added `deleteHabit(_ habit: Habit) async` — optimistic removal from local array + `archiveHabit` call.

### HomeView.swift (complete rewrite — all changes below)
1. **Hero card bug fixed** — HeroHabitCard is now inside a `NavigationLink(value: hero)` when NOT in edit mode. Opens HabitDetailView on tap (non-button area).
2. **"Now" badge removed** — HeroHabitCard no longer shows the `🌙 Now` capsule badge.
3. **Heart state** — heart medallion ignites gold only when `viewModel.allHabitsCompleted`. Dim/muted gradient when habits remain. Smooth `.easeInOut(0.6)` transition.
4. **Edit mode system**:
   - `@State private var isEditMode: Bool` added
   - Long-press on HeroHabitCard (`simultaneousGesture`) → enter edit mode
   - Drag on any shared/personal grid card (`onDrag`) → auto-enters edit mode + haptic
   - All cards `wobble(active: isEditMode)` via `WobbleModifier` (oscillates ±2.5°)
   - Edit mode bar appears at top of habits section: hint text + "Done" button
   - "Done" button exits edit mode
   - Drag-to-reorder gated: `HabitDropDelegate.dropEntered` checks `isEditMode` before moving
   - Check-in buttons disabled in edit mode (guard in onToggle closures)
5. **Delete personal intentions**:
   - `PersonalHabitCard` now takes `isEditMode: Bool` + `onDelete: () -> Void`
   - In edit mode, a red `×` badge appears top-left of each personal card
   - Tapping `×` sets `habitToDelete = habit`
   - `DeleteConfirmationModal` overlay appears — Midnight Green card, gold border, serif font
   - Custom copy: "Are you sure you want to remove \"\(habitName)\" from your sacred intentions?"
   - "Keep It" cancels, "Remove" calls `viewModel.deleteHabit` + exits edit mode
6. **Card depth (inner shadows)** — all card backgrounds have a blurred dark stroke overlay simulating carved inner shadow. Applied to HeroHabitCard, SharedHabitCard, PersonalHabitCard.
7. **Grain on cards** — `CardGrain` canvas view (300 pre-computed points, opacity 0.032) overlaid on all card backgrounds. Separate from global `GrainTexture` (900 points).
8. **Gender copy** — `CirclePresenceRow`: "brothers checked in" → "members checked in". `MembersSheet`: `.navigationTitle("Brothers")` → `.navigationTitle("Your Circle")`.
9. **Fallback presence names** — `Omar/Amir/Khalid` generic placeholders → `Member` with initials `M1/M2/M3`.
10. **Empty state copy** — "Complete onboarding to begin your journey." → "Tap + to add your first intention."
11. **Invite nudge copy** — "Invite 2 brothers/sisters to begin." → "Invite your circle to activate the group streak."
12. **Once-per-day UI lock** — Check-in buttons get `.disabled(isCompleted)` in HeroHabitCard and SharedHabitCard. PersonalHabitCard check-in button also disabled when isCompleted. Visually: Done state still shows gold, but button doesn't respond.
13. **Navigation from grid cards** — SharedHabitCard and PersonalHabitCard use `.onTapGesture { guard !isEditMode; navigationPath.append(habit) }` instead of NavigationLink wrapping (avoids gesture conflicts with drag and edit mode).

**Build: `** BUILD SUCCEEDED **` — zero errors, 2 unused-withAnimation warnings (cosmetic, no impact).**

---

## What's NOT Done Yet (next step for this wave)

### Item 4 — Bento Compact Tiles (QUEUED — do as separate commit)

This was deliberately deferred to a second commit so the user can revert it independently.

**What to implement:**
- In `habitGrid` (the shared habits 2-column grid): completed habits render as a compact tile instead of a full card.
- Compact tile: shows only the centered icon + gold checkmark. Height ~72pt. No name, no "Check In" button.
- Full card: the current `SharedHabitCard` unchanged. Height ~130pt.
- Sorting: pending habits first (top of grid), completed habits last (bottom as compact tiles). This gives the "UI clears up" reward as day progresses.
- Completed habits in compact form still navigate to HabitDetailView on tap (per user decision).
- Implementation: add a `CompactHabitTile` private struct. In `habitGrid`, use `if isCompleted { CompactHabitTile(...) } else { SharedHabitCard(...) }`.
- LazyVGrid handles the height mismatch naturally (per-column flow, no row synchronization).

**The Hero card:** Hero (`habits.first`) is always shown as `HeroHabitCard` (full card) even when completed — it's the spiritual anchor, not subject to the compact treatment.

---

## Wave Order (Phase 13 reminder)

| Wave | Screen | Status |
|------|--------|--------|
| 1 | Home (Dashboard) | 🔄 In progress — Item 4 (Bento) next, then user sign-off |
| 2 | Habit Detail | ⬜ Not started |
| 3 | Community / Feed | ⬜ Not started |
| 4 | Feed cards | ⬜ Not started |
| 5 | My Circles + Circle Detail | ⬜ Not started |
| 6 | Profile | ⬜ Not started |
| 7 | Auth screen | ⬜ Not started |

---

## Open Issues / Notes

- Two `withAnimation` result-unused warnings in `HomeView.swift` (lines ~918, ~1382). Cosmetic — build succeeds. Fix if desired by assigning to `_ =` or using `withAnimation { }.value`.
- RLS bug for `circle_moments` INSERT — pre-existing, unresolved, not touched this session.
- Phase 13 has NO GSD plan files — this is intentional. Interactive iteration only.
- Simulator UDID: `AAD4DE32-6D0C-4C10-BCF1-1A4612DD9D92` (iPhone 17 Pro, OS 26.3.1).

---

## Files Changed This Session

- `Circles/Services/HabitService.swift`
- `Circles/Home/HomeViewModel.swift`
- `Circles/Home/HomeView.swift` (complete rewrite)
