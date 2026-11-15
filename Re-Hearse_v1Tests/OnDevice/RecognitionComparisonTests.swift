import XCTest
import PDFKit
import UIKit
import OemerKit
@testable import Rehearse_v1

/// Reads every page of the PDFs in RECOGNITION_COMPARE_DIR twice — with OemerKit's corrections
/// (the app's setting) and in Python-parity mode (the engine before them) — and prints what
/// differs: notes, chords, accidentals, the key, clef and key changes, and how many fixes the
/// app's own ScoreCleanup still has to make. Runs only when the folder is given (pass
/// TEST_RUNNER_RECOGNITION_COMPARE_DIR to xcodebuild).
final class RecognitionComparisonTests: XCTestCase {

    struct Summary: CustomStringConvertible {
        var pages = 0, notes = 0, chordNotes = 0, accidentals = 0, rests = 0, measures = 0
        var startKey: String = "?"
        var keyChanges = 0, clefChanges = 0, cleanupClefs = 0, cleanupKeys = 0, failedPages = 0
        var description: String {
            "\(measures) measures, \(notes) notes (\(chordNotes) in chords), \(accidentals) altered, \(rests) rests, "
                + "key \(startKey), \(keyChanges) key change(s), \(clefChanges) clef change(s); "
                + "cleanup still undid \(cleanupClefs) clef(s), \(cleanupKeys) key(s)"
                + (failedPages > 0 ? "; \(failedPages) page(s) failed" : "")
        }
    }

    func test_compareParityAndCorrected() async throws {
        guard let dir = ProcessInfo.processInfo.environment["RECOGNITION_COMPARE_DIR"] else {
            throw XCTSkip("set TEST_RUNNER_RECOGNITION_COMPARE_DIR to compare recognition modes")
        }
        let folder = URL(fileURLWithPath: dir)
        let pdfs = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "pdf" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var corrected = SheetMusicRecognizer.Configuration()
        corrected.pythonParity = false
        var parity = SheetMusicRecognizer.Configuration()
        parity.pythonParity = true
        let fixed = try SheetMusicRecognizer(configuration: corrected)
        let old = try SheetMusicRecognizer(configuration: parity)

        for pdf in pdfs {
            let document = try XCTUnwrap(PDFDocument(url: pdf))
            var pitches: [[[String]]] = []
            for (label, recognizer) in [("before (parity)", old), ("after (corrected)", fixed)] {
                let summary = try await summarize(document, with: recognizer)
                print("[Compare] \(pdf.deletingPathExtension().lastPathComponent) \(label): \(summary)")
                pitches.append(lastPitches)
            }
            // where the two modes name notes differently (same notes in both: compare by position)
            var differing = 0
            for m in 0..<min(pitches[0].count, pitches[1].count) where pitches[0][m] != pitches[1][m] {
                differing += 1
                if differing <= 6 {
                    let pairs = zip(pitches[0][m], pitches[1][m]).filter { $0 != $1 }.map { "\($0)→\($1)" }
                    print("[Diff] \(pdf.deletingPathExtension().lastPathComponent) m\(m + 1): \(pairs.joined(separator: " "))")
                }
            }
            print("[Diff] \(pdf.deletingPathExtension().lastPathComponent): \(differing) measure(s) differ")
        }
    }

    /// Per measure, the pitched notes' names (sorted, so chord order does not count as a change).
    private var lastPitches: [[String]] = []

    private func summarize(_ document: PDFDocument, with recognizer: SheetMusicRecognizer) async throws -> Summary {
        var summary = Summary()
        var pages: [XMLElementNode] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index), let image = Self.render(page) else { continue }
            summary.pages += 1
            // RECOGNITION_COMPARE_SAVE: keep the rendered pages, to run them through OemerKit's tools
            if let folder = ProcessInfo.processInfo.environment["RECOGNITION_COMPARE_SAVE"],
               let png = UIImage(cgImage: image).pngData(), let name = document.documentURL?.deletingPathExtension().lastPathComponent {
                try? png.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name)-p\(index + 1).png"))
            }
            do {
                let result = try await recognizer.recognize(cgImage: image)
                pages.append(try MusicXMLDocument.parse(result.musicXML))
            } catch {
                summary.failedPages += 1
            }
        }
        guard let score = MusicXMLDocument.merge(pages: pages) else { return summary }
        let measures = score.firstChild(named: "part")?.children(named: "measure") ?? []
        if ProcessInfo.processInfo.environment["RECOGNITION_COMPARE_DETAIL"] != nil {
            for (m, measure) in measures.prefix(4).enumerated() {
                let names = measure.children(named: "note").compactMap { note -> String? in
                    guard let pitch = note.firstChild(named: "pitch") else { return nil }
                    let alter = ["1": "#", "-1": "b"][pitch.firstChild(named: "alter")?.text ?? "0"] ?? ""
                    let staff = note.firstChild(named: "staff")?.text ?? "1"
                    return (staff == "1" ? "R:" : "L:") + (pitch.firstChild(named: "step")?.text ?? "") + alter + (pitch.firstChild(named: "octave")?.text ?? "")
                }
                print("[Detail] m\(m + 1): \(names.joined(separator: " "))")
            }
        }
        summary.measures = measures.count
        var firstKey: Int?
        for (m, measure) in measures.enumerated() {
            for attributes in measure.children(named: "attributes") {
                for key in attributes.children(named: "key") {
                    let fifths = Int(key.firstChild(named: "fifths")?.text ?? "") ?? 0
                    if firstKey == nil { firstKey = fifths } else if m > 0 { summary.keyChanges += 1 }
                }
                if m > 0 { summary.clefChanges += attributes.children(named: "clef").count }
            }
            for note in measure.children(named: "note") {
                if note.firstChild(named: "rest") != nil { summary.rests += 1; continue }
                guard let pitch = note.firstChild(named: "pitch") else { continue }
                summary.notes += 1
                if note.firstChild(named: "chord") != nil { summary.chordNotes += 1 }
                if (pitch.firstChild(named: "alter")?.text ?? "0") != "0" { summary.accidentals += 1 }
            }
        }
        lastPitches = measures.map { measure in
            measure.children(named: "note").compactMap { note -> String? in
                guard let pitch = note.firstChild(named: "pitch") else { return nil }
                let alter = ["1": "#", "-1": "b"][pitch.firstChild(named: "alter")?.text ?? "0"] ?? ""
                return (note.firstChild(named: "staff")?.text == "2" ? "L:" : "R:")
                    + (pitch.firstChild(named: "step")?.text ?? "") + alter + (pitch.firstChild(named: "octave")?.text ?? "")
            }.sorted()
        }
        summary.startKey = firstKey.map { $0 < 0 ? "\(-$0)♭" : ($0 > 0 ? "\($0)♯" : "C") } ?? "?"
        // page starts repeat the clefs (merged pages keep their own <attributes>): not changes
        summary.clefChanges -= max(0, pages.count - 1) * 2
        summary.keyChanges -= max(0, pages.count - 1)
        let report = ScoreCleanup.clean(score)
        summary.cleanupClefs = report.clefs
        summary.cleanupKeys = report.keys
        return summary
    }

    /// The page as the app's converter renders it: about 4 MP, on white.
    private static func render(_ page: PDFPage) -> CGImage? {
        let box = page.bounds(for: .cropBox).size
        let size = page.rotation % 180 == 0 ? box : CGSize(width: box.height, height: box.width)
        let scale = (4_000_000 / max(size.width * size.height, 1)).squareRoot()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let pixels = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        return UIGraphicsImageRenderer(size: pixels, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pixels))
            ctx.cgContext.scaleBy(x: pixels.width / size.width, y: pixels.height / size.height)
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .cropBox, to: ctx.cgContext)
        }.cgImage
    }
}
