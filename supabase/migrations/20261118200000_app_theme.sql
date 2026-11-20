-- Seasonal app theme (read by the iOS app from 1.1) for the dashboard's Theme Studio.
-- Only two themes: 'default' and 'christmas'. The theme only adds decorations; it never changes
-- the app's colours or layout, and the app treats any value it doesn't know as 'default'.
-- Additive: one new app_config column with a safe default, snapshot/defaults/validation extended,
-- a new admin_set_theme() wrapper. Rollback at the bottom.

alter table public.app_config
  add column theme text not null default 'default'
    check (theme in ('default', 'christmas'));

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
    'maintenance_ends_at', c.maintenance_ends_at,
    'theme', c.theme);
$$;
revoke execute on function public._app_config_snapshot(public.app_config) from public, anon, authenticated;

-- Defaults for keys missing from an older snapshot (history saved before maintenance or themes existed):
-- rolling back to one of those means maintenance off and the default theme.
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
    'maintenance_ends_at', null,
    'theme', 'default');
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
  v_theme   text := lower(btrim(v_cfg ->> 'theme'));
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
  if v_theme is null or v_theme not in ('default', 'christmas') then
    raise exception 'Theme must be Default or Christmas' using errcode = '22023';
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
         theme = v_theme,
         version = v_current.version + 1, updated_at = now()
   where platform = 'ios'
  returning * into v_result;

  insert into public.app_config_history (platform, version, config, changed_by, changed_by_email, note)
  values ('ios', v_result.version, public._app_config_snapshot(v_result),
          (select auth.uid()), (select auth.jwt() ->> 'email'), nullif(btrim(p_note), ''));

  v_action := case
    when v_result.maintenance_enabled and not v_current.maintenance_enabled then 'app_config.maintenance_on'
    when v_current.maintenance_enabled and not v_result.maintenance_enabled then 'app_config.maintenance_off'
    when v_result.theme is distinct from v_current.theme then 'app_config.theme'
    else 'app_config.publish'
  end;
  perform public._admin_log(v_action, 'app_config', 'ios',
    jsonb_build_object('version', v_result.version, 'note', p_note,
                       'from', jsonb_build_object('min', v_current.min_supported_version, 'latest', v_current.latest_version,
                                                  'maintenance', v_current.maintenance_enabled, 'theme', v_current.theme),
                       'to', jsonb_build_object('min', v_min, 'latest', v_latest, 'maintenance', v_m_on,
                                                'maintenance_message', case when v_m_on then v_m_msg end,
                                                'theme', v_theme)));
  return v_result;
end;
$$;
revoke execute on function public._apply_app_config(jsonb, integer, text) from public, anon, authenticated;

-- Version settings from the App config form; maintenance and theme are kept as they are.
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
      || (p_config - 'maintenance_enabled' - 'maintenance_title' - 'maintenance_message' - 'maintenance_ends_at' - 'theme'),
    p_expected_version, p_note);
end;
$$;

-- Theme Studio: switches the app theme; versions and maintenance are kept as they are.
create or replace function public.admin_set_theme(p_theme text, p_expected_version integer, p_note text default null)
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
    public._app_config_snapshot(v_current) || jsonb_build_object('theme', p_theme),
    p_expected_version, p_note);
end;
$$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.admin_update_app_config(jsonb, integer, text)',
    'public.admin_set_theme(text, integer, text)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated, service_role', f);
  end loop;
end;
$$;

-- admin_set_maintenance and admin_rollback_app_config need no change: they pass the full snapshot
-- (which now carries the theme), and rollback to a snapshot without a theme uses the default theme.

-- Rollback:
--   drop function public.admin_set_theme(text, integer, text);
--   re-create _app_config_snapshot / _app_config_defaults / _apply_app_config / admin_update_app_config
--     from 20261118170000_maintenance_mode_and_system_status.sql;
--   alter table public.app_config drop column theme;
