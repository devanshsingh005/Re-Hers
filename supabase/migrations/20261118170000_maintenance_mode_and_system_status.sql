-- Maintenance mode (read by the iOS app from 1.1) and the dashboard's System Settings page.
-- Additive: new app_config columns with safe defaults (maintenance off), replaced admin_* functions,
-- and a new read-only admin_system_status(). Rollback at the bottom.

alter table public.app_config
  add column maintenance_enabled boolean not null default false,
  add column maintenance_title   text not null default 'Down for maintenance'
    check (char_length(maintenance_title) between 1 and 80),
  add column maintenance_message text not null default 'Rehearse is getting an update. Please check back soon.'
    check (char_length(maintenance_message) between 1 and 300),
  add column maintenance_ends_at timestamptz;

-- The whole published config as one JSON value (what history stores and rollback restores).
create or replace function public._app_config_snapshot(c public.app_config)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'min_supported_version', c.min_supported_version,
    'latest_version', c.latest_version,
    'update_required_message', c.update_required_message,
    'update_available_message', c.update_available_message,
    'maintenance_enabled', c.maintenance_enabled,
    'maintenance_title', c.maintenance_title,
    'maintenance_message', c.maintenance_message,
    'maintenance_ends_at', c.maintenance_ends_at);
$$;
revoke execute on function public._app_config_snapshot(public.app_config) from public, anon, authenticated;

-- Defaults for keys missing from an older snapshot (history saved before maintenance existed).
create or replace function public._app_config_defaults()
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'maintenance_enabled', false,
    'maintenance_title', 'Down for maintenance',
    'maintenance_message', 'Rehearse is getting an update. Please check back soon.',
    'maintenance_ends_at', null);
$$;
revoke execute on function public._app_config_defaults() from public, anon, authenticated;

-- Validates and publishes a complete config. Every caller passes a full snapshot.
create or replace function public._apply_app_config(p_config jsonb, p_expected_version integer, p_note text)
returns public.app_config
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current public.app_config;
  v_result  public.app_config;
  v_cfg     jsonb := public._app_config_defaults() || p_config;
  v_min     text := btrim(v_cfg ->> 'min_supported_version');
  v_latest  text := btrim(v_cfg ->> 'latest_version');
  v_req     text := btrim(v_cfg ->> 'update_required_message');
  v_avail   text := btrim(v_cfg ->> 'update_available_message');
  v_m_on    boolean := coalesce((v_cfg ->> 'maintenance_enabled')::boolean, false);
  v_m_title text := btrim(v_cfg ->> 'maintenance_title');
  v_m_msg   text := btrim(v_cfg ->> 'maintenance_message');
  v_m_ends  timestamptz := nullif(v_cfg ->> 'maintenance_ends_at', '')::timestamptz;
  v_action  text;
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
  if coalesce(char_length(v_m_title), 0) not between 1 and 80 then
    raise exception 'Maintenance title must be 1 to 80 characters' using errcode = '22023';
  end if;
  if coalesce(char_length(v_m_msg), 0) not between 1 and 300 then
    raise exception 'Maintenance message must be 1 to 300 characters' using errcode = '22023';
  end if;
  -- A past "expected back" time is meaningless: drop it rather than show it.
  if v_m_ends is not null and v_m_ends <= now() then
    v_m_ends := null;
  end if;

  update public.app_config
     set min_supported_version = v_min, latest_version = v_latest,
         update_required_message = v_req, update_available_message = v_avail,
         maintenance_enabled = v_m_on, maintenance_title = v_m_title,
         maintenance_message = v_m_msg, maintenance_ends_at = v_m_ends,
         version = v_current.version + 1, updated_at = now()
   where platform = 'ios'
  returning * into v_result;

  insert into public.app_config_history (platform, version, config, changed_by, changed_by_email, note)
  values ('ios', v_result.version, public._app_config_snapshot(v_result),
          (select auth.uid()), (select auth.jwt() ->> 'email'), nullif(btrim(p_note), ''));

  v_action := case
    when v_result.maintenance_enabled and not v_current.maintenance_enabled then 'app_config.maintenance_on'
    when v_current.maintenance_enabled and not v_result.maintenance_enabled then 'app_config.maintenance_off'
    else 'app_config.publish'
  end;
  perform public._admin_log(v_action, 'app_config', 'ios',
    jsonb_build_object('version', v_result.version, 'note', p_note,
                       'from', jsonb_build_object('min', v_current.min_supported_version, 'latest', v_current.latest_version,
                                                  'maintenance', v_current.maintenance_enabled),
                       'to', jsonb_build_object('min', v_min, 'latest', v_latest, 'maintenance', v_m_on,
                                                'maintenance_message', case when v_m_on then v_m_msg end)));
  return v_result;
end;
$$;
revoke execute on function public._apply_app_config(jsonb, integer, text) from public, anon, authenticated;

-- Version settings from the App config form; maintenance settings are kept as they are.
create or replace function public.admin_update_app_config(p_config jsonb, p_expected_version integer, p_note text default null)
returns public.app_config
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current public.app_config;
begin
  perform public._admin_guard();
  select * into v_current from public.app_config where platform = 'ios';
  return public._apply_app_config(
    public._app_config_snapshot(v_current)
      || (p_config - 'maintenance_enabled' - 'maintenance_title' - 'maintenance_message' - 'maintenance_ends_at'),
    p_expected_version, p_note);
end;
$$;

-- Turns maintenance on/off or edits its message; version settings are kept as they are.
create or replace function public.admin_set_maintenance(
  p_enabled boolean, p_title text, p_message text, p_ends_at timestamptz, p_expected_version integer, p_note text default null)
returns public.app_config
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current public.app_config;
begin
  perform public._admin_guard();
  if p_enabled and p_ends_at is not null and p_ends_at <= now() then
    raise exception 'The expected end time must be in the future' using errcode = '22023';
  end if;
  select * into v_current from public.app_config where platform = 'ios';
  return public._apply_app_config(
    public._app_config_snapshot(v_current) || jsonb_build_object(
      'maintenance_enabled', p_enabled,
      'maintenance_title', p_title,
      'maintenance_message', p_message,
      'maintenance_ends_at', p_ends_at),
    p_expected_version, p_note);
end;
$$;

-- Rollback restores the whole snapshot; keys an old snapshot lacks fall back to defaults (maintenance off).
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

-- Everything the System Settings page shows from the database.
create or replace function public.admin_system_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tables jsonb;
  v_count  bigint;
  r        record;
begin
  perform public._admin_guard();

  v_tables := '[]'::jsonb;
  for r in
    select c.relname, c.relrowsecurity
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r'
     order by c.relname
  loop
    execute format('select count(*) from public.%I', r.relname) into v_count;
    v_tables := v_tables || jsonb_build_object(
      'name', r.relname, 'rows', v_count, 'rls', r.relrowsecurity,
      'bytes', pg_total_relation_size(format('public.%I', r.relname)::regclass));
  end loop;

  return jsonb_build_object(
    'checked_at', now(),
    'database', jsonb_build_object(
      'version', split_part(version(), ' on ', 1),
      'size_bytes', pg_database_size(current_database()),
      'timezone', current_setting('TimeZone'),
      'tables', v_tables,
      'migrations', (select coalesce(jsonb_agg(jsonb_build_object('version', m.version, 'name', m.name) order by m.version desc), '[]'::jsonb)
                       from (select version, name from supabase_migrations.schema_migrations order by version desc limit 6) m)),
    'storage', (select coalesce(jsonb_agg(jsonb_build_object(
                  'id', b.id, 'public', b.public, 'file_size_limit', b.file_size_limit,
                  'files', (select count(*) from storage.objects o where o.bucket_id = b.id),
                  'bytes', (select coalesce(sum((o.metadata ->> 'size')::bigint), 0) from storage.objects o where o.bucket_id = b.id))
                  order by b.id), '[]'::jsonb)
                  from storage.buckets b),
    'auth', jsonb_build_object(
      'users', (select count(*) from auth.users where deleted_at is null),
      'confirmed', (select count(*) from auth.users where deleted_at is null and email_confirmed_at is not null),
      'signups_24h', (select count(*) from auth.users where created_at >= now() - interval '24 hours'),
      'with_authenticator', (select count(distinct user_id) from auth.mfa_factors where status = 'verified'),
      'admins', (select coalesce(jsonb_agg(jsonb_build_object(
                   'email', u.email, 'last_sign_in_at', u.last_sign_in_at,
                   'phones', (select count(*) from auth.mfa_factors f where f.user_id = u.id and f.status = 'verified'))
                   order by u.email), '[]'::jsonb)
                   from public.admins a join auth.users u on u.id = a.user_id)),
    'app_config', (select to_jsonb(c) from public.app_config c where c.platform = 'ios'),
    'audit', jsonb_build_object(
      'entries', (select count(*) from public.admin_audit_log),
      'last_at', (select max(created_at) from public.admin_audit_log))
  );
end;
$$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.admin_update_app_config(jsonb, integer, text)',
    'public.admin_set_maintenance(boolean, text, text, timestamptz, integer, text)',
    'public.admin_rollback_app_config(bigint, integer)',
    'public.admin_system_status()'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated, service_role', f);
  end loop;
end;
$$;

-- Rollback:
--   drop function public.admin_system_status(), public.admin_set_maintenance(boolean, text, text, timestamptz, integer, text);
--   re-create _apply_app_config / admin_update_app_config / admin_rollback_app_config from 20261118120000_admin_dashboard.sql;
--   drop function public._app_config_snapshot(public.app_config), public._app_config_defaults();
--   alter table public.app_config drop column maintenance_enabled, drop column maintenance_title,
--     drop column maintenance_message, drop column maintenance_ends_at;
