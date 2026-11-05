import Foundation

// MARK: - ScoreTimeline
//
// The score as Animation, Play Along and the sheet view use it, parsed once from the score JSON
// (MusicXML run through `MusicXMLDocument.jsonObject`; Discover songs use the same shape).
//
// Per note: pitch, staff, voice, written value (type + dots), stem, beams, ties, slurs,
// tuplets, articulations, fermatas, accidentals, grace / rest / chord flags, the clef in effect,
// any 8va / 8vb line over it, its loudness (from dynamics, hairpins and accents) and its
// position in the original engraving (`default-x`). Per measure: its own length (time
// signature, pickup or content), key, time signature, clefs, line breaks (`<print
// new-system>`), its original width, barlines, repeats, endings and D.C. / D.S. / Fine / Coda.
//
// Time: tempo marks (sound, metronome, or Italian tempo words) and fermatas make the written
// time map. The performance (repeats taken, endings chosen, D.C. / D.S. followed) has its own
// time map; Animation plays that, Play Along and the sheet use written ticks.
//
// Timing inside a measure: when the JSON keeps each measure's element order (`#order`,
// written by MusicXMLDocument) notes, <backup> and <forward> are replayed the way MusicXML
// defines them. Older JSON falls back to one running position per staff and voice. All ticks
// are rescaled to one resolution (`ticksPerQuarter`).

nonisolated enum NoteValue: Int, Comparable, Sendable {
    case breve = 0, whole, half, quarter, eighth, sixteenth, thirtySecond, sixtyFourth

    static func < (a: NoteValue, b: NoteValue) -> Bool { a.rawValue < b.rawValue }

    init?(musicXMLType type: String) {
        switch type {
        case "breve", "long", "maxima": self = .breve
        case "whole":                   self = .whole
        case "half":                    self = .half
        case "quarter":                 self = .quarter
        case "eighth":                  self = .eighth
        case "16th":                    self = .sixteenth
        case "32nd":                    self = .thirtySecond
        case "64th", "128th", "256th":  self = .sixtyFourth
        default:                        return nil
        }
    }

    /// Length in quarter notes, without dots.
    var quarters: Double { pow(2, Double(NoteValue.quarter.rawValue - rawValue)) }
    /// Flags (or beams) the value carries: eighth 1, 16th 2, …
    var flagCount: Int { max(0, rawValue - NoteValue.quarter.rawValue) }
    var isHollow: Bool { self <= .half }
    var hasStem: Bool { self >= .half }

    /// The written value closest to a duration, for notes and rests without a <type>.
    static func closest(toQuarters q: Double) -> (value: NoteValue, dots: Int) {
        guard q > 0 else { return (.quarter, 0) }
        var best: (NoteValue, Int) = (.quarter, 0)
        var bestError = Double.infinity
        for raw in 0...7 {
            guard let value = NoteValue(rawValue: raw) else { continue }
            for dots in 0...2 {
                let length = value.quarters * (2 - pow(0.5, Double(dots)))
                let error = abs(log2(length / q))
                if error < bestError - 1e-9 { bestError = error; best = (value, dots) }
            }
        }
        return best
    }
}

nonisolated struct ScoreClef: Equatable, Sendable {
    let sign: String
    let line: Int
    let octaveChange: Int

    static let treble = ScoreClef(sign: "G", line: 2, octaveChange: 0)
    static let bass   = ScoreClef(sign: "F", line: 4, octaveChange: 0)

    var isBass: Bool { sign == "F" }

    /// Diatonic index (octave × 7 + step, C = 0) of the bottom staff line.
    var bottomLineDiatonic: Int {
        let reference: Int
        switch sign {
        case "F": reference = 3 * 7 + 3   // F3
        case "C": reference = 4 * 7       // C4
        default:  reference = 4 * 7 + 4   // G4 (also percussion / TAB)
        }
        return reference - 2 * (line - 1) + 7 * octaveChange
    }
}

nonisolated struct ScoreTimeSignature: Equatable, Sendable {
    let beats: Int
    let beatType: Int

    func ticks(ticksPerQuarter tpq: Int) -> Int {
        Int((Double(beats) * 4 / Double(max(beatType, 1)) * Double(tpq)).rounded())
    }

    /// The span one beam group may cover: a dotted quarter in compound time, else one beat.
    func beamSpan(ticksPerQuarter tpq: Int) -> Int {
        if beatType >= 8 && beats % 3 == 0 { return tpq * 3 / 2 * 8 / beatType }
        return max(1, tpq * 4 / max(beatType, 1))
    }
}

nonisolated struct ScoreNote: Sendable {
    enum Accidental: Sendable { case sharp, flat, natural, doubleSharp, doubleFlat }
    enum Stem: Sendable { case up, down, none }
    enum Articulation: Sendable { case staccato, staccatissimo, spiccato, tenuto, detachedLegato, accent, strongAccent }
    struct Tuplet: Equatable, Sendable { let actual: Int; let normal: Int }

    let measureIndex: Int
    let staff: Int                 // 1 = treble / right hand, 2 = bass / left hand
    let voice: String
    let startTick: Int
    let durationTicks: Int         // as written
    /// How long the note sounds, through any ties. 0 for a note that continues a tie.
    fileprivate(set) var soundingTicks: Int
    let step: String?
    let octave: Int?
    let alter: Int
    let isRest: Bool
    fileprivate(set) var isMeasureRest: Bool
    let isGrace: Bool
    let isChordTone: Bool          // <chord/>: shares the previous note's start
    /// False for `print-object="no"`: played, not drawn.
    let isPrinted: Bool
    let value: NoteValue
    let dots: Int
    let stem: Stem?
    let tieStart: Bool
    let tieStop: Bool
    let articulations: Set<Articulation>
    let hasFermata: Bool
    /// From <time-modification>: `actual` notes in the time of `normal`.
    let tuplet: Tuplet?
    /// Where the original engraving put the note, in tenths from the measure's start.
    let defaultX: Double?
    /// The accidental to print: as written, or worked out from the key and the measure.
    fileprivate(set) var accidental: Accidental?
    /// Notes (chord tones included) sharing a beam have the same group.
    fileprivate(set) var beamGroup: Int?
    /// Diatonic steps the note is printed away from its pitch (under an 8va / 8vb line).
    fileprivate(set) var displayShift: Int
    /// MIDI velocity from the dynamics, hairpins and accents in force.
    fileprivate(set) var velocity: Int
    /// Under a slur (and not its last note): played legato.
    fileprivate(set) var isLegato: Bool
    let clef: ScoreClef
    /// Staff position for rests that give a <display-step>.
    let restDiatonic: Int?

    fileprivate let writtenAccidental: Accidental?
    fileprivate let beamText: String?
    fileprivate let restIsMarkedMeasure: Bool
    fileprivate let slurMarks: [SpanMark]
    fileprivate let tupletMarks: [SpanMark]
    fileprivate let dynamicsPercent: Double?

    var isLeftHand: Bool { staff >= 2 }
    var endTick: Int { startTick + durationTicks }
    var soundingEndTick: Int { startTick + soundingTicks }
    var isStruck: Bool { !isRest && !isGrace && soundingTicks > 0 && midi != nil }

    var diatonic: Int? {
        guard let step, let octave, let i = ScoreNote.steps.firstIndex(of: step) else { return nil }
        return octave * 7 + i
    }

    /// Where it is printed on the staff (an octave line moves it).
    var displayDiatonic: Int? { diatonic.map { $0 + displayShift } }

    var midi: Int? {
        guard let step, let octave, let i = ScoreNote.steps.firstIndex(of: step) else { return nil }
        let midi = 12 * (octave + 1) + ScoreNote.semitones[i] + alter
        return (0...127).contains(midi) ? midi : nil
    }

    /// Share of its length the note is held when its articulation says so: staccato and its
    /// relatives shorten it, tenuto and slurs hold it fully. Nil means ordinary playing.
    var heldFraction: Double? {
        if articulations.contains(.staccatissimo) { return 0.3 }
        if articulations.contains(.spiccato) { return 0.4 }
        if articulations.contains(.staccato) { return 0.5 }
        if articulations.contains(.detachedLegato) { return 0.75 }
        if articulations.contains(.tenuto) || isLegato { return 1 }
        return nil
    }

    /// The name as written: "F#4", "Bb3".
    var writtenName: String? {
        guard let step, let octave else { return nil }
        let mark: String
        switch alter {
        case 2:  mark = "##"
        case 1:  mark = "#"
        case -1: mark = "b"
        case -2: mark = "bb"
        default: mark = ""
        }
        return "\(step)\(mark)\(octave)"
    }

    /// The piano key's name ("C#4", sharps only), so E#, Cb or double sharps find their key.
    var keyName: String? { midi.map(ScoreNote.keyName(midi:)) }

    static func keyName(midi: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return "\(names[midi % 12])\(midi / 12 - 1)"
    }

    static let steps = ["C", "D", "E", "F", "G", "A", "B"]
    fileprivate static let semitones = [0, 2, 4, 5, 7, 9, 11]
}

/// A <slur> or <tuplet> end as written on a note.
nonisolated fileprivate struct SpanMark: Sendable {
    let number: Int
    let type: String
    let above: Bool?
    let bracket: Bool?
}

nonisolated struct ScoreNavigation: OptionSet, Sendable {
    let rawValue: Int
    static let segno    = ScoreNavigation(rawValue: 1 << 0)
    static let coda     = ScoreNavigation(rawValue: 1 << 1)
    static let toCoda   = ScoreNavigation(rawValue: 1 << 2)
    static let daCapo   = ScoreNavigation(rawValue: 1 << 3)
    static let dalSegno = ScoreNavigation(rawValue: 1 << 4)
    static let fine     = ScoreNavigation(rawValue: 1 << 5)
}

nonisolated struct ScoreMeasure: Sendable {
    let index: Int
    let number: String
    let startTick: Int
    let lengthTicks: Int
    let keyFifths: Int
    let time: ScoreTimeSignature?
    /// Clef of each staff at the measure's start (index 0 = staff 1).
    let clefs: [ScoreClef]
    let keyChanged: Bool
    let timeChanged: Bool
    /// The original starts a new line (system) here.
    let startsNewSystem: Bool
    /// The measure's width in the original engraving, in tenths.
    let widthTenths: Double?
    let repeatStart: Bool
    let repeatEnd: Bool
    let repeatTimes: Int
    /// The volta (1st / 2nd ending) this measure belongs to; empty outside endings.
    let endingNumbers: [Int]
    let endingStarts: Bool
    /// The ending closes here (a hook down) or just stops ("discontinue").
    let endingStops: Bool
    let endingClosed: Bool
    let endingText: String?
    /// Part of the last ending of its group (the one played after a D.C. / D.S.).
    fileprivate(set) var endingIsLast: Bool
    /// "light-heavy" (final), "light-light" (double), … at the measure's end.
    let rightBarStyle: String?
    let navigation: ScoreNavigation

    var endTick: Int { startTick + lengthTicks }
}

nonisolated struct ScoreClefChange: Sendable {
    let tick: Int
    let staff: Int
    let clef: ScoreClef
}

nonisolated struct TempoMark: Sendable {
    let tick: Int
    let bpm: Double                // quarter notes per minute
}

/// Markings printed above or below a staff.
nonisolated struct ScoreDirection: Sendable {
    enum Kind: Sendable {
        case dynamic(String)
        case words(String)
        case metronome(beat: NoteValue, dots: Int, perMinute: Double)
        case wedge(crescendo: Bool, endTick: Int)
        /// `down`: printed an octave (or two) lower than it sounds, under an "8va" line.
        case octaveShift(size: Int, down: Bool, endTick: Int)
        case segno
        case coda
    }

    let tick: Int
    let staff: Int
    let above: Bool
    let kind: Kind
}

nonisolated struct ScoreSlur: Sendable {
    let from: Int                  // note indices
    let to: Int
    let above: Bool?
}

nonisolated struct ScoreTuplet: Sendable {
    let notes: [Int]               // the group's notes and rests (one per onset), in order
    let actual: Int
    let above: Bool?
    let bracket: Bool?
}

nonisolated struct PerformedMeasure: Sendable {
    let measureIndex: Int
    let tick: Int                  // where it starts in the performance
}

/// Ticks ↔ seconds through a list of tempo changes.
nonisolated struct TimeMap: Sendable {
    struct Segment: Sendable { let tick: Double; let seconds: Double; let bpm: Double }

    let ticksPerQuarter: Double
    let segments: [Segment]

    /// `marks` sorted by tick; the first one should be at 0.
    init(marks: [(tick: Double, bpm: Double)], ticksPerQuarter: Int) {
        self.ticksPerQuarter = Double(max(1, ticksPerQuarter))
        var segments: [Segment] = []
        for mark in marks where (mark.bpm > 0) {
            if let last = segments.last {
                if mark.tick <= last.tick {
                    segments[segments.count - 1] = Segment(tick: last.tick, seconds: last.seconds, bpm: mark.bpm)
                    continue
                }
                if mark.bpm == last.bpm { continue }
                let seconds = last.seconds + (mark.tick - last.tick) / self.ticksPerQuarter * 60 / last.bpm
                segments.append(Segment(tick: mark.tick, seconds: seconds, bpm: mark.bpm))
            } else {
                segments.append(Segment(tick: mark.tick, seconds: 0, bpm: mark.bpm))
            }
        }
        if segments.isEmpty { segments = [Segment(tick: 0, seconds: 0, bpm: 84)] }
        self.segments = segments
    }

    func bpm(atTick tick: Double) -> Double { segments[index(tick: tick)].bpm }

    func seconds(atTick tick: Double) -> Double {
        let s = segments[index(tick: tick)]
        return s.seconds + (tick - s.tick) / ticksPerQuarter * 60 / s.bpm
    }

    func tick(atSeconds seconds: Double) -> Double {
        var lo = 0, hi = segments.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if segments[mid].seconds <= seconds { lo = mid } else { hi = mid - 1 }
        }
        let s = segments[lo]
        return s.tick + (seconds - s.seconds) * s.bpm / 60 * ticksPerQuarter
    }

    private func index(tick: Double) -> Int {
        var lo = 0, hi = segments.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if segments[mid].tick <= tick { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }
}

nonisolated struct ScoreTimeline: Sendable {
    let ticksPerQuarter: Int
    let staffCount: Int
    let measures: [ScoreMeasure]
    /// Sorted by start; at one start grace notes first, then by staff and pitch.
    let notes: [ScoreNote]
    /// Tempo marks as written (sound, metronome or tempo words).
    let tempos: [TempoMark]
    /// Clef changes inside measures (changes at a measure start are in `ScoreMeasure.clefs`).
    let clefChanges: [ScoreClefChange]
    let directions: [ScoreDirection]
    let slurs: [ScoreSlur]
    let tuplets: [ScoreTuplet]
    /// True when every measure kept its element order, so backups and forwards were exact.
    let keepsElementOrder: Bool
    /// Written ticks ↔ seconds: tempo marks, with fermatas held longer.
    let writtenTime: TimeMap
    /// The measures in the order they are played.
    let performance: [PerformedMeasure]
    /// Performance ticks ↔ seconds.
    let performanceTime: TimeMap

    var totalTicks: Int { measures.last?.endTick ?? 0 }
    var totalSeconds: Double { seconds(atTick: Double(totalTicks)) }

    /// Notes that make a sound: no rests, grace notes or tie continuations.
    var struckNotes: [ScoreNote] { notes.filter(\.isStruck) }

    func seconds(atTick tick: Double) -> Double { writtenTime.seconds(atTick: tick) }
    func tick(atSeconds seconds: Double) -> Double { writtenTime.tick(atSeconds: seconds) }

    var performanceTicks: Int {
        guard let last = performance.last else { return 0 }
        return last.tick + measures[last.measureIndex].lengthTicks
    }

    var performanceSeconds: Double { performanceTime.seconds(atTick: Double(performanceTicks)) }

    /// The written tick being played at a performance tick.
    func scoreTick(atPerformanceTick tick: Double) -> Double {
        guard !performance.isEmpty else { return tick }
        var lo = 0, hi = performance.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if Double(performance[mid].tick) <= tick { lo = mid } else { hi = mid - 1 }
        }
        let measure = measures[performance[lo].measureIndex]
        let offset = max(0, min(tick - Double(performance[lo].tick), Double(measure.lengthTicks)))
        return Double(measure.startTick) + offset
    }

    /// The measure playing at `tick` (the first or last one outside the score).
    func measureIndex(atTick tick: Double) -> Int {
        guard !measures.isEmpty else { return 0 }
        var lo = 0, hi = measures.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if Double(measures[mid].startTick) <= tick { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }
}

// MARK: - Parsing

extension ScoreTimeline {
    enum ParseError: Error {
        case invalidJSON
        case noMeasures
    }

    nonisolated static func parse(data: Data, defaultTempoBPM: Double = 84,
                                  defaultDivisions: Int = 6) throws -> ScoreTimeline {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParseError.invalidJSON
        }
        return try parse(root: root, defaultTempoBPM: defaultTempoBPM, defaultDivisions: defaultDivisions)
    }

    nonisolated static func parse(root: [String: Any], defaultTempoBPM: Double = 84,
                                  defaultDivisions: Int = 6) throws -> ScoreTimeline {
        let parts = RawPart.all(in: root)
        guard !parts.isEmpty else { throw ParseError.noMeasures }
        var builder = TimelineBuilder(parts: parts, defaultTempo: defaultTempoBPM,
                                      defaultDivisions: defaultDivisions)
        return builder.build()
    }

    /// Quarter notes per minute for a tempo word ("Allegro", "Andante con moto", "Alla marcia").
    nonisolated static func tempo(forWords text: String) -> Double? {
        let lower = text.lowercased()
        // longer words first, so "allegretto" is not read as "allegro"
        let terms: [(String, Double)] = [
            ("prestissimo", 200), ("presto", 176), ("vivacissimo", 172), ("vivace", 156),
            ("allegretto", 116), ("allegro", 132), ("moderato", 112), ("marcia", 108),
            ("andantino", 100), ("andante", 92), ("adagietto", 74), ("adagio", 70),
            ("larghetto", 60), ("largo", 50), ("lento", 56), ("grave", 40)
        ]
        return terms.first { lower.contains($0.0) }?.1
    }
}

/// Reads values from the xmltodict-style JSON: repeated children are arrays, empty elements
/// are `null`, text next to attributes is `#text`.
nonisolated private enum J {
    static func list(_ value: Any?) -> [Any] {
        guard let value, !(value is NSNull) else { return [] }
        return value as? [Any] ?? [value]
    }

    static func dicts(_ value: Any?) -> [[String: Any]] { list(value).compactMap { $0 as? [String: Any] } }

    /// How many times an element occurs (`<dot/>` is `null`, two dots are `[null, null]`).
    static func count(_ value: Any?) -> Int {
        guard let value else { return 0 }
        return (value as? [Any])?.count ?? 1
    }

    /// Names of an element's children (`<articulations><staccato/></articulations>`).
    static func childNames(_ value: Any?) -> [String] {
        list(value).flatMap { item -> [String] in
            guard let d = item as? [String: Any] else { return [] }
            return d.keys.filter { !$0.hasPrefix("@") && !$0.hasPrefix("#") }
        }
    }

    static func string(_ value: Any?) -> String? {
        switch value {
        case let s as String:        return s.trimmingCharacters(in: .whitespaces)
        case let n as NSNumber:      return n.stringValue
        case let d as [String: Any]: return string(d["#text"])
        case let a as [Any]:         return string(a.first)
        default:                     return nil
        }
    }

    static func double(_ value: Any?) -> Double? {
        if let n = value as? NSNumber, !(value is String) { return n.doubleValue }
        return string(value).flatMap(Double.init)
    }

    static func int(_ value: Any?) -> Int? { double(value).map { Int($0.rounded()) } }

    static func placement(_ d: [String: Any]) -> Bool? {
        J.string(d["@placement"]).map { $0 == "above" }
    }
}

nonisolated private struct RawPart {
    let measures: [[String: Any]]
    let sounds: [[String: Any]]

    static func all(in root: [String: Any]) -> [RawPart] {
        if let score = root["score-partwise"] as? [String: Any] {
            let parts = J.dicts(score["part"])
                .map { RawPart(measures: J.dicts($0["measure"]), sounds: J.dicts($0["sound"])) }
                .filter { !$0.measures.isEmpty }
            if !parts.isEmpty { return parts }
        }
        if let holder = firstMeasureHolder(in: root) {
            return [RawPart(measures: J.dicts(holder["measure"]), sounds: J.dicts(holder["sound"]))]
        }
        return []
    }

    private static func firstMeasureHolder(in dict: [String: Any]) -> [String: Any]? {
        if !J.dicts(dict["measure"]).isEmpty { return dict }
        for (_, value) in dict {
            for child in J.dicts(value) {
                if let found = firstMeasureHolder(in: child) { return found }
            }
        }
        return nil
    }
}

/// One note as read from a part, before the measures are laid end to end.
nonisolated private struct PendingNote {
    var offset: Int
    var duration: Int
    var staff: Int
    var voice: String
    var step: String?
    var octave: Int?
    var alter = 0
    var unpitched = false
    var isRest: Bool
    var restMarkedMeasure = false
    var restDiatonic: Int?
    var isGrace: Bool
    var isChord: Bool
    var isPrinted = true
    var value: NoteValue = .quarter
    var dots: Int
    var stem: ScoreNote.Stem?
    var beamText: String?
    var tieStart = false
    var tieStop = false
    var accidental: ScoreNote.Accidental?
    var articulations: Set<ScoreNote.Articulation> = []
    var fermata = false
    var tuplet: ScoreNote.Tuplet?
    var slurMarks: [SpanMark] = []
    var tupletMarks: [SpanMark] = []
    var defaultX: Double?
    var dynamicsPercent: Double?
    var clef: ScoreClef
}

/// A direction as read from a part; spans (hairpins, octave lines) are paired up later.
nonisolated private struct PendingDirection {
    enum Kind {
        case dynamic(String)
        case words(String)
        case metronome(NoteValue, Int, Double)
        case wedgeStart(crescendo: Bool, number: Int)
        case wedgeStop(number: Int)
        case octaveStart(size: Int, down: Bool, number: Int)
        case octaveStop(number: Int)
        case segno
        case coda
    }
    let offset: Int                // -1: the end of the measure (position unknown)
    let staff: Int
    let above: Bool
    let kind: Kind
}

nonisolated private struct PartMeasure {
    var number = ""
    var notes: [PendingNote] = []
    var contentTicks = 0
    var isImplicit = false
    var keyFifths = 0
    var time: ScoreTimeSignature?
    var clefsAtStart: [Int: ScoreClef] = [:]
    var midMeasureClefs: [(offset: Int, staff: Int, clef: ScoreClef)] = []
    var tempos: [(offset: Int, bpm: Double)] = []
    var wordTempos: [(offset: Int, bpm: Double)] = []
    var dynamics: [(offset: Int, velocity: Int)] = []
    var sforzandos: [Int] = []
    var directions: [PendingDirection] = []
    var keptOrder = false
    var newSystem = false
    var widthTenths: Double?
    var repeatStart = false
    var repeatEnd = false
    var repeatTimes = 2
    var endingStart: [Int]?
    var endingText: String?
    var endingStop: Bool?          // true: closed ("stop"), false: open ("discontinue")
    var rightBarStyle: String?
    var navigation: ScoreNavigation = []
}

nonisolated private struct PartState {
    var divisions: Int
    var keyFifths = 0
    var time: ScoreTimeSignature?
    var clefs: [Int: ScoreClef] = [:]
    var staves = 1
}

nonisolated private struct TimelineBuilder {
    let parts: [RawPart]
    let defaultTempo: Double
    let defaultDivisions: Int
    let tpq: Int

    /// Velocities for dynamic marks (MIDI 0–127).
    static let dynamicLevels: [String: Int] = [
        "pppppp": 16, "ppppp": 20, "pppp": 24, "ppp": 32, "pp": 44, "p": 56, "mp": 70,
        "mf": 84, "f": 98, "ff": 110, "fff": 120, "ffff": 127, "fffff": 127, "ffffff": 127
    ]
    static let sforzandoMarks: Set<String> = ["sf", "sfz", "sffz", "fz", "rf", "rfz", "sfp", "sfpp", "fp"]
    static let defaultVelocity = 84

    init(parts: [RawPart], defaultTempo: Double, defaultDivisions: Int) {
        self.parts = parts
        self.defaultTempo = (10...400).contains(defaultTempo) ? defaultTempo : 84
        self.defaultDivisions = max(1, defaultDivisions)
        var divisions = Set<Int>()
        for part in parts {
            for measure in part.measures {
                for attributes in J.dicts(measure["attributes"]) {
                    if let d = J.int(attributes["divisions"]), d > 0 { divisions.insert(d) }
                }
            }
        }
        if divisions.isEmpty { divisions.insert(self.defaultDivisions) }
        // one resolution every <divisions> divides; capped so odd values can't explode it
        var common = 1
        for d in divisions { common = common / Self.gcd(common, d) * d }
        tpq = common <= 10080 ? common : 10080
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }

    mutating func build() -> ScoreTimeline {
        let readParts = parts.map(read(part:))
        let staffCounts = readParts.map { measures in
            max(1, measures.flatMap(\.notes).map(\.staff).max() ?? 1)
        }
        let totalStaves = staffCounts.reduce(0, +)
        // more than a grand staff (several parts, organ, …): each staff goes to the treble or
        // bass staff by its clef; a piano learner reads one grand staff
        let byClef = totalStaves > 2
        var staffOffsets: [Int] = []
        var offset = 0
        for count in staffCounts { staffOffsets.append(offset); offset += count }
        let staffCount = byClef ? 2 : max(1, totalStaves)

        let measureCount = readParts.map(\.count).max() ?? 0
        var measures: [ScoreMeasure] = []
        var notes: [ScoreNote] = []
        var tempos: [TempoMark] = []
        var clefChanges: [ScoreClefChange] = []
        var dynamicMarks: [(tick: Int, velocity: Int)] = []
        var sforzandos = Set<Int>()
        var pendingDirections: [(tick: Int, measureEnd: Int, staff: Int, direction: PendingDirection)] = []
        var start = 0
        var previousLength: Int?
        var previousKey: Int?
        var previousTime: ScoreTimeSignature?
        var previousClefs: [ScoreClef]?
        var keptOrder = true
        var openEnding: (numbers: [Int], text: String?)?

        for part in parts {
            for sound in part.sounds {
                if let bpm = J.double(sound["@tempo"]) { tempos.append(TempoMark(tick: 0, bpm: bpm)) }
                if let dynamics = J.double(sound["@dynamics"]) {
                    dynamicMarks.append((0, Self.velocity(percent: dynamics)))
                }
            }
        }

        for index in 0..<measureCount {
            let pieces = readParts.compactMap { index < $0.count ? $0[index] : nil }
            guard let lead = pieces.first else { continue }
            keptOrder = keptOrder && pieces.allSatisfy(\.keptOrder)

            let content = pieces.map(\.contentTicks).max() ?? 0
            let expected = lead.time?.ticks(ticksPerQuarter: tpq)
            let length: Int
            if pieces.contains(where: \.isImplicit) && content > 0 {
                length = content                                  // pickup / incomplete measure
            } else if let expected, expected > 0 {
                length = max(expected, content)                   // never cut notes off
            } else if content > 0 {
                length = content                                  // no time signature (OMR)
            } else {
                length = previousLength ?? tpq * 4
            }

            var clefs: [ScoreClef] = []
            if byClef {
                clefs = [.treble, .bass]
            } else {
                for (p, piece) in readParts.enumerated() where index < piece.count {
                    for s in 1...staffCounts[p] {
                        clefs.append(piece[index].clefsAtStart[s] ?? (s == 1 ? .treble : .bass))
                    }
                }
            }

            if let numbers = pieces.lazy.compactMap(\.endingStart).first {
                openEnding = (numbers, pieces.lazy.compactMap(\.endingText).first)
            }
            let endingStop = pieces.lazy.compactMap(\.endingStop).first
            let tempoWordsOnly = pieces.allSatisfy { $0.tempos.isEmpty }

            measures.append(ScoreMeasure(
                index: index,
                number: lead.number.isEmpty ? String(index + 1) : lead.number,
                startTick: start,
                lengthTicks: length,
                keyFifths: lead.keyFifths,
                time: lead.time,
                clefs: clefs,
                keyChanged: previousKey.map { $0 != lead.keyFifths } ?? (lead.keyFifths != 0),
                timeChanged: lead.time != nil && lead.time != previousTime,
                startsNewSystem: index > 0 && pieces.contains(where: \.newSystem),
                widthTenths: pieces.count == 1 ? lead.widthTenths : nil,
                repeatStart: pieces.contains(where: \.repeatStart),
                repeatEnd: pieces.contains(where: \.repeatEnd),
                repeatTimes: pieces.map(\.repeatTimes).max() ?? 2,
                endingNumbers: openEnding?.numbers ?? [],
                endingStarts: pieces.contains { $0.endingStart != nil },
                endingStops: endingStop != nil,
                endingClosed: endingStop == true,
                endingText: openEnding?.text,
                endingIsLast: false,
                rightBarStyle: lead.rightBarStyle,
                navigation: pieces.reduce(into: ScoreNavigation()) { $0.formUnion($1.navigation) }
            ))
            if endingStop != nil { openEnding = nil }
            if let previousClefs, previousClefs != clefs, !byClef {
                for (s, clef) in clefs.enumerated() where s < previousClefs.count && previousClefs[s] != clef {
                    clefChanges.append(ScoreClefChange(tick: start, staff: s + 1, clef: clef))
                }
            }

            for (p, piece) in readParts.enumerated() where index < piece.count {
                let measure = piece[index]
                func globalStaff(_ local: Int, _ clef: ScoreClef) -> Int {
                    byClef ? (clef.isBass ? 2 : 1) : staffOffsets[p] + local
                }
                for pending in measure.notes {
                    let staff = globalStaff(pending.staff, pending.clef)
                    notes.append(ScoreNote(
                        measureIndex: index,
                        staff: staff,
                        voice: "\(p)-\(pending.voice)",
                        startTick: start + pending.offset,
                        durationTicks: pending.duration,
                        soundingTicks: pending.duration,
                        step: pending.step,
                        octave: pending.octave,
                        alter: pending.alter,
                        isRest: pending.isRest || pending.unpitched && pending.step == nil,
                        isMeasureRest: false,
                        isGrace: pending.isGrace,
                        isChordTone: pending.isChord,
                        isPrinted: pending.isPrinted,
                        value: pending.value,
                        dots: pending.dots,
                        stem: pending.stem,
                        tieStart: pending.tieStart,
                        tieStop: pending.tieStop,
                        articulations: pending.articulations,
                        hasFermata: pending.fermata,
                        tuplet: pending.tuplet,
                        defaultX: pending.defaultX,
                        accidental: nil,
                        beamGroup: nil,
                        displayShift: 0,
                        velocity: Self.defaultVelocity,
                        isLegato: false,
                        clef: byClef ? (staff == 2 ? .bass : .treble) : pending.clef,
                        restDiatonic: pending.restDiatonic,
                        writtenAccidental: pending.accidental,
                        beamText: pending.beamText,
                        restIsMarkedMeasure: pending.restMarkedMeasure,
                        slurMarks: pending.slurMarks,
                        tupletMarks: pending.tupletMarks,
                        dynamicsPercent: pending.dynamicsPercent
                    ))
                }
                for change in measure.midMeasureClefs where !byClef {
                    clefChanges.append(ScoreClefChange(tick: start + change.offset,
                                                       staff: globalStaff(change.staff, change.clef),
                                                       clef: change.clef))
                }
                for mark in measure.tempos { tempos.append(TempoMark(tick: start + mark.offset, bpm: mark.bpm)) }
                if tempoWordsOnly {
                    for mark in measure.wordTempos { tempos.append(TempoMark(tick: start + mark.offset, bpm: mark.bpm)) }
                }
                for mark in measure.dynamics { dynamicMarks.append((start + mark.offset, mark.velocity)) }
                for mark in measure.sforzandos { sforzandos.insert(start + mark) }
                for direction in measure.directions {
                    let staff = byClef ? direction.staff : staffOffsets[p] + direction.staff
                    let tick = direction.offset < 0 ? start + length : start + direction.offset
                    pendingDirections.append((tick, start + length, staff, direction))
                }
            }

            previousLength = length
            previousKey = lead.keyFifths
            previousTime = lead.time ?? previousTime
            previousClefs = clefs
            start += length
        }

        markLastEndings(&measures)

        notes.sort { a, b in
            if a.startTick != b.startTick { return a.startTick < b.startTick }
            if a.isGrace != b.isGrace { return a.isGrace }
            if a.staff != b.staff { return a.staff < b.staff }
            return (a.diatonic ?? 0) < (b.diatonic ?? 0)
        }
        let directions = pairDirections(pendingDirections, end: start)
        finishRests(&notes, measures: measures)
        mergeTies(&notes)
        applyOctaveShifts(&notes, directions: directions)
        assignAccidentals(&notes, measures: measures)
        assignBeams(&notes, measures: measures)
        let slurs = pairSlurs(&notes)
        let tuplets = groupTuplets(notes)
        assignVelocities(&notes, marks: dynamicMarks, sforzandos: sforzandos, directions: directions)

        let tempoMarks = tempoMap(tempos, firstMeasureEnd: measures.first?.endTick ?? 0)
        let written = writtenTimeMap(tempoMarks, notes: notes)
        let performance = perform(measures)
        let performed = performanceTimeMap(performance, measures: measures, written: written)

        return ScoreTimeline(ticksPerQuarter: tpq, staffCount: staffCount, measures: measures, notes: notes,
                             tempos: tempoMarks,
                             clefChanges: clefChanges.sorted { $0.tick < $1.tick },
                             directions: directions, slurs: slurs, tuplets: tuplets,
                             keepsElementOrder: keptOrder,
                             writtenTime: written, performance: performance, performanceTime: performed)
    }

    // MARK: Reading one part

    private func read(part: RawPart) -> [PartMeasure] {
        var state = PartState(divisions: defaultDivisions)
        var result: [PartMeasure] = []
        for measure in part.measures {
            result.append(read(measure: measure, state: &state))
        }
        return result
    }

    private func scaled(_ duration: Int, _ state: PartState) -> Int {
        Int((Double(duration) * Double(tpq) / Double(max(state.divisions, 1))).rounded())
    }

    private static func velocity(percent: Double) -> Int {
        // MusicXML: a percentage of the default forte velocity (90)
        max(1, min(127, Int((percent * 0.9).rounded())))
    }

    private func read(measure m: [String: Any], state: inout PartState) -> PartMeasure {
        var out = PartMeasure()
        out.number = J.string(m["@number"]) ?? ""
        out.isImplicit = J.string(m["@implicit"]) == "yes"
        out.widthTenths = J.double(m["@width"])
        for p in J.dicts(m["print"]) where J.string(p["@new-system"]) == "yes" || J.string(p["@new-page"]) == "yes" {
            out.newSystem = true
        }
        readBarlines(m, into: &out)

        let order = (m["#order"] as? [String]) ?? []
        out.keptOrder = !order.isEmpty
        let sequence: [String]
        if out.keptOrder {
            sequence = order
        } else {
            // no element order: attributes and tempo first, then the notes by staff and voice
            sequence = ["attributes", "sound", "direction", "note"].flatMap { name in
                Array(repeating: name, count: J.list(m[name]).count)
            }
        }
        var lists: [String: [Any]] = [:]
        var used: [String: Int] = [:]
        for name in Set(sequence) { lists[name] = J.list(m[name]) }
        func next(_ name: String) -> Any? {
            let i = used[name, default: 0]
            used[name] = i + 1
            guard let list = lists[name], i < list.count else { return nil }
            return list[i]
        }

        // ordered: one cursor, as MusicXML defines; unordered: one per staff and voice
        var cursor = 0
        var lastStart = 0
        var cursors: [String: Int] = [:]
        var lastStarts: [String: Int] = [:]
        var furthest = 0
        var sawContent = false
        out.keyFifths = state.keyFifths
        out.time = state.time
        out.clefsAtStart = state.clefs

        for name in sequence {
            switch name {
            case "attributes":
                guard let a = next(name) as? [String: Any] else { continue }
                if let d = J.int(a["divisions"]), d > 0 { state.divisions = d }
                if let staves = J.int(a["staves"]) { state.staves = max(1, staves) }
                if let key = J.dicts(a["key"]).first, let fifths = J.int(key["fifths"]) {
                    state.keyFifths = fifths
                    if !sawContent { out.keyFifths = fifths }
                }
                if let time = J.dicts(a["time"]).first, let beatsText = J.string(time["beats"]),
                   let beatType = J.int(time["beat-type"]) {
                    let beats = beatsText.split(separator: "+").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.reduce(0, +)
                    if beats > 0 && beatType > 0 {
                        state.time = ScoreTimeSignature(beats: beats, beatType: beatType)
                        if !sawContent { out.time = state.time }
                    }
                }
                for c in J.dicts(a["clef"]) {
                    let staff = J.int(c["@number"]) ?? 1
                    let sign = (J.string(c["sign"]) ?? "G").uppercased()
                    let defaultLine = sign == "F" ? 4 : sign == "C" ? 3 : 2
                    let clef = ScoreClef(sign: sign, line: J.int(c["line"]) ?? defaultLine,
                                         octaveChange: J.int(c["clef-octave-change"]) ?? 0)
                    state.clefs[staff] = clef
                    if !sawContent {
                        out.clefsAtStart[staff] = clef
                    } else {
                        out.midMeasureClefs.append((out.keptOrder ? cursor : 0, staff, clef))
                    }
                }

            case "sound":
                guard let s = next(name) as? [String: Any] else { continue }
                readSound(s, at: out.keptOrder ? cursor : 0, into: &out)

            case "direction":
                guard let d = next(name) as? [String: Any] else { continue }
                let shift = J.int(d["offset"]).map { scaled($0, state) } ?? 0
                readDirection(d, at: out.keptOrder ? max(0, cursor + shift) : nil, into: &out)

            case "backup":
                guard let b = next(name) as? [String: Any] else { continue }
                cursor = max(0, cursor - scaled(J.int(b["duration"]) ?? 0, state))

            case "forward":
                guard let f = next(name) as? [String: Any] else { continue }
                cursor += scaled(J.int(f["duration"]) ?? 0, state)
                furthest = max(furthest, cursor)

            case "note":
                guard let n = next(name) as? [String: Any] else { continue }
                sawContent = true
                let isGrace = n["grace"] != nil
                let isChord = n["chord"] != nil
                let duration = isGrace ? 0 : scaled(J.int(n["duration"]) ?? 0, state)
                let staff = max(1, J.int(n["staff"]) ?? 1)
                let voice = J.string(n["voice"]) ?? "1"

                let start: Int
                if out.keptOrder {
                    start = isChord ? lastStart : cursor
                    lastStart = start
                    if !isChord { cursor += duration }
                    furthest = max(furthest, cursor, start + duration)
                } else {
                    let key = "\(staff)-\(voice)"
                    let current = cursors[key, default: 0]
                    start = isChord ? lastStarts[key, default: current] : current
                    lastStarts[key] = start
                    if !isChord { cursors[key] = current + duration }
                    furthest = max(furthest, start + duration, cursors[key, default: 0])
                }

                // cue notes take time but are not part of what is played
                if n["cue"] != nil { continue }
                out.notes.append(readNote(n, start: start, duration: duration, staff: staff, voice: voice,
                                          isGrace: isGrace, isChord: isChord, state: state))

            default:
                _ = next(name)
            }
        }

        out.contentTicks = furthest
        return out
    }

    private func readNote(_ n: [String: Any], start: Int, duration: Int, staff: Int, voice: String,
                          isGrace: Bool, isChord: Bool, state: PartState) -> PendingNote {
        var pending = PendingNote(
            offset: start, duration: duration, staff: staff, voice: voice,
            isRest: n["rest"] != nil, isGrace: isGrace, isChord: isChord, dots: J.count(n["dot"]),
            clef: state.clefs[staff] ?? (staff == 1 ? .treble : .bass))
        pending.isPrinted = J.string(n["@print-object"]) != "no"
        pending.defaultX = J.double(n["@default-x"])
        pending.dynamicsPercent = J.double(n["@dynamics"])

        if let pitch = n["pitch"] as? [String: Any] {
            pending.step = J.string(pitch["step"])?.uppercased()
            pending.octave = J.int(pitch["octave"])
            pending.alter = J.int(pitch["alter"]) ?? 0
        } else if let unpitched = n["unpitched"] as? [String: Any] {
            pending.unpitched = true
            pending.step = J.string(unpitched["display-step"])?.uppercased()
            pending.octave = J.int(unpitched["display-octave"])
        }
        if let rest = n["rest"] as? [String: Any] {
            pending.restMarkedMeasure = J.string(rest["@measure"]) == "yes"
            if let step = J.string(rest["display-step"]), let octave = J.int(rest["display-octave"]),
               let i = ScoreNote.steps.firstIndex(of: step.uppercased()) {
                pending.restDiatonic = octave * 7 + i
            }
        }

        if let type = J.string(n["type"]), let value = NoteValue(musicXMLType: type) {
            pending.value = value
        } else if isGrace {
            pending.value = .eighth
        } else {
            var quarters = Double(duration) / Double(tpq)
            if let tm = n["time-modification"] as? [String: Any], let a = J.double(tm["actual-notes"]),
               let b = J.double(tm["normal-notes"]), a > 0, b > 0 {
                quarters *= a / b
            }
            let closest = NoteValue.closest(toQuarters: quarters)
            pending.value = closest.value
            if pending.dots == 0 { pending.dots = closest.dots }
        }

        switch J.string(n["stem"]) {
        case "up":   pending.stem = .up
        case "down": pending.stem = .down
        case "none": pending.stem = ScoreNote.Stem.none
        default:     break
        }

        for beam in J.list(n["beam"]) {
            let level = (beam as? [String: Any]).flatMap { J.int($0["@number"]) } ?? 1
            if level == 1 { pending.beamText = J.string(beam) }
        }

        if let tm = n["time-modification"] as? [String: Any], let a = J.int(tm["actual-notes"]),
           let b = J.int(tm["normal-notes"]), a > 0, b > 0, a != b {
            pending.tuplet = ScoreNote.Tuplet(actual: a, normal: b)
        }

        var tieTypes = J.dicts(n["tie"]).compactMap { J.string($0["@type"]) }
        for notations in J.dicts(n["notations"]) {
            tieTypes += J.dicts(notations["tied"]).compactMap { J.string($0["@type"]) }
            for slur in J.dicts(notations["slur"]) {
                pending.slurMarks.append(SpanMark(number: J.int(slur["@number"]) ?? 1,
                                                  type: J.string(slur["@type"]) ?? "",
                                                  above: J.placement(slur), bracket: nil))
            }
            for tuplet in J.dicts(notations["tuplet"]) {
                pending.tupletMarks.append(SpanMark(number: J.int(tuplet["@number"]) ?? 1,
                                                    type: J.string(tuplet["@type"]) ?? "",
                                                    above: J.placement(tuplet),
                                                    bracket: J.string(tuplet["@bracket"]).map { $0 == "yes" }))
            }
            for name in J.childNames(notations["articulations"]) {
                switch name {
                case "staccato":        pending.articulations.insert(.staccato)
                case "staccatissimo":   pending.articulations.insert(.staccatissimo)
                case "spiccato":        pending.articulations.insert(.spiccato)
                case "tenuto":          pending.articulations.insert(.tenuto)
                case "detached-legato": pending.articulations.insert(.detachedLegato)
                case "accent":          pending.articulations.insert(.accent)
                case "strong-accent":   pending.articulations.insert(.strongAccent)
                default:                break
                }
            }
            if notations["fermata"] != nil { pending.fermata = true }
        }
        pending.tieStart = tieTypes.contains("start")
        pending.tieStop = tieTypes.contains("stop")

        switch J.string(n["accidental"]) {
        case "sharp":                       pending.accidental = .sharp
        case "flat":                        pending.accidental = .flat
        case "natural":                     pending.accidental = .natural
        case "double-sharp", "sharp-sharp": pending.accidental = .doubleSharp
        case "flat-flat", "double-flat":    pending.accidental = .doubleFlat
        default:                            break
        }
        return pending
    }

    /// <sound>: tempo, dynamics and D.C. / D.S. / Fine / Coda.
    private func readSound(_ s: [String: Any], at offset: Int, into out: inout PartMeasure) {
        if let bpm = J.double(s["@tempo"]) { out.tempos.append((offset, bpm)) }
        if let dynamics = J.double(s["@dynamics"]) { out.dynamics.append((offset, Self.velocity(percent: dynamics))) }
        if s["@segno"] != nil { out.navigation.insert(.segno) }
        if s["@coda"] != nil { out.navigation.insert(.coda) }
        if s["@tocoda"] != nil { out.navigation.insert(.toCoda) }
        if J.string(s["@dacapo"]) == "yes" { out.navigation.insert(.daCapo) }
        if s["@dalsegno"] != nil { out.navigation.insert(.dalSegno) }
        if s["@fine"] != nil { out.navigation.insert(.fine) }
    }

    /// `offset` nil: the element order is unknown, so starts go to the measure's start and
    /// ends to its end.
    private func readDirection(_ d: [String: Any], at offset: Int?, into out: inout PartMeasure) {
        let staff = max(1, J.int(d["staff"]) ?? 1)
        let placement = J.placement(d)
        let at = offset ?? 0
        let end = offset ?? -1
        func add(_ kind: PendingDirection.Kind, above: Bool, at position: Int? = nil) {
            out.directions.append(PendingDirection(offset: position ?? at, staff: staff, above: placement ?? above, kind: kind))
        }

        var hasTempo = false
        for sound in J.dicts(d["sound"]) {
            if sound["@tempo"] != nil { hasTempo = true }
            readSound(sound, at: at, into: &out)
        }
        for type in J.dicts(d["direction-type"]) {
            for dynamics in J.dicts(type["dynamics"]) {
                for name in J.childNames(dynamics) {
                    let mark = name == "other-dynamics" ? (J.string(dynamics[name]) ?? "") : name
                    add(.dynamic(mark), above: false)
                    if let level = Self.dynamicLevels[mark] { out.dynamics.append((at, level)) }
                    if Self.sforzandoMarks.contains(mark) {
                        out.sforzandos.append(at)
                        if mark == "fp" || mark == "sfp" { out.dynamics.append((at + 1, Self.dynamicLevels["p"]!)) }
                    }
                }
            }
            for metronome in J.dicts(type["metronome"]) {
                guard let perMinute = J.double(metronome["per-minute"]) else { continue }
                let unit = J.string(metronome["beat-unit"]).flatMap { NoteValue(musicXMLType: $0) } ?? .quarter
                let dots = J.count(metronome["beat-unit-dot"])
                add(.metronome(unit, dots, perMinute), above: true)
                if !hasTempo {
                    out.tempos.append((at, perMinute * unit.quarters * (2 - pow(0.5, Double(dots)))))
                    hasTempo = true
                }
            }
            for words in J.list(type["words"]) {
                guard let text = J.string(words), !text.isEmpty else { continue }
                add(.words(text), above: true)
                if !hasTempo, let bpm = ScoreTimeline.tempo(forWords: text) { out.wordTempos.append((at, bpm)) }
            }
            for wedge in J.dicts(type["wedge"]) {
                let number = J.int(wedge["@number"]) ?? 1
                switch J.string(wedge["@type"]) {
                case "crescendo":  add(.wedgeStart(crescendo: true, number: number), above: false)
                case "diminuendo": add(.wedgeStart(crescendo: false, number: number), above: false)
                case "stop":       add(.wedgeStop(number: number), above: false, at: end)
                default:           break
                }
            }
            for shift in J.dicts(type["octave-shift"]) {
                let number = J.int(shift["@number"]) ?? 1
                let size = J.int(shift["@size"]) ?? 8
                switch J.string(shift["@type"]) {
                case "down": add(.octaveStart(size: size, down: true, number: number), above: true)
                case "up":   add(.octaveStart(size: size, down: false, number: number), above: false)
                case "stop": add(.octaveStop(number: number), above: true, at: end)
                default:     break
                }
            }
            if type["segno"] != nil { add(.segno, above: true); out.navigation.insert(.segno) }
            if type["coda"] != nil { add(.coda, above: true); out.navigation.insert(.coda) }
        }
    }

    private func readBarlines(_ m: [String: Any], into out: inout PartMeasure) {
        for barline in J.dicts(m["barline"]) {
            let location = J.string(barline["@location"]) ?? "right"
            if let style = J.string(barline["bar-style"]), location == "right" { out.rightBarStyle = style }
            if let repeatMark = barline["repeat"] as? [String: Any] {
                if J.string(repeatMark["@direction"]) == "forward" {
                    out.repeatStart = true
                } else {
                    out.repeatEnd = true
                    out.repeatTimes = max(2, J.int(repeatMark["@times"]) ?? 2)
                }
            }
            for ending in J.dicts(barline["ending"]) {
                let numbers = (J.string(ending["@number"]) ?? "1")
                    .split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
                switch J.string(ending["@type"]) {
                case "start":
                    out.endingStart = numbers.isEmpty ? [1] : numbers
                    out.endingText = J.string(ending["#text"]) ?? numbers.map(String.init).joined(separator: ", ") + "."
                case "stop":        out.endingStop = true
                case "discontinue": out.endingStop = false
                default:            break
                }
            }
        }
    }

    // MARK: Finishing touches

    private func tempoMap(_ marks: [TempoMark], firstMeasureEnd: Int) -> [TempoMark] {
        var byTick: [Int: Double] = [:]
        for mark in marks where (10...400).contains(mark.bpm) { byTick[mark.tick] = mark.bpm }
        var sorted = byTick.sorted { $0.key < $1.key }.map { TempoMark(tick: $0.key, bpm: $0.value) }
        if sorted.first?.tick != 0 {
            // a mark inside the first measure (after a pickup note) sets the opening tempo
            let opening = sorted.first.flatMap { $0.tick <= firstMeasureEnd ? $0.bpm : nil } ?? defaultTempo
            sorted.insert(TempoMark(tick: 0, bpm: opening), at: 0)
        }
        // drop marks that don't change anything
        var map: [TempoMark] = []
        for mark in sorted where map.last?.bpm != mark.bpm { map.append(mark) }
        return map
    }

    /// Tempo marks, with time stretched under fermatas (held about 1.8 × their length).
    private func writtenTimeMap(_ marks: [TempoMark], notes: [ScoreNote]) -> TimeMap {
        var holds: [(Int, Int)] = []
        for note in notes where note.hasFermata && note.durationTicks > 0 {
            holds.append((note.startTick, note.endTick))
        }
        let base = TimeMap(marks: marks.map { (Double($0.tick), $0.bpm) }, ticksPerQuarter: tpq)
        guard !holds.isEmpty else { return base }
        var boundaries = Set(marks.map(\.tick))
        for (a, b) in holds { boundaries.insert(a); boundaries.insert(b) }
        let stretched = boundaries.sorted().map { tick -> (tick: Double, bpm: Double) in
            let held = holds.contains { tick >= $0.0 && tick < $0.1 }
            return (Double(tick), base.bpm(atTick: Double(tick)) / (held ? 1.8 : 1))
        }
        return TimeMap(marks: stretched, ticksPerQuarter: tpq)
    }

    private func performanceTimeMap(_ performance: [PerformedMeasure], measures: [ScoreMeasure],
                                    written: TimeMap) -> TimeMap {
        var marks: [(tick: Double, bpm: Double)] = []
        for performed in performance {
            let measure = measures[performed.measureIndex]
            let shift = Double(performed.tick - measure.startTick)
            marks.append((Double(performed.tick), written.bpm(atTick: Double(measure.startTick))))
            for segment in written.segments where segment.tick > Double(measure.startTick) && segment.tick < Double(measure.endTick) {
                marks.append((segment.tick + shift, segment.bpm))
            }
        }
        return TimeMap(marks: marks, ticksPerQuarter: tpq)
    }

    /// The order the measures are played in: repeats taken (with their 1st / 2nd endings),
    /// then D.C. / D.S. followed to Fine or the Coda. After a D.C. / D.S. repeats are not
    /// taken again and the last ending is played.
    private func perform(_ measures: [ScoreMeasure]) -> [PerformedMeasure] {
        guard !measures.isEmpty else { return [] }
        let segno = measures.firstIndex { $0.navigation.contains(.segno) }
        let codas = measures.indices.filter { measures[$0].navigation.contains(.coda) }
        var result: [PerformedMeasure] = []
        var tick = 0
        var i = 0
        var repeatStart = 0
        var timesPlayed: [Int: Int] = [:]
        var pass = 1
        var jumped = false
        var cameBack = false
        var steps = 0
        while i < measures.count && steps < measures.count * 16 {
            steps += 1
            let m = measures[i]
            if m.repeatStart && !cameBack {
                repeatStart = i
                pass = 1
            }
            cameBack = false
            if !m.endingNumbers.isEmpty {
                let play = jumped ? m.endingIsLast : m.endingNumbers.contains(pass)
                if !play { i += 1; continue }
            }
            result.append(PerformedMeasure(measureIndex: i, tick: tick))
            tick += m.lengthTicks
            if jumped && m.navigation.contains(.fine) { break }
            if jumped && m.navigation.contains(.toCoda), let coda = codas.first(where: { $0 > i }) {
                i = coda
                continue
            }
            if m.repeatEnd && !jumped {
                let played = timesPlayed[i, default: 1]
                if played < m.repeatTimes {
                    timesPlayed[i] = played + 1
                    pass = played + 1
                    i = repeatStart
                    cameBack = true
                    continue
                }
                timesPlayed[i] = nil
            }
            if !jumped && (m.navigation.contains(.daCapo) || m.navigation.contains(.dalSegno)) {
                jumped = true
                i = m.navigation.contains(.dalSegno) ? (segno ?? 0) : 0
                cameBack = true
                continue
            }
            i += 1
        }
        return result
    }

    private func markLastEndings(_ measures: inout [ScoreMeasure]) {
        var i = 0
        while i < measures.count {
            guard !measures[i].endingNumbers.isEmpty else { i += 1; continue }
            var j = i
            while j < measures.count && !measures[j].endingNumbers.isEmpty { j += 1 }
            let last = measures[i..<j].flatMap(\.endingNumbers).max() ?? 1
            for k in i..<j { measures[k].endingIsLast = measures[k].endingNumbers.contains(last) }
            i = j
        }
    }

    /// Pairs hairpin and octave-line starts with their stops.
    private func pairDirections(_ pending: [(tick: Int, measureEnd: Int, staff: Int, direction: PendingDirection)],
                                end: Int) -> [ScoreDirection] {
        var result: [ScoreDirection] = []
        var wedges: [Int: (tick: Int, staff: Int, above: Bool, crescendo: Bool)] = [:]
        var octaves: [Int: (tick: Int, staff: Int, above: Bool, size: Int, down: Bool)] = [:]
        for item in pending.sorted(by: { $0.tick < $1.tick }) {
            let d = item.direction
            switch d.kind {
            case .dynamic(let mark):
                result.append(ScoreDirection(tick: item.tick, staff: item.staff, above: d.above, kind: .dynamic(mark)))
            case .words(let text):
                result.append(ScoreDirection(tick: item.tick, staff: item.staff, above: d.above, kind: .words(text)))
            case .metronome(let unit, let dots, let perMinute):
                result.append(ScoreDirection(tick: item.tick, staff: item.staff, above: d.above,
                                             kind: .metronome(beat: unit, dots: dots, perMinute: perMinute)))
            case .segno:
                result.append(ScoreDirection(tick: item.tick, staff: item.staff, above: true, kind: .segno))
            case .coda:
                result.append(ScoreDirection(tick: item.tick, staff: item.staff, above: true, kind: .coda))
            case .wedgeStart(let crescendo, let number):
                wedges[number] = (item.tick, item.staff, d.above, crescendo)
            case .wedgeStop(let number):
                if let open = wedges.removeValue(forKey: number) {
                    result.append(ScoreDirection(tick: open.tick, staff: open.staff, above: open.above,
                                                 kind: .wedge(crescendo: open.crescendo, endTick: max(item.tick, open.tick))))
                }
            case .octaveStart(let size, let down, let number):
                octaves[number] = (item.tick, item.staff, d.above, size, down)
            case .octaveStop(let number):
                if let open = octaves.removeValue(forKey: number) {
                    result.append(ScoreDirection(tick: open.tick, staff: open.staff, above: open.above,
                                                 kind: .octaveShift(size: open.size, down: open.down, endTick: max(item.tick, open.tick))))
                }
            }
        }
        for open in wedges.values {
            result.append(ScoreDirection(tick: open.tick, staff: open.staff, above: open.above,
                                         kind: .wedge(crescendo: open.crescendo, endTick: end)))
        }
        for open in octaves.values {
            result.append(ScoreDirection(tick: open.tick, staff: open.staff, above: open.above,
                                         kind: .octaveShift(size: open.size, down: open.down, endTick: end)))
        }
        return result.sorted { $0.tick < $1.tick }
    }

    private func finishRests(_ notes: inout [ScoreNote], measures: [ScoreMeasure]) {
        for i in notes.indices where notes[i].isRest {
            let measure = measures[notes[i].measureIndex]
            let fillsMeasure = notes[i].durationTicks >= measure.lengthTicks
            notes[i].isMeasureRest = fillsMeasure && (notes[i].restIsMarkedMeasure || notes[i].startTick == measure.startTick)
        }
    }

    /// A tied note sounds once for the whole tie: its first note gets the total length and the
    /// notes continuing it sound for 0.
    private func mergeTies(_ notes: inout [ScoreNote]) {
        var open: [Int: Int] = [:]   // midi → index of the note the tie started on
        for i in notes.indices where !notes[i].isRest && !notes[i].isGrace {
            guard let midi = notes[i].midi else { continue }
            if notes[i].tieStop, let origin = open[midi],
               notes[origin].soundingEndTick >= notes[i].startTick - tpq / 8 {
                notes[origin].soundingTicks = max(notes[origin].soundingTicks,
                                                  notes[i].endTick - notes[origin].startTick)
                notes[i].soundingTicks = 0
                if notes[i].tieStart { open[midi] = origin } else { open[midi] = nil }
            } else if notes[i].tieStart {
                open[midi] = i
            } else {
                open[midi] = nil
            }
        }
    }

    /// Under an 8va line notes are printed an octave below their pitch (8vb: above).
    private func applyOctaveShifts(_ notes: inout [ScoreNote], directions: [ScoreDirection]) {
        for direction in directions {
            guard case .octaveShift(let size, let down, let endTick) = direction.kind else { continue }
            let steps = size >= 22 ? 21 : size >= 15 ? 14 : 7
            for i in notes.indices where notes[i].staff == direction.staff
                && notes[i].startTick >= direction.tick && notes[i].startTick <= endTick && !notes[i].isRest {
                notes[i].displayShift = down ? -steps : steps
            }
        }
    }

    /// The accidental each note prints: the written one, else whatever its alteration needs
    /// against the key signature and the accidentals earlier in the measure.
    private func assignAccidentals(_ notes: inout [ScoreNote], measures: [ScoreMeasure]) {
        var measureIndex = -1
        var altered: [Int: [Int: Int]] = [:]   // staff → staff position → alter in force
        for i in notes.indices {
            let note = notes[i]
            guard !note.isRest, let step = note.step, let position = note.displayDiatonic else { continue }
            if note.measureIndex != measureIndex {
                measureIndex = note.measureIndex
                altered = [:]
            }
            let inForce = altered[note.staff]?[position]
                ?? Self.keyAlter(step: step, fifths: measures[note.measureIndex].keyFifths)
            if let written = note.writtenAccidental {
                notes[i].accidental = written
            } else if note.tieStop && note.soundingTicks == 0 {
                notes[i].accidental = nil
            } else if note.alter != inForce {
                switch note.alter {
                case 2:  notes[i].accidental = .doubleSharp
                case 1:  notes[i].accidental = .sharp
                case -1: notes[i].accidental = .flat
                case -2: notes[i].accidental = .doubleFlat
                default: notes[i].accidental = .natural
                }
            }
            altered[note.staff, default: [:]][position] = note.alter
        }
    }

    static func keyAlter(step: String, fifths: Int) -> Int {
        let sharps = ["F", "C", "G", "D", "A", "E", "B"]
        if fifths > 0, let i = sharps.firstIndex(of: step), i < fifths { return 1 }
        if fifths < 0, let i = Array(sharps.reversed()).firstIndex(of: step), i < -fifths { return -1 }
        return 0
    }

    /// Beam groups as written (<beam number="1">), or — for scores without beams, such as OMR
    /// output — eighths and shorter grouped by beat.
    private func assignBeams(_ notes: inout [ScoreNote], measures: [ScoreMeasure]) {
        struct Lane: Hashable { let measure: Int; let staff: Int; let voice: String }
        var lanes: [Lane: [Int]] = [:]
        for i in notes.indices where !notes[i].isGrace {
            lanes[Lane(measure: notes[i].measureIndex, staff: notes[i].staff, voice: notes[i].voice), default: []].append(i)
        }
        var nextGroup = 0
        for (lane, indices) in lanes.sorted(by: { ($0.key.measure, $0.key.staff) < ($1.key.measure, $1.key.staff) }) {
            // one entry per onset: the chord's first note leads, rests break groups
            var leaders: [Int] = []
            var tonesByStart: [Int: [Int]] = [:]
            for i in indices {
                if notes[i].isRest { leaders.append(i); continue }
                if tonesByStart[notes[i].startTick] == nil { leaders.append(i) }
                tonesByStart[notes[i].startTick, default: []].append(i)
            }
            func assign(_ group: [Int]) {
                guard group.count >= 2 else { return }
                for leader in group {
                    for i in tonesByStart[notes[leader].startTick] ?? [leader] { notes[i].beamGroup = nextGroup }
                }
                nextGroup += 1
            }

            if leaders.contains(where: { notes[$0].beamText != nil }) {
                var group: [Int] = []
                for i in leaders {
                    switch notes[i].isRest ? nil : notes[i].beamText {
                    case "begin":
                        assign(group); group = [i]
                    case "continue":
                        group.append(i)
                    case "end":
                        group.append(i); assign(group); group = []
                    default:
                        assign(group); group = []
                    }
                }
                assign(group)
            } else {
                let measure = measures[lane.measure]
                let span = measure.time?.beamSpan(ticksPerQuarter: tpq) ?? tpq
                var group: [Int] = []
                var groupBeat = -1
                var expectedStart = -1
                for i in leaders {
                    let note = notes[i]
                    let beat = (note.startTick - measure.startTick) / max(span, 1)
                    let beamable = !note.isRest && note.value.flagCount > 0 && note.stem != ScoreNote.Stem.none
                    if beamable && beat == groupBeat && note.startTick == expectedStart {
                        group.append(i)
                    } else {
                        assign(group)
                        group = beamable ? [i] : []
                        groupBeat = beat
                    }
                    expectedStart = note.endTick
                }
                assign(group)
            }
        }
    }

    /// Slurs as written, paired by number; the notes under a slur (all but its last) play legato.
    private func pairSlurs(_ notes: inout [ScoreNote]) -> [ScoreSlur] {
        var open: [String: (index: Int, above: Bool?)] = [:]
        var slurs: [ScoreSlur] = []
        for i in notes.indices {
            let part = notes[i].voice.split(separator: "-").first.map(String.init) ?? "0"
            for mark in notes[i].slurMarks {
                // paired within a staff: OMR reuses numbers across staves
                let key = "\(part)-\(notes[i].staff)-\(mark.number)"
                if mark.type == "start" {
                    open[key] = (i, mark.above)
                } else if mark.type == "stop", let start = open.removeValue(forKey: key), start.index != i {
                    slurs.append(ScoreSlur(from: start.index, to: i, above: start.above ?? mark.above))
                }
            }
        }
        for slur in slurs {
            let first = notes[slur.from], last = notes[slur.to]
            for i in slur.from..<slur.to where notes[i].staff == first.staff && notes[i].voice == first.voice
                && notes[i].startTick < last.startTick {
                notes[i].isLegato = true
            }
        }
        return slurs
    }

    /// Tuplet groups as written (<tuplet type="start/stop">), else consecutive notes with the
    /// same <time-modification> until they add up to a half beat.
    private func groupTuplets(_ notes: [ScoreNote]) -> [ScoreTuplet] {
        struct Lane: Hashable { let staff: Int; let voice: String }
        var lanes: [Lane: [Int]] = [:]
        for i in notes.indices where !notes[i].isGrace && !notes[i].isChordTone && notes[i].tuplet != nil {
            lanes[Lane(staff: notes[i].staff, voice: notes[i].voice), default: []].append(i)
        }
        var result: [ScoreTuplet] = []
        for (_, indices) in lanes {
            var group: [Int] = []
            var bracket: Bool?
            var above: Bool?
            var written = false
            var total = 0
            func close() {
                if group.count >= 2, let ratio = notes[group[0]].tuplet {
                    result.append(ScoreTuplet(notes: group, actual: ratio.actual, above: above, bracket: bracket))
                }
                group = []; total = 0; above = nil; bracket = nil; written = false
            }
            for i in indices {
                let note = notes[i]
                if let last = group.last, notes[last].endTick != note.startTick || notes[last].tuplet != note.tuplet {
                    close()
                }
                if let start = note.tupletMarks.first(where: { $0.type == "start" }) {
                    close()
                    written = true
                    above = start.above
                    bracket = start.bracket
                }
                group.append(i)
                total += note.durationTicks
                if note.tupletMarks.contains(where: { $0.type == "stop" }) {
                    close()
                } else if !written, tpq % 2 == 0, total % (tpq / 2) == 0 {
                    close()
                }
            }
            close()
        }
        return result.sorted { $0.notes[0] < $1.notes[0] }
    }

    /// Loudness of every note: the dynamic in force (hairpins move it toward the next mark),
    /// the note's own `dynamics`, accents and sforzandos.
    private func assignVelocities(_ notes: inout [ScoreNote], marks: [(tick: Int, velocity: Int)],
                                  sforzandos: Set<Int>, directions: [ScoreDirection]) {
        let sorted = marks.sorted { $0.tick < $1.tick }
        func level(at tick: Int) -> Double {
            Double(sorted.last { $0.tick <= tick }?.velocity ?? Self.defaultVelocity)
        }
        struct Ramp { let start: Int; let end: Int; let from: Double; let to: Double }
        var ramps: [Ramp] = []
        for direction in directions {
            guard case .wedge(let crescendo, let end) = direction.kind, end > direction.tick else { continue }
            let from = level(at: direction.tick)
            let target = sorted.first { $0.tick >= end - tpq / 2 && $0.tick <= end + 2 * tpq }.map { Double($0.velocity) }
            let to = target ?? max(20, min(127, from + (crescendo ? 16 : -16)))
            ramps.append(Ramp(start: direction.tick, end: end, from: from, to: to))
        }
        for i in notes.indices where !notes[i].isRest {
            let note = notes[i]
            var v = level(at: note.startTick)
            if let ramp = ramps.last(where: { note.startTick >= $0.start && note.startTick <= $0.end + tpq / 4 }) {
                let f = min(1, Double(note.startTick - ramp.start) / Double(max(1, ramp.end - ramp.start)))
                v = ramp.from + (ramp.to - ramp.from) * f
            } else if let ramp = ramps.last(where: { $0.end < note.startTick }),
                      !sorted.contains(where: { $0.tick > ramp.end && $0.tick <= note.startTick }) {
                v = ramp.to   // a hairpin with no closing mark leaves the new level in force
            }
            if let percent = note.dynamicsPercent { v = Double(Self.velocity(percent: percent)) }
            if note.articulations.contains(.strongAccent) { v += 22 } else if note.articulations.contains(.accent) { v += 14 }
            if sforzandos.contains(note.startTick) { v += 20 }
            notes[i].velocity = max(20, min(127, Int(v.rounded())))
        }
    }
}
