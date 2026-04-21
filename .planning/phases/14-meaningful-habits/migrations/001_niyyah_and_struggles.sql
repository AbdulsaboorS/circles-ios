-- Phase 14.1 — Meaningful Habits schema deltas
--
-- Adds:
--   habits.niyyah          TEXT    (nullable) — one-line intention for the habit
--   profiles.struggles_islamic JSONB (nullable) — quiz answers (Islamic pillars)
--   profiles.struggles_life    JSONB (nullable) — quiz answers (life/heart context)
--
-- Idempotent: safe to re-run. No data migration required — all new columns
-- are nullable and default to NULL for existing rows.
--
-- Already applied to the hosted Supabase instance on 2026-04-20 via
-- Dashboard → SQL Editor. This file is checked in so the schema delta
-- lives with the phase that introduced it.

BEGIN;

-- 1. habits.niyyah
ALTER TABLE public.habits
    ADD COLUMN IF NOT EXISTS niyyah TEXT;

COMMENT ON COLUMN public.habits.niyyah IS
    'Optional one-line user intention ("why") for this habit. Rendered on HabitDetailView and folded into the Gemini roadmap prompt. Nullable — users may skip the niyyah step during creation.';

-- 2. profiles.struggles_islamic / struggles_life
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS struggles_islamic JSONB,
    ADD COLUMN IF NOT EXISTS struggles_life    JSONB;

COMMENT ON COLUMN public.profiles.struggles_islamic IS
    'JSONB array of slug strings chosen on the onboarding quiz Islamic-struggles screen (e.g. ["fajr","quran","dhikr"]). NULL means the user has not completed the quiz.';

COMMENT ON COLUMN public.profiles.struggles_life IS
    'JSONB array of slug strings chosen on the onboarding quiz life/heart-context screen (e.g. ["focus","patience","sleep"]). NULL means the user has not completed the quiz.';

-- Ask PostgREST to reload its schema cache so the new columns are
-- immediately queryable through the REST/Storage APIs.
NOTIFY pgrst, 'reload schema';

COMMIT;
