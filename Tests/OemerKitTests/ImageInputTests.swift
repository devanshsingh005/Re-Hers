#if canImport(CoreML)
import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import OemerKit
#if canImport(UIKit)
import UIKit
#endif

/// Photos as cameras deliver them: every EXIF orientation (portrait iPhone photos are stored
/// sideways with orientation 6), HEIC, ~48 MP, and the CGImage/UIImage entry points. Each must
/// prepare the same upright image for the models as the upright original.
///
/// The sideways test images are made by an explicit pixel loop from the EXIF definition, not by
/// Core Image or ImageIO, so the code under test is not checked against itself.
final class ImageInputTests: XCTestCase {
    /// RGBA8 pixels, row-major.
    struct Pixels {
        var width: Int
        var height: Int
        var data: [UInt8]
    }

    static let packageDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // OemerKitTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()

    /// Files written here are left for manual runs (e.g. oemer-demo on the 48 MP portrait).
    static let outDir: URL = {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("OemerKitImageInputs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let upright: Pixels? = {
        guard let data = try? Data(contentsOf: packageDir.appendingPathComponent("Examples/tabi.jpg")),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return pixels(of: image)
    }()

    // MARK: - Orientation

    /// Every EXIF orientation through the file/data path (ImageIO), lossless.
    func testEveryExifOrientationFromData() throws {
        let up = try XCTUnwrap(Self.upright)
        let expected = try ImagePreparation.load(data: Self.encode(up, orientation: 1, type: "public.tiff"))
        for o in 2...8 {
            let data = try Self.encode(Self.stored(up, orientation: o), orientation: o, type: "public.tiff")
            assertSame(try ImagePreparation.load(data: data), expected, "TIFF data, EXIF \(o)", lossy: false)
        }
        try assertDetectsWrongOrientation(expected) { p in
            try ImagePreparation.load(data: Self.encode(p, orientation: 1, type: "public.tiff"))
        }
    }

    /// Every orientation through recognize(cgImage:orientation:) (Core Image path).
    func testEveryOrientationFromCGImage() throws {
        let up = try XCTUnwrap(Self.upright)
        let expected = try ImagePreparation.prepare(Self.image(up), orientation: .up)
        for o in 2...8 {
            let orientation = try XCTUnwrap(CGImagePropertyOrientation(rawValue: UInt32(o)))
            let got = try ImagePreparation.prepare(Self.image(Self.stored(up, orientation: o)), orientation: orientation)
            assertSame(got, expected, "CGImage, orientation \(o)", lossy: false)
        }
        try assertDetectsWrongOrientation(expected) { p in try ImagePreparation.prepare(Self.image(p), orientation: .up) }
    }

    /// A portrait iPhone photo: stored sideways with orientation 6, as JPEG and HEIC files.
    func testPortraitPhotoJPEGAndHEIC() throws {
        let up = try XCTUnwrap(Self.upright)
        let sideways = Self.stored(up, orientation: 6)
        for (type, ext) in [("public.jpeg", "jpg"), ("public.heic", "heic")] {
            let expected = try ImagePreparation.load(data: Self.encode(up, orientation: 1, type: type))
            let url = Self.outDir.appendingPathComponent("tabi-portrait.\(ext)")
            try Self.encode(sideways, orientation: 6, type: type).write(to: url)
            assertSame(try ImagePreparation.load(url: url), expected, "\(ext) file, EXIF 6", lossy: true)
        }
    }

    // MARK: - Large photos

    /// A ~48 MP portrait photo (current iPhone main camera) as HEIC and JPEG files, read by the
    /// file path and, fully decoded, by the CGImage path.
    func test48MegapixelPortrait() throws {
        let up = try XCTUnwrap(Self.upright)
        let big = Self.resized(up, width: 6800, height: 7039)  // 47.9 MP
        let sideways = Self.stored(big, orientation: 6)
        let target = ImagePreparation.targetSize(width: big.width, height: big.height)
        let expectedCG = try ImagePreparation.prepare(Self.image(big), orientation: .up)
        for (type, ext) in [("public.heic", "heic"), ("public.jpeg", "jpg")] {
            let uprightURL = Self.outDir.appendingPathComponent("big-upright.\(ext)")
            let portraitURL = Self.outDir.appendingPathComponent("big-portrait.\(ext)")
            try Self.encode(big, orientation: 1, type: type).write(to: uprightURL)
            try Self.encode(sideways, orientation: 6, type: type).write(to: portraitURL)
            let size = (try FileManager.default.attributesOfItem(atPath: portraitURL.path)[.size] as? Int) ?? 0

            let expected = try ImagePreparation.load(url: uprightURL)
            var t = Date()
            let got = try ImagePreparation.load(url: portraitURL)
            let fileTime = Date().timeIntervalSince(t)
            XCTAssertEqual(got.width, target.width)
            XCTAssertEqual(got.height, target.height)
            assertSame(got, expected, "48 MP \(ext) file, EXIF 6", lossy: true)

            // what recognize(uiImage:) does with a camera image: full decode, then orient
            t = Date()
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(portraitURL as CFURL, nil))
            let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let viaCG = try ImagePreparation.prepare(decoded, orientation: .right)
            let cgTime = Date().timeIntervalSince(t)
            assertSame(viaCG, expectedCG, "48 MP \(ext) decoded, CGImage .right", lossy: true)
            print(String(format: "48 MP %@ (%.1f MB): file path %.2fs, CGImage path %.2fs; %@", ext,
                         Double(size) / 1_048_576, fileTime, cgTime, Self.memory))
        }
    }

    // MARK: - End to end

    /// The whole public path for a portrait photo from the library (PhotosPicker gives Data):
    /// same notes, at the same places on the photo, as for the upright photo.
    func testRecognizePortraitPhotoData() async throws {
        let up = try XCTUnwrap(Self.upright)
        let recognizer = try SheetMusicRecognizer()
        let a = try await recognizer.recognize(imageData: Self.encode(up, orientation: 1, type: "public.tiff"))
        let b = try await recognizer.recognize(imageData: Self.encode(Self.stored(up, orientation: 6), orientation: 6, type: "public.tiff"))
        assertSameNotes(b, a, "recognize(imageData:) EXIF 6")
    }

    #if canImport(UIKit)
    static let uiOrientations: [(UIImage.Orientation, Int, String)] = [
        (.up, 1, "up"), (.upMirrored, 2, "upMirrored"), (.down, 3, "down"), (.downMirrored, 4, "downMirrored"),
        (.leftMirrored, 5, "leftMirrored"), (.right, 6, "right"), (.rightMirrored, 7, "rightMirrored"), (.left, 8, "left"),
    ]

    /// recognize(uiImage:) maps UIImage.Orientation to the EXIF orientation; check all eight.
    func testEveryUIImageOrientation() throws {
        let up = try XCTUnwrap(Self.upright)
        let expected = try ImagePreparation.prepare(Self.image(up), orientation: .up)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        for (orientation, exif, name) in Self.uiOrientations {
            let image = UIImage(cgImage: Self.image(Self.stored(up, orientation: exif)), scale: 1, orientation: orientation)
            // UIKit itself must draw the test image upright, which checks the test image
            let drawn = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in image.draw(at: .zero) }
            let shown = try ImagePreparation.prepare(XCTUnwrap(drawn.cgImage), orientation: .up)
            assertSame(shown, expected, "UIKit draws .\(name)", lossy: false)

            let cg = try XCTUnwrap(image.cgImage)
            let got = try ImagePreparation.prepare(cg, orientation: CGImagePropertyOrientation(image.imageOrientation))
            assertSame(got, expected, "UIImage .\(name)", lossy: false)
        }
    }

    /// The whole public path for a camera UIImage (portrait: .right).
    func testRecognizePortraitUIImage() async throws {
        let up = try XCTUnwrap(Self.upright)
        let recognizer = try SheetMusicRecognizer()
        let a = try await recognizer.recognize(cgImage: Self.image(up))
        let portrait = UIImage(cgImage: Self.image(Self.stored(up, orientation: 6)), scale: 1, orientation: .right)
        let b = try await recognizer.recognize(uiImage: portrait)
        assertSameNotes(b, a, "recognize(uiImage:) .right")
    }
    #endif

    // MARK: - Checks

    /// Lossless inputs must give (nearly) the same pixels; lossy ones differ by compression noise.
    func assertSame(_ got: PreparedImage, _ expected: PreparedImage, _ label: String, lossy: Bool,
                    file: StaticString = #filePath, line: UInt = #line)
    {
        XCTAssertEqual(got.originalWidth, expected.originalWidth, label, file: file, line: line)
        XCTAssertEqual(got.originalHeight, expected.originalHeight, label, file: file, line: line)
        XCTAssertEqual(got.width, expected.width, label, file: file, line: line)
        XCTAssertEqual(got.height, expected.height, label, file: file, line: line)
        guard got.pixels.count == expected.pixels.count else { return }
        let d = Self.difference(got, expected)
        print(String(format: "%@: mean diff %.3f, pixels off by >64: %.4f%%", label, d.mean, d.outliers * 100))
        XCTAssertLessThan(d.mean, lossy ? 2 : 0.5, label, file: file, line: line)
        XCTAssertLessThan(d.outliers, lossy ? 0.005 : 0.001, label, file: file, line: line)
    }

    /// The pixel check must catch a page that is upside down or mirrored but the same size.
    func assertDetectsWrongOrientation(_ expected: PreparedImage, _ prepare: (Pixels) throws -> PreparedImage) throws {
        let up = try XCTUnwrap(Self.upright)
        for o in [2, 3] {
            let d = Self.difference(try prepare(Self.stored(up, orientation: o)), expected)
            print(String(format: "control, EXIF %d pixels left untransformed: mean diff %.3f, pixels off by >64: %.4f%%",
                         o, d.mean, d.outliers * 100))
            XCTAssertGreaterThan(d.mean, 5, "wrong orientation \(o) not detected")
        }
    }

    func assertSameNotes(_ got: SheetMusicResult, _ expected: SheetMusicResult, _ label: String,
                         file: StaticString = #filePath, line: UInt = #line)
    {
        XCTAssertEqual(got.imageSize, expected.imageSize, label, file: file, line: line)
        // every expected note must be found with the same name within 3 px on the photo
        var unmatched = 0
        for n in expected.notes {
            let hit = got.notes.contains {
                $0.name == n.name && abs($0.rect.midX - n.rect.midX) <= 3 && abs($0.rect.midY - n.rect.midY) <= 3
            }
            if !hit { unmatched += 1 }
        }
        print("\(label): \(got.notes.count) notes vs \(expected.notes.count) upright, \(unmatched) upright notes not matched")
        XCTAssertLessThanOrEqual(abs(got.notes.count - expected.notes.count), expected.notes.count / 100, label, file: file, line: line)
        XCTAssertLessThanOrEqual(unmatched, expected.notes.count / 100, label, file: file, line: line)
    }

    // MARK: - Test images

    /// The pixels a camera stores with EXIF `orientation` so that the photo shows `p` upright.
    static func stored(_ p: Pixels, orientation o: Int) -> Pixels {
        let W = p.width, H = p.height
        let ws = o >= 5 ? H : W, hs = o >= 5 ? W : H
        var out = [UInt8](repeating: 0, count: ws * hs * 4)
        p.data.withUnsafeBufferPointer { src in
            out.withUnsafeMutableBufferPointer { dst in
                for r in 0..<hs {
                    for c in 0..<ws {
                        // EXIF: which side of the upright picture stored row 0 and column 0 are on
                        let x: Int, y: Int
                        switch o {
                        case 2: (x, y) = (W - 1 - c, r)          // row 0 top, column 0 right
                        case 3: (x, y) = (W - 1 - c, H - 1 - r)  // bottom, right
                        case 4: (x, y) = (c, H - 1 - r)          // bottom, left
                        case 5: (x, y) = (r, c)                  // left, top
                        case 6: (x, y) = (W - 1 - r, c)          // right, top
                        case 7: (x, y) = (W - 1 - r, H - 1 - c)  // right, bottom
                        case 8: (x, y) = (r, H - 1 - c)          // left, bottom
                        default: (x, y) = (c, r)
                        }
                        let s = (y * W + x) * 4, d = (r * ws + c) * 4
                        dst[d] = src[s]
                        dst[d + 1] = src[s + 1]
                        dst[d + 2] = src[s + 2]
                        dst[d + 3] = src[s + 3]
                    }
                }
            }
        }
        return Pixels(width: ws, height: hs, data: out)
    }

    static let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

    static func pixels(of image: CGImage, width: Int? = nil, height: Int? = nil) -> Pixels {
        let w = width ?? image.width, h = height ?? image.height
        var data = [UInt8](repeating: 255, count: w * h * 4)
        data.withUnsafeMutableBytes { buf in
            let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: srgb, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return Pixels(width: w, height: h, data: data)
    }

    static func resized(_ p: Pixels, width: Int, height: Int) -> Pixels {
        pixels(of: image(p), width: width, height: height)
    }

    static func image(_ p: Pixels) -> CGImage {
        let provider = CGDataProvider(data: Data(p.data) as CFData)!
        return CGImage(width: p.width, height: p.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: p.width * 4,
                       space: srgb, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }

    static func encode(_ p: Pixels, orientation: Int, type: String, quality: Double = 0.9) throws -> Data {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, type as CFString, 1, nil) else {
            throw XCTSkip("\(type) encoding is not available here")
        }
        let props: [CFString: Any] = [kCGImagePropertyOrientation: orientation,
                                      kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, image(p), props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw XCTSkip("\(type) encoding failed here") }
        return data as Data
    }

    /// Mean absolute difference per channel (0...255) and the share of pixels off by more than 64.
    static func difference(_ a: PreparedImage, _ b: PreparedImage) -> (mean: Double, outliers: Double) {
        precondition(a.pixels.count == b.pixels.count)
        var sum = 0, outliers = 0
        a.pixels.withUnsafeBufferPointer { pa in
            b.pixels.withUnsafeBufferPointer { pb in
                for i in stride(from: 0, to: pa.count, by: 4) {
                    let d0 = abs(Int(pa[i]) - Int(pb[i]))
                    let d1 = abs(Int(pa[i + 1]) - Int(pb[i + 1]))
                    let d2 = abs(Int(pa[i + 2]) - Int(pb[i + 2]))
                    sum += d0 + d1 + d2
                    if max(d0, d1, d2) > 64 { outliers += 1 }
                }
            }
        }
        let n = a.pixels.count / 4
        return (Double(sum) / Double(n * 3), Double(outliers) / Double(n))
    }

    /// Current and peak memory footprint of the test process.
    static var memory: String {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return "memory n/a" }
        return String(format: "process memory %.0f MB, peak %.0f MB", Double(info.phys_footprint) / 1_048_576,
                      Double(info.ledger_phys_footprint_peak) / 1_048_576)
    }
}
#endif
