# Supabase cleanup — Step 2 audit and plan

Project `djqgmowfjxsnjdffdohw`, Postgres 17.6, free plan. Written 2026-11-16.
Backup: `backups/2026-11-16_2111/` (verified by test restore). Rollback commands: `ROLLBACK.md` in that folder.

**Status (2026-11-16, evening): executed.** Approved by the owner and run end to end. Applied migrations are in `supabase/migrations/20261116*`. Differences from this plan:
- `profiles.daily_goal_minutes` was not added: the goal stays in `user_onboarding.practice_mins` (owner's decision), and the app no longer sends it.
- `increment_study_time(uuid, int)` was dropped and replaced by `add_my_study_time(int)`, which only touches the caller's own row.
- `reports` was left completely untouched (no index, no policy change), at the owner's request.
- All 17 avatar files were kept; the app now deletes a user's previous avatars when they upload a new one.

Result: database 16 MB; storage 965 files / 333 MB → 38 files / 17 MB; users 62, profiles 62 (unchanged).

## 1. Schema map (live, at backup time)

Database 17 MB of 500 MB. Storage 333 MB of 1 GB.

| Table | Rows | Size | Used by app | Verdict |
|---|---|---|---|---|
| `profiles` | 62 | 80 kB | yes (9 files) | keep, add 3 columns |
| `user_onboarding` | 47 | 144 kB | yes | keep, fix policies, drop 3 indexes |
| `lesson_events` | 771 | 248 kB | yes | keep, add index |
| `songs` | 7 | 80 kB | yes (Discover) | keep, move files, drop 3 columns |
| `recent_plays` | 42 | 88 kB | yes | keep, add index |
| `playlists` | 11 | 64 kB | yes | keep table, delete all rows |
| `playlist_items` | 11 | 80 kB | yes | keep table, delete all rows, drop 1 column |
| `reports` | 4 | 32 kB | insert only | keep untouched (admin panel later) |
| `jobs` | 89 | 200 kB | no | drop |
| `sheet_files` | 89 | 168 kB | no | drop |
| `scans` | 89 | 464 kB | no | drop |
| `music_quiz_questions` | 10 | 48 kB | no | drop |
| `user_blocks` | 0 | 16 kB | no | drop |
| `user_storage_usage` (view) | – | – | no | drop |

Relationships: every user table references `auth.users(id)` with `ON DELETE CASCADE`; `user_onboarding.id → profiles.id`; `playlist_items.playlist_id → playlists.id` (cascade); `recent_plays.song_id → songs.id` (cascade). Legacy links to remove: `songs.sheet_file_id → sheet_files`, `playlist_items.sheet_scan_id → scans`, `sheet_files.job_id → jobs`.

| Bucket | Objects | Size | Verdict |
|---|---|---|---|
| `pdf_uploads` | 564 | 243 MB | delete after the 14 Discover PDFs are copied out |
| `sheet_data` | 345 | 41 MB | delete after the 7 Discover JSON files are copied out |
| `PlayListCover` | 33 | 30 MB | keep bucket, delete all 33 files |
| `useprofile` | 17 | 16 MB | keep everything (avatars) |
| `Sheets` | 6 | 415 kB | delete (app only uses it as a fallback for `sheet_url`, which is being dropped) |
| `discover_assets` | 0 | 0 | delete |
| `library` (new) | 21 | ~3 MB | new public-read bucket for Discover songs |

Accounts: 62 in `auth.users`, 62 in `profiles`. **No statement in this plan touches `auth.users`, and none deletes or rewrites a `profiles` row.**

## 2. Data-flow map (app)

One shared client in `Services/SupabaseManager.swift`; the key comes from a git-ignored xcconfig. No service-role key in the app. No Realtime, no polling.

| Screen / service | Calls |
|---|---|
| `AuthViewController`, `OTPVerificationViewController`, `PasswordRecoveryService` | auth; reads `profiles`, `user_onboarding` |
| `OnboardingViewModel`, `GuestSessionManager` | upsert `user_onboarding`, update `profiles` |
| `HomeViewController` | `profiles` (`select *`), `DailyGoalManager`, playlists, recents |
| `DailyGoalManager` | reads/writes 3 `profiles` columns that do not exist — fails every time |
| `SupabaseProgressManager` | insert `lesson_events`; read-then-write `profiles` progress (3 places) |
| `UserProfileViewController` | 4× `profiles`, 2× `user_onboarding`, `lesson_events`, avatar upload, delete-account function |
| `PlaylistsManager` | 5× `playlists`, 8× `playlist_items`, cover upload |
| `SongService` (`Models/Song.swift`), `SongDetailsPage` | `songs` (5-minute memory cache already) |
| `RecentPlayModel` | upsert `recent_plays` |
| `DiscoverSongDetailViewController` | insert `reports` |
| `NavigationBarHelper` | signs the avatar URL on every navigation bar build |

Tangles and hiccups found:

- **Screens talk to Supabase directly** in about 20 files; there is no data layer.
- **N+1 in playlists:** `fetchRemotePlaylists` runs one query for playlists, then one per playlist for its items.
- **Read-modify-write on study time:** `SupabaseProgressManager` reads `total_study_seconds` and writes back the sum, so two devices can overwrite each other. The atomic `increment_study_time` function exists but is never called.
- **Daily goal sync is broken:** the three columns are missing, so both the read and the write throw (caught and only logged).
- **Practice-goal change is silently dropped:** `user_onboarding` has no UPDATE policy, so the update from the Profile screen changes 0 rows.
- **`select *` in 19 places**, 31 separate `auth.currentUser` / `auth.session` lookups, and the profile row is fetched independently by Home, Profile, DailyGoal and Progress.
- **Avatar and cover URLs are re-signed** instead of cached for their one-hour lifetime (covers are cached, avatars are not).

## 3. Security gaps (current)

| Gap | Fix |
|---|---|
| `delete_user_account_data`, `increment_study_time`, `handle_new_user` callable by anyone | **fixed in migration 01** |
| `user_onboarding`: readable by everyone, insertable by anyone, no update rule | Step 4 |
| `pdf_uploads`: anyone can read, upload, delete without signing in | bucket removed in Step 3 |
| `sheet_data`: anonymous upload; any signed-in user reads/deletes everything | bucket removed in Step 3 |
| `useprofile`: any signed-in user can overwrite or read any avatar | Step 4 |
| `PlayListCover`: any signed-in user can upload anywhere in the bucket | Step 4 |
| 3 functions without a fixed `search_path` | Step 4 |
| 29 policies call `auth.uid()` per row; 26 duplicate permissive policies | Step 4 rewrite |
| Leaked-password protection off | needs a paid plan; accepted |

## 4. Step 3 migrations, in order

Each runs alone, is checked, and has a rollback. Storage files are removed through the Storage API (SQL deletes on `storage.objects` are blocked by Supabase and would leave the files behind).

**00 — baseline (no database change).** Save the current `public` schema as `supabase/migrations/20261116_000_baseline.sql` so the repo matches the live project.

**01 — lock down functions. DONE.** Verified: `anon` and `authenticated` can no longer execute the three functions; the service role still can; 62 users / 62 profiles unchanged.

**02 — Discover library.**
1. Create bucket `library` (public read, 20 MB file limit, PDF/JSON/images only).
2. Copy the 21 files to `library/songs/<song_id>/{original.pdf,labeled.pdf,score.json}` and verify sizes.
3. Point the 7 rows at the new files (full public URLs, which the current app build already understands):
   ```sql
   update public.songs set
     original_pdf_path = '<base>/library/songs/' || id || '/original.pdf',
     labeled_pdf_path  = '<base>/library/songs/' || id || '/labeled.pdf',
     output_json_path  = '<base>/library/songs/' || id || '/score.json';
   ```
4. Open each of the 7 songs' three URLs and confirm HTTP 200 before anything is deleted.
5. Drop unused columns (the FK goes with the column):
   ```sql
   alter table public.songs drop column sheet_file_id, drop column sheet_url, drop column is_converted;
   ```
   `cover_image_url` stays: today it holds bundled image names (`trackimage_1`…); the admin portal can store uploaded cover paths in it later.

**03 — playlists reset.** *(destructive)*
```sql
delete from public.playlist_items;   -- 11 rows
delete from public.playlists;        -- 11 rows, 6 users
alter table public.playlist_items drop column sheet_scan_id;
```
Then delete all 33 files (30 MB) in `PlayListCover`. Bucket, tables and the feature stay; a test user creates a playlist with a cover afterwards to prove it works.

**04 — drop legacy objects.** *(destructive)*
```sql
drop view  public.user_storage_usage;
drop table public.sheet_files;          -- 89 rows
drop table public.jobs;                 -- 89 rows
drop table public.scans;                -- 89 rows
drop table public.music_quiz_questions; -- 10 rows
drop table public.user_blocks;          -- 0 rows
```
In the same step: `delete_user_account_data` loses its `jobs`/`scans` lines, and the `delete-account` edge function is redeployed without its `jobs`/`scans`/`pdf_uploads`/`sheet_data` lookups — otherwise account deletion would start failing.

**05 — delete legacy storage.** *(destructive, only after 02 is verified)*
- all 564 objects in `pdf_uploads` (243 MB) and all 345 in `sheet_data` (41 MB), then both buckets
- all 6 objects in `Sheets` (415 kB), then the bucket
- the empty `discover_assets` bucket
- `useprofile`: nothing deleted

Storage after this step: about 19 MB (16 MB avatars + 3 MB library).

**06 — profiles daily-goal columns.**
```sql
alter table public.profiles
  add column daily_goal_minutes  smallint,
  add column practice_mins_today smallint not null default 0,
  add column last_practice_date  date;
```
All three are needed now because the current build writes them in one update. `user_onboarding.practice_mins` remains the source of truth for the goal; Step 5 makes the app read and write the goal there, after which `daily_goal_minutes` is dropped.

**07 — indexes.**
```sql
create index lesson_events_user_time_idx on public.lesson_events (user_id, occurred_at desc);
create index playlists_user_created_idx  on public.playlists (user_id, created_at desc);
create index playlist_items_user_idx     on public.playlist_items (user_id);
create index recent_plays_song_idx       on public.recent_plays (song_id);
create index reports_reporter_idx        on public.reports (reporter_id);
drop index public.idx_user_onboarding_unique;   -- exact duplicate of the primary key
drop index public.idx_user_onboarding_genres;   -- never used
drop index public.idx_user_onboarding_level;    -- never used
```
No slow queries exist at this size (largest table 771 rows; slowest recorded statement 21 ms, a dashboard browse). These indexes cover the foreign keys and the filters the policies use.

**08 — `VACUUM (ANALYZE)`** on the remaining tables, then re-check size against 500 MB.

## 5. Step 4 — RLS (after Step 3)

Policies are rewritten as one per table per operation, `to authenticated`, using `(select auth.uid())`.

| Table | select | insert | update | delete |
|---|---|---|---|---|
| `profiles` | own | own | own | – (edge function only) |
| `user_onboarding` | own | own | own | – |
| `lesson_events` | own | own | – | – |
| `recent_plays` | own | own | own | own |
| `playlists` | own | own | own | own |
| `playlist_items` | own | own, and the playlist must be theirs | own | own |
| `reports` | – | own | – | – |
| `songs` | everyone, active songs only | – | – | – |

- `songs` writes stay closed to the app. The future admin portal writes with the service role on its server, or through an `is_admin` claim added then; nothing needs to change in the tables for that.
- Storage: `useprofile` and `PlayListCover` become owner-only for read, upload, replace and delete; `library` is read-only for everyone.
- `search_path` fixed on the three functions; `anon` loses table privileges it does not need.
- Tests: as anonymous, user A and user B, prove A cannot read or write B's rows or files, then re-run the security advisor.

## 6. Every destructive action

| # | Action | Impact |
|---|---|---|
| 03 | delete all `playlist_items` | 11 rows |
| 03 | delete all `playlists` | 11 rows, 6 users |
| 03 | delete all files in `PlayListCover` | 33 files, 30 MB |
| 03 | drop `playlist_items.sheet_scan_id` | 9 non-null values |
| 02 | drop `songs.sheet_file_id`, `sheet_url`, `is_converted` | 7 rows lose 3 unused columns |
| 04 | drop `sheet_files`, `jobs`, `scans` | 89 rows each |
| 04 | drop `music_quiz_questions`, `user_blocks`, view `user_storage_usage` | 10 rows, 0 rows |
| 05 | delete `pdf_uploads` and `sheet_data` contents and buckets | 909 files, 284 MB |
| 05 | delete `Sheets` contents and bucket, `discover_assets` bucket | 6 files, 415 kB |
| 07 | drop 3 indexes on `user_onboarding` | no data |

Not deleted: any account, any profile, any avatar, `lesson_events`, `recent_plays`, `user_onboarding`, `reports`, `songs` rows.

## 7. Open points

1. **Old builds.** After 04/05 an older installed build that still uploads to the server pipeline would fail on upload. The plan assumes that is acceptable.
2. **Second copy of the backup.** It exists only on this Mac. Copy `backups/2026-11-16_2111/` elsewhere before 03.
3. **`playlists.is_public`** is dropped in Step 5 together with the app model change, not in Step 3, because the current build may send that field on insert. Its public-read policy goes in Step 4.
4. **Avatars with no recorded owner.** Some of the 17 avatar files may have been uploaded without an owner id; Step 4 checks this before switching to owner-only rules so nobody loses their picture.
