-- Applied to project djqgmowfjxsnjdffdohw on 2026-11-16 via Supabase MCP.
-- Only the service role (the delete-account edge function) and triggers may run these.
-- Rollback: GRANT EXECUTE ON FUNCTION <name> TO PUBLIC, anon, authenticated;
revoke execute on function public.delete_user_account_data(uuid) from public, anon, authenticated;
revoke execute on function public.increment_study_time(uuid, integer) from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
grant execute on function public.delete_user_account_data(uuid) to service_role;
grant execute on function public.increment_study_time(uuid, integer) to service_role;
