#if canImport(CoreML)
import Accelerate
import CoreML
import CoreVideo
import Foundation
import OemerCore

/// How overlapping tile predictions are combined.
public enum TileStitching: Sendable {
    /// Average the class probabilities of every tile covering a pixel (what oemer does).
    case average
    /// Each pixel takes the prediction of the one tile whose center region owns it — no
    /// accumulation buffers, same result where tiles agree.
    case centerCrop
}

/// Loads (compiling on first use) and caches the bundled Core ML models.
enum ModelStore {
    /// Bump when the bundled models change so cached compiled copies are refreshed.
    static let modelVersion = "1"

    static func compiledURL(named name: String) async throws -> URL {
        guard let packageURL = Bundle.module.url(forResource: name, withExtension: "mlpackage") else {
            throw OMRError.modelUnavailable("\(name).mlpackage is missing from the OemerKit bundle")
        }
        let fm = FileManager.default
        let dir = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("OemerKit", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("\(name)-v\(modelVersion).mlmodelc", isDirectory: true)
        if fm.fileExists(atPath: dest.path) { return dest }
        let compiled = try await MLModel.compileModel(at: packageURL)
        if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
        do {
            try fm.moveItem(at: compiled, to: dest)
        } catch {
            try fm.copyItem(at: compiled, to: dest)
        }
        return dest
    }
}

/// One of the two segmentation networks, run tile by tile over the page.
// Immutable after init; MLModel predictions are thread-safe, and per-call buffers live in classify().
final class SegmentationModel: @unchecked Sendable {
    let model: MLModel
    let tileSize: Int
    let classCount: Int

    init(named name: String, computeUnits: MLComputeUnits) async throws {
        let url = try await ModelStore.compiledURL(named: name)
        let config = MLModelConfiguration()
        config.computeUnits = computeUnits
        model = try MLModel(contentsOf: url, configuration: config)
        guard let constraint = model.modelDescription.inputDescriptionsByName["image"]?.imageConstraint else {
            throw OMRError.modelUnavailable("\(name): unexpected input")
        }
        tileSize = constraint.pixelsWide
        guard let shape = model.modelDescription.outputDescriptionsByName["probs"]?.multiArrayConstraint?.shape,
              let c = shape.last?.intValue
        else { throw OMRError.modelUnavailable("\(name): unexpected output") }
        classCount = c
    }

    /// Tile origins along one axis: every `step`, the last tile flush with the end.
    static func positions(length: Int, tile: Int, step: Int) -> [Int] {
        if length <= tile { return [0] }
        var out: [Int] = []
        var p = 0
        while p + tile < length {
            out.append(p)
            p += step
        }
        out.append(length - tile)
        return out
    }

    /// Runs the network over the whole image and returns the per-pixel class index.
    func classify(_ image: PreparedImage, overlap: Int, stitching: TileStitching, batchSize: Int = 4,
                  progress: (Double) -> Void) async throws -> Grid<UInt8>
    {
        let T = tileSize
        let W = image.width, H = image.height
        let step = max(1, T - overlap)
        let xs = SegmentationModel.positions(length: W, tile: T, step: step)
        let ys = SegmentationModel.positions(length: H, tile: T, step: step)
        let tiles = ys.flatMap { y in xs.map { (x: $0, y: y) } }

        // ownership bounds for center-crop stitching: midpoints of overlaps
        func bounds(_ ps: [Int], _ length: Int) -> [(Int, Int)] {
            ps.indices.map { i in
                let lo = i == 0 ? 0 : (ps[i - 1] + T + ps[i]) / 2
                let hi = i == ps.count - 1 ? length : (ps[i] + T + ps[i + 1]) / 2
                return (lo, hi)
            }
        }
        let xb = bounds(xs, W), yb = bounds(ys, H)

        var classes = Grid<UInt8>(width: W, height: H, repeating: 0)
        var accum: [Float] = stitching == .average ? [Float](repeating: 0, count: W * H * classCount) : []
        let pool = try PixelBufferPool(size: T)
        // FP16 -> Float conversion buffer, owned by this call so concurrent recognitions never share it
        var scratch: [Float] = []

        var done = 0
        var index = 0
        while index < tiles.count {
            try Task.checkCancellation()
            await ThermalGovernor.pauseIfNeeded()
            let chunk = Array(tiles[index..<min(index + batchSize, tiles.count)])
            let inputs: [MLFeatureProvider] = try chunk.map { t in
                let pb = try pool.makeTile(from: image, x: t.x, y: t.y)
                return try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pb)])
            }
            let outputs = try await predict(inputs)
            for (k, t) in chunk.enumerated() {
                guard let probs = outputs.features(at: k).featureValue(for: "probs")?.multiArrayValue else {
                    throw OMRError.modelUnavailable("model returned no probabilities")
                }
                let ti = index + k
                let yi = ti / xs.count, xi = ti % xs.count
                if stitching == .average {
                    accumulate(probs, at: t, into: &accum, width: W, height: H, scratch: &scratch)
                } else {
                    writeArgmax(probs, at: t, rows: yb[yi], cols: xb[xi], into: &classes, scratch: &scratch)
                }
            }
            index += chunk.count
            done += chunk.count
            progress(Double(done) / Double(tiles.count))
        }
        if stitching == .average {
            let C = classCount
            accum.withUnsafeBufferPointer { a in
                for i in 0..<(W * H) {
                    var best = 0
                    var bv = a[i * C]
                    for c in 1..<C where a[i * C + c] > bv {
                        bv = a[i * C + c]
                        best = c
                    }
                    classes.data[i] = UInt8(best)
                }
            }
        }
        return classes
    }

    private func predict(_ inputs: [MLFeatureProvider]) async throws -> MLBatchProvider {
        let batch = MLArrayBatchProvider(array: inputs)
        let model = self.model
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    cont.resume(returning: try model.predictions(from: batch, options: MLPredictionOptions()))
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    /// Reads probs[0, y, x, c] honoring the array's strides (outputs can be padded).
    /// FP16 outputs are converted into `scratch`, which is reused between tiles.
    private func withProbs(_ arr: MLMultiArray, scratch halfScratch: inout [Float],
                           _ body: (_ value: (Int, Int, Int) -> Float) -> Void)
    {
        let shape = arr.shape.map { $0.intValue }
        let s = arr.strides.map { $0.intValue }
        let sy = s[1], sx = s[2], sc = s[3]
        // number of elements spanned in memory (outputs from the Neural Engine may be padded)
        var span = 1
        for i in 0..<shape.count { span += (shape[i] - 1) * s[i] }
        switch arr.dataType {
        case .float32:
            let p = arr.dataPointer.bindMemory(to: Float.self, capacity: span)
            body { y, x, c in p[y * sy + x * sx + c * sc] }
        case .double:
            let p = arr.dataPointer.bindMemory(to: Double.self, capacity: span)
            body { y, x, c in Float(p[y * sy + x * sx + c * sc]) }
        case .float16:
            if halfScratch.count < span { halfScratch = [Float](repeating: 0, count: span) }
            halfScratch.withUnsafeMutableBufferPointer { dstBuf in
                var src = vImage_Buffer(data: arr.dataPointer, height: 1, width: vImagePixelCount(span), rowBytes: span * 2)
                var dst = vImage_Buffer(data: dstBuf.baseAddress, height: 1, width: vImagePixelCount(span), rowBytes: span * 4)
                _ = vImageConvert_Planar16FtoPlanarF(&src, &dst, vImage_Flags(kvImageNoFlags))
            }
            halfScratch.withUnsafeBufferPointer { p in
                body { y, x, c in p[y * sy + x * sx + c * sc] }
            }
        default:
            body { y, x, c in arr[[0, NSNumber(value: y), NSNumber(value: x), NSNumber(value: c)]].floatValue }
        }
    }

    private func accumulate(_ arr: MLMultiArray, at t: (x: Int, y: Int), into accum: inout [Float], width W: Int, height H: Int,
                            scratch: inout [Float])
    {
        let T = tileSize, C = classCount
        let th = min(T, H - t.y), tw = min(T, W - t.x)
        withProbs(arr, scratch: &scratch) { value in
            accum.withUnsafeMutableBufferPointer { a in
                for y in 0..<th {
                    let row = (t.y + y) * W
                    for x in 0..<tw {
                        let base = (row + t.x + x) * C
                        for c in 0..<C { a[base + c] += value(y, x, c) }
                    }
                }
            }
        }
    }

    private func writeArgmax(_ arr: MLMultiArray, at t: (x: Int, y: Int), rows: (Int, Int), cols: (Int, Int),
                             into classes: inout Grid<UInt8>, scratch: inout [Float])
    {
        let C = classCount
        let W = classes.width
        withProbs(arr, scratch: &scratch) { value in
            classes.data.withUnsafeMutableBufferPointer { out in
                for gy in rows.0..<rows.1 {
                    let y = gy - t.y
                    guard y >= 0 && y < tileSize else { continue }
                    for gx in cols.0..<cols.1 {
                        let x = gx - t.x
                        guard x >= 0 && x < tileSize else { continue }
                        var best = 0
                        var bv = value(y, x, 0)
                        for c in 1..<C {
                            let v = value(y, x, c)
                            if v > bv { bv = v; best = c }
                        }
                        out[gy * W + gx] = UInt8(best)
                    }
                }
            }
        }
    }
}

/// Reusable BGRA pixel buffers for model input tiles.
final class PixelBufferPool {
    let size: Int
    private let pool: CVPixelBufferPool

    init(size: Int) throws {
        self.size = size
        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: size,
            kCVPixelBufferHeightKey: size,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        ]
        var p: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &p)
        guard let pool = p else { throw OMRError.modelUnavailable("could not create pixel buffers") }
        self.pool = pool
    }

    /// Copies the T x T region at (x, y) of the image into a pixel buffer (white outside the image).
    func makeTile(from image: PreparedImage, x: Int, y: Int) throws -> CVPixelBuffer {
        var out: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out)
        guard let pb = out else { throw OMRError.modelUnavailable("could not allocate a pixel buffer") }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { throw OMRError.modelUnavailable("pixel buffer has no memory") }
        let dstStride = CVPixelBufferGetBytesPerRow(pb)
        let dst = base.assumingMemoryBound(to: UInt8.self)
        let srcStride = image.width * 4
        image.pixels.withUnsafeBufferPointer { src in
            for r in 0..<size {
                let row = dst + r * dstStride
                let sy = y + r
                if sy >= image.height {
                    memset(row, 255, size * 4)
                    continue
                }
                let cols = max(0, min(size, image.width - x))
                if cols > 0 {
                    memcpy(row, src.baseAddress! + sy * srcStride + x * 4, cols * 4)
                }
                if cols < size { memset(row + cols * 4, 255, (size - cols) * 4) }
            }
        }
        return pb
    }
}

/// Keeps sustained inference from overheating the phone: when iOS reports thermal pressure,
/// short pauses are inserted between tile batches.
enum ThermalGovernor {
    static func pauseIfNeeded() async {
        switch ProcessInfo.processInfo.thermalState {
        case .serious:
            try? await Task.sleep(nanoseconds: 40_000_000)
        case .critical:
            try? await Task.sleep(nanoseconds: 250_000_000)
        default:
            break
        }
    }
}
#endif
