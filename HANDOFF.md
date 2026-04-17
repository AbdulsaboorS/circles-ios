# Handoff — Session 2026-04-16 (Final-Pass Bug Fixes)

Use [`.planning/HANDOFF.md`](/Users/abdulsaboorshaikh/Desktop/Circles/.planning/HANDOFF.md) as the source of truth for the next session.

## Current status

- Phase 13 remains in final-pass mode.
- The BeReal-inspired `Profile / Settings` redesign is now implemented.
- Two follow-up bug fixes are now implemented locally:
  - `Nudges Sent` now uses the real nudge source of truth and refreshes in-session
  - posted Moments now stay visible across Feed / Circles for the active daily-moment cycle instead of disappearing at UTC midnight
- Build is verified locally with `xcodebuild`.
- The user has not runtime-tested these latest two bug fixes yet and plans to test them after the next bug is fixed.
- Next-session work should continue the remaining final-pass bug list and then do runtime QA.

## Latest relevant work

- `NudgeService.swift`, `ProfileView.swift`, `ProfileViewModel.swift`, `HomeView.swift`, `HomeViewModel.swift`
  - `Nudges Sent` no longer reads `habit_reactions`
  - canonical count now comes from `nudge_log` / RPC helper path
  - successful nudge sends now publish an in-session refresh event
  - Home presence-sheet nudges now hit the backend instead of only toggling local UI state
- `DailyMomentService.swift`, `FeedService.swift`, `MomentService.swift`
  - social moment visibility now follows the active daily-moment cycle
  - Feed / circle cards / circle detail / `hasPostedToday` no longer drop posts at UTC midnight
- `.planning/phases/01-schema-foundations/nudge_log_count_rpc.sql`
  - added as the repo-side helper SQL for sender-scoped `Nudges Sent` counting

## Next-session focus

1. Read [`.planning/HANDOFF.md`](/Users/abdulsaboorshaikh/Desktop/Circles/.planning/HANDOFF.md) first.
2. Continue with the next remaining bug from the user’s final-pass list.
3. After that bug is fixed, runtime-test the newly implemented nudge-count and moment-visibility fixes.
4. Continue final Phase 13 polish and QA from there.
