-- Admin dashboard (letsrehearse.studio/admin) and remote app config.
-- Additive only. Nothing the iOS app already reads or writes behaves differently:
--   * new tables: admins, admin_audit_log, app_config, app_config_history
--   * reports gets status columns with defaults (the app only inserts reporter_id, content_id, content_type, reason)
--   * admin-only policies on songs and the `library` bucket (app users never match them)
--   * admin_* functions: callable by signed-in users but refuse anyone who isn't an admin with a verified authenticator (aal2)
-- Rollback: see the bottom of this file.

-- ---------------------------------------------------------------------------
-- Admins
-- ---------------------------------------------------------------------------
create table public.admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;
comment on table public.admins is 'Dashboard admins. No policies: read only by security-definer functions and the service role.';

-- True only for an admin whose current session passed the authenticator step.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select auth.jwt() ->> 'aal') = 'aal2', false)
     and exists (select 1 from public.admins a where a.user_id = (select auth.uid()));
$$;

-- Used by the login page before the authenticator step, so non-admins are turned away
-- before they can enrol an authenticator. Only tells callers about themselves.
create or replace function public.admin_is_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.admins a where a.user_id = (select auth.uid()));
$$;

revoke execute on function public.is_admin(), public.admin_is_member() from public, anon;
grant execute on function public.is_admin(), public.admin_is_member() to authenticated, service_role;

create or replace function public._admin_guard()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
end;
$$;
revoke execute on function public._admin_guard() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Audit log
-- ---------------------------------------------------------------------------
create table public.admin_audit_log (
  id          bigint generated always as identity primary key,
  admin_id    uuid references auth.users(id) on delete set null,
  admin_email text,
  action      text not null check (char_length(action) between 1 and 100),
  target_type text,
  target_id   text,
  details     jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index admin_audit_log_created_idx on public.admin_audit_log (created_at desc);
alter table public.admin_audit_log enable row level security;
revoke all on public.admin_audit_log from anon, authenticated;
grant select on public.admin_audit_log to authenticated;
create policy admin_audit_log_read on public.admin_audit_log
  for select to authenticated using ((select public.is_admin()));

create or replace function public._admin_log(p_action text, p_target_type text, p_target_id text, p_details jsonb default '{}'::jsonb)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.admin_audit_log (admin_id, admin_email, action, target_type, target_id, details)
  values ((select auth.uid()), (select auth.jwt() ->> 'email'), p_action, p_target_type, p_target_id, coalesce(p_details, '{}'::jsonb));
$$;
revoke execute on function public._admin_log(text, text, text, jsonb) from public, anon, authenticated;

-- Lets the dashboard record actions done straight against Storage (file uploads), which can't log themselves.
create or replace function public.admin_record(p_action text, p_target_type text, p_target_id text, p_details jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public._admin_guard();
  if p_action not like 'storage.%' then
    raise exception 'only storage actions can be recorded directly' using errcode = '22023';
  end if;
  perform public._admin_log(p_action, p_target_type, p_target_id, p_details);
end;
$$;

-- ---------------------------------------------------------------------------
-- Remote app config (read by the iOS app from 1.1)
-- ---------------------------------------------------------------------------
create or replace function public._version_key(p_version text)
returns int[]
language sql
immutable
set search_path = ''
as $$
  select (string_to_array(p_version, '.')::int[] || array[0, 0, 0])[1:3];
$$;
revoke execute on function public._version_key(text) from public, anon, authenticated;

create table public.app_config (
  platform                 text primary key check (platform = 'ios'),
  min_supported_version    text not null check (min_supported_version ~ '^\d{1,4}(\.\d{1,4}){0,2}$'),
  latest_version           text not null check (latest_version ~ '^\d{1,4}(\.\d{1,4}){0,2}$'),
  update_required_message  text not null check (char_length(update_required_message) between 1 and 300),
  update_available_message text not null check (char_length(update_available_message) between 1 and 300),
  version                  integer not null default 1,
  updated_at               timestamptz not null default now(),
  check (public._version_key(min_supported_version) <= public._version_key(latest_version))
);
alter table public.app_config enable row level security;
revoke all on public.app_config from anon, authenticated;
grant select on public.app_config to anon, authenticated;
create policy app_config_read on public.app_config for select to anon, authenticated using (true);
comment on table public.app_config is 'Published app config, readable by everyone (the app reads it before sign-in). Written only through admin_update_app_config / admin_rollback_app_config.';

create table public.app_config_history (
  id               bigint generated always as identity primary key,
  platform         text not null,
  version          integer not null,
  config           jsonb not null,
  changed_by       uuid references auth.users(id) on delete set null,
  changed_by_email text,
  note             text,
  created_at       timestamptz not null default now(),
  unique (platform, version)
);
alter table public.app_config_history enable row level security;
revoke all on public.app_config_history from anon, authenticated;
grant select on public.app_config_history to authenticated;
create policy app_config_history_read on public.app_config_history
  for select to authenticated using ((select public.is_admin()));

-- Safe defaults: 1.0 is the live build, so nothing is blocked or prompted.
insert into public.app_config (platform, min_supported_version, latest_version, update_required_message, update_available_message)
values ('ios', '1.0', '1.0',
        'This version of Rehearse is no longer supported. Please update to keep practising.',
        'A new version of Rehearse is available with improvements and fixes.');
insert into public.app_config_history (platform, version, config, note)
select platform, version,
       jsonb_build_object('min_supported_version', min_supported_version, 'latest_version', latest_version,
                          'update_required_message', update_required_message, 'update_available_message', update_available_message),
       'Initial config'
  from public.app_config;

create or replace function public._apply_app_config(p_config jsonb, p_expected_version integer, p_note text)
returns public.app_config
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current public.app_config;
  v_result  public.app_config;
  v_min     text := btrim(p_config ->> 'min_supported_version');
  v_latest  text := btrim(p_config ->> 'latest_version');
  v_req     text := btrim(p_config ->> 'update_required_message');
  v_avail   text := btrim(p_config ->> 'update_available_message');
begin
  select * into v_current from public.app_config where platform = 'ios' for update;
  if p_expected_version is not null and v_current.version <> p_expected_version then
    raise exception 'config_changed: someone published version % since you opened this page', v_current.version using errcode = '40001';
  end if;
  if v_min is null or v_min !~ '^\d{1,4}(\.\d{1,4}){0,2}$' then
    raise exception 'Minimum version must look like 1.2 or 1.2.3' using errcode = '22023';
  end if;
  if v_latest is null or v_latest !~ '^\d{1,4}(\.\d{1,4}){0,2}$' then
    raise exception 'Latest version must look like 1.2 or 1.2.3' using errcode = '22023';
  end if;
  if public._version_key(v_min) > public._version_key(v_latest) then
    raise exception 'Minimum version can''t be higher than the latest version' using errcode = '22023';
  end if;
  if coalesce(char_length(v_req), 0) not between 1 and 300 or coalesce(char_length(v_avail), 0) not between 1 and 300 then
    raise exception 'Messages must be 1 to 300 characters' using errcode = '22023';
  end if;

  update public.app_config
     set min_supported_version = v_min, latest_version = v_latest,
         update_required_message = v_req, update_available_message = v_avail,
         version = v_current.version + 1, updated_at = now()
   where platform = 'ios'
  returning * into v_result;

  insert into public.app_config_history (platform, version, config, changed_by, changed_by_email, note)
  values ('ios', v_result.version,
          jsonb_build_object('min_supported_version', v_min, 'latest_version', v_latest,
                             'update_required_message', v_req, 'update_available_message', v_avail),
          (select auth.uid()), (select auth.jwt() ->> 'email'), nullif(btrim(p_note), ''));

  perform public._admin_log('app_config.publish', 'app_config', 'ios',
    jsonb_build_object('version', v_result.version, 'note', p_note,
                       'from', jsonb_build_object('min', v_current.min_supported_version, 'latest', v_current.latest_version),
                       'to', jsonb_build_object('min', v_min, 'latest', v_latest)));
  return v_result;
end;
$$;
revoke execute on function public._apply_app_config(jsonb, integer, text) from public, anon, authenticated;

create or replace function public.admin_update_app_config(p_config jsonb, p_expected_version integer, p_note text default null)
returns public.app_config
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public._admin_guard();
  return public._apply_app_config(p_config, p_expected_version, p_note);
end;
$$;

create or replace function public.admin_rollback_app_config(p_history_id bigint, p_expected_version integer)
returns public.app_config
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.app_config_history;
begin
  perform public._admin_guard();
  select * into v_row from public.app_config_history where id = p_history_id and platform = 'ios';
  if not found then
    raise exception 'That version no longer exists' using errcode = '22023';
  end if;
  return public._apply_app_config(v_row.config, p_expected_version, 'Rolled back to version ' || v_row.version);
end;
$$;

-- ---------------------------------------------------------------------------
-- Reports: moderation status (the app keeps inserting exactly as before)
-- ---------------------------------------------------------------------------
alter table public.reports
  add column status      text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  add column admin_note  text check (char_length(admin_note) <= 2000),
  add column resolved_at timestamptz,
  add column resolved_by uuid references auth.users(id) on delete set null;

-- ---------------------------------------------------------------------------
-- Songs + library bucket: admin writes (app users keep reading active songs only)
-- ---------------------------------------------------------------------------
create policy songs_admin_read on public.songs
  for select to authenticated using ((select public.is_admin()));

create policy library_admin_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'library' and (storage.foldername(name))[1] = 'songs' and (select public.is_admin()));
create policy library_admin_update on storage.objects
  for update to authenticated
  using (bucket_id = 'library' and (storage.foldername(name))[1] = 'songs' and (select public.is_admin()))
  with check (bucket_id = 'library' and (storage.foldername(name))[1] = 'songs' and (select public.is_admin()));
create policy library_admin_select on storage.objects
  for select to authenticated
  using (bucket_id = 'library' and (select public.is_admin()));

-- ---------------------------------------------------------------------------
-- Read functions for the dashboard
-- ---------------------------------------------------------------------------

-- Everyone counted as a user: all accounts except admins.
create or replace function public._app_users()
returns table (id uuid, email text, created_at timestamptz, last_sign_in_at timestamptz,
               email_confirmed_at timestamptz, banned_until timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select u.id, u.email::text, u.created_at, u.last_sign_in_at, u.email_confirmed_at, u.banned_until
    from auth.users u
   where not exists (select 1 from public.admins a where a.user_id = u.id)
     and u.deleted_at is null;
$$;
revoke execute on function public._app_users() from public, anon, authenticated;

-- A user's latest activity: practice, a song played, a lesson, or a sign-in.
create or replace function public._last_activity()
returns table (user_id uuid, last_activity timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select u.id,
         greatest(u.last_sign_in_at, p.last_active_at,
                  (select max(r.last_played_at) from public.recent_plays r where r.user_id = u.id),
                  (select max(l.occurred_at) from public.lesson_events l where l.user_id = u.id))
    from public._app_users() u
    left join public.profiles p on p.id = u.id;
$$;
revoke execute on function public._last_activity() from public, anon, authenticated;

create or replace function public.admin_overview(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_days  integer := least(greatest(coalesce(p_days, 30), 7), 365);
  v_since timestamptz := date_trunc('day', now()) - make_interval(days => v_days - 1);
  v_result jsonb;
begin
  perform public._admin_guard();

  with users as (select * from public._app_users()),
       activity as (select * from public._last_activity()),
       days as (select generate_series(v_since, date_trunc('day', now()), interval '1 day') as day),
       lessons as (
         select l.* from public.lesson_events l join users u on u.id = l.user_id
          where l.occurred_at >= v_since
       ),
       daily_active as (
         select date_trunc('day', t.at) as day, count(distinct t.user_id) as n
           from (select user_id, occurred_at as at from lessons
                 union all
                 select r.user_id, r.last_played_at from public.recent_plays r join users u on u.id = r.user_id
                  where r.last_played_at >= v_since) t
          group by 1
       )
  select jsonb_build_object(
    'generated_at', now(),
    'days', v_days,
    'totals', jsonb_build_object(
      'users',            (select count(*) from users),
      'confirmed_users',  (select count(*) from users where email_confirmed_at is not null),
      'suspended_users',  (select count(*) from users where banned_until > now()),
      'new_7d',           (select count(*) from users where created_at >= now() - interval '7 days'),
      'new_30d',          (select count(*) from users where created_at >= now() - interval '30 days'),
      'active_1d',        (select count(*) from activity where last_activity >= now() - interval '1 day'),
      'active_7d',        (select count(*) from activity where last_activity >= now() - interval '7 days'),
      'active_30d',       (select count(*) from activity where last_activity >= now() - interval '30 days'),
      'study_seconds',    (select coalesce(sum(p.total_study_seconds), 0) from public.profiles p join users u on u.id = p.id),
      'practising_users', (select count(*) from public.profiles p join users u on u.id = p.id where p.total_study_seconds > 0),
      'lesson_events',    (select count(*) from lessons),
      'uploads',          (select count(*) from public.user_uploads x join users u on u.id = x.user_id),
      'uploaders',        (select count(distinct x.user_id) from public.user_uploads x join users u on u.id = x.user_id),
      'playlists',        (select count(*) from public.playlists x join users u on u.id = x.user_id),
      'songs_active',     (select count(*) from public.songs where is_active),
      'reports_open',     (select count(*) from public.reports where status = 'open')
    ),
    'series', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'day', to_char(d.day, 'YYYY-MM-DD'),
               'signups', (select count(*) from users u where date_trunc('day', u.created_at) = d.day),
               'active', coalesce((select n from daily_active a where a.day = d.day), 0),
               'lessons', (select count(*) from lessons l where date_trunc('day', l.occurred_at) = d.day),
               'lesson_minutes', (select coalesce(round(sum(l.duration_seconds) / 60.0), 0) from lessons l where date_trunc('day', l.occurred_at) = d.day)
             ) order by d.day), '[]'::jsonb)
        from days d
    ),
    'lesson_types', (
      select coalesce(jsonb_agg(jsonb_build_object('type', event_type, 'count', n) order by n desc), '[]'::jsonb)
        from (select event_type, count(*) n from lessons group by 1) t
    ),
    'onboarding_levels', (
      select coalesce(jsonb_agg(jsonb_build_object('level', level, 'count', n) order by n desc), '[]'::jsonb)
        from (select o.level, count(*) n from public.user_onboarding o join users u on u.id = o.id group by 1) t
    ),
    'practice_goals', (
      select coalesce(jsonb_agg(jsonb_build_object('minutes', practice_mins, 'count', n) order by practice_mins), '[]'::jsonb)
        from (select o.practice_mins, count(*) n from public.user_onboarding o join users u on u.id = o.id group by 1) t
    ),
    'top_songs', (
      select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'title', s.title, 'composer', s.composer, 'players', t.n) order by t.n desc), '[]'::jsonb)
        from (select r.song_id, count(distinct r.user_id) n from public.recent_plays r join users u on u.id = r.user_id
               group by 1 order by 2 desc limit 5) t
        join public.songs s on s.id = t.song_id
    )
  ) into v_result;
  return v_result;
end;
$$;

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
  if coalesce(p_filter, 'all') not in ('all', 'active', 'inactive', 'suspended', 'unconfirmed') then
    raise exception 'unknown filter' using errcode = '22023';
  end if;

  with matched as (
    select u.id, u.email, u.created_at, u.last_sign_in_at, u.email_confirmed_at, u.banned_until,
           p.username, p.full_name, coalesce(p.total_study_seconds, 0) as study_seconds, p.current_chapter,
           a.last_activity,
           (select count(*) from public.user_uploads x where x.user_id = u.id) as uploads
      from public._app_users() u
      left join public.profiles p on p.id = u.id
      left join public._last_activity() a on a.user_id = u.id
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
       'is_admin', exists (select 1 from public.admins a where a.user_id = u.id)),
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

create or replace function public.admin_list_songs()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public._admin_guard();
  return (
    select coalesce(jsonb_agg(to_jsonb(s) || jsonb_build_object(
             'players', (select count(distinct r.user_id) from public.recent_plays r where r.song_id = s.id),
             'open_reports', (select count(*) from public.reports x where x.content_id = s.id and x.status = 'open'))
           order by s.sort_order, s.title), '[]'::jsonb)
      from public.songs s
  );
end;
$$;

create or replace function public.admin_save_song(p_song jsonb)
returns public.songs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id       uuid := nullif(p_song ->> 'id', '')::uuid;
  v_existing public.songs;
  v_result   public.songs;
  v_active   boolean := coalesce((p_song ->> 'is_active')::boolean, false);
  v_tags     text[];
begin
  perform public._admin_guard();

  select coalesce(array_agg(btrim(t)) filter (where btrim(t) <> ''), '{}')
    into v_tags
    from jsonb_array_elements_text(coalesce(p_song -> 'skill_tags', '[]'::jsonb)) t;

  if coalesce(char_length(btrim(p_song ->> 'title')), 0) not between 1 and 200 then
    raise exception 'Title is required (up to 200 characters)' using errcode = '22023';
  end if;
  if coalesce(char_length(btrim(p_song ->> 'composer')), 0) not between 1 and 200 then
    raise exception 'Composer is required (up to 200 characters)' using errcode = '22023';
  end if;
  if v_active and (coalesce(p_song ->> 'labeled_pdf_path', '') = '' or coalesce(p_song ->> 'output_json_path', '') = ''
                   or coalesce(p_song ->> 'original_pdf_path', '') = '') then
    raise exception 'Upload the original PDF, labeled PDF and score JSON before showing a song in the app' using errcode = '22023';
  end if;

  if v_id is not null then
    select * into v_existing from public.songs where id = v_id for update;
  end if;

  if v_existing.id is null then
    insert into public.songs (id, title, composer, level, tempo, hands, skill_tags, skill_description, initials,
                              is_free, is_active, sort_order, cover_image_url, original_pdf_path, labeled_pdf_path, output_json_path)
    values (coalesce(v_id, gen_random_uuid()), btrim(p_song ->> 'title'), btrim(p_song ->> 'composer'),
            (p_song ->> 'level')::smallint, p_song ->> 'tempo', p_song ->> 'hands', v_tags,
            coalesce(btrim(p_song ->> 'skill_description'), ''), upper(left(coalesce(nullif(btrim(p_song ->> 'initials'), ''), btrim(p_song ->> 'title')), 3)),
            coalesce((p_song ->> 'is_free')::boolean, true), v_active, coalesce((p_song ->> 'sort_order')::smallint, 0),
            nullif(p_song ->> 'cover_image_url', ''), nullif(p_song ->> 'original_pdf_path', ''),
            nullif(p_song ->> 'labeled_pdf_path', ''), nullif(p_song ->> 'output_json_path', ''))
    returning * into v_result;
    perform public._admin_log('song.create', 'song', v_result.id::text, jsonb_build_object('title', v_result.title, 'is_active', v_result.is_active));
  else
    update public.songs set
      title = btrim(p_song ->> 'title'),
      composer = btrim(p_song ->> 'composer'),
      level = (p_song ->> 'level')::smallint,
      tempo = p_song ->> 'tempo',
      hands = p_song ->> 'hands',
      skill_tags = v_tags,
      skill_description = coalesce(btrim(p_song ->> 'skill_description'), ''),
      initials = upper(left(coalesce(nullif(btrim(p_song ->> 'initials'), ''), btrim(p_song ->> 'title')), 3)),
      is_free = coalesce((p_song ->> 'is_free')::boolean, true),
      is_active = v_active,
      sort_order = coalesce((p_song ->> 'sort_order')::smallint, 0),
      cover_image_url = nullif(p_song ->> 'cover_image_url', ''),
      original_pdf_path = nullif(p_song ->> 'original_pdf_path', ''),
      labeled_pdf_path = nullif(p_song ->> 'labeled_pdf_path', ''),
      output_json_path = nullif(p_song ->> 'output_json_path', '')
    where id = v_existing.id
    returning * into v_result;
    perform public._admin_log('song.update', 'song', v_result.id::text, jsonb_build_object(
      'title', v_result.title,
      'changed', (select coalesce(jsonb_agg(n.key), '[]'::jsonb)
                    from jsonb_each(to_jsonb(v_result)) n
                    join jsonb_each(to_jsonb(v_existing)) o on o.key = n.key
                   where n.value is distinct from o.value)));
  end if;
  return v_result;
end;
$$;

create or replace function public.admin_list_reports(p_status text default 'open')
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public._admin_guard();
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', r.id, 'reason', r.reason, 'content_type', r.content_type, 'content_id', r.content_id,
             'status', r.status, 'admin_note', r.admin_note, 'created_at', r.created_at, 'resolved_at', r.resolved_at,
             'reporter_id', r.reporter_id,
             'reporter_email', (select u.email from auth.users u where u.id = r.reporter_id),
             'reporter_username', (select p.username from public.profiles p where p.id = r.reporter_id),
             'song_title', (select s.title from public.songs s where s.id = r.content_id),
             'song_active', (select s.is_active from public.songs s where s.id = r.content_id),
             'resolved_by_email', (select u.email from auth.users u where u.id = r.resolved_by)
           ) order by r.created_at desc), '[]'::jsonb)
      from public.reports r
     where coalesce(p_status, 'all') = 'all' or r.status = p_status
  );
end;
$$;

create or replace function public.admin_update_report(p_report_id uuid, p_status text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old text;
begin
  perform public._admin_guard();
  if p_status not in ('open', 'resolved', 'dismissed') then
    raise exception 'unknown status' using errcode = '22023';
  end if;
  select status into v_old from public.reports where id = p_report_id for update;
  if not found then
    raise exception 'Report not found' using errcode = 'P0002';
  end if;
  update public.reports
     set status = p_status,
         admin_note = nullif(btrim(p_note), ''),
         resolved_at = case when p_status = 'open' then null else now() end,
         resolved_by = case when p_status = 'open' then null else (select auth.uid()) end
   where id = p_report_id;
  perform public._admin_log('report.' || p_status, 'report', p_report_id::text,
                            jsonb_build_object('from', v_old, 'note', nullif(btrim(p_note), '')));
end;
$$;

-- Public-facing grants for the admin_* functions (each one refuses non-admins itself).
do $$
declare
  f text;
begin
  foreach f in array array[
    'public.admin_record(text, text, text, jsonb)',
    'public.admin_update_app_config(jsonb, integer, text)',
    'public.admin_rollback_app_config(bigint, integer)',
    'public.admin_overview(integer)',
    'public.admin_list_users(text, text, integer, integer)',
    'public.admin_get_user(uuid)',
    'public.admin_list_songs()',
    'public.admin_save_song(jsonb)',
    'public.admin_list_reports(text)',
    'public.admin_update_report(uuid, text, text)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated, service_role', f);
  end loop;
end;
$$;

-- Rollback (run in this order):
--   drop function public.admin_update_report(uuid, text, text), public.admin_list_reports(text), public.admin_save_song(jsonb),
--     public.admin_list_songs(), public.admin_get_user(uuid), public.admin_list_users(text, text, integer, integer),
--     public.admin_overview(integer), public._last_activity(), public._app_users(), public.admin_rollback_app_config(bigint, integer),
--     public.admin_update_app_config(jsonb, integer, text), public._apply_app_config(jsonb, integer, text), public.admin_record(text, text, text, jsonb);
--   drop policy library_admin_insert on storage.objects; drop policy library_admin_update on storage.objects;
--   drop policy library_admin_select on storage.objects; drop policy songs_admin_read on public.songs;
--   alter table public.reports drop column status, drop column admin_note, drop column resolved_at, drop column resolved_by;
--   drop table public.app_config_history, public.app_config, public.admin_audit_log, public.admins;
--   drop function public._version_key(text), public._admin_log(text, text, text, jsonb), public._admin_guard(),
--     public.admin_is_member(), public.is_admin();
