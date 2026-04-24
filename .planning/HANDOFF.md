# Shared Handoff

This file is the repo-wide coordination doc.

Keep it short. Use it for:
- what is on `main`
- which worktrees are active
- merge sequencing
- overlap risks

Do not use this file for session history, long QA plans, or phase specs.

## Current Repo State

### Default Branch
- `main`

### Merged To Main
- Phase 13 UI/UX pass is complete
- Journey tab shipped
- Profile hero/settings polish shipped
- Bugs C and F are resolved
- Phase 14 Meaningful Habits is built on `main` and awaiting hands-on validation

### Active Worktree
- `phase-15-social-pulse`
  - worktree: `/Users/abdulsaboorshaikh/Desktop/Circles/.claude/worktrees/phase-15-social-pulse`
  - scope: notifications, routing, settings, circle activity, habit reminders
  - status: code-complete and build-verified
  - deferred: `send-circle-check-in` deployment and combined end-to-end notification QA

### Product Priorities After Phase 15 Merge
1. Test onboarding bugs and fix them
2. Do the full UI/UX pass
3. Finalize the name
4. Finalize the logo
5. Work on landing-page video animations and onboarding animations if needed

## Merge Notes

- Phase 15 can be merged once you are ready to treat it as build-complete with QA deferred
- After merge, delete the Phase 15 worktree and any branch-only notes tied to it
- If `main` moves first in shared startup, routing, or notification files, rebuild after updating the branch

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
- no direct commits to `main`
- keep this file repo-wide and current-state only
- keep detailed QA notes outside startup docs
