# Re-Hearse

Re-Hearse is an iOS app for uploading sheet music, practicing songs, and using guided rehearsal tools powered by a Supabase-backed iOS client.

Open `Rehearse.xcodeproj` (scheme `Re-Hearse_v1`).

## Sheet music conversion (on device)

Uploaded sheet music is converted entirely on the iPhone; nothing is sent to a server.
[OemerKit](OemerKit/README.md) (vendored in `OemerKit/`) runs the oemer recognition models with
Core ML on the Neural Engine and its recognition engine in Swift. `Services/SheetMusic/` turns
each upload into:

- the score JSON that Play Along, Animation and the upload result screen read (the same shape
  the old Audiveris server returned),
- a labeled PDF with English note names under the notes,
- MusicXML.

Uploads and their results are stored per account in the app's Application Support folder
(`LocalSheetLibrary`). Supabase is still used for sign-in, Discover, profiles, progress and
playlists.

The models load on first use (slower right after install); a page then takes a few seconds on a
recent iPhone. Judge speed and heat in Release builds.

## App Store Compliance Notes

- The iOS app is the only client included in this repository.
- Before any Google Play submission, the Android client must be audited separately.
- Public legal pages are served from the app's static public site:
  - `https://letsrehearse.studio/privacy-policy/`
  - `https://letsrehearse.studio/terms-of-service/`

## Backend (no longer used by the app for conversion)

`backend/` holds the former conversion service (FastAPI, Redis worker, Audiveris on Azure). The
app no longer calls it. Its configuration lives in `backend/.env`:

- `SUPABASE_URL`
- `SUPABASE_KEY`
- `BACKEND_API_URL`
- `AUDIVERIS_API_URL`
- `LOG_LEVEL`
