import Foundation
import XCTest
@testable import OemerCore

/// The corrections made outside parity mode (`OMROptions.pythonParity == false`), each on a
/// small hand-made grand staff, mostly next to what the Python pipeline does.
///
/// Geometry: staff space 10 px. System 0: treble lines at y = 100…140 (F5 … E4), bass lines at
/// y = 200…240 (A3 … G2). System 1 (when used) is the same 300 px lower. Every 5 px is one step.
final class CorrectionTests: XCTestCase {
    // MARK: - Fixture

    final class Score {
        let ctx: OMRContext
        var treble: [Staff] = []
        var bass: [Staff] = []

        init(parity: Bool, systems: Int = 1, width: Int = 1000) throws {
            let height = 300 * systems + 100
            let z = Grid<Float>(width: width, height: height, repeating: 0)
            let classifiers = try XCTUnwrap(EndToEndTests.classifiers)
            ctx = OMRContext(staff: z, symbols: z, stemsRests: z, notehead: z, clefsKeys: z,
                             floatMaps: false, classifiers: classifiers, pythonParity: parity)
            var row: [Staff] = []
            for g in 0..<systems {
                let t = Score.staff(top: 100 + 300 * Double(g), x: 0...Double(width - 1), track: 0, group: g)
                let b = Score.staff(top: 200 + 300 * Double(g), x: 0...Double(width - 1), track: 1, group: g)
                treble.append(t)
                bass.append(b)
                row += [t, b]
            }
            setStaffs([row])
        }

        func setStaffs(_ grid: [[Staff]]) {
            ctx.staffLayout = StaffLayout(grid: grid, zones: [0..<ctx.width])
            ctx.staffsFlat = ctx.staffLayout.flat
        }

        static func staff(top: Double, x: ClosedRange<Double>, track: Int, group: Int) -> Staff {
            let st = Staff()
            for i in 0..<5 {
                let line = StaffLine()
                for px in stride(from: x.lowerBound, through: x.upperBound, by: 10) { line.addPoint(y: top + 10 * Double(i), x: px) }
                st.addLine(line)
            }
            st.track = track
            st.group = group
            return st
        }

        /// A quarter-note chord (one stem group) at `x` with noteheads centered at `ys`.
        @discardableResult
        func chord(x: Int, ys: [Int], track: Int, group: Int = 0, sfn: [SfnType?]? = nil) -> [NoteHead] {
            var made: [NoteHead] = []
            for (i, y) in ys.enumerated() {
                let n = NoteHead(bbox: BBox(x - 6, y - 4, x + 6, y + 4))
                n.track = track
                n.group = group
                let staff = track == 0 ? treble[group] : bass[group]
                n.staffLinePos = ctx.staffLinePosition(Double(y), on: staff)
                n.label = .quarter
                n.stemUp = true
                n.sfn = sfn?[i] ?? nil
                n.id = ctx.notes.count
                ctx.notes.append(n)
                made.append(n)
            }
            let g = NoteGroup()
            g.id = ctx.groups.count
            g.noteIds = made.map(\.id)
            g.track = track
            g.group = group
            g.stemUp = true
            g.hasStem = true
            g.bbox = BBox(x - 6, (ys.min() ?? 0) - 30, x + 6, (ys.max() ?? 0) + 4)
            ctx.groups.append(g)
            return made
        }

        /// An accidental glyph left of `x`, standing for the pitch at `pitchY`.
        @discardableResult
        func accidental(_ label: SfnType, x: Int, pitchY: Int, track: Int, group: Int = 0, boundTo note: NoteHead? = nil) -> Sfn {
            let s = Sfn(bbox: label == .flat ? BBox(x - 4, pitchY - 20, x + 4, pitchY + 5) : BBox(x - 4, pitchY - 12, x + 4, pitchY + 12))
            s.label = label
            s.track = track
            s.group = group
            let staff = track == 0 ? treble[group] : bass[group]
            s.linePos = ctx.staffLinePosition(Double(pitchY), on: staff)
            if let note = note {
                s.noteId = note.id
                note.sfn = label
            }
            ctx.sfns.append(s)
            return s
        }

        func barline(x: Int, group: Int = 0) {
            let b = Barline(bbox: BBox(x, 100 + 300 * group, x + 1, 240 + 300 * group))
            b.group = group
            ctx.barlines.append(b)
        }

        func transcribe() -> (xml: String, notes: [RecognizedNote]) {
            let builder = MusicXMLBuilder(ctx: ctx)
            builder.build()
            let xml = builder.toMusicXML(title: "Test")
            return (xml, builder.writtenNotes)
        }
    }

    static func fifths(_ xml: String) -> [Int] {
        xml.components(separatedBy: "<fifths>").dropFirst().compactMap { Int($0.prefix(while: { $0 != "<" })) }
    }

    // MARK: - Task 1: accidentals

    /// An accidental holds for its own staff and octave only. oemer shares one state for all
    /// staffs and octaves, so F#4 in the right hand turned the left hand's F3 and F5 sharp.
    func testAccidentalStaysOnItsStaffAndOctave() throws {
        for parity in [false, true] {
            let s = try Score(parity: parity)
            s.chord(x: 100, ys: [135], track: 0, sfn: [.sharp])  // F#4
            s.chord(x: 200, ys: [210], track: 1)                  // F3 (bass)
            s.chord(x: 300, ys: [135], track: 0)                  // F4 again
            s.chord(x: 400, ys: [100], track: 0)                  // F5
            let names = s.transcribe().notes.map(\.name)
            if parity {
                XCTAssertEqual(names, ["F#4", "F#3", "F#4", "F#5"], "oemer's behavior")
            } else {
                XCTAssertEqual(names, ["F#4", "F3", "F#4", "F5"])
            }
        }
    }

    /// The accidental search covers 2.5 staff spaces to the right and 0.75 above and below and
    /// prefers the notehead nearest the accidental's pitch; oemer scans one row for one space.
    func testAccidentalFindsNoteheadOffsetFromIt() throws {
        for parity in [false, true] {
            let s = try Score(parity: parity)
            // notehead (G4 area) 15 px right of the sharp and 9 px above its middle
            let n = NoteHead(bbox: BBox(119, 117, 131, 125))
            n.id = 0
            s.ctx.notes = [n]
            for y in 117...125 { for x in 119...131 { s.ctx.noteIdMap[y, x] = 0 } }
            let found = s.ctx.nearbyNoteId(BBox(96, 118, 104, 142), label: .sharp)
            XCTAssertEqual(found, parity ? nil : 0)
        }
    }

    func testAccidentalPicksTheChordToneAtItsHeight() throws {
        let s = try Score(parity: false)
        let a = NoteHead(bbox: BBox(110, 111, 122, 119))  // C5 (y 115)
        let b = NoteHead(bbox: BBox(110, 121, 122, 129))  // A4 (y 125)
        a.id = 0
        b.id = 1
        s.ctx.notes = [a, b]
        for (i, n) in [a, b].enumerated() {
            for y in n.bbox.y1...n.bbox.y2 { for x in n.bbox.x1...n.bbox.x2 { s.ctx.noteIdMap[y, x] = Int32(i) } }
        }
        XCTAssertEqual(s.ctx.nearbyNoteId(BBox(100, 113, 108, 137), label: .sharp), 1)  // centered at 125
        XCTAssertEqual(s.ctx.nearbyNoteId(BBox(100, 95, 108, 120), label: .flat), 0)    // bowl at 115
    }

    /// An accidental no note claimed alters the next note on its staff at its position.
    func testLooseAccidentalAltersTheNextNoteOfItsPitch() throws {
        for parity in [false, true] {
            let s = try Score(parity: parity)
            s.chord(x: 100, ys: [125], track: 0)                 // A4, before the sharp
            s.accidental(.sharp, x: 150, pitchY: 115, track: 0)  // sharp at C5, unbound
            s.chord(x: 180, ys: [125], track: 0)                 // A4
            s.chord(x: 220, ys: [115], track: 0)                 // C5
            let names = s.transcribe().notes.map(\.name)
            XCTAssertEqual(names, parity ? ["A4", "A4", "C5"] : ["A4", "A4", "C#5"])
        }
    }

    // MARK: - Task 2: key signatures

    /// Two flats on the treble staff, none read on the bass staff: oemer's check that the
    /// measure starts with one accidental per staff fails and the key is lost.
    func testKeyFromTheStaffThatShowsIt() throws {
        for parity in [false, true] {
            let s = try Score(parity: parity)
            s.accidental(.flat, x: 40, pitchY: 120, track: 0)  // Bb4
            s.accidental(.flat, x: 52, pitchY: 105, track: 0)  // Eb5
            s.chord(x: 100, ys: [105], track: 0)               // E5
            s.chord(x: 110, ys: [230], track: 1)               // B2
            let r = s.transcribe()
            XCTAssertEqual(Self.fifths(r.xml), parity ? [0] : [-2])
            XCTAssertEqual(r.notes.map(\.name), parity ? ["E5", "B2"] : ["Eb5", "Bb2"])
        }
    }

    /// The key read at the start of a later system is a reminder: a staff that lost an
    /// accidental there does not change the key.
    func testKeyPersistsOverWeakerReminder() throws {
        let s = try Score(parity: false, systems: 2)
        for (track, ys) in [(0, [120, 105]), (1, [230, 215])] {  // Bb Eb on both staffs
            for (i, y) in ys.enumerated() { s.accidental(.flat, x: 40 + 12 * i, pitchY: y, track: track) }
        }
        s.chord(x: 100, ys: [120], track: 0)
        s.chord(x: 100, ys: [230], track: 1)
        // system 1: only the Bb is read on each staff
        s.accidental(.flat, x: 40, pitchY: 420, track: 0, group: 1)
        s.accidental(.flat, x: 40, pitchY: 530, track: 1, group: 1)
        s.chord(x: 100, ys: [405], track: 0, group: 1)  // E5
        s.chord(x: 100, ys: [515], track: 1, group: 1)  // E3
        let r = s.transcribe()
        XCTAssertEqual(Self.fifths(r.xml), [-2], "no key change")
        XCTAssertEqual(r.notes.map(\.name), ["Bb4", "Bb2", "Eb5", "Eb3"])
    }

    /// A single accidental before the first note in the middle of a piece is a note's
    /// accidental, not a key change, unless every staff shows the key.
    func testLoneAccidentalIsNotAKeyChange() throws {
        let s = try Score(parity: false)
        s.chord(x: 100, ys: [125], track: 0)
        s.chord(x: 100, ys: [230], track: 1)
        s.barline(x: 300)
        s.accidental(.sharp, x: 340, pitchY: 100, track: 0)  // F5 position, like a one-sharp key
        s.chord(x: 380, ys: [100], track: 0)
        s.chord(x: 380, ys: [230], track: 1)
        let r = s.transcribe()
        XCTAssertEqual(Self.fifths(r.xml), [0])
        XCTAssertEqual(r.notes.map(\.name), ["A4", "B2", "F#5", "B2"])
    }

    func testKeyChangeShownOnEveryStaff() throws {
        let s = try Score(parity: false)
        s.chord(x: 100, ys: [125], track: 0)
        s.chord(x: 100, ys: [230], track: 1)
        s.barline(x: 300)
        s.accidental(.sharp, x: 340, pitchY: 100, track: 0)  // F#5
        s.accidental(.sharp, x: 340, pitchY: 210, track: 1)  // F#3
        s.chord(x: 380, ys: [135], track: 0)                 // F4
        s.chord(x: 380, ys: [230], track: 1)
        let r = s.transcribe()
        XCTAssertEqual(Self.fifths(r.xml), [0, 1])
        XCTAssertEqual(r.notes.map(\.name), ["A4", "B2", "F#4", "B2"])
    }

    // MARK: - Task 3: staffs of chord notes, clefs, staff lookup

    /// A chord read across two staffs keeps every note's pitch: the moved note is measured
    /// again on the staff the chord goes to (majority of its noteheads).
    func testChordMovedToOneStaffKeepsPitch() throws {
        let s = try Score(parity: false)
        let notes = s.chord(x: 100, ys: [225, 215, 165], track: 1)  // C3, E3, and a high note
        notes[2].track = 0  // as read: nearer the treble staff
        notes[2].staffLinePos = s.ctx.staffLinePosition(165, on: s.treble[0])
        let target = s.ctx.unifyStaff(of: notes.map(\.id))
        XCTAssertEqual(target.track, 1)
        XCTAssertEqual(notes.map(\.track), [1, 1, 1])
        XCTAssertEqual(notes[2].staffLinePos, 16)  // A4 on the bass staff, 3½ ledger lines up
        s.ctx.groups[0].track = 1
        XCTAssertEqual(s.transcribe().notes.map(\.name), ["C3", "E3", "A4"])
    }

    /// Without a detected clef the bass staff reads as bass.
    func testBassStaffDefaultsToFClef() throws {
        let s = try Score(parity: false)
        s.chord(x: 100, ys: [240], track: 1)
        XCTAssertEqual(s.transcribe().notes.map(\.name), ["G2"])
    }

    /// oemer measures the Euclidean distance to each staff segment's center, so a staff whose
    /// lines were detected over a shorter x range loses notes that are vertically nearer to it.
    func testStaffLookupIsVertical() throws {
        for parity in [false, true] {
            let s = try Score(parity: parity)
            let treble = Score.staff(top: 100, x: 0...999, track: 0, group: 0)
            let bass = Score.staff(top: 200, x: 0...400, track: 1, group: 0)
            s.setStaffs([[treble, bass]])
            let (st, _) = s.ctx.findClosestStaffs(380, 172)  // 3.2 spaces below treble, 2.8 above bass
            XCTAssertEqual(st.track, parity ? 0 : 1)
        }
    }

    // MARK: - Task 4: chord order

    func testChordWrittenLowestFirst() throws {
        for parity in [false, true] {
            let s = try Score(parity: parity)
            s.chord(x: 100, ys: [115, 140, 130], track: 0)  // C5, E4, G4 as detected
            let r = s.transcribe()
            XCTAssertEqual(r.notes.map(\.name), parity ? ["C5", "E4", "G4"] : ["E4", "G4", "C5"])
            XCTAssertEqual(Set(r.notes.map(\.chord)), [0], "one chord")
            let firstPitched = try XCTUnwrap(r.xml.components(separatedBy: "<note>").dropFirst().first { $0.contains("<pitch>") })
            XCTAssertFalse(firstPitched.contains("<chord"), "the chord's first note carries no <chord/>")
        }
    }

    /// A chord whose first note cannot be written (out of range) starts with its next note.
    func testChordStartsAfterUnwritableNote() throws {
        let s = try Score(parity: false, width: 1000)
        let notes = s.chord(x: 100, ys: [140, 130], track: 0)  // E4, G4
        notes[0].staffLinePos = -40  // far below the range of a piano
        let xml = s.transcribe().xml
        // (the builder fills the empty bass staff with a rest first)
        let firstPitched = try XCTUnwrap(xml.components(separatedBy: "<note>").dropFirst().first { $0.contains("<pitch>") })
        XCTAssertFalse(firstPitched.contains("<chord"))
        XCTAssertTrue(firstPitched.contains("<step>G</step>"))
    }

    // MARK: - Real pages

    /// The saved model outputs of the end-to-end fixtures, read with the corrections: nothing
    /// fails, no note is lost, the key is the one oemer reads and never changes (each page is in
    /// one key), and every chord is written from its lowest note up.
    func testFixturesWithCorrections() throws {
        let dir = EndToEndTests.packageDir.appendingPathComponent("Tests/OemerCoreTests/Fixtures")
        let classifiers = try XCTUnwrap(EndToEndTests.classifiers)
        let expectedKey = ["tabi_nodeskew": 4, "tabi_deskew": 4, "clean_piano_nodeskew": -1, "photo_piano_deskew": -2]
        for (name, key) in expectedKey {
            let (maps, deskew) = try EndToEndTests.loadMaps(dir.appendingPathComponent("\(name).omrmaps"))
            let parity = try OMREngine.transcribe(maps, classifiers: classifiers,
                                                  options: OMROptions(deskew: deskew, pythonParity: true))
            let fixed = try OMREngine.transcribe(maps, classifiers: classifiers, options: OMROptions(deskew: deskew))
            XCTAssertGreaterThanOrEqual(fixed.notes.count, parity.notes.count, name)
            XCTAssertEqual(Self.fifths(fixed.musicXML), [key], name)
            var unsorted = 0
            for (_, chord) in Dictionary(grouping: fixed.notes, by: \.chord) where chord.count > 1 {
                let midi = chord.map(Self.midi)
                if midi != midi.sorted() { unsorted += 1 }
            }
            XCTAssertEqual(unsorted, 0, name)
        }
    }

    static func midi(_ n: RecognizedNote) -> Int {
        let semi = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11][n.step] ?? 0
        return (n.octave + 1) * 12 + semi + n.alter
    }

    // MARK: - Helpers

    func testStaffLinePosition() throws {
        let s = try Score(parity: false)
        let positions = [140, 135, 130, 100, 95, 145, 150, 160].map { s.ctx.staffLinePosition(Double($0), on: s.treble[0]) }
        XCTAssertEqual(positions, [1, 2, 3, 9, 10, 0, -1, -3])
    }
}
