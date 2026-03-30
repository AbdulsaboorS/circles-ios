Phase 10 — group streak (Supabase)

**Do not paste this README into the SQL Editor.** It is Markdown, not SQL.

## What to run

1. Open **`migration.sql`** in this folder.
2. Select all → copy → Supabase Dashboard → SQL Editor → paste → Run.

Optional (Amir update / remove member RLS only if needed): run **`migration-optional-rls.sql`** the same way. Skip any policy that already exists.

## What the migration does

- Adds `circles.group_streak_last_complete_utc_date`.
- Creates a `SECURITY DEFINER` trigger on `circle_moments` so `group_streak_days` updates when every member has posted for the same UTC calendar day.
