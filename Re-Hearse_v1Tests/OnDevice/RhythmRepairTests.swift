import XCTest
@testable import Rehearse_v1

/// Measures the recognizer made longer than their time signature (RhythmRepair).
final class RhythmRepairTests: XCTestCase {
    /// A two-staff 4/4 piece (divisions 4: a sixteenth is 1) whose second measure is given;
    /// measures 1 and 3 are plain whole notes, so the expected length is 16.
    private func score(middle: String) throws -> XMLElementNode {
        func whole(_ n: Int) -> String {
            """
            <measure number="\(n)">\(n == 1 ? "<attributes><divisions>4</divisions><staves>2</staves></attributes>" : "")
              <note><pitch><step>C</step><octave>5</octave></pitch><duration>16</duration><voice>1</voice><type>whole</type><staff>1</staff></note>
              <backup><duration>16</duration></backup>
              <note><pitch><step>C</step><octave>3</octave></pitch><duration>16</duration><voice>1</voice><type>whole</type><staff>2</staff></note>
            </measure>
            """
        }
        return try MusicXMLDocument.parse("<score-partwise><part id=\"P1\">\(whole(1))\(middle)\(whole(3))</part></score-partwise>")
    }

    private func note(_ step: String, _ octave: Int, _ duration: Int, staff: Int, rest: Bool = false) -> String {
        let pitch = rest ? "<rest/>" : "<pitch><step>\(step)</step><octave>\(octave)</octave></pitch>"
        return "<note>\(pitch)<duration>\(duration)</duration><voice>1</voice><type>16th</type><staff>\(staff)</staff></note>"
    }

    func test_emptyOpeningBeat_inEveryStaff_isRemoved() throws {
        // a quarter rest in both staves (a metronome note taken for music), then a full measure
        let treble = note("", 0, 4, staff: 1, rest: true) + (0..<4).map { _ in note("E", 5, 4, staff: 1) }.joined()
        let bass = note("", 0, 4, staff: 2, rest: true) + (0..<4).map { _ in note("C", 3, 4, staff: 2) }.joined()
        let root = try score(middle: "<measure number=\"2\">\(treble)<backup><duration>20</duration></backup>\(bass)</measure>")
        let report = RhythmRepair.repair(root)
        XCTAssertEqual(report.leadingGaps, 1)
        let timeline = try ScoreTimeline.parse(root: MusicXMLDocument.jsonObject(root))
        XCTAssertEqual(timeline.measures[1].lengthTicks, timeline.measures[0].lengthTicks)
        let starts = timeline.notes.filter { $0.measureIndex == 1 && !$0.isRest && $0.staff == 1 }.map(\.startTick)
        XCTAssertEqual(starts.first, timeline.measures[1].startTick, "the first note starts the measure")
    }

    func test_overfullMeasure_isRetimedToFit_withPlainValues() throws {
        // eighths in the treble, with one read as a dotted eighth: 18 sixteenths in a 16 measure
        let treble = [3, 2, 2, 2, 2, 2, 2, 3].map { note("G", 4, $0, staff: 1) }.joined()
        let root = try score(middle: "<measure number=\"2\">\(treble)<backup><duration>18</duration></backup>\(note("C", 3, 18, staff: 2))</measure>")
        let report = RhythmRepair.repair(root)
        XCTAssertEqual(report.refitted, 1)
        let measure = root.firstChild(named: "part")!.children(named: "measure")[1]
        let treblesDurations = measure.children(named: "note")
            .filter { $0.firstChild(named: "staff")?.text == "1" }
            .compactMap { Int($0.firstChild(named: "duration")?.text ?? "") }
        XCTAssertEqual(treblesDurations.reduce(0, +), 16)
        XCTAssertEqual(treblesDurations, Array(repeating: 2, count: 8), "the two stray dots go, the eighths stay")
        let types = measure.children(named: "note").filter { $0.firstChild(named: "staff")?.text == "1" }
            .compactMap { $0.firstChild(named: "type")?.text }
        XCTAssertEqual(Set(types), ["eighth"])
    }

    func test_measureOfTheRightLength_isLeftAlone() throws {
        let treble = (0..<8).map { _ in note("G", 4, 2, staff: 1) }.joined()
        let xml = "<measure number=\"2\">\(treble)<backup><duration>16</duration></backup>\(note("C", 3, 16, staff: 2))</measure>"
        let root = try score(middle: xml)
        let before = MusicXMLDocument.serialize(root)
        XCTAssertEqual(RhythmRepair.repair(root), RhythmRepair.Report())
        XCTAssertEqual(MusicXMLDocument.serialize(root), before)
    }
}
