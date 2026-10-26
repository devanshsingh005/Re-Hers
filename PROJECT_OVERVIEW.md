# Re-Hearse Project Overview

**Last Updated:** October 25, 2026
**Status:** Active Development

---

## 📋 Table of Contents

1. [Project Summary](#project-summary)
2. [Architecture Overview](#architecture-overview)
3. [On-Device Sheet Music Conversion](#on-device-sheet-music-conversion)
4. [Supabase: Data & Storage](#supabase-data--storage)
5. [Key Features](#key-features)
6. [Project Structure](#project-structure)
7. [Development Setup](#development-setup)
8. [Security & Privacy](#security--privacy)
9. [Troubleshooting](#troubleshooting)

---

## 📱 Project Summary

**Re-Hearse** is a music learning and practice app for iPhone: upload sheet music, watch it played
on an animated piano, practise it with Play Along, and follow guided lessons.

### Core Purpose
- Upload sheet music (scan, photo or PDF) and convert it **on the device** into playable data
- Show the sheet with English note names under the notes
- Animated piano playback and guided Play Along practice
- Live note detection from the microphone
- Lessons, daily goals and practice progress

### Technology Stack
- **App:** iOS 17+, Swift, UIKit
- **Sheet music recognition:** [OemerKit](OemerKit/README.md), on the device (Core ML on the
  Neural Engine + the oemer recognition engine in Swift)
- **Accounts, content and sync:** Supabase (Auth, PostgreSQL, Storage)
- **Analytics:** Firebase Analytics
- **Audio:** AVFoundation (AVAudioEngine, sampler with SoundFonts)

---

## 🏗️ Architecture Overview

```
┌───────────────────────────────────────────────────────────────┐
│                         iOS APPLICATION                       │
│                                                               │
│  Upload ─▶ LocalSheetLibrary ─▶ OnDeviceSheetConverter        │
│              (per-account files)      │                       │
│                                       ▼                       │
│                       OemerKit (Core ML + Swift engine)       │
│                                       │                       │
│            score JSON · labeled PDF · MusicXML ◀──┘           │
│                     │                                         │
│      Animation · Play Along · upload result · playlists       │
└─────────────────────┬─────────────────────────────────────────┘
                      │ sign-in, Discover, profiles, playlists, progress
                      ▼
        ┌──────────────────────────────┐
        │ Supabase                     │
        │ Auth · PostgreSQL · Storage  │
        └──────────────────────────────┘
```

The app has no server of its own. Sheet music never leaves the device; Supabase holds the
account and everything that is shared or synced (Discover content, profiles, playlists, progress).

### Upload Flow
1. The user scans pages (VisionKit), takes a photo, picks one from the library, or picks a PDF.
2. `UploadScreen` makes a PDF (photos and scans are placed on 612×792 pt pages) and hands it to
   `LocalSheetLibrary`, which stores it and starts the conversion.
3. `UploadPageNextViewController` opens at once and shows progress while the page is read.
4. When done, it shows the labeled PDF and unlocks Animation and Play Along.

---

## 🎼 On-Device Sheet Music Conversion

All in `Services/SheetMusic/`:

| File | Role |
|------|------|
| `LocalSheetLibrary.swift` | The user's uploads, stored per account in *Application Support/SheetLibrary/&lt;user id&gt;/*: `input.pdf`, `output.json`, `labeled.pdf`, `score.musicxml` and an index. Runs conversions (they continue when you leave the screen), reports progress, retries failures and resumes conversions cut off by closing the app. |
| `OnDeviceSheetConverter.swift` | Renders each PDF page (~4 MP), runs OemerKit on it, merges the pages' MusicXML, and writes the score JSON and the labeled PDF. Pages without music are skipped. |
| `MusicXMLDocument.swift` | MusicXML tree: parse, merge pages, write back, and convert to the JSON the app reads (`{"score-partwise": …}` with `@attributes`, arrays for repeated elements, `null` for empty ones, the layout Audiveris output had). |
| `NoteLabelRenderer.swift` | Places English note names ("C#4", "Bb3") 2.5 staff spaces below each note's staff, 1.3 staff spaces high; collisions move down a line, and a label never covers a notehead. Draws them on the original PDF pages (vector pages stay vector). |

**OemerKit** (vendored in `OemerKit/`, a local Swift package) does the recognition: two
segmentation networks run with Core ML, then a pure-Swift port of the oemer pipeline finds
staffs, noteheads, rhythm, accidentals and clefs and writes MusicXML. It also reports where
every note and its staff are on the page, which the labels use. See `OemerKit/README.md` for
accuracy, speed and its own tests (`bash OemerKit/scripts/verify_mac.sh` on a Mac).

Consumers of the score JSON: `MusicJSONLoader` (Animation, Play Along), `SheetMusicView`
(notation in Animation), and the key/tempo/chord readers in `UploadPageNextViewController`.

---

## 🗄️ Supabase: Data & Storage

### Tables used by the app
| Table | Used for |
|-------|----------|
| `profiles` | User profile (name, avatar) |
| `user_onboarding` | Onboarding answers |
| `songs` | Discover catalog (with paths to each song's PDFs and score JSON) |
| `playlists`, `playlist_items` | Playlists; an upload is referenced by `track_id = "local-upload:<uuid>"` |
| `recent_plays` | Recently played songs |
| `lesson_events`, `learning_chapters` | Lessons and progress |
| `reports` | Content reports from Discover |

### Storage buckets
- `pdf_uploads`, `sheet_data`: Discover song assets (original/labeled PDFs, score JSON)
- `useprofile`: profile pictures
- `PlayListCover`: playlist cover images

### Legacy data
Before conversion moved onto the device, uploads were stored in the `jobs` and `scans` tables and
the `pdf_uploads` / `sheet_data` buckets. The app no longer reads or writes them; the
`delete-account` Edge Function (`supabase/functions/delete-account`) still deletes them with the
account.

---

## 🎵 Key Features

### 1. Sheet Music Upload & Conversion
- **Input:** document scan, camera photo, photo library image, or PDF
- **Process:** on the device: OemerKit reads each page, works offline, nothing is uploaded
- **Output:** score JSON for practice, a labeled PDF with note names, MusicXML
- **Screens:** `Screens/Upload/` (upload, result, all uploads)

### 2. Animated Piano Playback
- **Display:** scrolling notation (`SheetMusicView`) with an animated keyboard (`PianoView`)
- **Sync:** audio, keys and sheet position follow the score's timing
- **Interaction:** play/pause, seek, tempo, instrument
- **Screen:** `Screens/PianoAnimation/AnimationViewController.swift`

### 3. Play Along
- **Guidance:** shows the expected notes and listens through the microphone or on-screen keys
- **Feedback:** marks right and wrong notes, tracks progress, ends with a report
- **Screen:** `Screens/PlayAlong/PlayAlongViewController.swift`

### 4. Live Note Detection ("Chord Recognition")
- **Input:** microphone, FFT pitch detection (`Components/PitchDetector.swift`)
- **Display:** strongest detected note and its frequency
- **Screen:** `Screens/ChordRecognition/MainChordRecognitionScreen.swift`

### 5. Lessons, Goals and Progress
- Lesson map and chapters (`Screens/LearningCurve/`), daily goal and continue-learning cards
  (`Screens/Home/`), progress stored through `SupabaseProgressManager`

### 6. Discover and Playlists
- Curated songs from Supabase (`Screens/Discover/`), playlists mixing Discover songs and the
  user's uploads (`Screens/Playlist/`)

### 7. Accounts
- Supabase Auth (email/password, OTP, password reset) in `Screens/Auth/`; guest mode with some
  features gated (`Services/GuestFeatureAccessPolicy.swift`)

---

## 📁 Project Structure

```
Rehearse/
├── Rehearse.xcodeproj          # the Xcode project (scheme Re-Hearse_v1)
├── Re-Hearse_v1/               # assets, Info.plist, PrivacyInfo, xcconfig files
├── App/                        # AppDelegate, SceneDelegate
├── Screens/                    # one folder per feature (Upload, PianoAnimation, PlayAlong, …)
├── Services/                   # Supabase, analytics, guest mode, …
│   └── SheetMusic/             # on-device conversion (see above)
├── Components/                 # shared UI and PitchDetector
├── Models/, Extensions/, Utilities/
├── Resources/SoundFonts/       # piano sounds
├── OemerKit/                   # sheet music recognition package (local Swift package)
├── Re-Hearse_v1Tests/          # unit tests (OnDevice/ covers the conversion pipeline)
├── supabase/                   # Edge Functions and migrations
└── docs/                       # architecture and audit notes
```

---

## 🚀 Development Setup

### Prerequisites
- macOS with Xcode 16 or later (tested with Xcode 26.6)
- iOS 17+ device or simulator. The Simulator has no Neural Engine, so recognition runs on the
  Mac's CPU there; judge speed and heat on a device, in Release.

### Steps
1. Open `Rehearse.xcodeproj` and select the `Re-Hearse_v1` scheme.
2. Supabase credentials come from `Re-Hearse_v1/Debug.xcconfig` / `Release.xcconfig`
   (`SUPABASE_URL`, `SUPABASE_KEY`).
3. Build and run. Swift packages (Supabase, Firebase, SkeletonView, OemerKit) resolve
   automatically; OemerKit is local, in `OemerKit/`.

### Tests
- App: Product → Test, or
  `xcodebuild test -project Rehearse.xcodeproj -scheme Re-Hearse_v1 -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- OemerKit: `bash OemerKit/scripts/verify_mac.sh`

---

## 🔒 Security & Privacy

- Sheet music photos, scans and PDFs are processed on the device and never uploaded.
- Uploads are stored per account inside the app's sandbox; signing in as someone else shows
  that account's uploads only.
- Supabase Row-Level Security isolates each user's rows and storage objects.
- Account deletion (Profile) calls the `delete-account` Edge Function, which removes the user's
  data, including legacy uploads, and the auth account.
- Privacy manifest: `Re-Hearse_v1/PrivacyInfo.xcprivacy`; see `docs/APP_STORE_PRIVACY_AUDIT.md`.

---

## 🐛 Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Upload ends with "We couldn't find any sheet music" | No staff lines recognized (blurry, dark, handwritten, not music) | Retake a sharp, evenly lit photo of printed music |
| First upload after install is slow | Core ML compiles the models on first use | Normal; later uploads are faster |
| Conversion slow in the Simulator | No Neural Engine in the Simulator | Test speed on a device |
| Piano animation stutters | Audio engine timing | Check CPU usage |
| Note detection inaccurate | Poor audio input or FFT thresholds | Test the microphone, adjust thresholds in `PitchDetector` |

---

**End of Project Overview**
