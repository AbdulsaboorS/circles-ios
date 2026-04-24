# Worktree Workflow
> On-demand only. Do not read this at session start unless the user is actively using parallel worktrees.

## Goal
Run parallel workstreams without colliding in Git.

Core rule:
- one active workstream = one branch + one worktree + one branch note
- never have multiple agents working in the same checkout

## Standard Layout
- main checkout: `/Users/abdulsaboorshaikh/Desktop/Circles`
- extra worktrees live beside it or under `.claude/worktrees/`
- each worktree uses its own branch
- each active worktree may keep a branch note under `.planning/notes/`

## Create A Worktree
From the main checkout:

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
cd ../Circles-notifications
pwd
git branch --show-current
git status
```

## Session Start
1. Confirm the directory
2. Confirm the active branch
3. Run `git status`
4. Read the branch note if one exists
5. Continue only that workstream

## Session End
1. Commit stable changes or leave a very clear partial state
2. Update the branch note if one is being used
3. Update `.planning/HANDOFF.md` only if repo-wide coordination changed
4. Record what still needs verification

Do not leave ambiguous uncommitted changes behind.

## Branch Notes
Branch notes are optional but useful when a worktree will be resumed later.

If you use one, keep it short and focused on:
- goal
- scope
- touched files
- decisions
- verified state
- next step
- blockers

Use `.planning/HANDOFF.md` for repo-wide coordination, not branch notes.

## Conflict Avoidance
- never have two agents work in the same directory
- never commit directly to `main` from parallel work unless explicitly intended
- keep ownership explicit by phase or subsystem
- minimize overlap in shared startup, routing, service, and model files
- if overlap is unavoidable, keep commits small and document it

Higher-risk shared files:
- `Circles/CirclesApp.swift`
- `Circles/ContentView.swift`
- `Circles/Services/`
- `Circles/Home/`
- `Circles/Profile/`
- shared models and routing code

## Integration Workflow
1. Build and verify the branch in its own worktree
2. Merge it into `main`
3. Update the remaining branch from `main`
4. Resolve conflicts there
5. Rebuild and reverify
6. Merge the updated branch

Use either `git rebase main` or `git merge main`, but stay consistent within a workstream.

## Recovery
If a worktree becomes stale:
1. Check for uncommitted changes
2. Commit or intentionally stash them in that worktree
3. Update from `main`
4. Resolve conflicts
5. Rebuild before continuing

Do not delete a worktree with uncommitted changes unless that state is intentionally preserved elsewhere.

## Quick Commands

```bash
git worktree list
git worktree remove ../Circles-notifications
git branch --show-current
```

## Summary
- `HANDOFF.md` = shared repo coordination
- `.planning/notes/*.md` = optional per-worktree continuity
- `WORKTREE_WORKFLOW.md` = on-demand operating instructions
