-- Moment Mechanic Redesign — BeReal parity (2026-04-23)
-- Run in Supabase Dashboard → SQL Editor.
-- Steps are ordered so each block can be run independently if something trips.

-- ============================================================================
-- 1. Add circle_moments.moment_date DATE (nullable first so backfill can populate)
-- ============================================================================

ALTER TABLE circle_moments
  ADD COLUMN IF NOT EXISTS moment_date DATE;

-- ============================================================================
-- 2. Backfill historical rows from posted_at (UTC date).
--    Safe to re-run: WHERE moment_date IS NULL.
-- ============================================================================

UPDATE circle_moments
   SET moment_date = (posted_at AT TIME ZONE 'UTC')::date
 WHERE moment_date IS NULL;

-- ============================================================================
-- 3. Resolve any duplicates on (user_id, moment_date) before unique index.
--    Keep the most recent posted_at per pair; delete older duplicates.
-- ============================================================================

WITH ranked AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY user_id, moment_date
           ORDER BY posted_at DESC, id DESC
         ) AS rn
    FROM circle_moments
   WHERE moment_date IS NOT NULL
)
DELETE FROM circle_moments
 WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

-- ============================================================================
-- 4. Lock the column NOT NULL now that backfill + dedupe are done.
-- ============================================================================

ALTER TABLE circle_moments
  ALTER COLUMN moment_date SET NOT NULL;

-- ============================================================================
-- 5. Unique index: one moment per user per day.
--    Replaces the implicit 25hr dedupe with an explicit DB guarantee.
-- ============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS circle_moments_user_moment_date_idx
  ON circle_moments (user_id, moment_date);

-- ============================================================================
-- 6. pg_cron: daily UTC job to seed daily_moments with a random moment_time.
--    Runs at 00:05 UTC. moment_time range matches seed-daily-moment edge fn
--    (13:00–23:59 UTC or 00:00–02:59 UTC ≈ 8am–10pm US Eastern).
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE OR REPLACE FUNCTION seed_todays_daily_moment()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  today_date      DATE := (now() AT TIME ZONE 'UTC')::date;
  prayers         TEXT[] := ARRAY['fajr','dhuhr','asr','maghrib','isha'];
  random_prayer   TEXT;
  -- allowed UTC hours: 13..23 and 0..2  (14 values)
  allowed_hours   INT[] := ARRAY[13,14,15,16,17,18,19,20,21,22,23,0,1,2];
  chosen_hour     INT;
  chosen_minute   INT;
  moment_time_str TEXT;
BEGIN
  -- Skip if today's row already exists
  IF EXISTS (SELECT 1 FROM daily_moments WHERE moment_date = today_date) THEN
    RETURN;
  END IF;

  random_prayer   := prayers[1 + floor(random() * array_length(prayers, 1))::int];
  chosen_hour     := allowed_hours[1 + floor(random() * array_length(allowed_hours, 1))::int];
  chosen_minute   := floor(random() * 60)::int;
  moment_time_str := lpad(chosen_hour::text, 2, '0') || ':' || lpad(chosen_minute::text, 2, '0');

  INSERT INTO daily_moments (moment_date, prayer_name, moment_time)
       VALUES (today_date, random_prayer, moment_time_str)
  ON CONFLICT (moment_date) DO NOTHING;
END;
$$;

-- Unschedule any prior version of this job, then (re)schedule at 00:05 UTC daily.
SELECT cron.unschedule(jobid)
  FROM cron.job
 WHERE jobname = 'seed_todays_daily_moment';

SELECT cron.schedule(
  'seed_todays_daily_moment',
  '5 0 * * *',
  $$SELECT seed_todays_daily_moment();$$
);

-- ============================================================================
-- 7. Seed today's row immediately so the app has data before the next cron tick.
-- ============================================================================

SELECT seed_todays_daily_moment();

NOTIFY pgrst, 'reload schema';
