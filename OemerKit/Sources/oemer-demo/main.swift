import Foundation
#if canImport(CoreML)
import OemerKit

// Command-line demo for macOS (Apple Silicon recommended): runs the full on-device pipeline —
// image loading, both Core ML models, the Swift engine — on an image file.
//
//   swift run -c release oemer-demo <image> [output.musicxml] [--no-deskew] [--gpu] [--repeat N]
//   swift run -c release oemer-demo --selftest
//
// Writes the MusicXML (default: next to the image) and prints timings and the recognized notes.

let args = Array(CommandLine.arguments.dropFirst())

func usage() -> Never {
    print("usage: oemer-demo <image> [output.musicxml] [--no-deskew] [--gpu] [--repeat N]\n       oemer-demo --selftest")
    exit(2)
}

var config = SheetMusicRecognizer.Configuration()
if args.contains("--no-deskew") { config.deskew = false }
if args.contains("--gpu") { config.computeUnits = .all }
var repeats = 1
if let i = args.firstIndex(of: "--repeat"), i + 1 < args.count, let n = Int(args[i + 1]) { repeats = max(1, n) }

do {
    let recognizer = try SheetMusicRecognizer(configuration: config)
    let t0 = Date()
    try await recognizer.prepare()
    print(String(format: "models ready in %.2fs (first run compiles them; later runs use the cache)", Date().timeIntervalSince(t0)))

    if args.contains("--selftest") {
        let report = try await recognizer.runSelfTest()
        print(report)
        exit(report.passed ? 0 : 1)
    }

    let positional = args.filter { !$0.hasPrefix("--") && Int($0) == nil }
    guard let imagePath = positional.first else { usage() }
    let imageURL = URL(fileURLWithPath: imagePath)
    let outURL = positional.count > 1
        ? URL(fileURLWithPath: positional[1])
        : imageURL.deletingPathExtension().appendingPathExtension("musicxml")

    var result: SheetMusicResult? = nil
    for run in 1...repeats {
        let t = Date()
        result = try await recognizer.recognize(imageAt: imageURL)
        let stages = result!.timings.sorted { $0.key < $1.key }.map { String(format: "%@ %.2fs", $0.key, $0.value) }
        print(String(format: "run %d: %.2fs total  [%@]", run, Date().timeIntervalSince(t), stages.joined(separator: ", ")))
    }
    let r = result!
    try r.musicXML.write(to: outURL, atomically: true, encoding: .utf8)
    print("image \(Int(r.imageSize.width))x\(Int(r.imageSize.height)), \(r.notes.count) notes -> \(outURL.path)")
    for (i, n) in r.notes.prefix(40).enumerated() {
        print(String(format: "%3d  staff %d  %-4@ %-8@ at (%.0f, %.0f)", i + 1, n.staff, n.name as NSString,
                     (n.type + (n.dotted ? "." : "")) as NSString, n.rect.midX, n.rect.midY))
    }
    if r.notes.count > 40 { print("... \(r.notes.count - 40) more") }
} catch {
    print("error: \(error)")
    exit(1)
}
#else
print("oemer-demo needs Core ML (macOS); on other platforms use oemer-check.")
exit(2)
#endif
