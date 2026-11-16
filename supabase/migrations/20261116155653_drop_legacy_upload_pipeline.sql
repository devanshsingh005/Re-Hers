-- Applied to project djqgmowfjxsnjdffdohw on 2026-11-16 via Supabase MCP.
-- Approved 2026-11-16. Uploads are converted and stored on the device; these were only used by the old server pipeline.
-- Rows are in backups/2026-11-16_2111 (ROLLBACK.md, section A: restore jobs before sheet_files).
drop view  public.user_storage_usage;
drop table public.sheet_files;
drop table public.jobs;
drop table public.scans;
drop table public.music_quiz_questions;
drop table public.user_blocks;

-- Called only by the delete-account edge function (service role). Every user table also cascades from auth.users.
create or replace function public.delete_user_account_data(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.playlists       where user_id = p_user_id;  -- playlist_items cascade
  delete from public.recent_plays    where user_id = p_user_id;
  delete from public.lesson_events   where user_id = p_user_id;
  delete from public.user_onboarding where id = p_user_id;
  delete from public.profiles        where id = p_user_id;
end;
$$;
revoke execute on function public.delete_user_account_data(uuid) from public, anon, authenticated;
grant execute on function public.delete_user_account_data(uuid) to service_role;
