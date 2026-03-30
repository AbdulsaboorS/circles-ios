-- Phase 10: UTC group streak (required).
-- Paste this whole file into Supabase SQL Editor and run once.
-- Do NOT paste SQL.md — that file is Markdown and will error on "##".

-- 1. Bookkeeping: last UTC day when every member posted
ALTER TABLE public.circles
  ADD COLUMN IF NOT EXISTS group_streak_last_complete_utc_date DATE;

-- 2. Trigger: maintain group_streak_days on new circle_moments rows
CREATE OR REPLACE FUNCTION public.refresh_group_streak_from_moment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  d date;
  m int;
  p int;
  last_d date;
  cur_streak int;
BEGIN
  d := (NEW.posted_at AT TIME ZONE 'UTC')::date;

  SELECT c.group_streak_days, c.group_streak_last_complete_utc_date
  INTO cur_streak, last_d
  FROM public.circles c
  WHERE c.id = NEW.circle_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  cur_streak := COALESCE(cur_streak, 0);

  IF last_d IS NOT NULL AND d > last_d + 1 THEN
    cur_streak := 0;
    last_d := NULL;
  END IF;

  SELECT COUNT(*)::int INTO m
  FROM public.circle_members
  WHERE circle_id = NEW.circle_id;

  IF m = 0 THEN
    UPDATE public.circles
    SET group_streak_days = cur_streak,
        group_streak_last_complete_utc_date = last_d
    WHERE id = NEW.circle_id;
    RETURN NEW;
  END IF;

  SELECT COUNT(DISTINCT user_id)::int INTO p
  FROM public.circle_moments
  WHERE circle_id = NEW.circle_id
    AND (posted_at AT TIME ZONE 'UTC')::date = d;

  IF p < m THEN
    UPDATE public.circles
    SET group_streak_days = cur_streak,
        group_streak_last_complete_utc_date = last_d
    WHERE id = NEW.circle_id;
    RETURN NEW;
  END IF;

  IF last_d = d THEN
    UPDATE public.circles
    SET group_streak_days = cur_streak,
        group_streak_last_complete_utc_date = last_d
    WHERE id = NEW.circle_id;
    RETURN NEW;
  END IF;

  IF last_d IS NULL THEN
    cur_streak := 1;
  ELSIF last_d = d - 1 THEN
    cur_streak := cur_streak + 1;
  ELSE
    cur_streak := 1;
  END IF;

  last_d := d;

  UPDATE public.circles
  SET group_streak_days = cur_streak,
      group_streak_last_complete_utc_date = last_d
  WHERE id = NEW.circle_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_refresh_group_streak_on_moment_insert ON public.circle_moments;

CREATE TRIGGER tr_refresh_group_streak_on_moment_insert
  AFTER INSERT ON public.circle_moments
  FOR EACH ROW
  EXECUTE PROCEDURE public.refresh_group_streak_from_moment();
