-- Align `habit_plans` with the Circles iOS app (Phase 1 + Phase 11).
-- Run in Supabase → SQL Editor if you see errors like:
--   "Could not find the 'milestones' column of 'habit_plans' in the schema cache"
--
-- There is no "reload schema" toggle in the Supabase dashboard. Schema usually updates
-- within seconds after DDL. This script ends with NOTIFY so PostgREST can refresh
-- its cache (same mechanism as https://postgrest.org/en/stable/schema_cache.html).

-- If the table does not exist yet, create the full shape (matches Phase 1 SPEC + Phase 11 column).
CREATE TABLE IF NOT EXISTS public.habit_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  habit_id UUID NOT NULL REFERENCES public.habits(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  milestones JSONB NOT NULL DEFAULT '[]'::jsonb,
  week_number INT NOT NULL DEFAULT 1,
  refinement_count INT NOT NULL DEFAULT 0,
  refinement_week INT NOT NULL DEFAULT 0,
  refinement_cycle TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(habit_id, user_id)
);

-- If the table already existed without some columns, add them (safe to re-run).
ALTER TABLE public.habit_plans
  ADD COLUMN IF NOT EXISTS milestones JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.habit_plans
  ADD COLUMN IF NOT EXISTS week_number INT NOT NULL DEFAULT 1;

ALTER TABLE public.habit_plans
  ADD COLUMN IF NOT EXISTS refinement_count INT NOT NULL DEFAULT 0;

ALTER TABLE public.habit_plans
  ADD COLUMN IF NOT EXISTS refinement_week INT NOT NULL DEFAULT 0;

ALTER TABLE public.habit_plans
  ADD COLUMN IF NOT EXISTS refinement_cycle TEXT;

ALTER TABLE public.habit_plans
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE public.habit_plans
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- RLS (skip errors if already enabled / policy exists — adjust names if you customized).
ALTER TABLE public.habit_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own habit plans" ON public.habit_plans;

CREATE POLICY "Users can manage own habit plans"
ON public.habit_plans FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Nudge PostgREST (Supabase REST) to reload schema metadata.
NOTIFY pgrst, 'reload schema';
