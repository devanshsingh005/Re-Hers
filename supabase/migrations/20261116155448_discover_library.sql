-- Applied to project djqgmowfjxsnjdffdohw on 2026-11-16 via Supabase MCP.
-- Discover songs now live in the public `library` bucket: songs/<song_id>/{original.pdf,labeled.pdf,score.json}.
-- Files were copied there (and verified) before this ran. Rollback: restore columns from backups/2026-11-16_2111 (ROLLBACK.md, section A).
update public.songs set
  original_pdf_path = 'https://djqgmowfjxsnjdffdohw.supabase.co/storage/v1/object/public/library/songs/' || id || '/original.pdf',
  labeled_pdf_path  = 'https://djqgmowfjxsnjdffdohw.supabase.co/storage/v1/object/public/library/songs/' || id || '/labeled.pdf',
  output_json_path  = 'https://djqgmowfjxsnjdffdohw.supabase.co/storage/v1/object/public/library/songs/' || id || '/score.json';

-- Unused: sheet_file_id pointed at the legacy sheet_files table, sheet_url at the Sheets bucket, is_converted was never read.
alter table public.songs
  drop column sheet_file_id,
  drop column sheet_url,
  drop column is_converted;

comment on table public.songs is 'Discover library. Readable by everyone; written only by the admin portal (service role). Files: storage bucket "library", songs/<id>/.';
