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
- Onboarding QA pass in progress on `main`. Five minor issues fixed 2026-04-26 (Prayer Sync reframe + double back button, primer copy + niyyah beat, AI-gen → primer transition softened, quiz processing copy). Carry-forward bugs #5/#7/#8 tracked in STATE.md. No cross-stream conflicts.
- Earlier (2026-04-25 session 2) onboarding gaps A + B baseline still in place; gaps C (mirror copy) and D (Path 1 plan reveal) still deferred.

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
