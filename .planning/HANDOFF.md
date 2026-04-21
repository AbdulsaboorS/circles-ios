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
- Phase 13 fully complete — all waves (1–6) signed off
- Journey tab (Phase 13A) shipped and QA'd
- Profile hero + settings card polish shipped (2026-04-20)
- Bugs C (habit icon) and F (niyyah save) resolved
- Moment gate tests 1–5 all verified

### Active Workstreams
- `phase-14-notifications` *(branch name is historical — this work is now scoped as new Phase 15 — Social Pulse per the 2026-04-20 renumbering in ROADMAP.md)*
  - purpose: notification architecture and implementation (nudges, comment push, permission UX, real-device verification)
  - worktree: `/Users/abdulsaboorshaikh/Desktop/Circles/.claude/worktrees/phase-14-notifications`
  - branch note: `.planning/notes/phase-14-notifications.md`
  - status: Phase 14.1 built + build-verified; needs SQL migration run + manual QA
  - conceptual mapping: branch name `phase-14-notifications` → new **Phase 15 — Social Pulse**. Do not rename the branch; update branch-local docs to reference new numbering.

### Next Workstream on `main`
- **Phase 14 — Meaningful Habits** (Personalization Era scope locked 2026-04-20)
  - See ROADMAP.md for full scope
  - In-flight streak glow work on `main` pauses and folds into Phase 14's streak visual
  - Misc behaviour-bug fixes still ship as standalone commits on `main`
  - Habit-catalog overhaul absorbed into Phase 14 (no longer a separate workstream)

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
