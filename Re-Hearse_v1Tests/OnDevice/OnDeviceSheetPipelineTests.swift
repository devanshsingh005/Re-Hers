import PDFKit
import UIKit
import XCTest
@testable import Rehearse_v1

/// The on-device replacement for the old /convert server pipeline: a PDF goes into
/// LocalSheetLibrary and comes back as score JSON (read by Play Along, Animation and the result
/// screen), a labeled PDF and MusicXML, without any network.
final class OnDeviceSheetPipelineTests: XCTestCase {
    // MARK: - MusicXML → JSON (the shape the server's xmltodict output had)

    func test_jsonObject_hasTheServerShape() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
        <score-partwise version="4.0">
          <part id="P1">
            <sound tempo="90"/>
            <measure number="1">
              <attributes><divisions>16</divisions><key><fifths>4</fifths></key>
                <clef number="1"><sign>G</sign><line>2</line></clef><clef number="2"><sign>F</sign><line>4</line></clef>
              </attributes>
              <note><pitch><step>C</step><alter>1</alter><octave>4</octave></pitch><duration>16</duration><dot/><staff>1</staff></note>
              <note><chord/><pitch><step>E</step><octave>4</octave></pitch><duration>16</duration><staff>1</staff></note>
              <backup><duration>16</duration></backup>
              <note><rest measure="yes"/><duration>16</duration><staff>2</staff></note>
            </measure>
          </part>
        </score-partwise>
        """
        let json = MusicXMLDocument.jsonObject(try MusicXMLDocument.parse(xml))
        let score = try XCTUnwrap(json["score-partwise"] as? [String: Any])
        XCTAssertEqual(score["@version"] as? String, "4.0")
        let part = try XCTUnwrap(score["part"] as? [String: Any])           // one part: an object
        XCTAssertEqual((part["sound"] as? [String: Any])?["@tempo"] as? String, "90")
        let measure = try XCTUnwrap(part["measure"] as? [String: Any])      // one measure: an object
        let notes = try XCTUnwrap(measure["note"] as? [[String: Any]])      // repeated: an array
        XCTAssertEqual(notes.count, 3)
        XCTAssertTrue(notes[0]["dot"] is NSNull)                            // empty element: null
        XCTAssertTrue(notes[1]["chord"] is NSNull)
        XCTAssertEqual((notes[0]["pitch"] as? [String: Any])?["alter"] as? String, "1")  // text: string
        XCTAssertEqual((notes[2]["rest"] as? [String: Any])?["@measure"] as? String, "yes")
        let clefs = try XCTUnwrap((measure["attributes"] as? [String: Any])?["clef"] as? [[String: Any]])
        XCTAssertEqual(clefs.map { $0["@number"] as? String }, ["1", "2"])
        XCTAssertEqual((measure["backup"] as? [String: Any])?["duration"] as? String, "16")
    }

    func test_merge_appendsPagesAndRenumbersMeasures() throws {
        func page(_ measures: Int) throws -> XMLElementNode {
            let body = (1...measures).map { "<measure number=\"\($0)\"><note><rest/></note></measure>" }.joined()
            return try MusicXMLDocument.parse("<score-partwise><work><work-title>Score</work-title></work><part id=\"P1\">\(body)</part></score-partwise>")
        }
        let merged = try XCTUnwrap(MusicXMLDocument.merge(pages: [page(2), page(3)]))
        let numbers = merged.firstChild(named: "part")?.children(named: "measure").map {
            $0.attributes.first { $0.name == "number" }?.value
        }
        XCTAssertEqual(numbers, ["1", "2", "3", "4", "5"])
        // and it survives a round trip through the writer
        let reparsed = try MusicXMLDocument.parse(MusicXMLDocument.serialize(merged))
        XCTAssertEqual(reparsed.firstChild(named: "part")?.children(named: "measure").count, 5)
    }

    // MARK: - End to end: tabi.jpg as an uploaded PDF

    @MainActor
    func test_upload_isConvertedOnDevice_andFeedsTheApp() async throws {
        let library = LocalSheetLibrary.shared
        let upload = try library.add(pdfData: try Self.tabiPDF(), title: "Tabi (test)",
                                     originalFilename: "SheetMusic_test.pdf")
        defer { try? library.delete(scanId: upload.scanId) }
        XCTAssertEqual(upload.status, .processing)

        let start = Date()
        let finished = await library.waitForConversion(id: upload.id)
        let done = try XCTUnwrap(finished)
        let seconds = Date().timeIntervalSince(start)
        XCTAssertEqual(done.status, .completed, done.errorMessage ?? "")
        let notes = try XCTUnwrap(done.noteCount)
        print("[OnDeviceTest] \(notes) notes on \(done.pageCount ?? 0) page(s) in \(String(format: "%.1f", seconds))s")
        XCTAssertGreaterThan(notes, 300)  // oemer finds ~346 on tabi
        XCTAssertLessThan(notes, 400)
        XCTAssertEqual(done.skippedPages, [])

        // the result screen, Play Along and Animation read this JSON
        let json = try XCTUnwrap(library.scoreJSON(id: upload.id))
        XCTAssertNotNil(json["score-partwise"])
        let data = try JSONSerialization.data(withJSONObject: json)
        let chords = try MusicJSONLoader.loadSongChords(from: data)
        print("[OnDeviceTest] MusicJSONLoader: \(chords.count) chords, "
              + "first: \(chords.first.map { $0.rightHandNotes + $0.leftHandNotes } ?? [])")
        XCTAssertGreaterThan(chords.count, 100)
        XCTAssertTrue(chords.contains { !$0.leftHandNotes.isEmpty }, "bass staff notes go to the left hand")
        XCTAssertTrue(chords.contains { !$0.rightHandNotes.isEmpty })

        let sheet = SheetMusicView(frame: CGRect(x: 0, y: 0, width: 900, height: 320))
        sheet.layoutIfNeeded()
        sheet.loadData(data)
        // the view parses on a background queue and renders via the main queue; an async test
        // runs on the main queue itself, so it has to yield (not spin the run loop) to let that run
        for _ in 0..<150 where Self.shapeLayers(in: sheet.layer) == 0 {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertGreaterThan(Self.shapeLayers(in: sheet.layer), 0, "Animation's sheet view draws the notes")

        // labeled PDF: same pages as the upload, with the note names as text
        let labeled = try XCTUnwrap(library.labeledPDF(id: upload.id).flatMap { PDFDocument(data: $0) })
        let original = try XCTUnwrap(library.inputPDF(id: upload.id).flatMap { PDFDocument(data: $0) })
        XCTAssertEqual(labeled.pageCount, original.pageCount)
        XCTAssertEqual(labeled.page(at: 0)?.bounds(for: .cropBox).size, original.page(at: 0)?.bounds(for: .cropBox).size)
        let names = (labeled.page(at: 0)?.string ?? "").split(whereSeparator: \.isWhitespace)
        let pitchNames = names.filter { $0.range(of: #"^[A-G][#b]?[0-9]$"#, options: .regularExpression) != nil }
        print("[OnDeviceTest] labeled PDF: \(pitchNames.count) note names, e.g. \(pitchNames.prefix(8))")
        XCTAssertEqual(pitchNames.count, notes, "one name per note")
        try Self.labeledPreview(labeled).pngData()?.write(to: FileManager.default.temporaryDirectory
            .appendingPathComponent("labeled-tabi.png"))

        let xml = try XCTUnwrap(library.musicXML(id: upload.id))
        XCTAssertTrue(xml.contains("<work-title>Tabi (test)</work-title>"))

        // rename and delete stay on the device
        try library.rename(scanId: upload.scanId, to: "Renamed")
        XCTAssertEqual(library.upload(id: upload.id)?.title, "Renamed")
        try library.delete(scanId: upload.scanId)
        XCTAssertNil(library.upload(id: upload.id))
        XCTAssertNil(library.inputPDF(id: upload.id))
    }

    @MainActor
    func test_nonMusicUpload_failsWithAFriendlyMessage() async throws {
        let library = LocalSheetLibrary.shared
        let blank = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)).pdfData { ctx in
            ctx.beginPage()
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 612, height: 792))
            ("Shopping list: milk, eggs" as NSString).draw(at: CGPoint(x: 72, y: 72),
                                                           withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
        }
        let upload = try library.add(pdfData: blank, title: "Not music", originalFilename: "blank.pdf")
        defer { try? library.delete(scanId: upload.scanId) }
        let finished = await library.waitForConversion(id: upload.id)
        let done = try XCTUnwrap(finished)
        XCTAssertEqual(done.status, .failed)
        XCTAssertEqual(done.errorMessage, SheetConversionError.noMusicFound.errorDescription)
    }

    // MARK: - Helpers

    /// tabi.jpg on a 612×792 PDF page, the way UploadScreen.createPDF builds uploads.
    static func tabiPDF() throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("OemerKit/Examples/tabi.jpg")
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path))
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in
            ctx.beginPage()
            let scale = min(page.width / image.size.width, page.height / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (page.width - size.width) / 2, y: (page.height - size.height) / 2,
                                  width: size.width, height: size.height))
        }
    }

    static func shapeLayers(in layer: CALayer) -> Int {
        (layer is CAShapeLayer ? 1 : 0) + (layer.sublayers ?? []).reduce(0) { $0 + shapeLayers(in: $1) }
    }

    /// First page of the labeled PDF as an image, for looking at the result.
    static func labeledPreview(_ doc: PDFDocument) -> UIImage {
        let page = doc.page(at: 0)!
        let size = page.bounds(for: .cropBox).size
        return UIGraphicsImageRenderer(size: CGSize(width: size.width * 2, height: size.height * 2)).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size.width * 2, height: size.height * 2))
            ctx.cgContext.scaleBy(x: 2, y: 2)
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .cropBox, to: ctx.cgContext)
        }
    }
}
