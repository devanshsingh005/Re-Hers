import Foundation
import OemerCore

// Command-line checker: runs the Swift engine on saved segmentation maps (PGM files written
// by tools/golden_export.py) so results can be compared with the Python reference.
//
//   oemer-check <maps_dir> <classifiers.bin> <out_dir> [--deskew] [--repeat N]

func readPGM(_ path: String) throws -> Mask {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    var tokens: [String] = []
    var idx = data.startIndex
    while tokens.count < 4 {
        while idx < data.endIndex, data[idx] == 0x20 || data[idx] == 0x0A || data[idx] == 0x0D || data[idx] == 0x09 { idx += 1 }
        var tok = ""
        while idx < data.endIndex, !(data[idx] == 0x20 || data[idx] == 0x0A || data[idx] == 0x0D || data[idx] == 0x09) {
            tok.append(Character(UnicodeScalar(data[idx])))
            idx += 1
        }
        tokens.append(tok)
    }
    idx += 1  // single whitespace after maxval
    guard tokens[0] == "P5", let w = Int(tokens[1]), let h = Int(tokens[2]) else {
        throw NSError(domain: "pgm", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad PGM \(path)"])
    }
    let bytes = [UInt8](data[idx..<(idx + w * h)])
    return Mask(width: w, height: h, data: bytes.map { $0 > 0 ? 1 : 0 })
}

let args = CommandLine.arguments

// oemer-check --pyset <vectors.json>: verify the CPython set emulation (single-module dev builds only)
#if OEMER_DEV_CHECKS
if args.count == 3 && args[1] == "--pyset" {
    let data = try! Data(contentsOf: URL(fileURLWithPath: args[2]))
    let cases = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
    var failures = 0
    for (i, c) in cases.enumerated() {
        let vals = c["vals"] as! [Int]
        var s = PySet(vals)
        for d in c["discards"] as! [Int] { s.discard(d) }
        let other = PySet(c["other"] as! [Int])
        var u = PySet()
        u.update(s)
        u.update(other)
        var p = PySet()
        p.update(s)
        var pops: [Int] = []
        while let v = p.pop() { pops.append(v) }
        let checks: [(String, [Int], [Int])] = [
            ("order", s.elements, c["order"] as! [Int]),
            ("inter", s.intersection(other).elements, c["inter"] as! [Int]),
            ("update", u.elements, c["update"] as! [Int]),
            ("pops", pops, c["pops"] as! [Int]),
        ]
        for (name, got, want) in checks where got != want {
            failures += 1
            if failures <= 5 { print("case \(i) \(name): got \(got.prefix(12)) want \(want.prefix(12))") }
        }
    }
    print("pyset: \(cases.count) cases, \(failures) mismatches")
    exit(failures == 0 ? 0 : 1)
}
#endif

guard args.count >= 4 else {
    print("usage: oemer-check <maps_dir> <classifiers.bin> <out_dir> [--deskew] [--repeat N]")
    exit(2)
}
let mapsDir = args[1], svmPath = args[2], outDir = args[3]
let deskew = args.contains("--deskew")
var repeatCount = 1
if let i = args.firstIndex(of: "--repeat"), i + 1 < args.count { repeatCount = Int(args[i + 1]) ?? 1 }

do {
    let t0 = Date()
    let maps = SegmentationMaps(
        staff: try readPGM("\(mapsDir)/staff.pgm"),
        symbols: try readPGM("\(mapsDir)/symbols.pgm"),
        stemsRests: try readPGM("\(mapsDir)/stems_rests.pgm"),
        notehead: try readPGM("\(mapsDir)/notehead.pgm"),
        clefsKeys: try readPGM("\(mapsDir)/clefs_keys.pgm"))
    let classifiers = try SymbolClassifiers(data: try Data(contentsOf: URL(fileURLWithPath: svmPath)))
    print(String(format: "loaded %dx%d maps in %.2fs", maps.width, maps.height, Date().timeIntervalSince(t0)))

    var result: OMRResult? = nil
    for _ in 0..<repeatCount {
        let t1 = Date()
        result = try OMREngine.transcribe(maps, classifiers: classifiers, options: OMROptions(deskew: deskew), debug: true)
        let stages = result!.timings.map { String(format: "%@ %.2fs", $0.stage, $0.seconds) }.joined(separator: ", ")
        print(String(format: "transcribed in %.2fs (%@)", Date().timeIntervalSince(t1), stages))
    }
    try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    try result!.musicXML.write(toFile: "\(outDir)/swift.musicxml", atomically: true, encoding: .utf8)
    try result!.debugJSON!.write(toFile: "\(outDir)/swift.json", atomically: true, encoding: .utf8)
    print("notes written: \(result!.notes.count)")
} catch {
    print("error: \(error)")
    exit(1)
}
