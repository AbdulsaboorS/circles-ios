-- group_streak_rpc.sql
-- Adds last_group_streak_date to circles and creates the check_and_update_group_streak RPC.
-- Run once in Supabase Dashboard → SQL Editor.

-- 1. Add tracking column for when the group streak was last incremented
ALTER TABLE circles ADD COLUMN IF NOT EXISTS last_group_streak_date DATE;

-- 2. Atomic RPC: checks if all circle members completed all accountable habits today.
--    If yes, increments group_streak_days (or resets to 1 if a day was missed).
--    Returns the current group_streak_days value (updated or unchanged).
CREATE OR REPLACE FUNCTION check_and_update_group_streak(p_circle_id UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_today        TEXT := TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD');
  v_yesterday    DATE := (NOW() AT TIME ZONE 'UTC')::DATE - INTERVAL '1 day';
  v_last_date    DATE;
  v_cur_streak   INT;
  v_member_count INT;
  v_habit_count  INT;
  v_done_count   INT;
  v_new_streak   INT;
BEGIN
  SELECT last_group_streak_date, COALESCE(group_streak_days, 0)
    INTO v_last_date, v_cur_streak
    FROM circles WHERE id = p_circle_id;

  -- Already counted today — return current value without touching anything
  IF v_last_date::TEXT = v_today THEN
    RETURN v_cur_streak;
  END IF;

  SELECT COUNT(*) INTO v_member_count
    FROM circle_members WHERE circle_id = p_circle_id;

  SELECT COUNT(*) INTO v_habit_count
    FROM habits
   WHERE circle_id = p_circle_id
     AND is_accountable = true
     AND is_active = true;

  -- Nothing to track if circle has no members or no accountable habits
  IF v_habit_count = 0 OR v_member_count = 0 THEN
    RETURN v_cur_streak;
  END IF;

  -- Count members who have completed ALL accountable habits today
  SELECT COUNT(*) INTO v_done_count
    FROM (
      SELECT hl.user_id
        FROM habit_logs hl
        JOIN habits h ON h.id = hl.habit_id
       WHERE h.circle_id = p_circle_id
         AND h.is_accountable = true
         AND h.is_active = true
         AND hl.date = v_today
         AND hl.completed = true
       GROUP BY hl.user_id
      HAVING COUNT(DISTINCT hl.habit_id) = v_habit_count
    ) completed_members;

  -- Not everyone is done yet — return current streak without updating
  IF v_done_count < v_member_count THEN
    RETURN v_cur_streak;
  END IF;

  -- All members done — determine new streak value
  IF v_last_date = v_yesterday THEN
    v_new_streak := v_cur_streak + 1;  -- streak continues
  ELSE
    v_new_streak := 1;                 -- gap detected, reset
  END IF;

  UPDATE circles
     SET group_streak_days      = v_new_streak,
         last_group_streak_date = v_today::DATE
   WHERE id = p_circle_id;

  RETURN v_new_streak;
END;
$$;
