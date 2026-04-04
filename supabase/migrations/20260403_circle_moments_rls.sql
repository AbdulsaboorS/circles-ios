-- Phase 11.4: Fix circle_moments RLS and storage upload policy
-- Run in Supabase Dashboard → SQL Editor

-- 1. Drop any existing broken INSERT policy on circle_moments
DROP POLICY IF EXISTS "circle_members_can_insert_moments" ON circle_moments;
DROP POLICY IF EXISTS "users_can_insert_own_moments" ON circle_moments;

-- 2. INSERT policy: user can insert a moment only if auth.uid() matches user_id
--    AND the user is a member of that circle
CREATE POLICY "users_insert_own_moments"
ON circle_moments
FOR INSERT
WITH CHECK (
  auth.uid() = user_id
  AND circle_id IN (
    SELECT circle_id FROM circle_members WHERE user_id = auth.uid()
  )
);

-- 3. SELECT policy: circle members can read moments from their circles
DROP POLICY IF EXISTS "circle_members_can_select_moments" ON circle_moments;
DROP POLICY IF EXISTS "users_can_select_circle_moments" ON circle_moments;

CREATE POLICY "circle_members_select_moments"
ON circle_moments
FOR SELECT
USING (
  circle_id IN (SELECT auth_user_circle_ids())
);

-- 4. Storage bucket policy for "circle-moments":
--    Authenticated users can upload (INSERT) objects to any path in the bucket.
--    (Supabase Storage policies are managed via Dashboard → Storage → Policies,
--     but can also be set via SQL on the storage.objects table.)
DROP POLICY IF EXISTS "authenticated_upload_circle_moments" ON storage.objects;

CREATE POLICY "authenticated_upload_circle_moments"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'circle-moments'
  AND auth.role() = 'authenticated'
);

-- Also allow authenticated users to SELECT (read) objects from the bucket
DROP POLICY IF EXISTS "authenticated_select_circle_moments" ON storage.objects;

CREATE POLICY "authenticated_select_circle_moments"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'circle-moments'
  AND auth.role() = 'authenticated'
);
