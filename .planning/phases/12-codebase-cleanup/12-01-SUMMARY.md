---
phase: 12-codebase-cleanup
plan: 01
subsystem: ui
tags: [swift, swiftui, cleanup, dead-code, onboarding, refactor]

requires:
  - phase: 11-ai-roadmap
    provides: Final live codebase before cleanup pass

provides:
  - 12 dead Swift files removed from disk (11 deleted, 1 renamed to correct name)
  - HalaqaMember.swift renamed to CircleMember.swift (correct model name)
  - ShareSheet extracted to Extensions/ShareSheet.swift (app-wide reuse)
  - LocationPickerView stripped of dead OnboardingCoordinator dependency
  - Old v1 OnboardingCoordinator cluster eliminated
  - Build compiles clean with zero errors

affects: [13-ui-ux-pass, design-system-consolidation]

tech-stack:
  added: []
  patterns:
    - "Dead file deletion: confirm zero external references before deleting"
    - "Model files should be named after the type they define"
    - "Shared UIKit bridges (ShareSheet) live in Extensions/"

key-files:
  created:
    - Circles/Models/CircleMember.swift
    - Circles/Extensions/ShareSheet.swift
  modified:
    - Circles/Onboarding/LocationPickerView.swift

key-decisions:
  - "HalaqaMember.swift was misnamed — contained CircleMember struct used app-wide; renamed not deleted"
  - "ShareSheet (UIActivityViewController bridge) extracted from AmiirStep4SoulGateView to Extensions/ for app-wide access"
  - "LocationPickerView kept but stripped of OnboardingCoordinator dependency — only cities static array is used by live code"

patterns-established:
  - "Verify build after each wave of deletions — hidden dependencies surface quickly"

requirements-completed: [CLEANUP-01]

duration: 25min
completed: 2026-04-07
---

# Phase 12 Plan 01: Delete Dead Files Summary

**Removed 12 dead Swift files (v1 OnboardingCoordinator cluster + 4 isolated dead files) while fixing two hidden dependencies discovered during deletion**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-07T00:57:50Z
- **Completed:** 2026-04-07T01:19:50Z
- **Tasks:** 2 of 3 auto-executed (Task 3 is human simulator verification)
- **Files modified:** 3 modified, 11 deleted, 2 created

## Accomplishments
- Deleted 4 isolated dead files: MomentCardView, JoinFromLinkView, AppIconView, HalaqaMember (renamed to CircleMember)
- Deleted 8 dead v1 onboarding files: OnboardingCoordinator, ProfileSetupView, RamadanAmountView, AIStepDownView, HabitSelectionView, AmiirStep4SoulGateView, MemberStep1HabitsView, MemberStep2LocationView
- Fixed hidden dependency: HalaqaMember.swift defined CircleMember (used throughout app) — recreated as CircleMember.swift
- Fixed hidden dependency: AmiirStep4SoulGateView.swift defined ShareSheet (used by HomeView) — extracted to Extensions/ShareSheet.swift
- LocationPickerView stripped of dead OnboardingCoordinator environment dependency while preserving static cities array

## Task Commits

1. **Task 1: Delete 4 isolated dead files** - `3b28d7e` (chore)
2. **Task 2: Delete old OnboardingCoordinator cluster** - `f6a07df` (chore)

## Files Created/Modified
- `Circles/Models/CircleMember.swift` - Created: CircleMember model (renamed from HalaqaMember.swift)
- `Circles/Extensions/ShareSheet.swift` - Created: UIActivityViewController bridge, extracted from deleted AmiirStep4SoulGateView
- `Circles/Onboarding/LocationPickerView.swift` - Modified: removed OnboardingCoordinator @Environment dependency, kept static cities array

## Decisions Made
- Renamed HalaqaMember.swift to CircleMember.swift rather than truly deleting — the file defined a live, widely-used type with a misleading filename
- ShareSheet extracted to Extensions/ (not Onboarding/) since it is a generic UIKit bridge used by HomeView's invite nudge feature, not onboarding-specific
- LocationPickerView kept as a stub view (body = EmptyView) because its `static let cities` array is used by AmiirStep3LocationView and JoinerIdentityView — full deletion would break compilation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] HalaqaMember.swift contained live CircleMember model**
- **Found during:** Task 1 (Delete 4 isolated dead files)
- **Issue:** Plan assessed HalaqaMember.swift as having "zero external references" but the file defined `struct CircleMember` which is used by CircleService, CircleDetailView, AmirCircleSettingsView, CirclePreviewView (9+ references). Deleting it caused a build failure.
- **Fix:** Recreated the model as `Circles/Models/CircleMember.swift` with the correct type name. Git detected this as a rename (100% similarity).
- **Files modified:** Circles/Models/CircleMember.swift (created)
- **Verification:** BUILD SUCCEEDED after recreation
- **Committed in:** 3b28d7e (Task 1 commit)

**2. [Rule 1 - Bug] AmiirStep4SoulGateView.swift defined ShareSheet used by HomeView**
- **Found during:** Task 2 (Delete old OnboardingCoordinator cluster)
- **Issue:** AmiirStep4SoulGateView.swift contained `struct ShareSheet: UIViewControllerRepresentable` which HomeView.swift references in its invite nudge share button. Deleting AmiirStep4SoulGateView caused a build failure.
- **Fix:** Extracted ShareSheet to `Circles/Extensions/ShareSheet.swift` as an app-wide utility.
- **Files modified:** Circles/Extensions/ShareSheet.swift (created)
- **Verification:** BUILD SUCCEEDED after extraction
- **Committed in:** f6a07df (Task 2 commit)

**3. [Rule 1 - Bug] LocationPickerView.swift used OnboardingCoordinator (deleted type)**
- **Found during:** Task 2 (Delete old OnboardingCoordinator cluster)
- **Issue:** LocationPickerView.swift had `@Environment(OnboardingCoordinator.self)` and called coordinator methods. After deleting OnboardingCoordinator, the file failed to compile with "cannot find type 'OnboardingCoordinator' in scope". The plan noted LocationPickerView should be kept for its cities array but didn't address this broken dependency.
- **Fix:** Stripped the OnboardingCoordinator @Environment and all coordinator calls from LocationPickerView, replacing body with EmptyView(). The `static let cities` array is preserved in place.
- **Files modified:** Circles/Onboarding/LocationPickerView.swift
- **Verification:** BUILD SUCCEEDED; AmiirStep3LocationView and JoinerIdentityView still compile using LocationPickerView.cities
- **Committed in:** f6a07df (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (all Rule 1 - hidden dependencies not caught in plan's reference analysis)
**Impact on plan:** All fixes required for build correctness. No scope creep. The plan's grep-based reference analysis missed struct-level definitions within files.

## Issues Encountered
- The plan's reference check strategy (grep for type names in filenames) missed cases where a file's name differs from the type it defines (HalaqaMember.swift vs CircleMember struct). Future deletion plans should grep for the type name, not just the filename.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Codebase is clean: 12 dead files removed, build is green
- Ready for Phase 12 Plan 02: MS token consolidation
- Task 3 (simulator smoke test) still requires manual verification in the simulator

---
*Phase: 12-codebase-cleanup*
*Completed: 2026-04-07*
