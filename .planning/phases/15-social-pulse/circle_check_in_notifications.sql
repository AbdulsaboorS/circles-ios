CREATE TABLE IF NOT EXISTS circle_check_in_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  circle_id uuid NOT NULL REFERENCES circles(id) ON DELETE CASCADE,
  trigger_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_date date NOT NULL DEFAULT CURRENT_DATE,
  send_index integer NOT NULL CHECK (send_index IN (1, 2)),
  distinct_member_count integer NOT NULL CHECK (distinct_member_count >= 2),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(recipient_user_id, notification_date, send_index)
);

ALTER TABLE circle_check_in_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view own circle check-in notification log"
  ON circle_check_in_notifications;
CREATE POLICY "Users view own circle check-in notification log"
  ON circle_check_in_notifications
  FOR SELECT
  USING (auth.uid() = recipient_user_id);

DROP POLICY IF EXISTS "Service role manages circle check-in notification log"
  ON circle_check_in_notifications;
CREATE POLICY "Service role manages circle check-in notification log"
  ON circle_check_in_notifications
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
