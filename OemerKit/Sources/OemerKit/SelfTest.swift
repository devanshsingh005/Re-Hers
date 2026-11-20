#if canImport(CoreML)
import CoreML
import Foundation
import OemerCore

/// Result of `SheetMusicRecognizer.runSelfTest()`.
public struct ModelSelfTestReport: Sendable, CustomStringConvertible {
    /// Fraction of pixels where the on-device model picks the same class as the original
    /// TensorFlow model (FP32) did for the bundled test tile.
    public let staffModelAgreement: Double
    public let detailModelAgreement: Double
    public let seconds: Double

    /// FP16 on the Neural Engine is expected to agree on well over 99% of pixels.
    public var passed: Bool { staffModelAgreement > 0.99 && detailModelAgreement > 0.99 }

    public var description: String {
        String(format: "staff/symbols model %.3f%%, detail model %.3f%% agreement (%.2fs) — %@",
               staffModelAgreement * 100, detailModelAgreement * 100, seconds, passed ? "PASS" : "CHECK")
    }
}

extension SheetMusicRecognizer {
    /// Runs both models on a bundled page tile and compares with reference output computed
    /// by the original TensorFlow models. Use it once on a real device after integrating.
    public func runSelfTest() async throws -> ModelSelfTestReport {
        guard let url = Bundle.module.url(forResource: "selftest", withExtension: "bin") else {
            throw OMRError.modelUnavailable("selftest.bin missing")
        }
        let data = try Data(contentsOf: url)
        let magic = "OEMERSELFTEST1".data(using: .utf8)!
        guard data.prefix(magic.count) == magic else { throw OMRError.modelUnavailable("bad selftest.bin") }
        var off = data.startIndex + magic.count
        let T = Int(data[off..<off + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        off += 4
        let bgr = [UInt8](data[off..<off + T * T * 3])
        off += T * T * 3
        let refStaff = [UInt8](data[off..<off + T * T])
        off += T * T
        let refDetail = [UInt8](data[off..<off + T * T])

        var bgra = [UInt8](repeating: 255, count: T * T * 4)
        for i in 0..<(T * T) {
            bgra[i * 4] = bgr[i * 3]
            bgra[i * 4 + 1] = bgr[i * 3 + 1]
            bgra[i * 4 + 2] = bgr[i * 3 + 2]
        }
        let image = PreparedImage(width: T, height: T, pixels: bgra, originalWidth: T, originalHeight: T)
        try await prepare()
        let t0 = Date()
        let staffNet = try await SegmentationModel(named: "UNetStaffSymbols", computeUnits: configuration.computeUnits)
        let detailNet = try await SegmentationModel(named: "SegNetDetails", computeUnits: configuration.computeUnits)
        guard staffNet.tileSize == T, detailNet.tileSize == T else {
            throw OMRError.modelUnavailable("self-test tile size \(T) does not match the models")
        }
        let a = try await staffNet.classify(image, overlap: 0, stitching: .centerCrop) { _ in }
        let b = try await detailNet.classify(image, overlap: 0, stitching: .centerCrop) { _ in }
        let agreeA = Double(zip(a.data, refStaff).filter { $0 == $1 }.count) / Double(T * T)
        let agreeB = Double(zip(b.data, refDetail).filter { $0 == $1 }.count) / Double(T * T)
        return ModelSelfTestReport(staffModelAgreement: agreeA, detailModelAgreement: agreeB,
                                   seconds: Date().timeIntervalSince(t0))
    }
}
#endif
