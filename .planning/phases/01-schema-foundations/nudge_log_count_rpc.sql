-- Sender-scoped count helper for Profile "Nudges Sent"
-- Safe to run multiple times.

create or replace function public.fetch_nudges_sent_count(p_user_id uuid)
returns table (sent_count bigint)
language sql
security definer
set search_path = public
as $$
    select count(*)::bigint as sent_count
    from public.nudge_log
    where sender_id = p_user_id;
$$;

revoke all on function public.fetch_nudges_sent_count(uuid) from public;
grant execute on function public.fetch_nudges_sent_count(uuid) to authenticated;
