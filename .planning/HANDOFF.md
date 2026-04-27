# Shared Handoff

Repo-wide coordination only. Keep this file short.

Use it for:
- what is on `main`
- active worktrees when they exist
- merge sequencing
- overlap risks

Do not use it for session history, long QA plans, or feature specs.

## Current Repo State

### Default Branch
- `main`

### On Main
- Phase 13 UI/UX pass is complete
- Journey tab shipped
- Profile hero/settings polish shipped
- Phase 14 Meaningful Habits is built and awaiting hands-on validation
- Phase 15 Social Pulse is now merged to `main`
- Phase 15 rollout and combined end-to-end notification QA remain intentionally deferred

### Active Worktrees
- none currently tracked as active in this handoff

### Open Planning Thread
- Onboarding QA pass in progress on `main`. Bugs #1–4 + #6 fixed 2026-04-26 session 1. Bug #5 closed session 2 (back-nav sufficient for MVP). Catalog migration for the onboarding suggestion path shipped 2026-04-27 session 3: deterministic `HabitCatalog` now drives Amir shared habits and both personal quiz flows. Build is green; hands-on QA is next. No cross-stream conflicts.
- Earlier (2026-04-25 session 2) onboarding gaps A + B baseline still in place; gaps C (mirror copy) and D (Path 1 plan reveal) still deferred.

### Next Session — Pickup Notes
- **Run full onboarding QA on the shipped catalog path.** Amir should now be 3 personalization screens → shared habits (7 total = 4 personalized + 3 starters, cap 2) → identity → private quiz (cap 3) → AI gen → moment → foundation → auth. Joiner should be circle alignment → transition → private quiz (7 total, cap 3) → AI gen → moment → identity → auth. Confirm custom habits add as removable chips inline on both active selection screens.
- **Regression checks to watch:** back-nav should preserve enum + `custom:` struggle answers, habit selections should stay deterministic for the same inputs, catalog entries should show their baked rationale / per-spirituality variant immediately with no network dependency, and no screen should still reference the old Groq/Gemini suggestion path.
- **Build baseline:** `xcodebuild -quiet -project Circles.xcodeproj -scheme Circles -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' build` passed on 2026-04-27 after this migration. Remaining warning is the pre-existing `FeedService.swift:99` unnecessary `await`.

### Product Priority Order
1. Test onboarding bugs and fix them
2. Do the full UI/UX pass
3. Finalize the name
4. Finalize the logo
5. Work on landing-page video animations and onboarding animations if needed

## Integration Hotspots

- `Circles/CirclesApp.swift`
- `Circles/ContentView.swift`
- `Circles/Navigation/`
- `Circles/Services/`
- `Circles/Profile/`
- `Circles/Home/`
- shared notification models and routing

## Coordination Rules

- one active stream per `git worktree`
- one branch per stream
- no direct commits to `main` unless the user explicitly wants main updated
- keep this file repo-wide and current-state only
- keep detailed QA notes outside startup docs
