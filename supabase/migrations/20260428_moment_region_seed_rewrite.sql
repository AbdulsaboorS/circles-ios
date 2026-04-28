-- Moment regions — Phase D2 pg_cron seed rewrite (2026-04-28)
-- Assumes the Phase D1 schema migration has already been applied on the server:
--   - moment_region enum exists
--   - daily_moments.region exists
--   - daily_moments primary key is (region, moment_date)
--
-- This keeps the existing 00:05 UTC cron, but seeds both the current and next
-- local day per region so every region's upcoming 09:00-23:00 window exists
-- before that local day begins.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_type
     WHERE typname = 'moment_region'
  ) THEN
    RAISE EXCEPTION 'Phase D2 requires D1 first: moment_region enum is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = 'daily_moments'
       AND column_name = 'region'
  ) THEN
    RAISE EXCEPTION 'Phase D2 requires D1 first: daily_moments.region is missing';
  END IF;
END;
$$;

CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE OR REPLACE FUNCTION seed_todays_daily_moment()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  prayers               TEXT[] := ARRAY['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  region_name           moment_region;
  region_timezone       TEXT;
  day_offset            INT;
  target_local_date     DATE;
  random_prayer         TEXT;
  local_minute_of_day   INT;
  local_timestamp       TIMESTAMP;
  utc_timestamp         TIMESTAMPTZ;
  utc_time_str          TEXT;
BEGIN
  FOR region_name, region_timezone IN
    SELECT *
      FROM (
        VALUES
          ('americas'::moment_region, 'America/New_York'),
          ('europe'::moment_region, 'Europe/Paris'),
          ('west_asia'::moment_region, 'Asia/Dubai'),
          ('east_asia'::moment_region, 'Asia/Tokyo')
      ) AS regions(region_name, region_timezone)
  LOOP
    FOR day_offset IN 0..1 LOOP
      target_local_date := ((now() AT TIME ZONE region_timezone)::date + day_offset);

      IF EXISTS (
        SELECT 1
          FROM daily_moments
         WHERE region = region_name
           AND moment_date = target_local_date
      ) THEN
        CONTINUE;
      END IF;

      random_prayer := prayers[1 + floor(random() * array_length(prayers, 1))::INT];
      local_minute_of_day := 540 + floor(random() * 900)::INT; -- 09:00...23:59 local
      local_timestamp := target_local_date::timestamp
        + make_interval(
          hours => local_minute_of_day / 60,
          mins => local_minute_of_day % 60
        );
      utc_timestamp := local_timestamp AT TIME ZONE region_timezone;
      utc_time_str := to_char(utc_timestamp AT TIME ZONE 'UTC', 'HH24:MI');

      INSERT INTO daily_moments (region, moment_date, prayer_name, moment_time)
      VALUES (region_name, target_local_date, random_prayer, utc_time_str)
      ON CONFLICT (region, moment_date) DO NOTHING;
    END LOOP;
  END LOOP;
END;
$$;

SELECT cron.unschedule(jobid)
  FROM cron.job
 WHERE jobname = 'seed_todays_daily_moment';

SELECT cron.schedule(
  'seed_todays_daily_moment',
  '5 0 * * *',
  $$SELECT seed_todays_daily_moment();$$
);

SELECT seed_todays_daily_moment();

NOTIFY pgrst, 'reload schema';
