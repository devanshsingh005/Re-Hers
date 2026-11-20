#!/bin/bash
# One-command check on a Mac (Xcode 15+, Apple Silicon recommended). Run from anywhere:
#
#   bash OemerKit/scripts/verify_mac.sh
#
# 1. builds the package for macOS (release) and for iOS (device),
# 2. runs the unit tests and the end-to-end tests (engine output must be byte-identical
#    to the Python reference on the bundled fixtures),
# 3. runs the Core ML self-test (both models vs. the original TensorFlow output),
# 4. transcribes Examples/tabi.jpg with the full pipeline and prints timings.
set -u
cd "$(dirname "$0")/.."
fail=0
step() { printf '\n=== %s\n' "$1"; }
check() { if [ "$1" -eq 0 ]; then echo "--- OK: $2"; else echo "--- FAILED: $2"; fail=1; fi; }

step "macOS release build"
swift build -c release
check $? "macOS build"

step "iOS device build"
if xcodebuild -version > /dev/null 2>&1; then
  xcodebuild -scheme OemerKit -destination 'generic/platform=iOS' -derivedDataPath .build/ios build -quiet
  check $? "iOS build"
else
  echo "xcodebuild not available (install Xcode, then: sudo xcode-select -s /Applications/Xcode.app)"; fail=1
fi

step "unit + end-to-end tests"
swift test -c release -Xswiftc -enable-testing
check $? "tests"

step "Core ML self-test"
swift run -c release oemer-demo --selftest
check $? "self-test"

step "full pipeline on Examples/tabi.jpg"
out="${TMPDIR:-/tmp}/oemerkit-tabi.musicxml"
swift run -c release oemer-demo Examples/tabi.jpg "$out" --repeat 2
check $? "demo"

echo
if [ $fail -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED (see above)"; fi
exit $fail
