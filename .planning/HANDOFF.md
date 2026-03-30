# Agent handoff — Circles iOS

**Use this when switching agents.** Detailed inventory lives in `STATE.md` and `ROADMAP.md`.

## Read first

| File | Purpose |
|------|---------|
| [`STATE.md`](STATE.md) | What’s built, phase list, **open issues & QA** |
| [`ROADMAP.md`](ROADMAP.md) | Phase 12 scope + remaining work |
| [`../CLAUDE.md`](../CLAUDE.md) | Repo layout, conventions, SQL notes, troubleshooting |
| [`phases/01-schema-foundations/habit_plans_align_app.sql`](phases/01-schema-foundations/habit_plans_align_app.sql) | Idempotent `habit_plans` + `NOTIFY pgrst, 'reload schema'` |
| [`phases/11-ai-roadmap/migration.sql`](phases/11-ai-roadmap/migration.sql) | Refinement RPC + `refinement_cycle` |

## Current position

- **Product:** v2.3 — Phases **1–11 shipped in code**; **Phase 12** (polish + App Store) is active.
- **Testing:** Manual QA surfaced integration/UI gaps (documented in `STATE.md` → Open issues).

## Secrets (local only)

`Circles/Secrets.plist`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`.

## Git

`main` → `origin` (GitHub)
