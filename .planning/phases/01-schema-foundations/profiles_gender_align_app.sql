-- Align `profiles.gender` with the Circles iOS app profile editor.
-- Run in Supabase -> SQL Editor if profile saves fail after selecting gender.
--
-- The app currently saves profile gender as:
--   'brother' | 'sister'
--
-- This script is safe to re-run. It adds the column if missing, relaxes any
-- old check constraint by dropping/recreating the canonical one, and nudges
-- PostgREST to reload the schema cache.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS gender TEXT;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_gender_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_gender_check
  CHECK (gender IS NULL OR gender IN ('brother', 'sister'));

NOTIFY pgrst, 'reload schema';
