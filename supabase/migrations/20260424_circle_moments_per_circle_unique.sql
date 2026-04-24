-- ============================================================================
-- Fix: multi-circle posting was blocked by an over-strict unique index.
--
-- Phase 14 added UNIQUE (user_id, moment_date) which enforced "one moment per
-- user per day" — but Phase 11.4's broadcast model posts one row per circle
-- with the same (user_id, moment_date). Result: posting to 7 circles surfaced
-- "Posted to 1 of 7 circles" because inserts 2..N hit the unique index.
--
-- The correct invariant is "one moment per user per CIRCLE per day."
-- ============================================================================

DROP INDEX IF EXISTS circle_moments_user_moment_date_idx;

CREATE UNIQUE INDEX IF NOT EXISTS circle_moments_user_circle_moment_date_idx
  ON circle_moments (user_id, circle_id, moment_date);
