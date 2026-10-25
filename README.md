# OemerKit — sheet music photo → MusicXML, on the iPhone

OemerKit is an on-device port of [oemer](https://github.com/BreezeWhite/oemer) (MIT) for iOS.
Give it a photo of printed sheet music; it returns MusicXML 4.0 plus the position of every
recognized note on the photo. Nothing leaves the device.

- **Neural networks** (oemer's two segmentation models) run through Core ML on the
  **Neural Engine** in 16-bit precision — the most power-efficient way to run them on an iPhone.
- **Everything after the networks** (dewarping, staff lines, noteheads, beams, rhythm,
  accidentals, MusicXML writing) is a pure-Swift reimplementation of oemer's Python code. It
  produces **byte-identical MusicXML** to the Python pipeline on the same model outputs
  (see *Verification*).

Requirements: iOS 16+ (or macOS 13+), Xcode 15+. Physical device recommended (the Neural
Engine is not available in the Simulator).

## Add it to your app

1. Copy the `OemerKit` folder next to your Xcode project (or push it to a git repo).
2. Xcode → *File → Add Package Dependencies… → Add Local…* → select the `OemerKit` folder.
3. Add the **OemerKit** library to your app target.

The package ships its resources (two Core ML models, ~53 MB, and the symbol classifiers,
~4.4 MB). In an Xcode build the models are compiled at build time and loaded straight from
the bundle; with plain `swift build` they are compiled the first time they are used and cached
in *Application Support/OemerKit*.

## Use it

```swift
import OemerKit

let recognizer = try SheetMusicRecognizer()

// Optional, e.g. at app launch: compile/load the models so the first scan is fast.
Task { try? await recognizer.prepare() }

// From a file (JPEG/HEIC/PNG — EXIF orientation is handled):
let result = try await recognizer.recognize(imageAt: photoURL) { progress in
    print("progress", progress)          // 0...1, called from a background thread
}
let musicXML: String = result.musicXML   // hand this to the rest of your app

// Or from a UIImage / CGImage / encoded Data:
let r2 = try await recognizer.recognize(uiImage: image)
let r3 = try await recognizer.recognize(imageData: jpegData)
```

`recognize` is `async`, runs off the main thread and honors task cancellation. One
`SheetMusicRecognizer` can be shared by the whole app (it is safe to call from several tasks;
the models are loaded once).

### Note positions (for labelling the photo)

`result.notes` lists every note written to the MusicXML, in document order:

```swift
for note in result.notes {
    note.name      // "C#4", "Bb3" …
    note.staff     // 1 = top (treble) staff, 2 = bass staff on piano music
    note.type      // "quarter", "eighth", …   note.dotted
    note.rect      // notehead rectangle on the original photo (pixels, origin top-left)
}
```

`result.imageSize` is the upright photo size those rectangles refer to.

### Options

```swift
var config = SheetMusicRecognizer.Configuration()
config.deskew = true                 // default: straighten curved/tilted pages. Best for photos AND scans.
config.computeUnits = .cpuAndNeuralEngine   // default; avoids the GPU, which heats the phone more
config.title = "My Song"             // <work-title> in the MusicXML
let recognizer = try SheetMusicRecognizer(configuration: config)
```

### Errors

`recognize` throws `OMRError.noStaffFound` when no staff lines are detected (not sheet music,
too blurry, too dark), `.imageTooNoisy` when the page produces far more symbol candidates than
any real score (heavy noise, not music), `.inconsistentStaffs` when staffs cannot be aligned,
`.imageDecodingFailed` for unreadable images and `.modelUnavailable` if the bundled models
cannot be loaded. For all but the last, show the user a "try another photo" message.

## Heat and speed

- The networks run tile by tile (512 × 512) on the Neural Engine with small overlaps; each
  pixel takes the prediction of the tile that owns its center region. This is about 2.7× less
  network work per page than oemer's original 256/288-pixel tiles with 50 % overlap, with the
  same accuracy (measured on the test pages below).
- When iOS reports *serious* or *critical* thermal state, OemerKit pauses briefly between
  tile batches instead of running flat out.
- The post-processing is single-threaded Swift: about 2–2.5 s per page in a **Release** build.
- **Build your app in Release when you judge speed or heat.** Xcode compiles Swift packages
  without optimization in the Debug configuration, and this engine is then ~15–20× slower
  (30–45 s of CPU per page), which *will* warm the phone. For device testing set
  *Product → Scheme → Edit Scheme → Run → Build Configuration → Release* (TestFlight/App Store
  builds are always Release).

## Accuracy

Measured on 16 generated test pages (8 piano/melody scores rendered cleanly, and the same 8
as simulated phone photos: perspective, page curl, blur, uneven light, JPEG), comparing the
MusicXML with the known score. *Pitch* = notes/rests with the right pitch, *event* = right
pitch **and** duration (edit-distance alignment per staff):

| pages           | deskew (default) pitch / event | no deskew pitch / event |
|-----------------|-------------------------------:|------------------------:|
| clean           | 0.845 / 0.741                  | 0.838 / 0.753           |
| simulated photo | 0.827 / 0.663                  | 0.645 / 0.565           |

These are oemer's own recognition limits (the Python original scores the same on the same
model outputs). Typical errors: durations of beamed groups, notes on ledger lines, dense chords.

## Test it on a Mac

One command builds everything (macOS and iOS), runs all tests, runs the Core ML self-test and
transcribes the bundled example page:

```bash
bash OemerKit/scripts/verify_mac.sh
```

What it checks and what to expect:

1. `swift build -c release` and an iOS device build with `xcodebuild` — no errors.
2. `swift test` — 19 tests. The 4 *EndToEndTests* run the whole engine on saved
   segmentation maps (tabi with and without deskew, a clean piano page, a photo) and require
   **byte-identical** MusicXML to the Python reference; *RobustnessTests* feed it blank,
   tiny, damaged and noisy inputs and require a clean result or error.
3. `oemer-demo --selftest` — runs both Core ML models on a bundled tile and compares with the
   original TensorFlow output: expect `PASS` (agreement > 99 %).
4. `oemer-demo Examples/tabi.jpg` — full pipeline on oemer's sample page; expect roughly
   340–350 notes, and per-stage timings (model1/model2 = neural networks, the rest = engine).

On an iPhone, call the same self-test once, e.g. from a debug menu:

```swift
let report = try await recognizer.runSelfTest()
print(report)   // e.g. "staff/symbols model 99.9xx%, detail model 99.9xx% agreement — PASS"
```

## Limitations (inherited from oemer)

- Printed Western notation only; handwritten music is not supported.
- Works best on one page per photo, reasonably sharp and evenly lit.
- Output contains notes, rests, chords, accidentals, key signatures, clefs, dots and
  barlines. Time signatures, ties, slurs, dynamics, lyrics and tuplets are not recognized.

## Verification

What has been verified (on Linux with Swift 6.1, since no Mac was available while porting):

- **Engine = Python, byte for byte.** `tools/golden_export.py` runs the original pipeline on
  saved model outputs and dumps every intermediate result; `oemer-check` runs the Swift engine
  on the same inputs; `tools/compare_golden.py` compares staffs, notes, groups, barlines,
  clefs, accidentals, rests and the MusicXML bytes. `tools/parity_suite.sh` does this for
  tabi plus all 16 test pages, with and without deskew: **34/34 cases identical**.
  (Two places where Python itself is non-deterministic — ties broken by hash order or by
  SIMD sort order — are pinned to one deterministic rule in both implementations.)
- **Low-level ports** (OpenCV contours, Hough lines, morphology, remap, scipy labelling and
  peak finding, sklearn clustering, libsvm, Pillow resize, CPython set order, numpy sums):
  unit tests with reference values from the Python libraries (`tools/gen_primitive_tests.py`).
- **Core ML models**: converted with coremltools; FP16 numerics checked against the
  TensorFlow models (99.99 % pixel agreement after replacing LayerNorm by an overflow-safe
  equivalent). The on-device run itself is what `runSelfTest()` / `verify_mac.sh` confirm.
- **Robustness**: the engine was run on 170 degenerate inputs (blank, saturated, 1×1 up to
  page size, very thin strips, crops, rotations, flips, missing or swapped layers, heavy
  noise), each with and without deskew — every case returns a result or throws an `OMRError`
  within seconds; none traps or hangs (`tools/robustness_maps.py`, `robustness_random.py`,
  `robustness_tiny.py`, `tools/wsl/robust.sh`). This found and fixed three crash/hang bugs
  (an endless loop in note grouping, an out-of-memory path in symbol clustering on noisy
  pages, a trap on one-pixel-high images); `RobustnessTests` keeps them covered.
- **Apple layer** (Core ML, image loading, public API, demo) type-checked against stand-ins
  of the Apple frameworks; it has not yet been compiled or run with the real SDK — that is
  step 1 of `verify_mac.sh`.

## Layout

```
OemerKit/
  Sources/OemerCore/     pure Swift recognition engine (also builds on Linux)
  Sources/OemerKit/      Core ML + image loading + public API, bundled models
  Sources/oemer-check/   command-line checker (engine on saved maps, for parity tests)
  Sources/oemer-demo/    macOS command-line demo of the full pipeline + self-test
  Tests/OemerCoreTests/  unit tests and end-to-end fixtures
  Examples/tabi.jpg      oemer's sample page
  scripts/verify_mac.sh  one-command check on a Mac
```

License: MIT (same as oemer). Models and algorithms © oemer authors.
