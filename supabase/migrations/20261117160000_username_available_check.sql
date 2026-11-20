-- Sign-up checks whether a username is free before creating the account. The user isn't
-- signed in yet (anon), and profiles is owner-only (20261116155933_rls_owner_only), so this
-- answers just that one question without exposing any profile.
create or replace function public.is_username_available(p_username text)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select not exists (
    select 1 from public.profiles where username = btrim(p_username)
  );
$$;

revoke all on function public.is_username_available(text) from public;
grant execute on function public.is_username_available(text) to anon, authenticated;
