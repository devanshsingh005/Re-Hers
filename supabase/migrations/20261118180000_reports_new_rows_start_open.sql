-- Applied to project djqgmowfjxsnjdffdohw on 2026-11-18 via Supabase MCP.
-- Reports sent from the app always start as "open": a modified client can't file a report that's
-- already dismissed or carries a fake admin note. Admin changes go through admin_update_report (an UPDATE).
-- Rollback: drop trigger reports_start_open on public.reports; drop function public._reports_start_open();
create or replace function public._reports_start_open()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.status := 'open';
  new.admin_note := null;
  new.resolved_at := null;
  new.resolved_by := null;
  return new;
end;
$$;
revoke execute on function public._reports_start_open() from public, anon, authenticated;
create trigger reports_start_open before insert on public.reports
  for each row execute function public._reports_start_open();
