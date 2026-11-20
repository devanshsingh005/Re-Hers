-- Applied to project djqgmowfjxsnjdffdohw on 2026-11-16 via Supabase MCP.
-- Least-privilege access. Every user table: a signed-in user sees and changes only their own rows.
-- songs: public read of active songs; writes only via service role (future admin portal).
-- reports is intentionally left unchanged (insert-own policy already correct; handled with the admin panel).

do $$
declare r record;
begin
  for r in select policyname, tablename from pg_policies
           where schemaname = 'public'
             and tablename in ('profiles','user_onboarding','lesson_events','recent_plays','playlists','playlist_items','songs')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- Table privileges: guests (anon) get only the song library.
revoke all on public.profiles, public.user_onboarding, public.lesson_events, public.recent_plays,
              public.playlists, public.playlist_items, public.songs from anon, authenticated;
grant select on public.songs to anon, authenticated;
grant select, insert, update         on public.profiles        to authenticated;
grant select, insert, update         on public.user_onboarding to authenticated;
grant select, insert                 on public.lesson_events   to authenticated;
grant select, insert, update         on public.recent_plays    to authenticated;
grant select, insert, update, delete on public.playlists       to authenticated;
grant select, insert, update, delete on public.playlist_items  to authenticated;

alter table public.profiles        enable row level security;
alter table public.user_onboarding enable row level security;
alter table public.lesson_events   enable row level security;
alter table public.recent_plays    enable row level security;
alter table public.playlists       enable row level security;
alter table public.playlist_items  enable row level security;
alter table public.songs           enable row level security;

create policy profiles_select_own on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy profiles_insert_own on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy profiles_update_own on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy onboarding_select_own on public.user_onboarding for select to authenticated using (id = (select auth.uid()));
create policy onboarding_insert_own on public.user_onboarding for insert to authenticated with check (id = (select auth.uid()));
create policy onboarding_update_own on public.user_onboarding for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy lesson_events_select_own on public.lesson_events for select to authenticated using (user_id = (select auth.uid()));
create policy lesson_events_insert_own on public.lesson_events for insert to authenticated with check (user_id = (select auth.uid()));

create policy recent_plays_select_own on public.recent_plays for select to authenticated using (user_id = (select auth.uid()));
create policy recent_plays_insert_own on public.recent_plays for insert to authenticated with check (user_id = (select auth.uid()));
create policy recent_plays_update_own on public.recent_plays for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy playlists_select_own on public.playlists for select to authenticated using (user_id = (select auth.uid()));
create policy playlists_insert_own on public.playlists for insert to authenticated with check (user_id = (select auth.uid()) and is_public is not true);
create policy playlists_update_own on public.playlists for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()) and is_public is not true);
create policy playlists_delete_own on public.playlists for delete to authenticated using (user_id = (select auth.uid()));

create policy playlist_items_select_own on public.playlist_items for select to authenticated using (user_id = (select auth.uid()));
create policy playlist_items_insert_own on public.playlist_items for insert to authenticated
  with check (user_id = (select auth.uid())
              and exists (select 1 from public.playlists p where p.id = playlist_id and p.user_id = (select auth.uid())));
create policy playlist_items_update_own on public.playlist_items for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid())
              and exists (select 1 from public.playlists p where p.id = playlist_id and p.user_id = (select auth.uid())));
create policy playlist_items_delete_own on public.playlist_items for delete to authenticated using (user_id = (select auth.uid()));

create policy songs_read_active on public.songs for select to anon, authenticated using (is_active);

-- Trigger functions: fixed search_path.
alter function public.handle_new_user() set search_path = '';
alter function public.handle_updated_at() set search_path = '';
revoke execute on function public.handle_updated_at() from public, anon, authenticated;

-- Storage. Old policies referenced deleted buckets or let any user touch any file.
do $$
declare r record;
begin
  for r in select policyname from pg_policies where schemaname = 'storage' and tablename = 'objects' loop
    execute format('drop policy %I on storage.objects', r.policyname);
  end loop;
end $$;

-- Avatars: files are named avatar_<user id>_<timestamp>.<ext> at the bucket root; uploader becomes owner.
create policy avatars_select_own on storage.objects for select to authenticated
  using (bucket_id = 'useprofile' and owner_id = (select auth.uid())::text);
create policy avatars_insert_own on storage.objects for insert to authenticated
  with check (bucket_id = 'useprofile' and lower(name) like 'avatar\_' || (select auth.uid())::text || '\_%');
create policy avatars_update_own on storage.objects for update to authenticated
  using (bucket_id = 'useprofile' and owner_id = (select auth.uid())::text)
  with check (bucket_id = 'useprofile' and lower(name) like 'avatar\_' || (select auth.uid())::text || '\_%');
create policy avatars_delete_own on storage.objects for delete to authenticated
  using (bucket_id = 'useprofile' and owner_id = (select auth.uid())::text);

-- Playlist covers: <user id>/<file> (the app writes the id upper-case).
create policy covers_select_own on storage.objects for select to authenticated
  using (bucket_id = 'PlayListCover' and lower((storage.foldername(name))[1]) = (select auth.uid())::text);
create policy covers_insert_own on storage.objects for insert to authenticated
  with check (bucket_id = 'PlayListCover' and lower((storage.foldername(name))[1]) = (select auth.uid())::text);
create policy covers_update_own on storage.objects for update to authenticated
  using (bucket_id = 'PlayListCover' and lower((storage.foldername(name))[1]) = (select auth.uid())::text)
  with check (bucket_id = 'PlayListCover' and lower((storage.foldername(name))[1]) = (select auth.uid())::text);
create policy covers_delete_own on storage.objects for delete to authenticated
  using (bucket_id = 'PlayListCover' and lower((storage.foldername(name))[1]) = (select auth.uid())::text);

-- library is a public bucket: files are read through /object/public/ without policies; only the service role writes.
