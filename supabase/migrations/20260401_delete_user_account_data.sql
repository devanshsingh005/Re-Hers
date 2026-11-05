create or replace function public.delete_user_account_data(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, storage
as $$
begin
  delete from public.playlist_items
  where playlist_id in (
    select id
    from public.playlists
    where user_id = p_user_id
  );

  delete from public.playlists
  where user_id = p_user_id;

  delete from public.recent_plays
  where user_id = p_user_id;

  delete from public.lesson_events
  where user_id = p_user_id;

  delete from public.jobs
  where user_id = p_user_id;

  delete from public.scans
  where user_id = p_user_id;

  delete from public.user_onboarding
  where id = p_user_id;

  delete from public.profiles
  where id = p_user_id;
end;
$$;
