# Phase 10 — Supabase SQL (run in SQL Editor)

## 1. Group streak bookkeeping column

Tracks the last UTC calendar day when **every** circle member posted at least one moment, so streaks advance correctly and gaps reset.

```sql
ALTER TABLE public.circles
  ADD COLUMN IF NOT EXISTS group_streak_last_complete_utc_date DATE;
```

## 2. Trigger: update `group_streak_days` on new `circle_moments` row

Uses **UTC date** of `posted_at` (matches `MomentService.todayDateString()`).

```sql
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

  -- Missed at least one full UTC day since last all-in day → break streak
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

  -- Everyone posted on UTC day d
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
```

## 3. Optional RLS for Amir settings (iOS)

Skip any statement that fails because a policy already exists. Adjust names to match your project.

**Circle creators update their circle** (core habits, gender):

```sql
CREATE POLICY "circles_update_by_creator"
  ON public.circles
  FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());
```

**Leave circle** (delete own membership row):

```sql
CREATE POLICY "circle_members_leave_self"
  ON public.circle_members
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());
```

**Amir removes another member** (not yourself):

```sql
CREATE POLICY "circle_members_delete_by_admin"
  ON public.circle_members
  FOR DELETE
  TO authenticated
  USING (
    user_id <> auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.circle_members m
      WHERE m.circle_id = circle_members.circle_id
        AND m.user_id = auth.uid()
        AND m.role = 'admin'
    )
  );
```

If `DELETE` on `circle_members` was fully denied before, you may only need the two delete policies above (self + admin).
