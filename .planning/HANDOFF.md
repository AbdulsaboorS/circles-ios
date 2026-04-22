# Shared Handoff

Repo-wide coordination only. Session detail lives in `.planning/notes/`.

---

## On Main (2026-04-22)

- Phases 1–14 complete and QA'd
- Phase 13A (Journey) + 13B (Profile redesign) shipped
- Session fixes pushed: multi-select Gemini, quiz re-entry delta, Habit Detail two-state redesign, NoorInfoSheet copy overhaul

## Active Branches

- `phase-15-social-pulse` — worktree at `.claude/worktrees/phase-15-social-pulse`
  - 15.1 + 15.2 built, pending user verification
  - Remaining: 15.3 circle check-in notifications, 15.4 habit reminders, hardening
  - Do not merge until Amir onboarding overhaul ships on `main`

## Next on Main

**Amir Onboarding Overhaul** — routing bug fix, flow reorder, 3 shared-personalization questions, catalog ranking, dead code removal. Full spec in `.planning/notes/main.md`.

## Integration Hotspots

- `Circles/CirclesApp.swift`
- `Circles/ContentView.swift`
- `Circles/Services/`
- `Circles/Home/`
- `Circles/Onboarding/`
