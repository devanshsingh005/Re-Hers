-- Applied to project djqgmowfjxsnjdffdohw on 2026-11-16 via Supabase MCP.
-- Today's practice progress (the daily goal itself stays in user_onboarding.practice_mins, chosen during onboarding).
alter table public.profiles
  add column practice_mins_today smallint not null default 0 check (practice_mins_today between 0 and 1440),
  add column last_practice_date  date;

-- Atomic study-time increment for the signed-in user only (replaces read-then-write in the app).
-- Security invoker: runs under the caller's RLS, so it can only touch their own profile.
create or replace function public.add_my_study_time(p_seconds integer)
returns bigint
language sql
security invoker
set search_path = ''
as $$
  update public.profiles
     set total_study_seconds = total_study_seconds + p_seconds,
         last_active_at = now()
   where id = (select auth.uid())
     and p_seconds between 1 and 21600
  returning total_study_seconds;
$$;
revoke execute on function public.add_my_study_time(integer) from public, anon;
grant execute on function public.add_my_study_time(integer) to authenticated, service_role;

-- Old version took any user id and was never called by the app.
drop function public.increment_study_time(uuid, integer);
