-- Applied to project djqgmowfjxsnjdffdohw on 2026-11-16 via Supabase MCP.
-- Bucket user_sheets (private, 10 MB file limit, application/octet-stream) was created through the Storage API.
-- Uploaded sheets synced across a user's devices. The id is the upload's id on the device that made it.
-- Files live in the private bucket user_sheets at <user_id>/<upload_id>/, compressed (raw DEFLATE):
--   input.pdf.z, score.musicxml.z, and labels.json.z (or labeled.pdf.z for uploads converted before labels were saved).
-- Only successfully converted uploads are synced. Limit: 10 uploads per user (enforced below), 10 MB per file (bucket).
create table public.user_uploads (
  id                 uuid primary key,
  user_id            uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title              text not null check (char_length(title) between 1 and 200),
  original_filename  text not null default '' check (char_length(original_filename) <= 300),
  file_size_bytes    integer not null check (file_size_bytes between 0 and 10485760),
  note_count         integer,
  page_count         integer,
  skipped_pages      integer[],
  conversion_seconds double precision,
  labeled_format     text not null default 'labels' check (labeled_format in ('labels', 'pdf')),
  files_ready        boolean not null default false,
  uploaded_at        timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index user_uploads_user_idx on public.user_uploads (user_id, uploaded_at desc);

create or replace function public.enforce_upload_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- serialize inserts per user so two devices can't both take the last slot
  perform pg_advisory_xact_lock(hashtextextended(new.user_id::text, 0));
  if (select count(*) from public.user_uploads where user_id = new.user_id) >= 10 then
    raise exception 'upload_limit_reached' using errcode = 'P0001', hint = 'A user can keep at most 10 uploads.';
  end if;
  return new;
end;
$$;
revoke execute on function public.enforce_upload_limit() from public, anon, authenticated;
create trigger user_uploads_limit before insert on public.user_uploads
  for each row execute function public.enforce_upload_limit();

alter table public.user_uploads enable row level security;
revoke all on public.user_uploads from anon, authenticated;
grant select, insert, update, delete on public.user_uploads to authenticated;

create policy user_uploads_select_own on public.user_uploads for select to authenticated using (user_id = (select auth.uid()));
create policy user_uploads_insert_own on public.user_uploads for insert to authenticated with check (user_id = (select auth.uid()));
create policy user_uploads_update_own on public.user_uploads for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy user_uploads_delete_own on public.user_uploads for delete to authenticated using (user_id = (select auth.uid()));

-- Files: only into the caller's folder, and only for an upload row they own (so storage is capped by the 10-row limit).
create policy user_sheets_select_own on storage.objects for select to authenticated
  using (bucket_id = 'user_sheets' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy user_sheets_insert_own on storage.objects for insert to authenticated
  with check (bucket_id = 'user_sheets'
              and (storage.foldername(name))[1] = (select auth.uid())::text
              and exists (select 1 from public.user_uploads u
                          where u.user_id = (select auth.uid()) and u.id::text = (storage.foldername(name))[2]));
create policy user_sheets_update_own on storage.objects for update to authenticated
  using (bucket_id = 'user_sheets' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'user_sheets'
              and (storage.foldername(name))[1] = (select auth.uid())::text
              and exists (select 1 from public.user_uploads u
                          where u.user_id = (select auth.uid()) and u.id::text = (storage.foldername(name))[2]));
create policy user_sheets_delete_own on storage.objects for delete to authenticated
  using (bucket_id = 'user_sheets' and (storage.foldername(name))[1] = (select auth.uid())::text);
