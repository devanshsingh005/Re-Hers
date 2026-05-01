# App Store Privacy Audit

## Pinned SDK Versions

Source: `Re-Hearse_v1.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

- `supabase-swift` `2.38.0`
- `swift-crypto` `4.2.0`
- `swift-asn1` `1.5.1`
- `swift-clocks` `1.0.6`
- `swift-concurrency-extras` `1.3.2`
- `swift-http-types` `1.5.1`
- `xctest-dynamic-overlay` `1.8.0`

## Manifest Verification

- Inspected locally:
  - `Re-Hearse_v1/PrivacyInfo.xcprivacy`
  - `build/Re-Hearse_v1.xcarchive/Products/Applications/Re-Hearse_v1.app/swift-crypto_Crypto.bundle/PrivacyInfo.xcprivacy`
  - `Re-Hearse_v1.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `swift-crypto` privacy manifests were observed locally in the built app archive.
- No `PrivacyInfo.xcprivacy` file was found locally for `supabase-swift` `2.38.0` in this environment.
- App-level disclosures should reflect the shipped iOS app's actual collected data and runtime use, not inferred SDK capabilities alone. Based on the local code inspection, that includes:
  - Account name
  - Name
  - Email address
  - User ID
  - Photos or videos selected for upload or capture
  - Audio data captured during chord recognition

## Account Deletion

- Method: Supabase Edge Function (`delete-account`) invoked from the Profile screen after password re-authentication and final destructive confirmation.
- Type: Hard delete, permanent and irreversible. There is no soft-delete path in the deletion flow.
- Auth: The function verifies the JWT server-side with `verify_jwt = true`, then validates the bearer token with an anon Supabase client before any admin operations.
- Data deleted: playlists, playlist items, recent plays, lesson events, scans, onboarding data, the user profile row, user-owned `jobs`, and user-owned storage objects in `useprofile`, `PlayListCover`, `pdf_uploads`, and `sheet_data`. Relational and storage-object cleanup runs through a SQL helper before the final `auth.admin.deleteUser(user.id)` step removes the auth account.
- Service role key: `SUPABASE_SERVICE_ROLE_KEY` is a dashboard secret only. It must never be committed to the repo or bundled in the iOS app.
- Apple Guideline 5.1.1(v): Satisfied. The app provides an account deletion mechanism that permanently removes the account and associated user data.
- The deletion result is surfaced back to the user in the UI, and failures are shown as an error alert.

## App Store Connect Follow-Up

Align the App Store privacy nutrition label with the app-level manifest and actual runtime behavior.

The public privacy-policy metadata URL should point to the static public policy page used by the iOS app:

- `https://letsrehearse.studio/privacy-policy/`

The public terms URL should match the app's public legal link:

- `https://letsrehearse.studio/terms-of-service/`

## Supabase Edge Function Secret

- `SUPABASE_SERVICE_ROLE_KEY` must be configured as a Supabase Edge Function secret for the account-deletion function.
- Never commit `SUPABASE_SERVICE_ROLE_KEY` to source control or expose it in the iOS app bundle.
