import XCTest
import UIKit
import PDFKit
@testable import Rehearse_v1

final class ScoreTimelineTests: XCTestCase {

    // MARK: Timing

    func test_elementOrder_appliesBackupAndForward() throws {
        let timeline = try parse(measures: [[
            "#order": ["attributes", "note", "note", "backup", "note", "backup", "forward", "note"],
            "attributes": ["divisions": "2", "time": ["beats": "2", "beat-type": "4"]],
            "note": [
                note("C", 5, duration: 2, type: "quarter"),
                note("D", 5, duration: 2, type: "quarter"),
                note("C", 3, duration: 4, type: "half", staff: 2, voice: "5"),
                note("E", 5, duration: 1, type: "eighth", voice: "2")
            ],
            "backup": [["duration": "4"], ["duration": "4"]],
            "forward": ["duration": "3"]
        ]])
        let starts = Dictionary(uniqueKeysWithValues: timeline.notes.map { ($0.writtenName ?? "", $0.startTick) })
        XCTAssertTrue(timeline.keepsElementOrder)
        XCTAssertEqual(starts["C5"], 0)
        XCTAssertEqual(starts["D5"], 2)
        XCTAssertEqual(starts["C3"], 0)
        XCTAssertEqual(starts["E5"], 3, "a forward after a backup moves the next voice into the measure")
        XCTAssertEqual(timeline.notes.first { $0.writtenName == "C3" }?.isLeftHand, true)
    }

    func test_withoutElementOrder_timesEachStaffAndVoiceOnItsOwn() throws {
        let timeline = try parse(measures: [[
            "attributes": ["divisions": "1"],
            "note": [
                note("C", 5, duration: 1, type: "quarter"),
                note("D", 5, duration: 1, type: "quarter"),
                note("C", 3, duration: 2, type: "half", staff: 2, voice: "5")
            ]
        ]])
        XCTAssertFalse(timeline.keepsElementOrder)
        XCTAssertEqual(timeline.notes.map(\.startTick), [0, 0, 1])
    }

    func test_compoundTime_measureIsSixEighthsLong() throws {
        let six = Array(repeating: note("G", 4, duration: 1, type: "eighth"), count: 6)
        let timeline = try parse(measures: [
            ["attributes": ["divisions": "2", "time": ["beats": "6", "beat-type": "8"]], "note": six],
            ["note": six]
        ])
        XCTAssertEqual(timeline.measures[0].lengthTicks, 3 * timeline.ticksPerQuarter)
        XCTAssertEqual(timeline.measures[1].startTick, 3 * timeline.ticksPerQuarter)
    }

    func test_pickupMeasure_keepsItsOwnLength() throws {
        let timeline = try parse(measures: [
            ["@implicit": "yes", "attributes": ["divisions": "1", "time": ["beats": "4", "beat-type": "4"]],
             "note": note("G", 4, duration: 1, type: "quarter")],
            ["note": note("C", 5, duration: 4, type: "whole")]
        ])
        XCTAssertEqual(timeline.measures[0].lengthTicks, timeline.ticksPerQuarter)
        XCTAssertEqual(timeline.notes[1].startTick, timeline.ticksPerQuarter)
    }

    func test_measureWithoutTimeSignature_isAsLongAsItsNotes() throws {
        // OMR output has no <time>; each measure is as long as what is in it
        let timeline = try parse(measures: [
            ["attributes": ["divisions": "1"], "note": [note("C", 5, duration: 1), note("D", 5, duration: 2)]],
            ["note": note("E", 5, duration: 4)]
        ])
        XCTAssertEqual(timeline.measures.map(\.lengthTicks), [3, 4].map { $0 * timeline.ticksPerQuarter })
    }

    func test_divisionsChange_isRescaled() throws {
        let timeline = try parse(measures: [
            ["attributes": ["divisions": "1", "time": ["beats": "4", "beat-type": "4"]],
             "note": note("C", 5, duration: 4, type: "whole")],
            ["attributes": ["divisions": "4"], "note": [note("D", 5, duration: 4), note("E", 5, duration: 12)]]
        ])
        XCTAssertEqual(timeline.ticksPerQuarter, 4)
        XCTAssertEqual(timeline.notes.map(\.startTick), [0, 16, 20])
        XCTAssertEqual(timeline.notes.map(\.durationTicks), [16, 4, 12])
    }

    func test_tempo_fromPartSoundAndMetronome() throws {
        let json: [String: Any] = ["score-partwise": ["part": [
            "sound": ["@tempo": "120"],
            "measure": [
                ["@number": "1", "attributes": ["divisions": "1", "time": ["beats": "2", "beat-type": "4"]],
                 "note": [note("C", 5, duration: 1), note("C", 5, duration: 1)]],
                ["@number": "2",
                 "direction": ["direction-type": ["metronome": ["beat-unit": "quarter", "beat-unit-dot": NSNull(),
                                                                "per-minute": "60"]]],
                 "note": [note("C", 5, duration: 1), note("C", 5, duration: 1)]]
            ]
        ]]]
        let timeline = try ScoreTimeline.parse(root: json)
        XCTAssertEqual(timeline.tempos.map(\.bpm), [120, 90])
        XCTAssertEqual(timeline.seconds(atTick: 2), 1.0, accuracy: 1e-9)          // two beats at 120
        XCTAssertEqual(timeline.seconds(atTick: 3), 1.0 + 60.0 / 90, accuracy: 1e-9)
        XCTAssertEqual(timeline.tick(atSeconds: 1.0 + 60.0 / 90), 3, accuracy: 1e-9)
    }

    // MARK: Notes

    func test_tiedNotes_soundOnceForTheWholeTie() throws {
        var first = note("C", 4, duration: 2, type: "half")
        first["tie"] = ["@type": "start"]
        var second = note("C", 4, duration: 2, type: "half")
        second["notations"] = ["tied": ["@type": "stop"]]
        let timeline = try parse(measures: [
            ["attributes": ["divisions": "1", "time": ["beats": "2", "beat-type": "4"]], "note": first],
            ["note": second]
        ])
        XCTAssertEqual(timeline.struckNotes.count, 1)
        XCTAssertEqual(timeline.notes[0].soundingTicks, 4 * timeline.ticksPerQuarter / 1)
        XCTAssertEqual(timeline.notes[1].soundingTicks, 0)
        XCTAssertEqual(MusicJSONLoader.songChords(from: timeline).count, 1, "a tie continuation is not a new chord")
    }

    func test_valuesDotsAndStems() throws {
        var dotted = note("A", 4, duration: 3, type: "quarter", stem: "down")
        dotted["dot"] = NSNull()
        let timeline = try parse(measures: [[
            "attributes": ["divisions": "2"],
            "note": [dotted, note("B", 4, duration: 1), ["rest": NSNull(), "duration": "4"]]
        ]])
        XCTAssertEqual(timeline.notes[0].value, .quarter)
        XCTAssertEqual(timeline.notes[0].dots, 1)
        XCTAssertEqual(timeline.notes[0].stem, .down)
        XCTAssertEqual(timeline.notes[1].value, .eighth, "inferred from the duration when <type> is missing")
        XCTAssertEqual(timeline.notes[2].value, .half)
        XCTAssertTrue(timeline.notes[2].isRest)
    }

    func test_accidentals_followKeyAndMeasure() throws {
        let timeline = try parse(measures: [
            ["attributes": ["divisions": "1", "key": ["fifths": "1"], "time": ["beats": "3", "beat-type": "4"]],
             "note": [note("F", 4, alter: 1, duration: 1), note("F", 4, duration: 1), note("F", 4, duration: 1)]],
            ["note": [note("F", 4, alter: 1, duration: 1), note("B", 4, alter: -1, duration: 2)]]
        ])
        XCTAssertEqual(timeline.notes.map(\.accidental), [nil, .natural, nil, nil, .flat])
    }

    func test_beams_inferredByBeat_orAsWritten() throws {
        let eighths = Array(repeating: note("E", 5, duration: 1, type: "eighth"), count: 4)
        let inferred = try parse(measures: [[
            "attributes": ["divisions": "2", "time": ["beats": "2", "beat-type": "4"]], "note": eighths
        ]])
        let groups = inferred.notes.map(\.beamGroup)
        XCTAssertNotNil(groups[0])
        XCTAssertEqual(groups[0], groups[1])
        XCTAssertEqual(groups[2], groups[3])
        XCTAssertNotEqual(groups[1], groups[2], "eighths are beamed by the beat")

        var written = eighths
        for (i, text) in ["begin", "continue", "continue", "end"].enumerated() {
            written[i]["beam"] = ["@number": "1", "#text": text]
        }
        let asWritten = try parse(measures: [[
            "attributes": ["divisions": "2", "time": ["beats": "2", "beat-type": "4"]], "note": written
        ]])
        XCTAssertEqual(Set(asWritten.notes.compactMap(\.beamGroup)).count, 1)
    }

    func test_bassClef_andTwoPartsShareTheGrandStaff() throws {
        let json: [String: Any] = ["score-partwise": ["part": [
            ["measure": ["@number": "1",
                         "attributes": ["divisions": "1", "clef": ["sign": "G", "line": "2"]],
                         "note": note("C", 5, duration: 4)]],
            ["measure": ["@number": "1",
                         "attributes": ["divisions": "1", "clef": ["sign": "F", "line": "4"]],
                         "note": note("C", 3, duration: 4)]]
        ]]]
        let timeline = try ScoreTimeline.parse(root: json)
        XCTAssertEqual(timeline.staffCount, 2)
        XCTAssertEqual(timeline.notes.map(\.startTick), [0, 0], "parts play together, not one after another")
        XCTAssertEqual(timeline.notes.first { $0.writtenName == "C3" }?.staff, 2)
        XCTAssertEqual(ScoreClef.bass.bottomLineDiatonic, 2 * 7 + 4)   // G2
        XCTAssertEqual(ScoreClef.treble.bottomLineDiatonic, 4 * 7 + 2) // E4
    }

    // MARK: Converter → timeline

    func test_converterJSON_keepsMeasureOrder() throws {
        let xml = """
        <score-partwise><part id="P1"><measure number="1">
          <attributes><divisions>1</divisions><staves>2</staves></attributes>
          <note><pitch><step>E</step><octave>5</octave></pitch><duration>1</duration><voice>1</voice><staff>1</staff></note>
          <note><pitch><step>F</step><octave>5</octave></pitch><duration>1</duration><voice>1</voice><staff>1</staff></note>
          <backup><duration>2</duration></backup>
          <forward><duration>1</duration></forward>
          <note><pitch><step>C</step><octave>3</octave></pitch><duration>1</duration><voice>2</voice><staff>2</staff></note>
        </measure></part></score-partwise>
        """
        let json = MusicXMLDocument.jsonObject(try MusicXMLDocument.parse(xml))
        XCTAssertTrue(MusicXMLDocument.isCurrentFormat(json))
        let timeline = try ScoreTimeline.parse(root: json)
        XCTAssertEqual(timeline.notes.first { $0.writtenName == "C3" }?.startTick, 1)
    }

    // MARK: Play Along chords

    func test_songChords_keepHeldBassAndTiming() throws {
        let json: [String: Any] = ["score-partwise": ["part": [
            "sound": ["@tempo": "60"],
            "measure": ["@number": "1",
                        "#order": ["attributes", "note", "note", "backup", "note"],
                        "attributes": ["divisions": "1", "time": ["beats": "2", "beat-type": "4"]],
                        "note": [note("E", 5, duration: 1), note("F", 5, duration: 1),
                                 note("C", 3, duration: 2, staff: 2, voice: "5")],
                        "backup": ["duration": "2"]]
        ]]]
        let chords = MusicJSONLoader.songChords(from: try ScoreTimeline.parse(root: json))
        XCTAssertEqual(chords.count, 2)
        XCTAssertEqual(chords[0].leftHandNotes, ["C3"])
        XCTAssertEqual(chords[0].rightHandNotes, ["E5"])
        XCTAssertEqual(chords[1].leftHandNotes, [])
        XCTAssertEqual(chords.map(\.duration), [1, 1])
    }

    // MARK: Sheet

    func test_sheet_lightsTheNotesUnderThePlayhead() throws {
        let timeline = try parse(measures: [[
            "attributes": ["divisions": "1", "time": ["beats": "2", "beat-type": "4"]],
            "note": [note("C", 5, duration: 1), note("D", 5, duration: 1)]
        ]])
        let view = SheetMusicView(frame: CGRect(x: 0, y: 0, width: 900, height: 160))
        view.layoutIfNeeded()
        view.load(timeline: timeline)
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline && heads(in: view, color: AnimatedPianoKeyView.rightColor) == 0 {
            view.updateToTick(0.5)
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertEqual(heads(in: view, color: AnimatedPianoKeyView.rightColor), 1, "the first note sounds at 0.5")
        view.updateToTick(1.5)
        XCTAssertEqual(heads(in: view, color: AnimatedPianoKeyView.rightColor), 1, "now only the second")
        view.updateToTick(0)
        XCTAssertEqual(heads(in: view, color: AnimatedPianoKeyView.rightColor), 1, "seeking back works out the states again")
    }

    // MARK: Performance order

    func test_repeatWithEndings_playsFirstEndingThenSecond() throws {
        let timeline = try parse(measures: [
            ["attributes": ["divisions": "1", "time": ["beats": "2", "beat-type": "4"]],
             "barline": ["@location": "left", "repeat": ["@direction": "forward"]],
             "note": note("C", 5, duration: 2)],
            ["barline": [["@location": "left", "ending": ["@number": "1", "@type": "start"]],
                         ["@location": "right", "ending": ["@number": "1", "@type": "stop"],
                          "repeat": ["@direction": "backward"]]],
             "note": note("D", 5, duration: 2)],
            ["barline": [["@location": "left", "ending": ["@number": "2", "@type": "start"]],
                         ["@location": "right", "ending": ["@number": "2", "@type": "discontinue"]]],
             "note": note("E", 5, duration: 2)],
            ["note": note("F", 5, duration: 2)]
        ])
        XCTAssertEqual(timeline.performance.map(\.measureIndex), [0, 1, 0, 2, 3])
        XCTAssertEqual(timeline.performance.map(\.tick), [0, 2, 4, 6, 8])
        XCTAssertEqual(timeline.measures[1].endingNumbers, [1])
        XCTAssertEqual(timeline.scoreTick(atPerformanceTick: 5), 1, "the second pass is measure 1 again")
        XCTAssertEqual(timeline.performanceSeconds, 10 * 60 / 84, accuracy: 1e-9)
    }

    func test_daCapoAlFine() throws {
        let timeline = try parse(measures: [
            ["attributes": ["divisions": "1"], "note": note("C", 5, duration: 1)],
            ["sound": ["@fine": "yes"], "note": note("D", 5, duration: 1)],
            ["sound": ["@dacapo": "yes"], "note": note("E", 5, duration: 1)]
        ])
        XCTAssertEqual(timeline.performance.map(\.measureIndex), [0, 1, 2, 0, 1])
    }

    // MARK: Articulation, dynamics, fermatas

    func test_articulationsDynamicsAndFermata() throws {
        var staccato = note("C", 5, duration: 1, type: "quarter")
        staccato["notations"] = ["articulations": ["staccato": NSNull()]]
        var accented = note("D", 5, duration: 1, type: "quarter")
        accented["notations"] = ["articulations": ["accent": NSNull()]]
        var held = note("E", 5, duration: 2, type: "half")
        held["notations"] = ["fermata": NSNull()]
        let timeline = try parse(measures: [[
            "#order": ["attributes", "direction", "note", "note", "note"],
            "attributes": ["divisions": "1", "time": ["beats": "4", "beat-type": "4"]],
            "direction": ["direction-type": ["dynamics": ["p": NSNull()]], "sound": ["@tempo": "60"]],
            "note": [staccato, accented, held]
        ]])
        XCTAssertEqual(timeline.notes[0].heldFraction, 0.5)
        XCTAssertEqual(timeline.notes[0].velocity, 56, "p")
        XCTAssertEqual(timeline.notes[1].velocity, 70, "p + accent")
        XCTAssertNil(timeline.notes[1].heldFraction)
        XCTAssertTrue(timeline.notes[2].hasFermata)
        XCTAssertEqual(timeline.seconds(atTick: 2), 2, accuracy: 1e-9)
        XCTAssertEqual(timeline.seconds(atTick: 4), 2 + 2 * 1.8, accuracy: 1e-9, "a fermata holds its note longer")
        XCTAssertEqual(timeline.directions.count, 1)
    }

    func test_crescendoRampsVelocityToTheNextMark() throws {
        let timeline = try parse(measures: [[
            "#order": ["attributes", "direction", "direction", "note", "note", "note", "direction", "note"],
            "attributes": ["divisions": "1"],
            "direction": [["direction-type": ["dynamics": ["p": NSNull()]]],
                          ["direction-type": ["wedge": ["@type": "crescendo"]]],
                          ["direction-type": [["wedge": ["@type": "stop"]], ["dynamics": ["f": NSNull()]]]]],
            "note": [note("C", 5, duration: 1), note("C", 5, duration: 1), note("C", 5, duration: 1), note("C", 5, duration: 1)]
        ]])
        let velocities = timeline.notes.map(\.velocity)
        XCTAssertEqual(velocities.first, 56)
        XCTAssertEqual(velocities.last, 98)
        XCTAssertEqual(velocities, velocities.sorted(), "louder through the hairpin")
    }

    func test_octaveShift_printsAnOctaveLower() throws {
        let timeline = try parse(measures: [[
            "#order": ["attributes", "direction", "note", "direction"],
            "attributes": ["divisions": "1"],
            "direction": [["direction-type": ["octave-shift": ["@type": "down", "@size": "8"]], "staff": "1"],
                          ["direction-type": ["octave-shift": ["@type": "stop", "@size": "8"]], "staff": "1"]],
            "note": note("C", 7, duration: 4)
        ]])
        XCTAssertEqual(timeline.notes[0].displayShift, -7)
        XCTAssertEqual(timeline.notes[0].midi, 96, "the pitch is unchanged")
    }

    func test_slursPlayLegato_andTupletsGroup() throws {
        var a = note("C", 5, duration: 1, type: "eighth")
        a["notations"] = ["slur": ["@type": "start", "@number": "1"]]
        var b = note("D", 5, duration: 1, type: "eighth")
        b["notations"] = ["slur": ["@type": "stop", "@number": "1"]]
        var triplet = note("E", 5, duration: 2, type: "eighth")
        triplet["time-modification"] = ["actual-notes": "3", "normal-notes": "2"]
        let timeline = try parse(measures: [[
            "attributes": ["divisions": "6"],
            "note": [a.merging(["duration": "3"]) { $1 }, b.merging(["duration": "3"]) { $1 }, triplet, triplet, triplet]
        ]])
        XCTAssertEqual(timeline.slurs.count, 1)
        XCTAssertTrue(timeline.notes[0].isLegato)
        XCTAssertFalse(timeline.notes[1].isLegato, "the last note under a slur is released")
        XCTAssertEqual(timeline.tuplets.count, 1)
        XCTAssertEqual(timeline.tuplets.first?.notes.count, 3)
        XCTAssertEqual(timeline.tuplets.first?.actual, 3)
    }

    func test_tempoWords_whenNoNumberIsGiven() throws {
        let timeline = try parse(measures: [[
            "attributes": ["divisions": "1"],
            "direction": ["direction-type": ["words": "Andante con moto"]],
            "note": note("C", 5, duration: 4)
        ]])
        XCTAssertEqual(timeline.tempos.first?.bpm, 92)
        XCTAssertEqual(ScoreTimeline.tempo(forWords: "Allegretto"), 116)
    }

    // MARK: Printed tempo (uploads)

    func test_printedTempo_readsMetronomeMarksAndWords() throws {
        XCTAssertEqual(PrintedTempo.find(in: "Opus 23\nAlla marcia (\u{ECA5} = 108)\nPiano"),
                       PrintedTempo.Mark(perMinute: 108, beatUnit: "quarter", dots: 0, words: "Alla marcia"))
        XCTAssertEqual(PrintedTempo.find(in: "Perfect\n\u{ECA5} = 48\n4"),
                       PrintedTempo.Mark(perMinute: 48, beatUnit: "quarter", dots: 0, words: nil))
        XCTAssertEqual(PrintedTempo.find(in: "\u{ECA5}\u{ECB7} = 60")?.quarterBPM, 90)
        XCTAssertEqual(PrintedTempo.find(in: "Sonatina\nAllegro\nMuzio Clementi")?.perMinute, 132)
        XCTAssertNil(PrintedTempo.find(in: "Op. 23 = 5\nPiano"))

        let xml = """
        <score-partwise><part id="P1"><sound tempo="90"/><measure number="1">
          <attributes><divisions>1</divisions></attributes>
          <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice></note>
        </measure></part></score-partwise>
        """
        let root = try MusicXMLDocument.parse(xml)
        PrintedTempo.apply(PrintedTempo.Mark(perMinute: 108, beatUnit: "quarter", dots: 0, words: "Alla marcia"), to: root)
        PrintedTempo.apply(PrintedTempo.Mark(perMinute: 108, beatUnit: "quarter", dots: 0, words: "Alla marcia"), to: root)
        let timeline = try ScoreTimeline.parse(root: MusicXMLDocument.jsonObject(root))
        XCTAssertEqual(timeline.tempos.map(\.bpm), [108])
        XCTAssertEqual(timeline.directions.filter { if case .metronome = $0.kind { return true } else { return false } }.count, 1,
                       "applied once")
    }

    func test_printedTempo_markBounds_andHidingTheNoteReadInIt() throws {
        // a page with "♩ = 48" printed at a known place (top-left origin, points)
        let pageSize = CGSize(width: 612, height: 792)
        let markOrigin = CGPoint(x: 100, y: 120)
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize)).pdfData { ctx in
            ctx.beginPage()
            ("\u{2669} = 48" as NSString).draw(at: markOrigin, withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        }
        let page = try XCTUnwrap(PDFDocument(data: pdf)?.page(at: 0))
        let mark = try XCTUnwrap(PrintedTempo.markBounds(on: page))
        XCTAssertEqual(mark.minX, markOrigin.x, accuracy: 4)
        XCTAssertEqual(mark.minY, markOrigin.y, accuracy: 6)
        XCTAssertLessThan(mark.height, 30)

        // the recognizer read the mark's note as a note, followed by a chord tone and the music
        let xml = """
        <score-partwise><part id="P1"><measure number="1">
          <note><pitch><step>A</step><alter>-1</alter><octave>6</octave></pitch><duration>16</duration><voice>1</voice><stem>down</stem><staff>1</staff></note>
          <note><chord/><pitch><step>C</step><octave>7</octave></pitch><duration>16</duration><voice>1</voice><staff>1</staff></note>
          <note><pitch><step>C</step><octave>5</octave></pitch><duration>16</duration><voice>1</voice><staff>1</staff></note>
        </measure></part></score-partwise>
        """
        let score = try MusicXMLDocument.parse(xml)
        let inMark = CGRect(x: mark.midX - 3, y: mark.midY - 2, width: 6, height: 4)
        let inStaff = CGRect(x: 300, y: 400, width: 6, height: 4)
        XCTAssertEqual(PrintedTempo.hideNotes(under: mark, at: [inMark, inMark, inStaff], in: score), [0, 1])
        let timeline = try ScoreTimeline.parse(root: MusicXMLDocument.jsonObject(score))
        XCTAssertEqual(timeline.struckNotes.map(\.writtenName), ["C5"], "only the real note sounds")
        XCTAssertEqual(timeline.struckNotes.first?.startTick, 16, "and keeps its time")
        XCTAssertEqual(timeline.notes.filter(\.isRest).map(\.isPrinted), [false], "the hidden rest is not drawn")
    }

    // MARK: Page layout

    func test_page_followsOriginalLineBreaks() throws {
        var measures: [[String: Any]] = (0..<6).map { _ in ["note": note("C", 5, duration: 4, type: "whole")] }
        measures[0]["attributes"] = ["divisions": "1", "time": ["beats": "4", "beat-type": "4"]]
        measures[3]["print"] = ["@new-system": "yes"]
        let timeline = try parse(measures: measures)
        XCTAssertTrue(timeline.measures[3].startsNewSystem)
        let view = SheetMusicView(frame: CGRect(x: 0, y: 0, width: 900, height: 220))
        view.layoutIfNeeded()
        view.load(timeline: timeline)
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline && view.systemRanges.isEmpty { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        XCTAssertEqual(view.systemRanges, [0..<3, 3..<6])
    }

    // MARK: Helpers

    private func parse(measures: [[String: Any]]) throws -> ScoreTimeline {
        let numbered = measures.enumerated().map { i, m -> [String: Any] in
            var m = m
            m["@number"] = m["@number"] ?? String(i + 1)
            return m
        }
        return try ScoreTimeline.parse(root: ["score-partwise": ["part": ["@id": "P1", "measure": numbered]]])
    }

    private func note(_ step: String, _ octave: Int, alter: Int = 0, duration: Int, type: String? = nil,
                      staff: Int = 1, voice: String = "1", stem: String? = nil) -> [String: Any] {
        var n: [String: Any] = [
            "pitch": ["step": step, "alter": String(alter), "octave": String(octave)],
            "duration": String(duration),
            "voice": voice,
            "staff": String(staff)
        ]
        if let type { n["type"] = type }
        if let stem { n["stem"] = stem }
        return n
    }

    private func heads(in view: SheetMusicView, color: UIColor) -> Int {
        func count(_ layer: CALayer) -> Int {
            let mine = (layer as? CAShapeLayer)?.fillColor == color.cgColor ? 1 : 0
            return mine + (layer.sublayers ?? []).reduce(0) { $0 + count($1) }
        }
        return count(view.layer)
    }
}
