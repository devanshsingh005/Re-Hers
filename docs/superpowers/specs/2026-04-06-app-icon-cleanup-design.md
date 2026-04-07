# App Icon Cleanup Design

## Goal
Keep a single standard iOS app icon asset set and make it clear that the app uses one shared icon design rather than separate light/dark/default app icon sets.

## Current State
- The project uses one asset catalog app icon set at `Re-Hearse_v1/Assets.xcassets/AppIcon.appiconset`.
- The set contains Apple-required size variants for iPhone plus the 1024x1024 marketing icon.
- The user wants the setup to conceptually represent `Default`, `Light`, and `Dark`, but all three should use the same artwork.

## Decision
Use one `AppIcon.appiconset` only.

We will not create separate `AppIconDefault`, `AppIconLight`, or `AppIconDark` asset sets because:
- iOS app icons still require multiple platform-specific size slots in a single icon set.
- Duplicating three identical icon sets would add confusion without adding behavior.
- The project already follows the standard Xcode app icon configuration.

## Implementation
- Keep `Re-Hearse_v1/Assets.xcassets/AppIcon.appiconset` as the only app icon asset set.
- Keep the existing required icon-size entries in `Contents.json`.
- Clarify the setup by renaming the 1024x1024 source file to a shared-name convention if needed.
- Do not add extra theme-specific app icon sets.
- Do not change runtime behavior or app theme behavior.

## Validation
- Confirm there is only one `.appiconset` in the asset catalog.
- Confirm `Contents.json` still references valid required icon slots.
- Confirm the project still builds after the asset cleanup.

## Out of Scope
- Alternate icons via `UIApplication.setAlternateIconName`.
- Automatic light/dark home screen icon switching.
- Creating distinct artwork for light or dark modes.
