-- Phase 11: habit_plans refinement guard (run in Supabase SQL Editor).
-- Requires habit_plans table from Phase 1 schema.

ALTER TABLE public.habit_plans
  ADD COLUMN IF NOT EXISTS refinement_cycle TEXT DEFAULT '';

CREATE OR REPLACE FUNCTION public.apply_habit_plan_refinement(p_habit_id uuid, p_milestones jsonb)
RETURNS public.habit_plans
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_cycle text;
  rec public.habit_plans%ROWTYPE;
  v_new_count int;
  v_week_num int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  v_cycle := to_char((timezone('UTC', now()))::date, 'IYYY') || '-W' || lpad(to_char((timezone('UTC', now()))::date, 'IW'), 2, '0');

  SELECT * INTO rec
  FROM public.habit_plans
  WHERE habit_id = p_habit_id AND user_id = v_uid
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'plan not found';
  END IF;

  IF rec.refinement_cycle IS NULL OR rec.refinement_cycle = '' OR rec.refinement_cycle IS DISTINCT FROM v_cycle THEN
    v_new_count := 1;
  ELSE
    IF rec.refinement_count >= 3 THEN
      RAISE EXCEPTION 'refinement limit reached for this week'
        USING ERRCODE = 'P0001';
    END IF;
    v_new_count := rec.refinement_count + 1;
  END IF;

  v_week_num := LEAST(
    4,
    GREATEST(
      1,
      FLOOR(EXTRACT(epoch FROM (timezone('UTC', now()) - rec.created_at)) / 86400.0 / 7.0)::int + 1
    )
  );

  UPDATE public.habit_plans hp
  SET
    milestones = p_milestones,
    refinement_count = v_new_count,
    refinement_cycle = v_cycle,
    refinement_week = to_char((timezone('UTC', now()))::date, 'IW')::int,
    week_number = v_week_num,
    updated_at = now()
  WHERE hp.id = rec.id
  RETURNING * INTO rec;

  RETURN rec;
END;
$$;

GRANT EXECUTE ON FUNCTION public.apply_habit_plan_refinement(uuid, jsonb) TO authenticated;
