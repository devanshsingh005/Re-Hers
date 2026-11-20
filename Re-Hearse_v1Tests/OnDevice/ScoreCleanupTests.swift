import XCTest
@testable import Rehearse_v1

final class ScoreCleanupTests: XCTestCase {

    private func note(_ step: String, _ octave: Int, alter: Int = 0, staff: Int) -> String {
        "<note><pitch><step>\(step)</step><alter>\(alter)</alter><octave>\(octave)</octave></pitch><duration>4</duration><voice>\(staff)</voice><staff>\(staff)</staff></note>"
    }

    private func names(_ score: XMLElementNode, measure: Int, staff: Int) -> [String] {
        let m = score.firstChild(named: "part")!.children(named: "measure")[measure]
        return m.children(named: "note").filter { $0.firstChild(named: "staff")?.text == String(staff) }.map {
            let p = $0.firstChild(named: "pitch")!
            let alter = ["1": "#", "-1": "b"][p.firstChild(named: "alter")?.text ?? "0"] ?? ""
            return p.firstChild(named: "step")!.text + alter + p.firstChild(named: "octave")!.text
        }
    }

    /// The Christmas Song case: the right hand's staff read with a bass clef for two measures.
    func test_falseBassClef_onTheRightHand_isUndone() throws {
        // under the false F clef the right hand's E♭4 and C5 came out as G2 and E♭3
        let xml = """
        <score-partwise><part id="P1">
        <measure number="1"><attributes><divisions>1</divisions><key><fifths>-3</fifths></key><staves>2</staves>
          <clef number="1"><sign>G</sign><line>2</line></clef><clef number="2"><sign>F</sign><line>4</line></clef></attributes>
          \(note("G", 4, staff: 1))<backup><duration>4</duration></backup>\(note("C", 3, staff: 2))</measure>
        <measure number="2"><attributes><clef number="1"><sign>F</sign><line>4</line></clef></attributes>
          \(note("G", 2, staff: 1))\(note("E", 3, alter: -1, staff: 1))<backup><duration>8</duration></backup>\(note("C", 3, staff: 2))</measure>
        <measure number="3"><attributes><clef number="1"><sign>G</sign><line>2</line></clef></attributes>
          \(note("G", 4, staff: 1))<backup><duration>4</duration></backup>\(note("C", 3, staff: 2))</measure>
        </part></score-partwise>
        """
        let score = try MusicXMLDocument.parse(xml)
        XCTAssertEqual(ScoreCleanup.clean(score), ScoreCleanup.Report(clefs: 1, keys: 0))
        // up an octave and a sixth: G2 → E♭4 (E takes the key's flat), E♭3 → C5
        XCTAssertEqual(names(score, measure: 1, staff: 1), ["Eb4", "C5"])
        let measures = score.firstChild(named: "part")!.children(named: "measure")
        XCTAssertTrue(measures[1].children(named: "attributes").isEmpty, "the false clef is gone")
        XCTAssertTrue(measures[2].children(named: "attributes").isEmpty, "and so is the change back")
    }

    /// A real clef change (the right hand going down into the bass) is kept.
    func test_realClefChange_isKept() throws {
        let xml = """
        <score-partwise><part id="P1">
        <measure number="1"><attributes><divisions>1</divisions><key><fifths>0</fifths></key>
          <clef number="1"><sign>G</sign><line>2</line></clef><clef number="2"><sign>F</sign><line>4</line></clef></attributes>
          \(note("C", 5, staff: 1))<backup><duration>4</duration></backup>\(note("C", 2, staff: 2))</measure>
        <measure number="2"><attributes><clef number="1"><sign>F</sign><line>4</line></clef></attributes>
          \(note("E", 3, staff: 1))<backup><duration>4</duration></backup>\(note("C", 2, staff: 2))</measure>
        </part></score-partwise>
        """
        let score = try MusicXMLDocument.parse(xml)
        XCTAssertEqual(ScoreCleanup.clean(score), ScoreCleanup.Report())
        XCTAssertEqual(names(score, measure: 1, staff: 1), ["E3"])
    }

    /// A key signature that comes and goes within a few measures is a misreading.
    func test_shortKeyChange_isUndone_butAModulationIsKept() throws {
        func measure(_ n: Int, key: Int?, notes: String) -> String {
            "<measure number=\"\(n)\">" + (key.map { "<attributes><key><fifths>\($0)</fifths></key></attributes>" } ?? "") + notes + "</measure>"
        }
        let a = note("A", 4, alter: -1, staff: 1), aNatural = note("A", 4, staff: 1)
        let xml = "<score-partwise><part id=\"P1\">"
            + "<measure number=\"1\"><attributes><divisions>1</divisions><key><fifths>-3</fifths></key><clef number=\"1\"><sign>G</sign><line>2</line></clef></attributes>\(a)</measure>"
            + measure(2, key: -2, notes: aNatural)          // E♭ major read as B♭ major: A♭ became A
            + measure(3, key: nil, notes: aNatural)
            + measure(4, key: -3, notes: a)
            + measure(5, key: 0, notes: aNatural)           // a real move to C major, kept
            + (6...12).map { measure($0, key: nil, notes: aNatural) }.joined()
            + "</part></score-partwise>"
        let score = try MusicXMLDocument.parse(xml)
        XCTAssertEqual(ScoreCleanup.clean(score), ScoreCleanup.Report(clefs: 0, keys: 1))
        XCTAssertEqual(names(score, measure: 1, staff: 1), ["Ab4"])
        XCTAssertEqual(names(score, measure: 2, staff: 1), ["Ab4"])
        XCTAssertEqual(names(score, measure: 5, staff: 1), ["A4"])
    }

    func test_printedTempo_numberUnderATempoWord() {
        XCTAssertEqual(PrintedTempo.find(in: "THE CHRISTMAS SONG\nMusic and Lyric by MEL TORMÉ\nand ROBERT WELLS\nSentimentally\n80\nE maj7 D 9( 11)"),
                       PrintedTempo.Mark(perMinute: 80, beatUnit: "quarter", dots: 0, words: "Sentimentally"))
        XCTAssertNil(PrintedTempo.find(in: "Sonata\nOp. 13\n2\nPiano"), "a page number under a title is not a tempo")
    }
}
