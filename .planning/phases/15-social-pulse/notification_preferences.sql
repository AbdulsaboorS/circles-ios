-- Phase 15.1 — Notification preferences
-- Run in Supabase Dashboard SQL Editor before enabling full Phase 15.1 settings enforcement.

create table if not exists notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  notifications_enabled boolean not null default true,
  moment_window_enabled boolean not null default true,
  nudges_enabled boolean not null default true,
  circle_activity_enabled boolean not null default true,
  habit_reminders_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table notification_preferences enable row level security;

create policy if not exists "Users manage own notification preferences"
  on notification_preferences
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function set_notification_preferences_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists notification_preferences_set_updated_at on notification_preferences;

create trigger notification_preferences_set_updated_at
before update on notification_preferences
for each row
execute function set_notification_preferences_updated_at();
