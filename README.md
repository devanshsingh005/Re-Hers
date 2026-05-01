# Re-Hearse

Re-Hearse is an iOS app for uploading sheet music, practicing songs, and using guided rehearsal tools powered by a Supabase-backed iOS client and a FastAPI backend.

## App Store Compliance Notes

- The iOS app is the only client included in this repository.
- Before any Google Play submission, the Android client must be audited separately.
- Public legal pages are served from the app's static public site:
  - `https://letsrehearse.studio/privacy-policy/`
  - `https://letsrehearse.studio/terms-of-service/`

## Backend Configuration

Set these values in `backend/.env` for production:

- `SUPABASE_URL`
- `SUPABASE_KEY`
- `BACKEND_API_URL`
- `AUDIVERIS_API_URL`
- `LOG_LEVEL`
