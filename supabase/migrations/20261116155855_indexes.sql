-- Applied to project djqgmowfjxsnjdffdohw on 2026-11-16 via Supabase MCP.
-- Cover foreign keys and the user_id filters every RLS policy uses.
create index lesson_events_user_time_idx on public.lesson_events (user_id, occurred_at desc);
create index playlists_user_created_idx  on public.playlists (user_id, created_at desc);
create index playlist_items_user_idx     on public.playlist_items (user_id);
create index recent_plays_song_idx       on public.recent_plays (song_id);
create index songs_active_order_idx      on public.songs (level, sort_order) where is_active;

-- Exact duplicate of user_onboarding_pkey, and two indexes that have never been used.
drop index public.idx_user_onboarding_unique;
drop index public.idx_user_onboarding_genres;
drop index public.idx_user_onboarding_level;
