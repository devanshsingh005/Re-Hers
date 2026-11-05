import Foundation
import XCTest
@testable import OemerCore

/// Inputs a random user photo can produce. The engine must never trap or hang on them: it
/// either returns a result or throws an `OMRError` (tools/robustness_maps.py and
/// tools/robustness_random.py run hundreds more of these against the release build).
final class RobustnessTests: XCTestCase {
    static let classifiers: SymbolClassifiers? = try? SymbolClassifiers(data: Data(contentsOf:
        EndToEndTests.packageDir.appendingPathComponent("Sources/OemerKit/Resources/classifiers.bin")))

    private func run(_ maps: SegmentationMaps, deskew: Bool) throws -> Result<OMRResult, OMRError> {
        let classifiers = try XCTUnwrap(Self.classifiers, "classifiers.bin not found")
        do {
            return .success(try OMREngine.transcribe(maps, classifiers: classifiers, options: OMROptions(deskew: deskew)))
        } catch let e as OMRError {
            return .failure(e)
        }
    }

    private func uniform(width: Int, height: Int, value: UInt8) -> SegmentationMaps {
        let m = Mask(width: width, height: height, repeating: value)
        return SegmentationMaps(staff: m, symbols: m, stemsRests: m, notehead: m, clefsKeys: m)
    }

    private func tabi() throws -> SegmentationMaps {
        let dir = EndToEndTests.packageDir.appendingPathComponent("Tests/OemerCoreTests/Fixtures")
        return try EndToEndTests.loadMaps(dir.appendingPathComponent("tabi_nodeskew.omrmaps")).0
    }

    func testBlankImageThrowsNoStaff() throws {
        for deskew in [false, true] {
            guard case .failure(.noStaffFound) = try run(uniform(width: 800, height: 1100, value: 0), deskew: deskew) else {
                return XCTFail("blank page (deskew \(deskew)) should throw noStaffFound")
            }
        }
    }

    func testTinyAndSaturatedImagesDoNotTrap() throws {
        for (w, h, v) in [(1, 1, UInt8(0)), (1, 1, 1), (8, 8, 1), (64, 64, 0), (64, 64, 1), (300, 40, 1)] {
            for deskew in [false, true] {
                _ = try run(uniform(width: w, height: h, value: v), deskew: deskew)
            }
        }
    }

    /// A note whose center lies outside its own stem group used to send note-group extraction
    /// into an endless loop (tabi with the stems layer removed, deskewed).
    func testMissingStemsLayerFinishes() throws {
        var maps = try tabi()
        maps.stemsRests = Mask.zeros(width: maps.width, height: maps.height)
        guard case .success(let r) = try run(maps, deskew: true) else { return XCTFail("should transcribe") }
        XCTAssertGreaterThan(r.notes.count, 0)
    }

    /// Heavy pixel noise makes tens of thousands of symbol candidates; the quadratic clustering
    /// steps must refuse them instead of allocating gigabytes.
    func testNoisyPageThrowsTooNoisy() throws {
        var maps = try tabi()
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func flip(_ m: inout Mask) {
            for i in 0..<m.data.count {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                if (seed >> 33) % 50 == 0 { m.data[i] ^= 1 }  // 2 %
            }
        }
        flip(&maps.staff); flip(&maps.symbols); flip(&maps.stemsRests); flip(&maps.notehead); flip(&maps.clefsKeys)
        for deskew in [false, true] {
            guard case .failure(.imageTooNoisy) = try run(maps, deskew: deskew) else {
                return XCTFail("noisy page (deskew \(deskew)) should throw imageTooNoisy")
            }
        }
    }
}
