# OemerTestApp

Minimal iOS app for checking OemerKit on a device: Core ML self-test, timed transcriptions of the
bundled `tabi.jpg` (per-stage timings, thermal state, memory footprint), and a photo picker for
your own pages. It links the package through a local reference (`../..`), so it always builds
the current sources.

## Run it

Open `OemerTestApp.xcodeproj`, pick your iPhone, set your team under *Signing & Capabilities*
(change the bundle identifier if Xcode says it is taken) and press Run. The shared scheme builds
**Release** and passes `-autorun`, so the self-test and 3 transcriptions start at once; the
output appears on screen and in the Xcode console, and is saved to `Documents/report.txt`
(share button). Change the count with `-repeat N` in *Edit Scheme → Run → Arguments*.

From the command line (Simulator):

```bash
xcodebuild -project OemerTestApp.xcodeproj -scheme OemerTestApp -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ../../.build/testapp build
xcrun simctl install booted ../../.build/testapp/Build/Products/Release-iphonesimulator/OemerTestApp.app
xcrun simctl launch --console-pty booted dev.oemerkit.OemerTestApp -autorun -repeat 3
```

The Simulator has no Neural Engine: Core ML runs on the Mac's CPU there, so its timings, thermal
state and memory headroom say nothing about a phone. Use it to check that everything works;
judge speed and heat on a device.
