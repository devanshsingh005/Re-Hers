#if canImport(CoreML)
import CoreGraphics
import CoreML
import Foundation
import ImageIO
import OemerCore
#if canImport(UIKit)
import UIKit
#endif

/// A recognized note with its position on the photo you passed in.
public struct LocatedNote: Sendable {
    /// e.g. "C#4", "Bb3"
    public let name: String
    /// "C"..."B"
    public let step: String
    /// -1 flat, 0 natural, +1 sharp
    public let alter: Int
    public let octave: Int
    /// 1-based staff within the system (1 = top/treble staff on piano music).
    public let staff: Int
    /// MusicXML note type: "whole", "half", "quarter", "eighth", "16th", "32nd", "64th".
    public let type: String
    public let dotted: Bool
    /// Notehead rectangle in the upright original image, in pixels (origin top-left).
    public let rect: CGRect
    /// 0-based system on the page (top to bottom); `staff` counts within it.
    public let system: Int
    /// This note's staff at the note: top of its first line, bottom of its last line, and the
    /// distance between lines, in pixels of the upright original image. Use them to place
    /// marks relative to the staff (e.g. note names a fixed distance below it).
    public let staffTop: Double
    public let staffBottom: Double
    public let staffSpace: Double
}

public struct SheetMusicResult: Sendable {
    /// MusicXML 4.0 (partwise) — the same format the oemer command line writes.
    public let musicXML: String
    /// Notes in MusicXML order, with their positions on the photo.
    public let notes: [LocatedNote]
    /// Size of the upright original image in pixels.
    public let imageSize: CGSize
    /// Seconds per stage ("prepare", "model1", "model2", "dewarp", "staffs", ...).
    public let timings: [String: Double]
}

/// Photo of sheet music -> MusicXML, entirely on device.
///
/// ```swift
/// let recognizer = try SheetMusicRecognizer()
/// try await recognizer.prepare()              // optional: warm up at app launch
/// let result = try await recognizer.recognize(imageAt: photoURL)
/// let xml = result.musicXML
/// ```
public final class SheetMusicRecognizer: @unchecked Sendable {
    public struct Configuration: Sendable {
        /// Neural Engine + CPU by default: the most power-efficient choice (the GPU heats the phone more).
        public var computeUnits: MLComputeUnits = .cpuAndNeuralEngine
        /// Straighten curved or tilted pages (recommended for camera photos).
        public var deskew: Bool = true
        /// Overlap between neighbouring model tiles, in pixels.
        public var tileOverlap: Int = 64
        public var stitching: TileStitching = .centerCrop
        /// Title written into the MusicXML.
        public var title: String = "Score"

        public init() {}
    }

    public let configuration: Configuration
    private let classifiers: SymbolClassifiers
    private let modelCache = ModelCache()

    public init(configuration: Configuration = Configuration()) throws {
        self.configuration = configuration
        guard let url = Bundle.module.url(forResource: "classifiers", withExtension: "bin") else {
            throw OMRError.badClassifierData
        }
        classifiers = try SymbolClassifiers(data: try Data(contentsOf: url))
    }

    /// Compiles (first launch only) and loads both models. Call early to avoid a delay on the
    /// first recognition; it is also done automatically when needed.
    public func prepare() async throws {
        _ = try await models()
    }

    private func models() async throws -> (SegmentationModel, SegmentationModel) {
        try await modelCache.models(computeUnits: configuration.computeUnits)
    }

    /// Recognizes an image file (JPEG/HEIC/PNG...). EXIF orientation is applied.
    public func recognize(imageAt url: URL, progress: (@Sendable (Double) -> Void)? = nil) async throws -> SheetMusicResult {
        let t0 = Date()
        let image = try ImagePreparation.load(url: url)
        return try await run(image, prepareTime: Date().timeIntervalSince(t0), progress: progress)
    }

    /// Recognizes encoded image data (JPEG/HEIC/PNG...). EXIF orientation is applied.
    public func recognize(imageData: Data, progress: (@Sendable (Double) -> Void)? = nil) async throws -> SheetMusicResult {
        let t0 = Date()
        let image = try ImagePreparation.load(data: imageData)
        return try await run(image, prepareTime: Date().timeIntervalSince(t0), progress: progress)
    }

    /// Recognizes a decoded image. `orientation` tells how to make the pixels upright.
    public func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation = .up,
                          progress: (@Sendable (Double) -> Void)? = nil) async throws -> SheetMusicResult
    {
        let t0 = Date()
        let image = try ImagePreparation.prepare(cgImage, orientation: orientation)
        return try await run(image, prepareTime: Date().timeIntervalSince(t0), progress: progress)
    }

    #if canImport(UIKit)
    /// Recognizes a UIImage (its imageOrientation is honored).
    public func recognize(uiImage: UIImage, progress: (@Sendable (Double) -> Void)? = nil) async throws -> SheetMusicResult {
        if let cg = uiImage.cgImage {
            return try await recognize(cgImage: cg, orientation: CGImagePropertyOrientation(uiImage.imageOrientation), progress: progress)
        }
        let renderer = UIGraphicsImageRenderer(size: uiImage.size)
        let flattened = renderer.image { _ in uiImage.draw(at: .zero) }
        guard let cg = flattened.cgImage else { throw OMRError.imageDecodingFailed }
        return try await recognize(cgImage: cg, orientation: .up, progress: progress)
    }
    #endif

    private func run(_ image: PreparedImage, prepareTime: Double,
                     progress: (@Sendable (Double) -> Void)?) async throws -> SheetMusicResult
    {
        var timings: [String: Double] = ["prepare": prepareTime]
        let (staffNet, detailNet) = try await models()
        let cfg = configuration

        var t = Date()
        let staffClasses = try await staffNet.classify(image, overlap: cfg.tileOverlap, stitching: cfg.stitching) { p in
            progress?(p * 0.45)
        }
        timings["model1"] = Date().timeIntervalSince(t)
        t = Date()
        let detailClasses = try await detailNet.classify(image, overlap: cfg.tileOverlap, stitching: cfg.stitching) { p in
            progress?(0.45 + p * 0.45)
        }
        timings["model2"] = Date().timeIntervalSince(t)
        try Task.checkCancellation()

        // class maps -> the five binary maps oemer works with
        let n = image.width * image.height
        var staff = Mask.zeros(width: image.width, height: image.height)
        var symbols = staff, stems = staff, heads = staff, clefs = staff
        for i in 0..<n {
            switch staffClasses.data[i] {
            case 1: staff.data[i] = 1
            case 2: symbols.data[i] = 1
            default: break
            }
            switch detailClasses.data[i] {
            case 1: stems.data[i] = 1
            case 2: heads.data[i] = 1
            case 3: clefs.data[i] = 1
            default: break
            }
        }
        let maps = SegmentationMaps(staff: staff, symbols: symbols, stemsRests: stems, notehead: heads, clefsKeys: clefs)

        let result = try OMREngine.transcribe(maps, classifiers: classifiers,
                                              options: OMROptions(deskew: cfg.deskew, title: cfg.title))
        for (stage, secs) in result.timings { timings[stage] = secs }
        progress?(1)

        // map note boxes back to the original photo
        let sx = image.scaleX, sy = image.scaleY
        let notes: [LocatedNote] = result.notes.map { n in
            let b = n.bbox
            var y1 = Double(b.y1), y2 = Double(b.y2)
            var staffTop = n.staffTop, staffBottom = n.staffBottom
            if let rows = result.dewarpRows {
                let cx = min(max((b.x1 + b.x2) / 2, 0), rows.width - 1)
                func source(_ y: Double) -> Double { Double(rows[min(max(Int(y.rounded()), 0), rows.height - 1), cx]) }
                y1 = source(Double(b.y1))
                y2 = source(Double(b.y2))
                staffTop = source(n.staffTop)
                staffBottom = source(n.staffBottom)
            }
            // dewarping can stretch the staff a little; scale the line distance with it
            let stretch = n.staffBottom > n.staffTop ? (staffBottom - staffTop) / (n.staffBottom - n.staffTop) : 1
            let rect = CGRect(x: Double(b.x1) / sx, y: y1 / sy,
                              width: Double(b.x2 - b.x1) / sx, height: max(0, y2 - y1) / sy)
            return LocatedNote(name: n.name, step: n.step, alter: n.alter, octave: n.octave, staff: n.staff,
                               type: n.type, dotted: n.dotted, rect: rect, system: n.system,
                               staffTop: staffTop / sy, staffBottom: staffBottom / sy,
                               staffSpace: n.staffSpace * stretch / sy)
        }
        return SheetMusicResult(musicXML: result.musicXML, notes: notes,
                                imageSize: CGSize(width: image.originalWidth, height: image.originalHeight),
                                timings: timings)
    }
}

/// Loads both models once and shares them between recognitions.
private actor ModelCache {
    private var loaded: (SegmentationModel, SegmentationModel)?
    private var loading: Task<(SegmentationModel, SegmentationModel), Error>?

    func models(computeUnits: MLComputeUnits) async throws -> (SegmentationModel, SegmentationModel) {
        if let loaded = loaded { return loaded }
        if let task = loading { return try await task.value }
        let task = Task {
            let a = try await SegmentationModel(named: "UNetStaffSymbols", computeUnits: computeUnits)
            let b = try await SegmentationModel(named: "SegNetDetails", computeUnits: computeUnits)
            return (a, b)
        }
        loading = task
        do {
            let pair = try await task.value
            loaded = pair
            loading = nil
            return pair
        } catch {
            loading = nil
            throw error
        }
    }
}

#if canImport(UIKit)
extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
#endif
#endif
