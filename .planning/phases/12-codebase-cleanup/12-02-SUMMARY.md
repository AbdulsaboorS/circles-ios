---
phase: 12-codebase-cleanup
plan: "02"
subsystem: design-system, services
tags: [cleanup, dead-code, refactor, components, flags]
dependency_graph:
  requires: [12-01]
  provides: [CLEANUP-02]
  affects: [HabitPlanService, HomeView, AmiirOnboardingCoordinator, MemberOnboardingCoordinator, Components, DesignSystem]
tech_stack:
  added: []
  patterns: [inline-flag-into-service, dead-component-pruning]
key_files:
  created: []
  modified:
    - Circles/Services/HabitPlanService.swift
    - Circles/Home/HomeView.swift
    - Circles/Onboarding/AmiirOnboardingCoordinator.swift
    - Circles/Onboarding/MemberOnboardingCoordinator.swift
    - Circles/DesignSystem/Components.swift
  deleted:
    - Circles/Services/RoadmapGenerationFlag.swift
    - Circles/DesignSystem/AppBackground.swift
decisions:
  - "Inlined 25-line RoadmapGenerationFlag enum into HabitPlanService as private static methods — eliminates dedicated file for trivial logic that belongs to the service"
  - "Preserved SectionHeader verbatim (with subtitle param) — CircleDetailView uses only title param but the full definition causes no harm and avoids silent API breakage"
  - "MARK comment in HabitPlanService documents inline origin — acceptable since it aids future readers understanding where the logic came from"
metrics:
  duration_minutes: 15
  completed_date: "2026-04-06"
  tasks_completed: 2
  tasks_total: 3
  files_modified: 5
  files_deleted: 2
---

# Phase 12 Plan 02: Design System Dead Weight + RoadmapGenerationFlag Inline Summary

**One-liner:** Removed 5 dead design-system components (AppCard, PrimaryButton, ChipButton, AppBackground) and inlined RoadmapGenerationFlag's 3 static UserDefaults methods into HabitPlanService, deleting 2 source files.

---

## Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Inline RoadmapGenerationFlag into HabitPlanService, delete the enum file | b6749f3 | HabitPlanService.swift (+28 lines), HomeView.swift, AmiirOnboardingCoordinator.swift, MemberOnboardingCoordinator.swift, deleted RoadmapGenerationFlag.swift |
| 2 | Prune Components.swift (delete dead wrappers), delete AppBackground.swift | 433ce68 | Components.swift (-138 lines), deleted AppBackground.swift |
| 3 | Simulator smoke test | — | Human verification task (build succeeded; runtime verification deferred to user) |

---

## Deviations from Plan

**None** — plan executed exactly as written.

Minor note: Components.swift is 33 lines (plan estimated < 25), because the actual SectionHeader definition has an optional `subtitle` parameter requiring slightly more code than the simplified version in the plan spec. The verbatim copy was preserved as required.

---

## Verification

Final grep output:
```
grep -rn "RoadmapGenerationFlag\." Circles/ --include="*.swift"  →  0 results
grep -rn "AppCard|PrimaryButton\b|AppBackground" Circles/ --include="*.swift"  →  0 results
```

Only remaining "RoadmapGenerationFlag" text in codebase is a MARK comment in HabitPlanService.swift: `// MARK: - Roadmap generation flag (inlined from RoadmapGenerationFlag)` — this is intentional documentation.

Build: `** BUILD SUCCEEDED **` (iPhone 17 simulator, iOS 26.3.1).

---

## What Was Removed

### RoadmapGenerationFlag.swift (deleted)
- 25-line enum with 3 static UserDefaults methods (set/clear/isActive)
- Logic inlined into HabitPlanService as setRoadmapGenerating / clearRoadmapGenerating / isRoadmapGenerating
- Key format preserved: `roadmap_generating_{userId.uuidString}`
- 5-minute staleness guard logic preserved exactly

### Components.swift (pruned from 171 → 33 lines)
- AppCard (32 lines) — dead, no external callers
- PrimaryButton (25 lines) — dead, no external callers
- ChipButton (26 lines) — dead, no external callers
- Two preview providers referencing the above dead components
- SectionHeader preserved verbatim

### AppBackground.swift (deleted)
- 75-line animated blob background view
- Only used in its own PreviewProvider and Components.swift previews
- No live views referenced it (all screens migrated to `Color(hex: "1A2E1E").ignoresSafeArea()` in Phase 11.1)

---

## Self-Check: PASSED

- [x] `Circles/Services/HabitPlanService.swift` exists and contains setRoadmapGenerating/clearRoadmapGenerating/isRoadmapGenerating
- [x] `Circles/Services/RoadmapGenerationFlag.swift` does not exist on disk
- [x] `Circles/DesignSystem/AppBackground.swift` does not exist on disk
- [x] `Circles/DesignSystem/Components.swift` exists and contains only SectionHeader
- [x] `b6749f3` commit exists in git log
- [x] `433ce68` commit exists in git log
- [x] Build succeeded with zero errors
