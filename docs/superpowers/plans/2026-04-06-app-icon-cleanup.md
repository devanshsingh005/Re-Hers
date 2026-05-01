# App Icon Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep one standard iOS app icon asset set and clarify that the project uses a single shared icon rather than separate light/dark/default icon sets.

**Architecture:** Keep `AppIcon.appiconset` as the only app icon set, preserve the Apple-required slots in `Contents.json`, and only clean naming/organization inside the asset folder. Do not introduce alternate icon behavior or duplicate themed icon sets.

**Tech Stack:** Xcode asset catalogs, JSON asset metadata, iOS app icon packaging

---

### Task 1: Audit And Normalize The App Icon Asset Set

**Files:**
- Modify: `Re-Hearse_v1/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Modify: `Re-Hearse_v1/Assets.xcassets/AppIcon.appiconset/*`
- Test: `Re-Hearse_v1/Assets.xcassets/AppIcon.appiconset/Contents.json`

- [ ] **Step 1: Inspect the current icon asset set**

Run: `ls -la /Users/user30/Documents/Re-Hers/Re-Hearse_v1/Assets.xcassets/AppIcon.appiconset && cat /Users/user30/Documents/Re-Hers/Re-Hearse_v1/Assets.xcassets/AppIcon.appiconset/Contents.json`
Expected: exactly one `.appiconset` with iPhone icon slots and one marketing icon file reference.

- [ ] **Step 2: Rename the 1024x1024 source icon to a shared-name convention if needed**

Use a single shared master filename such as:

```text
app-icon-shared-1024.png
```

Then update the matching `ios-marketing` entry in `Contents.json` so the filename matches the renamed file.

- [ ] **Step 3: Keep the required icon slots unchanged**

Preserve the existing JSON structure for the iPhone icon sizes:

```json
{
  "filename": "icon-60@3x.png",
  "idiom": "iphone",
  "scale": "3x",
  "size": "60x60"
}
```

Do not add `AppIconLight`, `AppIconDark`, or any extra app icon sets.

- [ ] **Step 4: Verify the asset catalog shape**

Run: `find /Users/user30/Documents/Re-Hers/Re-Hearse_v1/Assets.xcassets -maxdepth 2 -name '*.appiconset' | sort`
Expected: only `/Users/user30/Documents/Re-Hers/Re-Hearse_v1/Assets.xcassets/AppIcon.appiconset`

- [ ] **Step 5: Commit**

```bash
git add /Users/user30/Documents/Re-Hers/Re-Hearse_v1/Assets.xcassets/AppIcon.appiconset
git commit -m "clean up shared app icon asset"
```

### Task 2: Verify The Project Still Builds With The Cleaned Asset Set

**Files:**
- Test: `Re-Hearse_v1.xcodeproj`

- [ ] **Step 1: Run a simulator build**

Run: `xcodebuild build -quiet -project /Users/user30/Documents/Re-Hers/Re-Hearse_v1.xcodeproj -scheme Re-Hearse_v1 -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: build succeeds; any remaining warnings should be existing warnings, not new app icon structure failures.

- [ ] **Step 2: Confirm the icon cleanup matches the approved scope**

Checklist:

```text
- One AppIcon.appiconset only
- No separate light/dark/default icon sets
- Shared icon naming is clear
- No runtime behavior changes
```

- [ ] **Step 3: Commit verification state if needed**

```bash
git status --short
```

Expected: clean working tree after the asset cleanup commit.
