import Foundation
import XCTest
@testable import OemerCore

/// End-to-end regression: the engine run on saved segmentation maps must reproduce the Python
/// reference MusicXML byte for byte. Fixtures are written by tools/pack_fixture.py.
final class EndToEndTests: XCTestCase {
    /// The OemerKit package folder (override with OEMER_PACKAGE_DIR when the tests are built
    /// outside SwiftPM).
    static var packageDir: URL {
        if let p = ProcessInfo.processInfo.environment["OEMER_PACKAGE_DIR"] { return URL(fileURLWithPath: p) }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // OemerCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()
    }

    static let classifiers: SymbolClassifiers? = try? SymbolClassifiers(data: Data(contentsOf:
        packageDir.appendingPathComponent("Sources/OemerKit/Resources/classifiers.bin")))

    func testTabiNoDeskew() throws { try check("tabi_nodeskew") }
    func testTabiDeskew() throws { try check("tabi_deskew") }
    func testCleanPianoNoDeskew() throws { try check("clean_piano_nodeskew") }
    func testPhotoPianoDeskew() throws { try check("photo_piano_deskew") }

    private func check(_ name: String) throws {
        let dir = Self.packageDir.appendingPathComponent("Tests/OemerCoreTests/Fixtures")
        let (maps, deskew) = try Self.loadMaps(dir.appendingPathComponent("\(name).omrmaps"))
        let expected = try String(contentsOf: dir.appendingPathComponent("\(name).musicxml"), encoding: .utf8)
        let classifiers = try XCTUnwrap(Self.classifiers, "classifiers.bin not found")
        let result = try OMREngine.transcribe(maps, classifiers: classifiers, options: OMROptions(deskew: deskew))
        if result.musicXML != expected {
            let a = result.musicXML.split(separator: "\n", omittingEmptySubsequences: false)
            let b = expected.split(separator: "\n", omittingEmptySubsequences: false)
            let line = (0..<min(a.count, b.count)).first { a[$0] != b[$0] } ?? min(a.count, b.count)
            XCTFail("\(name): MusicXML differs from the reference at line \(line + 1): got "
                + "\(line < a.count ? String(a[line]) : "<end>") expected \(line < b.count ? String(b[line]) : "<end>")")
        }
    }

    /// Reads a run-length coded .omrmaps file (see tools/pack_fixture.py).
    static func loadMaps(_ url: URL) throws -> (SegmentationMaps, deskew: Bool) {
        let bytes = [UInt8](try Data(contentsOf: url))
        var pos = 0
        func u32() throws -> Int {
            guard pos + 4 <= bytes.count else { throw OMRError.badClassifierData }
            defer { pos += 4 }
            return Int(bytes[pos]) | Int(bytes[pos + 1]) << 8 | Int(bytes[pos + 2]) << 16 | Int(bytes[pos + 3]) << 24
        }
        func varint() throws -> Int {
            var v = 0, shift = 0
            while true {
                guard pos < bytes.count else { throw OMRError.badClassifierData }
                let b = bytes[pos]
                pos += 1
                v |= Int(b & 0x7F) << shift
                if b < 0x80 { return v }
                shift += 7
            }
        }
        guard bytes.count >= 8, String(decoding: bytes[0..<8], as: UTF8.self) == "OMRMAPS1" else {
            throw OMRError.badClassifierData
        }
        pos = 8
        let w = try u32(), h = try u32(), flags = try u32()
        var masks: [Mask] = []
        for _ in 0..<5 {
            var m = Mask.zeros(width: w, height: h)
            let n = try u32()
            var p = 0
            for r in 0..<n {
                let len = try varint()
                if r % 2 == 1 { for i in p..<(p + len) { m.data[i] = 1 } }
                p += len
            }
            guard p == w * h else { throw OMRError.badClassifierData }
            masks.append(m)
        }
        return (SegmentationMaps(staff: masks[0], symbols: masks[1], stemsRests: masks[2],
                                 notehead: masks[3], clefsKeys: masks[4]), flags & 1 == 1)
    }
}
