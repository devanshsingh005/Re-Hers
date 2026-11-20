import Foundation

/// An RBF-kernel SVC exported from scikit-learn, evaluated exactly like libsvm's
/// `svm_predict` (one-vs-one voting, ties go to the lower class index).
public struct SVMClassifier {
    public let name: String
    public let inputWidth: Int
    public let inputHeight: Int
    public let labels: [String]          // class index -> label (oemer class_map)
    let classValues: [Int]               // libsvm class index -> classes_ value
    let nSupport: [Int]
    let gamma: Double
    let supportVectors: [Float]          // nSV x dim, row-major
    let dualCoef: [Double]               // (nClass-1) x nSV, row-major
    let rho: [Double]                    // nClass*(nClass-1)/2
    let dim: Int

    /// oemer `predict(region, model_name)`: scale 0/1 regions to 0/255, resize with Pillow's
    /// bicubic filter to the model input size, then classify the raw pixels.
    func predict(region: Grid<Int32>) -> String {
        var r = region
        if r.data.max() == 1 {
            for i in 0..<r.data.count { r.data[i] *= 255 }
        }
        let u8 = Grid<UInt8>(width: r.width, height: r.height,
                             data: r.data.map { UInt8(truncatingIfNeeded: $0) })
        let resized = pilResizeBicubic(u8, width: inputWidth, height: inputHeight)
        return labels[predictIndex(resized.data.map { Double($0) })]
    }

    /// Classifies an already-prepared 8-bit crop (no 0/1 rescaling).
    func predict(pixels: Grid<UInt8>) -> String {
        let resized = pilResizeBicubic(pixels, width: inputWidth, height: inputHeight)
        return labels[predictIndex(resized.data.map { Double($0) })]
    }

    func predictIndex(_ x: [Double]) -> Int {
        let nClass = nSupport.count
        let nSV = nSupport.reduce(0, +)
        var kvalue = [Double](repeating: 0, count: nSV)
        supportVectors.withUnsafeBufferPointer { sv in
            for i in 0..<nSV {
                var sum = 0.0
                let base = i * dim
                for d in 0..<dim {
                    let diff = x[d] - Double(sv[base + d])
                    sum += diff * diff
                }
                kvalue[i] = exp(-gamma * sum)
            }
        }
        var start = [Int](repeating: 0, count: nClass)
        for i in 1..<nClass { start[i] = start[i - 1] + nSupport[i - 1] }
        var vote = [Int](repeating: 0, count: nClass)
        var p = 0
        for i in 0..<nClass {
            for j in (i + 1)..<max(i + 1, nClass) {
                var sum = 0.0
                let si = start[i], sj = start[j]
                let ci = nSupport[i], cj = nSupport[j]
                let coef1 = (j - 1) * nSV
                let coef2 = i * nSV
                for k in 0..<ci { sum += dualCoef[coef1 + si + k] * kvalue[si + k] }
                for k in 0..<cj { sum += dualCoef[coef2 + sj + k] * kvalue[sj + k] }
                sum -= rho[p]
                if sum > 0 { vote[i] += 1 } else { vote[j] += 1 }
                p += 1
            }
        }
        var best = 0
        for i in 1..<nClass where vote[i] > vote[best] { best = i }
        return classValues[best]
    }
}

/// The four classifiers oemer uses, loaded from the binary blob written by
/// `tools/export_classifiers.py`.
public struct SymbolClassifiers {
    public let clef: SVMClassifier
    public let sfn: SVMClassifier
    public let rests: SVMClassifier
    public let restsAbove8: SVMClassifier

    public init(data: Data) throws {
        var reader = BinaryReader(data: data)
        guard try reader.readString() == "OEMERSVM1" else { throw OMRError.badClassifierData }
        var models: [String: SVMClassifier] = [:]
        let count = Int(try reader.readUInt32())
        for _ in 0..<count {
            let name = try reader.readString()
            let w = Int(try reader.readUInt32())
            let h = Int(try reader.readUInt32())
            let nLabels = Int(try reader.readUInt32())
            var labels: [String] = []
            for _ in 0..<nLabels { labels.append(try reader.readString()) }
            let nClass = Int(try reader.readUInt32())
            var classValues: [Int] = []
            for _ in 0..<nClass { classValues.append(Int(try reader.readInt32())) }
            var nSupport: [Int] = []
            for _ in 0..<nClass { nSupport.append(Int(try reader.readUInt32())) }
            let gamma = try reader.readFloat64()
            let dim = Int(try reader.readUInt32())
            let nSV = nSupport.reduce(0, +)
            let sv = try reader.readUInt8Array(count: nSV * dim).map { Float($0) }
            let coef = try reader.readFloat64Array(count: (nClass - 1) * nSV)
            let rho = try reader.readFloat64Array(count: nClass * (nClass - 1) / 2)
            models[name] = SVMClassifier(name: name, inputWidth: w, inputHeight: h, labels: labels,
                                         classValues: classValues, nSupport: nSupport, gamma: gamma,
                                         supportVectors: sv, dualCoef: coef, rho: rho, dim: dim)
        }
        guard let c = models["clef"], let s = models["sfn"], let r = models["rests"],
              let r8 = models["rests_above8"] else { throw OMRError.badClassifierData }
        clef = c
        sfn = s
        rests = r
        restsAbove8 = r8
    }
}

struct BinaryReader {
    let data: Data
    var offset = 0

    mutating func take(_ n: Int) throws -> Data {
        guard offset + n <= data.count else { throw OMRError.badClassifierData }
        let start = data.startIndex + offset
        defer { offset += n }
        return data.subdata(in: start..<(start + n))
    }

    mutating func readUInt32() throws -> UInt32 {
        let d = try take(4)
        return d.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
    }

    mutating func readInt32() throws -> Int32 { Int32(bitPattern: try readUInt32()) }

    mutating func readFloat64() throws -> Double {
        let d = try take(8)
        return d.withUnsafeBytes { Double(bitPattern: UInt64(littleEndian: $0.loadUnaligned(as: UInt64.self))) }
    }

    mutating func readString() throws -> String {
        let n = Int(try readUInt32())
        return String(decoding: try take(n), as: UTF8.self)
    }

    mutating func readUInt8Array(count: Int) throws -> [UInt8] { [UInt8](try take(count)) }

    mutating func readFloat64Array(count: Int) throws -> [Double] {
        let d = try take(count * 8)
        return d.withUnsafeBytes { raw in
            (0..<count).map { Double(bitPattern: UInt64(littleEndian: raw.loadUnaligned(fromByteOffset: $0 * 8, as: UInt64.self))) }
        }
    }
}

public enum OMRError: Error, CustomStringConvertible {
    case badClassifierData
    case noStaffFound
    case inconsistentStaffs
    case modelUnavailable(String)
    case imageDecodingFailed
    case imageTooNoisy

    public var description: String {
        switch self {
        case .badClassifierData: return "The symbol classifier data is missing or corrupt."
        case .noStaffFound: return "No staff lines were found in the image."
        case .inconsistentStaffs: return "Staff lines could not be aligned across the page."
        case .modelUnavailable(let s): return "Model unavailable: \(s)"
        case .imageDecodingFailed: return "The image could not be read."
        case .imageTooNoisy: return "The image is too noisy to read (or is not sheet music)."
        }
    }
}
