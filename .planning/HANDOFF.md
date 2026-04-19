# Shared Handoff

This file is the repo-wide coordination doc for parallel workstreams.

Do not use this file as a session diary. Do not paste long narrative handoffs here.

Use this file for:
- what is merged to `main`
- which branches/worktrees are active
- merge order
- shared integration risks
- files or surfaces with likely overlap

Use branch-specific notes under `.planning/notes/` for session continuity within a single workstream.

---

## Current Repo State

### Default Branch
- `main`

### Merged To Main
- Phase 13 core UI/UX pass is substantially complete
- Profile / Settings redesign is in place
- Nudge-count fix is implemented
- Daily Moment active-cycle visibility fix is implemented

### Active Workstreams
- `phase-13-followup-testing`
  - purpose: final-pass bug fixes and post-Phase-13 runtime validation
  - worktree: set locally by active agent
  - branch note: `.planning/notes/phase-13-followup-testing.md`
- `phase-14-notifications`
  - purpose: notification architecture and implementation
  - worktree: set locally by active agent
  - branch note: `.planning/notes/phase-14-notifications.md`

### Recommended Merge Order
1. Merge the lower-risk branch first
2. Update the remaining branch from `main`
3. Resolve conflicts there
4. Rebuild and re-test
5. Merge the second branch

If one branch heavily changes shared app lifecycle code, merge that branch first so the other branch can rebase onto the final shape.

---

## Integration Hotspots

Changes in these files or areas are more likely to overlap across branches:
- `Circles/CirclesApp.swift`
- `Circles/ContentView.swift`
- `Circles/Services/`
- `Circles/Profile/`
- `Circles/Home/`
- shared models used across multiple flows
- any push / auth / session bootstrap logic

When a workstream touches one of these areas:
- keep commits small
- note the exact files in the branch-specific note
- update this shared handoff if the change affects other branches

---

## Coordination Rules

- Each active agent should work in its own `git worktree`
- Each active agent should use its own branch
- No agent should commit directly to `main`
- Avoid editing the same files in parallel unless necessary
- Before stopping a session, update the branch note in `.planning/notes/`
- Update this file only when repo-wide coordination state changes

---

## Branch Note Convention

Each active workstream should maintain a note file in `.planning/notes/` with:
- goal
- touched files
- decisions
- verified state
- next step
- blockers

Template:
- `.planning/notes/_TEMPLATE.md`

---

## Open Cross-Stream Risks

- Notification work may need app lifecycle or token-registration changes that overlap with shared services
- Final-pass testing may expose issues in shared flows that notifications also touch
- If both branches modify startup routing or shared models, expect rebase friction

---

## Update Checklist

Update this file when:
- a new branch/worktree becomes active
- a branch merges to `main`
- merge order changes
- a new integration hotspot appears
- one workstream creates a repo-wide constraint for another

Do not update this file for ordinary per-session progress. Put that in the branch note instead.
