# Handoff: first run on a Mac

Context for whoever (person or Claude session) picks this package up on the Mac.

## State when it left the Windows PC (2026-10-25)

- `OemerCore` (the pure-Swift engine) is verified on Linux with Swift 6.1: byte-identical MusicXML to
  the Python oemer reference on 34 cases, 19/19 XCTests passing, no traps or hangs on 170
  degenerate inputs.
- `OemerKit` (Core ML, image loading, public API) and `oemer-demo` were only **type-checked
  against hand-written stand-ins** for CoreML, CoreGraphics, ImageIO, CoreImage, CoreVideo,
  Accelerate and UIKit. They have never been compiled with the real SDK, so expect a few small
  compile fixes there (API spellings, optional/CF bridging, Sendable warnings).
- Nothing has run on Apple hardware yet: Core ML predictions, the Neural Engine, speed and
  heat are all untested.

## What to run

```bash
bash scripts/verify_mac.sh
```

Steps and expected results are in README.md under *Test it on a Mac*.

## Rules for fixing things

- Compile errors in `Sources/OemerKit` or `Sources/oemer-demo`: fix freely; that code was never
  built for real.
- Do **not** change behaviour in `Sources/OemerCore` to make something pass. Its output must stay
  byte-identical to the Python reference. The 4 `EndToEndTests` (fixtures in
  `Tests/OemerCoreTests/Fixtures`) enforce that on the Mac, where the Python reference is not
  available.
- If an `EndToEndTests` case differs on the Mac only, suspect a platform math difference
  (Darwin `exp`/`log`/`pow` vs glibc in the last bit) before suspecting the logic, and report the
  first differing line.
- `swift test` in Debug is slow (the engine is ~15–20x slower unoptimised); prefer
  `swift test -c release -Xswiftc -enable-testing`.
- Judge iPhone speed and heat only in Release builds.
