-- Applied to project djqgmowfjxsnjdffdohw on 2026-11-16 via Supabase MCP.
-- Approved 2026-11-16: remove every existing playlist; the feature stays. Rows are in backups/2026-11-16_2111.
delete from public.playlist_items;
delete from public.playlists;
-- Pointed at the legacy scans table, which is dropped next. Uploads are referenced via track_id = 'local-upload:<uuid>'.
alter table public.playlist_items drop column sheet_scan_id;
