# Android Compliance Gap

This repository does not contain an Android app module, `AndroidManifest.xml`, or app-level Gradle configuration for a shipping Android client.

## Required Before Any Google Play Submission

- Audit the actual Android client repository or module separately.
- Review Play Console Data Safety disclosures against the shipped Android code and SDKs.
- Verify billing, account deletion, permissions, deep links, and privacy-policy metadata in the Android build.

## Status

- iOS audit: handled in this repository.
- Android audit: still required in the Android codebase before release.
