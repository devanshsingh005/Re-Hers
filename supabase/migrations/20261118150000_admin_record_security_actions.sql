-- Applied to project djqgmowfjxsnjdffdohw on 2026-11-18 via Supabase MCP.
-- Let the dashboard log authenticator changes (security.*) as well as storage uploads.
-- Rollback: re-run admin_record from 20261118120000_admin_dashboard.sql (storage.% only).
create or replace function public.admin_record(p_action text, p_target_type text, p_target_id text, p_details jsonb default '{}'::jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public._admin_guard();
  if p_action not like 'storage.%' and p_action not like 'security.%' then
    raise exception 'only storage and security actions can be recorded directly' using errcode = '22023';
  end if;
  perform public._admin_log(p_action, p_target_type, p_target_id, p_details);
end;
$$;
revoke execute on function public.admin_record(text, text, text, jsonb) from public, anon;
grant execute on function public.admin_record(text, text, text, jsonb) to authenticated, service_role;
