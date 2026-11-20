import XCTest
import UIKit
@testable import Rehearse_v1

/// Renders whole pages of the Animation sheet to PNGs for checking the engraving by eye.
/// Runs only when SHEET_PREVIEW_DIR is set (pass TEST_RUNNER_SHEET_PREVIEW_DIR to xcodebuild):
/// every .pdf there is converted on the device first, every .json is drawn as it is, and a
/// <name>.sheet.png is written next to each.
final class SheetRenderPreviewTests: XCTestCase {
    func test_renderPreviews() async throws {
        guard let dir = ProcessInfo.processInfo.environment["SHEET_PREVIEW_DIR"] else {
            throw XCTSkip("set TEST_RUNNER_SHEET_PREVIEW_DIR to render previews")
        }
        let folder = URL(fileURLWithPath: dir)
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let data: Data
            switch file.pathExtension.lowercased() {
            case "pdf":
                let result = try await OnDeviceSheetConverter.shared.convert(pdfData: try Data(contentsOf: file),
                                                                            title: file.deletingPathExtension().lastPathComponent)
                data = result.scoreJSON
                try data.write(to: file.deletingPathExtension().appendingPathExtension("converted.json"))
            case "json" where !file.lastPathComponent.hasSuffix(".converted.json"):
                data = try Data(contentsOf: file)
            default:
                continue
            }
            let timeline = try ScoreTimeline.parse(data: data)
            // the sheet's size in Animation on an iPhone 17 Pro in landscape
            let view = await MainActor.run { () -> SheetMusicView in
                let view = SheetMusicView(frame: CGRect(x: 0, y: 0, width: 718, height: 218))
                view.layoutIfNeeded()
                view.load(timeline: timeline)
                return view
            }
            // the view draws from the main queue; an async test yields rather than spinning it
            for _ in 0..<150 {
                if await MainActor.run(body: { !view.systemRanges.isEmpty }) { break }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            let rendered = await MainActor.run { view.pageImage() }
            let image = try XCTUnwrap(rendered)
            try XCTUnwrap(image.pngData()).write(to: file.deletingPathExtension().appendingPathExtension("sheet.png"))
            print("[SheetPreview] \(file.lastPathComponent): \(timeline.measures.count) measures, "
                  + "\(timeline.notes.count) notes, tempo \(timeline.tempos.map(\.bpm)), "
                  + "\(String(format: "%.1f", timeline.performanceSeconds))s")
        }
    }
}
