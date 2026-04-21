# Worktree Workflow

This document defines how parallel agent work should be run in this repo without colliding in Git.

## Goal

Allow multiple active workstreams at the same time while keeping:
- uncommitted changes isolated
- branch history clean
- merge conflicts predictable
- session handoffs simple

## Core Rule

One active workstream = one branch + one worktree + one branch note.

Do not have multiple agents working in the same checkout.

---

## Standard Layout

Example:

- main checkout: `/Users/abdulsaboorshaikh/Desktop/Circles`
- notifications checkout: `/Users/abdulsaboorshaikh/Desktop/Circles-notifications`
- testing checkout: `/Users/abdulsaboorshaikh/Desktop/Circles-testing`

Example branches:

- `phase-13-followup-testing`
- `phase-15-social-pulse`

Branch notes:

- `.planning/notes/phase-13-followup-testing.md`
- `.planning/notes/phase-15-social-pulse.md`

---

## Creating A New Worktree

From the main repo checkout:

```bash
cd /Users/abdulsaboorshaikh/Desktop/Circles
git worktree add ../Circles-notifications -b phase-15-social-pulse
```

If the branch already exists:

```bash
cd /Users/abdulsaboorshaikh/Desktop/Circles
git worktree add ../Circles-notifications phase-15-social-pulse
```

After creation:

```bash
cd /Users/abdulsaboorshaikh/Desktop/Circles-notifications
git branch --show-current
git status
```

---

## Session Start Checklist

At the start of each session in a worktree:

1. Confirm the directory
2. Confirm the active branch
3. Run `git status`
4. Read the branch note in `.planning/notes/`
5. Continue only that workstream

Recommended commands:

```bash
pwd
git branch --show-current
git status
```

---

## Session End Checklist

Before ending a session:

1. Commit stable changes or leave a very clear partial state
2. Update the branch note
3. If the work creates repo-wide implications, update `.planning/HANDOFF.md`
4. Record what still needs verification

Do not leave ambiguous uncommitted changes without updating the branch note.

---

## Branch Note Rules

Every active workstream should maintain a branch-specific note file.

Required sections:
- Goal
- Scope
- Touched Files
- Decisions
- Verified
- Next
- Blockers

Use `.planning/notes/_TEMPLATE.md`.

Branch notes are for session continuity within one stream.

`.planning/HANDOFF.md` is for repo-wide coordination across streams.

---

## Conflict Avoidance Rules

- Never have two agents work in the same directory
- Never commit directly to `main`
- Keep ownership explicit by phase or subsystem
- Minimize overlap in shared files
- If overlap is unavoidable, keep commits small and frequent
- Record shared-file edits in the branch note

Higher-risk shared files:
- `Circles/CirclesApp.swift`
- `Circles/ContentView.swift`
- central services
- shared models
- auth/session bootstrap code

---

## Integration Workflow

When one branch is ready:

1. Build and test that branch in its own worktree
2. Merge it into `main`
3. Move to the remaining branch
4. Update that branch from `main`
5. Resolve conflicts there
6. Rebuild and retest
7. Merge the updated branch

Use either:

```bash
git rebase main
```

or:

```bash
git merge main
```

Prefer one strategy consistently within a workstream.

---

## Ownership Model

Parallel work is safer if each workstream owns a clear surface area.

Example:
- testing branch owns QA fixes, regressions, runtime validation
- notifications branch owns notification service, permission flow, APNs registration, settings UI related to notifications

If a workstream must touch a shared integration point, document it immediately in:
- the branch note
- `.planning/HANDOFF.md` if it affects other streams

---

## Recommended Branch Naming

Use names that match a single active phase or concern:

- `phase-13-followup-testing`
- `phase-15-social-pulse`
- `phase-15-social-pulse-settings`

Avoid vague names like:
- `fixes`
- `new-work`
- `abdul-branch`

---

## Recovery Rules

If a worktree becomes stale:

1. Check whether its branch has uncommitted changes
2. Commit or stash only within that worktree if needed
3. Update from `main`
4. Resolve conflicts in that branch
5. Rebuild before continuing

Do not delete a worktree with uncommitted changes unless you have intentionally preserved the state elsewhere.

---

## Quick Commands

List worktrees:

```bash
git worktree list
```

Remove a worktree after the branch is clean and no longer needed:

```bash
git worktree remove ../Circles-notifications
```

See current branch:

```bash
git branch --show-current
```

---

## Decision Summary

- `HANDOFF.md` = shared repo coordination
- `.planning/notes/*.md` = per-workstream continuity
- `WORKTREE_WORKFLOW.md` = permanent operating instructions
