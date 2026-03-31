# Agent handoff — Circles iOS

**Use this when switching agents.** Detailed inventory lives in `STATE.md` and `ROADMAP.md`.

## Read first

| File | Purpose |
|------|---------|
| [`STATE.md`](STATE.md) | What's built, phase list, **open issues & QA** |
| [`ROADMAP.md`](ROADMAP.md) | Phase 12 scope + remaining work |
| [`../CLAUDE.md`](../CLAUDE.md) | Repo layout, conventions, SQL notes, troubleshooting |
| [`phases/01-schema-foundations/habit_plans_align_app.sql`](phases/01-schema-foundations/habit_plans_align_app.sql) | Idempotent `habit_plans` + `NOTIFY pgrst, 'reload schema'` |
| [`phases/11-ai-roadmap/migration.sql`](phases/11-ai-roadmap/migration.sql) | Refinement RPC + `refinement_cycle` |

## Current position

- **Product:** v2.4 — Phase **11.1 (Midnight Sanctuary UI pass) COMPLETE.** All 4 groups shipped.
- **Next task:** Start Phase **11.2 — E2E QA + Bug Fixes**. Full E2E test every screen, fix known issues in `STATE.md` → Open issues, fix anything new found during testing.
- **Design:** "Midnight Sanctuary" is fully applied to all screens. See `STATE.md` → Phase 11.1 section.
- **Supabase:** Disable "Confirm email" in Auth → Settings (Dashboard only — MCP cannot do this). Required for email/password test login in AuthView.
- **Testing:** User is actively testing the app. Prioritize E2E QA before Phase 12 polish.

## Swift / Xcode 26 note

**`Color.msToken` must be explicit** — Xcode 26 / Swift 6 does NOT infer `Color` from shorthand dot syntax (`.msGold`) when the expected type is `ShapeStyle`. Always use `Color.msGold`, `Color.msTextPrimary`, etc. in new MS-themed code.

## Secrets (local only)

`Circles/Secrets.plist`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`.

## Git

`main` → `origin` (GitHub: AbdulsaboorS/circles-ios)
Latest commit: `1d0dfbd` — Phase 11.1 Groups 3 & 4 complete
