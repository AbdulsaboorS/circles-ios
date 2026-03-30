-- Phase 10: optional RLS for Amir settings in the iOS app.
-- Run AFTER migration.sql, only if you need update/delete and lack policies.
-- Skip any statement that fails with "policy already exists".

CREATE POLICY "circles_update_by_creator"
  ON public.circles
  FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "circle_members_leave_self"
  ON public.circle_members
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

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
