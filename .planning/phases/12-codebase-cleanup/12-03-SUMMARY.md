---
plan: 12-03
status: complete
completed: 2026-04-06
---

# Plan 12-03 Summary: Consolidate MS Tokens + Simplify ThemeManager

## What Was Built

Eliminated ~200 lines of duplicated `private extension Color` MS token definitions spread across 26 files by consolidating into a single shared internal extension in `DesignTokens.swift`. Simplified `ThemeManager` from a 150+ line class with NOAA solar math to a 17-line dark-mode enforcer.

## Tasks Completed

| Task | Status | Notes |
|------|--------|-------|
| Task 1: Add shared MS tokens to DesignTokens.swift | ✓ | 11 tokens added as internal extension |
| Task 2: Remove private Color blocks from 26 files | ✓ | 0 private blocks remain; `msCardPersonal` → `msCardDeep` in HomeView |
| Task 3: Simplify ThemeManager, remove NOAA solar math | ✓ | 17 lines; `scheduleAutoSwitch()` removed from CirclesApp |
| Task 4: Simulator smoke test | ⏳ | Human verification — deferred |

## Key Decisions

- `msCardPersonal` (HomeView) renamed to `msCardDeep` — same hex `#1E3122`, one canonical name
- Token `msBorder` uses canonical `0.18` opacity (some files had `0.28` — aligned to 0.18)
- `ThemeManager.colorScheme` changed from `var` to `let` (always `.dark`, no mutation needed)
- ContentView.swift unchanged — still reads `themeManager.colorScheme` which now returns constant `.dark`

## Files Modified

- `Circles/DesignSystem/DesignTokens.swift` — added MS token extension (11 tokens)
- `Circles/DesignSystem/ThemeManager.swift` — rewritten to 17-line dark-mode enforcer
- `Circles/CirclesApp.swift` — removed `scheduleAutoSwitch()` call
- 26 view files — removed `private extension Color` blocks

## Verification

```
grep -rn "private extension Color" Circles/ → 0 results ✓
grep -rn "msCardPersonal" Circles/ → 0 results ✓
grep -n "scheduleAutoSwitch" Circles/CirclesApp.swift → 0 results ✓
wc -l Circles/DesignSystem/ThemeManager.swift → 17 lines ✓
```

Build: `** BUILD SUCCEEDED **` — zero errors.

## Self-Check: PASSED
