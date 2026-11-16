import PDFKit
import UIKit
import XCTest
@testable import Rehearse_v1

/// What an upload looks like after a round trip through the account: files are stored compressed,
/// output.json is rebuilt from the MusicXML and labeled.pdf is redrawn from the input PDF + labels.
final class UploadCloudSyncTests: XCTestCase {
    private let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <work><work-title>Upload</work-title></work>
      <part id="P1">
        <sound tempo="96"/>
        <measure number="1">
          <attributes><divisions>16</divisions><key><fifths>-2</fifths></key>
            <clef number="1"><sign>G</sign><line>2</line></clef></attributes>
          <note><pitch><step>B</step><alter>-1</alter><octave>4</octave></pitch><duration>16</duration><staff>1</staff></note>
          <note><chord/><pitch><step>D</step><octave>5</octave></pitch><duration>16</duration><staff>1</staff></note>
          <backup><duration>16</duration></backup>
          <note><rest/><duration>16</duration><staff>1</staff></note>
        </measure>
      </part>
    </score-partwise>
    """

    func test_compression_roundTrips_andShrinksScores() throws {
        let data = Data(String(repeating: xml, count: 20).utf8)
        let packed = try UploadCloudSync.deflate(data)
        XCTAssertLessThan(packed.count, data.count / 5)
        XCTAssertEqual(try UploadCloudSync.inflate(packed), data)
    }

    func test_scoreJSON_rebuiltFromStoredMusicXML_matchesTheConvertersJSON() throws {
        let root = try MusicXMLDocument.parse(xml)
        let original = MusicXMLDocument.jsonObject(root)
        let stored = try UploadCloudSync.inflate(UploadCloudSync.deflate(Data(MusicXMLDocument.serialize(root).utf8)))
        let rebuilt = MusicXMLDocument.jsonObject(try MusicXMLDocument.parse(String(decoding: stored, as: UTF8.self)))
        func canonical(_ json: [String: Any]) throws -> Data {
            try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        }
        XCTAssertEqual(try canonical(rebuilt), try canonical(original))
        XCTAssertTrue(MusicXMLDocument.isCurrentFormat(rebuilt))
    }

    func test_labeledPDF_isRedrawnFromInputPDFAndSavedLabels() throws {
        let input = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)).pdfData { ctx in
            for _ in 0..<2 { ctx.beginPage() }
        }
        let sheet = LabelSheet(pages: [
            .init(labels: [.init(text: "Bb4", x: 400, baseline: 600, fontSize: 30)], scale: 2),
            .init(labels: [.init(text: "C#5", x: 300, baseline: 500, fontSize: 30)], scale: 2),
        ])
        let stored = try UploadCloudSync.deflate(JSONEncoder().encode(sheet))
        let decoded = try JSONDecoder().decode(LabelSheet.self, from: UploadCloudSync.inflate(stored))

        let redrawn = try XCTUnwrap(OnDeviceSheetConverter.labeledPDF(pdfData: input, sheet: decoded))
        let document = try XCTUnwrap(PDFDocument(data: redrawn))
        XCTAssertEqual(document.pageCount, 2)
        XCTAssertTrue(document.page(at: 0)?.string?.contains("Bb4") == true)
        XCTAssertTrue(document.page(at: 1)?.string?.contains("C#5") == true)

        // labels for a different page count can't be drawn on this PDF
        XCTAssertNil(OnDeviceSheetConverter.labeledPDF(pdfData: input, sheet: LabelSheet(pages: [sheet.pages[0]])))
    }

    @MainActor
    func test_add_rejectsFilesOver10MB() {
        let tooBig = Data(count: LocalSheetLibrary.maxFileBytes + 1)
        XCTAssertThrowsError(try LocalSheetLibrary.shared.add(pdfData: tooBig, title: "Big", originalFilename: "big.pdf")) {
            XCTAssertEqual($0 as? LocalSheetLibrary.LibraryError, .fileTooLarge)
        }
    }
}
