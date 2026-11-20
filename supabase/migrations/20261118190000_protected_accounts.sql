-- Applied to project djqgmowfjxsnjdffdohw on 2026-11-18 via Supabase MCP.
-- Accounts the dashboard must never suspend (e.g. the App Review demo account): the admin-users Edge
-- Function refuses to ban them, and the Users page shows them as protected.
-- Rollback: drop function public.admin_set_protected(uuid, boolean, text); drop table public.protected_accounts;
--           then re-create admin_list_users / admin_get_user from 20261118120000_admin_dashboard.sql.

create table public.protected_accounts (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  reason     text not null check (char_length(reason) between 1 and 200),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);
alter table public.protected_accounts enable row level security;
revoke all on public.protected_accounts from anon, authenticated;
comment on table public.protected_accounts is 'Accounts the dashboard must not suspend. No policies: read by admin_* functions and the service role.';

create or replace function public.admin_set_protected(p_user_id uuid, p_protected boolean, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
begin
  perform public._admin_guard();
  select email into v_email from auth.users where id = p_user_id;
  if v_email is null then
    raise exception 'User not found' using errcode = 'P0002';
  end if;
  if p_protected then
    if coalesce(char_length(btrim(p_reason)), 0) not between 1 and 200 then
      raise exception 'Say why this account is protected (up to 200 characters)' using errcode = '22023';
    end if;
    insert into public.protected_accounts (user_id, reason, created_by)
    values (p_user_id, btrim(p_reason), (select auth.uid()))
    on conflict (user_id) do update set reason = excluded.reason;
    perform public._admin_log('user.protect', 'user', p_user_id::text, jsonb_build_object('email', v_email, 'reason', btrim(p_reason)));
  else
    delete from public.protected_accounts where user_id = p_user_id;
    perform public._admin_log('user.unprotect', 'user', p_user_id::text, jsonb_build_object('email', v_email));
  end if;
end;
$$;
revoke execute on function public.admin_set_protected(uuid, boolean, text) from public, anon;
grant execute on function public.admin_set_protected(uuid, boolean, text) to authenticated, service_role;

create or replace function public.admin_list_users(
  p_search text default null, p_filter text default 'all', p_limit integer default 25, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_search text := nullif(btrim(lower(p_search)), '');
  v_limit  integer := least(greatest(coalesce(p_limit, 25), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_result jsonb;
begin
  perform public._admin_guard();
  if coalesce(p_filter, 'all') not in ('all', 'active', 'inactive', 'suspended', 'unconfirmed', 'protected') then
    raise exception 'unknown filter' using errcode = '22023';
  end if;

  with matched as (
    select u.id, u.email, u.created_at, u.last_sign_in_at, u.email_confirmed_at, u.banned_until,
           p.username, p.full_name, coalesce(p.total_study_seconds, 0) as study_seconds, p.current_chapter,
           a.last_activity,
           (select count(*) from public.user_uploads x where x.user_id = u.id) as uploads,
           pa.reason as protected_reason
      from public._app_users() u
      left join public.profiles p on p.id = u.id
      left join public._last_activity() a on a.user_id = u.id
      left join public.protected_accounts pa on pa.user_id = u.id
     where (v_search is null
            or lower(u.email) like '%' || v_search || '%'
            or lower(coalesce(p.username, '')) like '%' || v_search || '%'
            or lower(coalesce(p.full_name, '')) like '%' || v_search || '%'
            or u.id::text = v_search)
       and case coalesce(p_filter, 'all')
             when 'active'      then a.last_activity >= now() - interval '30 days'
             when 'inactive'    then a.last_activity is null or a.last_activity < now() - interval '30 days'
             when 'suspended'   then u.banned_until > now()
             when 'unconfirmed' then u.email_confirmed_at is null
             when 'protected'   then pa.user_id is not null
             else true
           end
  )
  select jsonb_build_object(
    'total', (select count(*) from matched),
    'rows', coalesce((select jsonb_agg(to_jsonb(r) order by r.created_at desc)
                        from (select * from matched order by created_at desc limit v_limit offset v_offset) r), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;

create or replace function public.admin_get_user(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  perform public._admin_guard();
  select jsonb_build_object(
    'account', jsonb_build_object(
       'id', u.id, 'email', u.email, 'created_at', u.created_at, 'last_sign_in_at', u.last_sign_in_at,
       'email_confirmed_at', u.email_confirmed_at, 'banned_until', u.banned_until,
       'is_admin', exists (select 1 from public.admins a where a.user_id = u.id),
       'protected_reason', (select pa.reason from public.protected_accounts pa where pa.user_id = u.id)),
    'profile', (select jsonb_build_object('username', p.username, 'full_name', p.full_name, 'bio', p.bio,
                  'current_chapter', p.current_chapter, 'current_part', p.current_part,
                  'total_study_seconds', p.total_study_seconds, 'practice_mins_today', p.practice_mins_today,
                  'last_practice_date', p.last_practice_date, 'last_active_at', p.last_active_at)
                  from public.profiles p where p.id = u.id),
    'onboarding', (select jsonb_build_object('level', o.level, 'genres', o.genres, 'practice_mins', o.practice_mins)
                     from public.user_onboarding o where o.id = u.id),
    'counts', jsonb_build_object(
       'lesson_events', (select count(*) from public.lesson_events l where l.user_id = u.id),
       'songs_played',  (select count(*) from public.recent_plays r where r.user_id = u.id),
       'uploads',       (select count(*) from public.user_uploads x where x.user_id = u.id),
       'playlists',     (select count(*) from public.playlists x where x.user_id = u.id),
       'reports_made',  (select count(*) from public.reports x where x.reporter_id = u.id)),
    'recent_lessons', (select coalesce(jsonb_agg(to_jsonb(l) - 'user_id' order by l.occurred_at desc), '[]'::jsonb)
                         from (select * from public.lesson_events l where l.user_id = u.id order by occurred_at desc limit 15) l),
    'uploads', (select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'title', x.title, 'file_size_bytes', x.file_size_bytes,
                                  'page_count', x.page_count, 'note_count', x.note_count, 'files_ready', x.files_ready,
                                  'uploaded_at', x.uploaded_at) order by x.uploaded_at desc), '[]'::jsonb)
                  from public.user_uploads x where x.user_id = u.id),
    'recent_songs', (select coalesce(jsonb_agg(jsonb_build_object('title', s.title, 'last_played_at', r.last_played_at)
                                  order by r.last_played_at desc), '[]'::jsonb)
                       from (select * from public.recent_plays r where r.user_id = u.id order by last_played_at desc limit 10) r
                       join public.songs s on s.id = r.song_id)
  ) into v_result
    from auth.users u
   where u.id = p_user_id;

  if v_result is null then
    raise exception 'User not found' using errcode = 'P0002';
  end if;
  return v_result;
end;
$$;
