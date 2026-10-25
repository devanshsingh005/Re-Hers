import Foundation

// Port of oemer/build_system.py

private let divisionPerQuarter = 16

/// NOTE_TYPE_TO_RHYTHM (dict order matters for get_label_by_dura).
private let noteRhythm: [(NoteType, String, Int)] = [
    (.whole, "whole", divisionPerQuarter * 4),
    (.half, "half", divisionPerQuarter * 2),
    (.halfOrWhole, "half", divisionPerQuarter * 2),
    (.quarter, "quarter", divisionPerQuarter),
    (.eighth, "eighth", divisionPerQuarter / 2),
    (.sixteenth, "16th", divisionPerQuarter / 4),
    (.thirtySecond, "32nd", divisionPerQuarter / 8),
    (.sixtyFourth, "64th", divisionPerQuarter / 16),
]

/// REST_TYPE_TO_DURATION (dict order matters for get_label_by_dura).
private let restDuration: [(RestType, Int)] = [
    (.quarter, divisionPerQuarter),
    (.eighth, divisionPerQuarter / 2),
    (.sixteenth, divisionPerQuarter / 4),
    (.thirtySecond, divisionPerQuarter / 8),
    (.sixtyFourth, divisionPerQuarter / 16),
    (.wholeHalf, divisionPerQuarter * 2),
    (.whole, divisionPerQuarter * 4),
    (.half, divisionPerQuarter * 2),
]

private func rhythm(_ t: NoteType?) -> (name: String, duration: Int) {
    let t = t ?? .quarter  // Python would raise KeyError for an unlabelled note
    let r = noteRhythm.first { $0.0 == t } ?? noteRhythm[3]
    return (r.1, r.2)
}

private func restDura(_ t: RestType) -> Int { restDuration.first { $0.0 == t }!.1 }

private let gClefPosToPitch = ["D", "E", "F", "G", "A", "B", "C"]
private let fClefPosToPitch = ["F", "G", "A", "B", "C", "D", "E"]
private let sharpKeyOrder = ["F", "C", "G", "D", "A", "E"]
private let flatKeyOrder = ["B", "E", "A", "D", "G", "C"]

/// A chord/voice built from a note group (top or bottom part).
final class Voice: MeasureSymbol {
    var id = 0
    var noteIds: [Int] = []
    var stemUp: Bool? = nil
    var groupId = 0
    var center = 0.0
    var label: NoteType? = nil
    var hasDot = false
    var duration = 0
    var rhythmName = ""

    init() { super.init(bbox: BBox(0, 0, 0, 0)) }
    override var xCenter: Double { center }
}

/// `get_label_by_dura(duration, mapping)`
private func labelByDura<T>(_ duration: Int, _ mapping: [(T, Int)]) -> (T?, Bool) {
    var minDiff = 9_999_999
    var tar: T? = nil
    for (label, dura) in mapping {
        let diff = duration - dura
        if diff >= 0 && diff < minDiff {
            minDiff = diff
            tar = label
        }
    }
    return (tar, minDiff > 0)
}

final class Measure {
    var symbols: [MeasureSymbol] = []
    var doubleBarline = false
    var hasClef = false
    var clefs: [Clef] = []
    var voices: [Voice] = []
    var sfns: [Sfn] = []
    var rests: [Rest] = []
    var number = 0
    var atBeginning = false
    var group = 0
    var timeSlots: [[MeasureSymbol]] = []
    var slotDuras: [[Double]] = []

    unowned let ctx: OMRContext
    init(ctx: OMRContext) { self.ctx = ctx }

    private static func sortByX<T: MeasureSymbol>(_ a: [T]) -> [T] {
        a.enumerated().sorted { $0.element.xCenter != $1.element.xCenter ? $0.element.xCenter < $1.element.xCenter : $0.offset < $1.offset }
            .map { $0.element }
    }

    func addSymbols(_ syms: [MeasureSymbol]) {
        symbols = Measure.sortByX(symbols + syms)
        for s in syms {
            if let v = s as? Voice {
                voices.append(v)
            } else if let c = s as? Clef {
                clefs.append(c)
                hasClef = true
            } else if let f = s as? Sfn {
                sfns.append(f)
            } else if let r = s as? Rest {
                rests.append(r)
            }
        }
        voices = Measure.sortByX(voices)
        clefs = Measure.sortByX(clefs)
        sfns = Measure.sortByX(sfns)
        rests = Measure.sortByX(rests)
    }

    func hasKey() -> Bool {
        let total = ctx.totalTrackNums
        let start = atBeginning ? total : 0
        let lo = min(start, symbols.count), hi = min(start + total, symbols.count)
        return symbols[lo..<hi].allSatisfy { $0 is Sfn }
    }

    /// Key signature as fifths (-6...6).
    func getKey() -> Int {
        if sfns.isEmpty { return 0 }
        let trackNums = ctx.totalTrackNums
        guard hasKey() else { return 0 }
        let start = atBeginning ? trackNums : 0
        let end = min(trackNums * 7 + 4, symbols.count)
        var cands: [Sfn] = []
        if start < end {
            for i in start..<end {
                guard let s = symbols[i] as? Sfn else { break }
                cands.append(s)
            }
        }
        guard let first = cands.first else { return 0 }  // Python raises IndexError here
        var counts = [Int](repeating: 0, count: trackNums)
        for s in cands where s.track < trackNums { counts[s.track] += 1 }
        let allSame = cands.allSatisfy { $0.label == first.label }
        var label = first.label
        if !allSame {
            var counter: [(SfnType, Int)] = [(.flat, 0), (.sharp, 0), (.natural, 0)]
            for s in cands {
                let i = counter.firstIndex { $0.0 == s.label }!
                counter[i].1 += 1
            }
            counter = counter.enumerated().sorted { $0.element.1 != $1.element.1 ? $0.element.1 > $1.element.1 : $0.offset < $1.offset }
                .map { $0.element }
            if counter[0].0 == .natural { counter.swapAt(0, 1) }
            if counter[0].0 == .flat {
                label = .flat
            } else if counter[0].0 == .sharp {
                label = .sharp
            }
        }
        var count = pyRound(Double(counts.reduce(0, +)) / Double(trackNums))
        if label == .flat { count *= -1 }
        for s in cands { s.isKey = true }
        return max(-6, min(6, count))
    }

    func trackClefs() -> [Clef?] {
        let n = ctx.totalTrackNums
        if atBeginning || doubleBarline {
            return (0..<n).map { track in
                if let c = clefs.first(where: { $0.track == track }) { return c }
                let c = Clef(bbox: BBox(0, 0, 0, 0))
                c.track = track
                c.group = group
                c.label = track % 2 == 0 ? .gClef : .fClef
                return c
            }
        }
        return Array(repeating: nil, count: n)
    }

    func duration(of s: MeasureSymbol) -> Int {
        if let v = s as? Voice { return v.duration }
        let r = s as! Rest
        var d = restDura(r.label)
        if r.hasDot == true { d = pyRound(Double(d) * 1.5) }
        return d
    }

    /// `extend_symbol_length(symbol, duration)`
    private func extend(_ s: MeasureSymbol, _ duration: Int) {
        if let v = s as? Voice {
            let (lab, dot) = labelByDura(duration, noteRhythm.map { ($0.0, $0.2) })
            v.label = lab
            v.hasDot = dot
            v.duration = duration
            v.rhythmName = rhythm(lab).name
            for nid in v.noteIds {
                if let l = lab { ctx.notes[nid].forceSetLabel(l) }
                ctx.notes[nid].hasDot = dot
            }
        } else if let r = s as? Rest {
            let (lab, dot) = labelByDura(duration, restDuration)
            if let l = lab { r.label = l }
            r.hasDot = dot
        }
    }

    /// `align_symbols()`
    func alignSymbols() {
        let trackNums = ctx.totalTrackNums
        let unit = ctx.globalUnitSize
        var slots: [[MeasureSymbol]] = []
        var corrSidx: [Int] = []
        var lastX: Double? = nil
        for (idx, sym) in symbols.enumerated() {
            if sym is Clef || sym is Sfn { continue }
            if let lx = lastX, abs(sym.xCenter - lx) < unit {
                slots[slots.count - 1].append(sym)
            } else {
                lastX = sym.xCenter
                slots.append([sym])
                corrSidx.append(idx)
            }
        }
        var trackDuras = [[Int]](repeating: [Int](repeating: 0, count: trackNums), count: slots.count)
        for (idx, slot) in slots.enumerated() {
            var per = [[Int]](repeating: [], count: trackNums)
            for s in slot where s.track < trackNums { per[s.track].append(duration(of: s)) }
            for t in 0..<trackNums { trackDuras[idx][t] = per[t].min() ?? 0 }
        }
        if trackNums != 2 {
            timeSlots = slots
            slotDuras = trackDuras.map { $0.map { Double($0) } }
            return
        }

        var diff = 0
        var leadTrack: Int? = nil
        var addIdx = 0
        var added = 0
        var solved = true
        var newDuras = trackDuras.map { $0.map { Double($0) } }
        var curIdx = 0

        func modify(_ addIdx: Int, _ diff: Int, _ lead: Int) {
            let other = 1 - lead
            let pos = trackDuras[addIdx][other]
            if pos != 0 {
                for s in slots[addIdx] where s.track == other { extend(s, diff + pos) }
                newDuras[addIdx][other] = Double(diff + pos)
            } else {
                let r = Rest(bbox: BBox(0, 0, 0, 0))
                let (lab, dot) = labelByDura(diff, restDuration)
                if let l = lab { r.label = l }
                r.hasDot = dot
                r.track = other
                r.group = group
                r.xCenterOverride = slots[addIdx][0].xCenter
                let insertIdx = corrSidx[curIdx] + added
                symbols.insert(r, at: min(insertIdx, symbols.count))
                slots[addIdx].insert(r, at: 0)
                added += 1
                newDuras[addIdx][other] = Double(diff)
            }
        }

        for (idx, td) in trackDuras.enumerated() {
            curIdx = idx
            let t1 = td[0], t2 = td[1]
            if t1 > 0 && t2 > 0 {
                if diff > 0, let l = leadTrack { modify(addIdx, diff, l) }
                if t1 > t2 {
                    diff = t1 - t2
                    leadTrack = 0
                } else {
                    diff = t2 - t1
                    leadTrack = 1
                }
                addIdx = idx
                solved = true
            } else if t1 > 0 {
                if leadTrack == 0 {
                    diff += t1
                } else if diff >= t1 {
                    diff -= t1
                } else {
                    diff = (0 < diff && diff < t1) ? t1 - diff : t1
                    addIdx = idx
                    leadTrack = 0
                }
                solved = false
            } else if t2 > 0 {
                if leadTrack == 1 {
                    diff += t2
                } else if diff >= t2 {
                    diff -= t2
                } else {
                    diff = (0 < diff && diff < t2) ? t2 - diff : t2
                    addIdx = idx
                    leadTrack = 1
                }
                solved = false
            }
        }
        if !solved && diff > 0, let l = leadTrack { modify(addIdx, diff, l) }
        timeSlots = slots
        slotDuras = newDuras
    }

    func timeSlotDura(_ x: Double) -> (Int, [Double]) {
        if timeSlots.count > 1 {
            for idx in 0..<(timeSlots.count - 1) {
                if timeSlots[idx][0].xCenter <= x && x < timeSlots[idx + 1][0].xCenter { return (idx, slotDuras[idx]) }
            }
        }
        return (timeSlots.count - 1, slotDuras.last ?? [])
    }
}

/// Mutable state shared by the actions while writing (`Action.ctx`).
private struct WriterState {
    var key = 0
    var clefs: [Clef?] = []
    var sfnState: [String: SfnType?] = [:]

    mutating func initSfnState() {
        sfnState = Dictionary(uniqueKeysWithValues: ["A", "B", "C", "D", "E", "F", "G"].map { ($0, nil as SfnType?) })
        if key > 0 {
            for n in sharpKeyOrder.prefix(key) { sfnState[n] = .sharp }
        } else if key < 0 {
            for n in flatKeyOrder.prefix(-key) { sfnState[n] = .flat }
        }
    }
}

private enum Action {
    case initMeasure(Measure)
    case measure(Measure, addBreak: Bool)
    case clefChange(Clef)
    case keyChange(Int)
    case note(NoteHead, chord: Bool, voice: Int)
    case rest(Rest)
    case backup(Int)
    case forward(Int)
}

/// One recognized note as written to MusicXML, with its position on the input image.
public struct RecognizedNote {
    /// Pixel box of the notehead (x1, y1, x2, y2) in the processed image.
    public let bbox: BBox
    public let step: String
    public let alter: Int
    public let octave: Int
    /// 1-based staff number in the system (1 = top staff).
    public let staff: Int
    public let type: String
    public let dotted: Bool

    /// Name like "C#4" / "Bb3".
    public var name: String { step + (alter == 1 ? "#" : alter == -1 ? "b" : "") + String(octave) }
}

final class MusicXMLBuilder {
    unowned let ctx: OMRContext
    private var measures: [(group: Int, measures: [Measure])] = []
    private var actions: [Action] = []
    private(set) var writtenNotes: [RecognizedNote] = []

    init(ctx: OMRContext) { self.ctx = ctx }

    private func voices() -> [Voice] {
        var out: [Voice] = []
        func addVoice(_ g: NoteGroup, _ nidsIn: [Int], _ stemUp: Bool?) {
            let nids = nidsIn.filter { !ctx.notes[$0].invalid }
            if nids.isEmpty { return }
            let v = Voice()
            v.group = g.group
            v.groupId = g.id
            v.track = g.track
            v.noteIds = nids
            v.stemUp = stemUp
            v.center = g.xCenter
            // Voice.init(): most common label (ties: first seen), majority dot
            let labels = nids.map { ctx.notes[$0].label }
            var order: [NoteType?] = []
            var counts: [Int] = []
            for l in labels {
                if let i = order.firstIndex(where: { $0 == l }) { counts[i] += 1 } else { order.append(l); counts.append(1) }
            }
            var best = 0
            for i in 1..<max(order.count, 1) where counts[i] > counts[best] { best = i }
            v.label = order[best]
            let t = nids.filter { ctx.notes[$0].hasDot }.count
            v.hasDot = t > nids.count - t
            for nid in nids {
                if ctx.notes[nid].label != v.label, let l = v.label { ctx.notes[nid].forceSetLabel(l) }
                ctx.notes[nid].hasDot = v.hasDot
            }
            let r = rhythm(v.label)
            v.rhythmName = r.name
            v.duration = v.hasDot ? pyRound(Double(r.duration) * 1.5) : r.duration
            out.append(v)
        }
        for g in ctx.groups {
            if g.stemUp == nil && g.hasStem == true {
                addVoice(g, g.topNoteIds, true)
                addVoice(g, g.bottomNoteIds, false)
            } else {
                addVoice(g, g.noteIds, g.stemUp)
            }
        }
        for (i, v) in out.enumerated() { v.id = i }
        return out
    }

    /// `sort_symbols(voices)`
    private func sortSymbols(_ voices: [Voice]) -> [(Int, [MeasureSymbol])] {
        var container: [Int: [MeasureSymbol]] = [:]
        var order: [Int] = []
        func add(_ items: [MeasureSymbol]) {
            for s in items {
                if container[s.group] == nil {
                    container[s.group] = []
                    order.append(s.group)
                }
                container[s.group]!.append(s)
            }
        }
        add(voices)
        add(ctx.barlines)
        add(ctx.rests)
        add(ctx.clefs)
        add(ctx.sfns.filter { $0.noteId == nil })
        return order.sorted().map { g in
            let list = container[g]!.enumerated()
                .sorted { $0.element.xCenter != $1.element.xCenter ? $0.element.xCenter < $1.element.xCenter : $0.offset < $1.offset }
                .map { $0.element }
            return (g, list)
        }
    }

    private func genMeasure(_ buffer: [MeasureSymbol], _ grp: Int, _ num: Int, _ atBeginning: Bool, _ doubleBarline: Bool) -> Measure {
        let m = Measure(ctx: ctx)
        m.addSymbols(buffer)
        m.doubleBarline = doubleBarline
        m.number = num
        m.atBeginning = atBeginning
        m.group = grp
        _ = m.getKey()
        m.alignSymbols()
        return m
    }

    private func genMeasures(_ container: [(Int, [MeasureSymbol])]) {
        var num = 1
        for (grp, insts) in container {
            var list: [Measure] = []
            var buffer: [MeasureSymbol] = []
            var atBeginning = true
            var doubleBarline = false
            for inst in insts {
                if inst is Barline {
                    if buffer.isEmpty {
                        doubleBarline = true
                    } else {
                        list.append(genMeasure(buffer, grp, num, atBeginning, doubleBarline))
                        num += 1
                        buffer = []
                        atBeginning = false
                        doubleBarline = false
                    }
                    continue
                }
                buffer.append(inst)
            }
            if !buffer.isEmpty { list.append(genMeasure(buffer, grp, num, atBeginning, doubleBarline)) }
            measures.append((grp, list))
        }
    }

    /// `MusicXMLBuilder.build()`
    func build() {
        genMeasures(sortSymbols(voices()))
        guard let first = measures.first(where: { $0.group == 0 })?.measures.first ?? measures.first?.measures.first else { return }
        actions.append(.initMeasure(first))
        var curKey = first.getKey()
        var curClefs = first.trackClefs()
        let totalTracks = curClefs.count

        for (_, ms) in measures {
            var addBreak = true
            for m in ms {
                actions.append(.measure(m, addBreak: addBreak))
                addBreak = false
                var lastTidx = 0
                var lastDura = 0.0
                var lastPos = 0.0
                var totals = [Double](repeating: 0, count: totalTracks)
                var minAdded = [Bool](repeating: false, count: totalTracks)
                for sym in m.symbols {
                    let track = sym.track
                    if let c = sym as? Clef {
                        if track < curClefs.count, curClefs[track]?.label != c.label {
                            actions.append(.clefChange(c))
                            curClefs[track] = c
                        }
                    } else if sym is Sfn {
                        if m.hasKey() {
                            let k = m.getKey()
                            if k != curKey {
                                actions.append(.keyChange(k))
                                curKey = k
                            }
                        }
                    } else {
                        guard track < totalTracks else { continue }
                        let (tidx, minDuras) = m.timeSlotDura(sym.xCenter)
                        let minDura = track < minDuras.count ? minDuras[track] : 0
                        let dura = Double(m.duration(of: sym))
                        if tidx == lastTidx && lastDura > 0 {
                            actions.append(.backup(Int(lastDura)))
                        } else {
                            minAdded = [Bool](repeating: false, count: totalTracks)
                            let diff = lastPos - totals[track]
                            if diff > 0 && diff != lastDura { actions.append(.backup(Int(diff))) }
                        }
                        let voiceOne: Bool
                        if dura == minDura && !minAdded[track] {
                            totals[track] += minDura
                            minAdded[track] = true
                            voiceOne = true
                        } else {
                            voiceOne = false
                        }
                        if let r = sym as? Rest {
                            actions.append(.rest(r))
                            lastPos = totals[track]
                            lastDura = dura
                            lastTidx = tidx
                        } else if let v = sym as? Voice {
                            if Double(v.duration) == minDura && voiceOne {
                                actions.append(.note(ctx.notes[v.noteIds[0]], chord: false, voice: 1))
                                for nid in v.noteIds.dropFirst() { actions.append(.note(ctx.notes[nid], chord: true, voice: 1)) }
                                lastPos = totals[track]
                                lastDura = dura
                                lastTidx = tidx
                            } else {
                                actions.append(.note(ctx.notes[v.noteIds[0]], chord: false, voice: 2))
                                for nid in v.noteIds.dropFirst() { actions.append(.note(ctx.notes[nid], chord: true, voice: 2)) }
                                var curPos = totals[track] + Double(v.duration)
                                if minAdded[track] { curPos -= minDura }
                                let d = lastPos - curPos
                                if d > 0 {
                                    actions.append(.forward(Int(d)))
                                } else if d < 0 {
                                    actions.append(.backup(Int(-d)))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - XML

    private func keyElement(_ k: Int) -> XMLNode {
        let key = XMLNode("key")
        key.add("fifths", text: String(k))
        return key
    }

    private func clefElement(_ c: Clef) -> XMLNode {
        let e = XMLNode("clef", [("number", String(c.track + 1))])
        let sign = c.label == .gClef ? "G" : "F"
        e.add("sign", text: sign)
        e.add("line", text: sign == "G" ? "2" : "4")
        return e
    }

    private func chroma(_ pos: Int, _ clef: ClefType) -> String {
        let order = clef == .gClef ? gClefPosToPitch : fClefPosToPitch
        return pos >= 0 ? order[pyMod(pos, 7)] : order[(pos % -7 + 7) % 7]
    }

    /// `decode_note(...)`; also records the written pitch.
    private func noteElement(_ n: NoteHead, clef: ClefType, chord: Bool, voice: Int) -> XMLNode? {
        if n.invalid { return nil }
        let e = XMLNode("note")
        if chord { e.add("chord") }
        let pos = n.staffLinePos
        let order: [String], octOffset: Int, pitchOffset: Int
        if clef == .gClef {
            order = gClefPosToPitch
            octOffset = 4
            pitchOffset = 1
        } else {
            order = fClefPosToPitch
            octOffset = 2
            pitchOffset = 3
        }
        // Python: order[pos % 7] if pos >= 0 else order[pos % -7]  (negative index wraps)
        let step = pos >= 0 ? order[pyMod(pos, 7)] : order[(pyMod(pos, -7) + 7) % 7]
        let octave: Int
        if pos - pitchOffset >= 0 {
            octave = Int(floor(Double(pos + pitchOffset) / 7)) + octOffset
        } else {
            octave = -Int(ceil(Double(pos + pitchOffset) / -7)) + octOffset
        }
        var alter = 0
        if n.sfn == .sharp { alter = 1 } else if n.sfn == .flat { alter = -1 }
        if octave < 0 || octave > 8 || (octave == 0 && step != "A") || (octave == 8 && step != "C") { return nil }

        let pitch = e.add("pitch")
        pitch.add("step", text: step)
        pitch.add("alter", text: String(alter))
        pitch.add("octave", text: String(octave))
        let r = rhythm(n.label)
        var dura = r.duration
        e.add("duration", text: String(dura))
        e.add("type", text: r.name)
        if n.hasDot {
            dura = pyRound(Double(dura) * 1.5)
            e.children.first { $0.name == "duration" }!.text = String(dura)
            e.add("dot")
        }
        e.add("stem", text: n.stemUp == true ? "up" : "down")
        e.add("staff", text: String(n.track + 1))
        e.add("voice", text: String(voice))
        writtenNotes.append(RecognizedNote(bbox: n.bbox, step: step, alter: alter, octave: octave,
                                           staff: n.track + 1, type: r.name, dotted: n.hasDot))
        return e
    }

    private func restElement(_ r: Rest) -> XMLNode {
        let e = XMLNode("note")
        e.add("rest", [("measure", "yes")])
        var d = restDura(r.label)
        let du = e.add("duration", text: String(d))
        if r.hasDot == true {
            d = pyRound(Double(d) * 1.5)
            du.text = String(d)
            e.add("dot")
        }
        e.add("staff", text: String(r.track + 1))
        return e
    }

    /// `MusicXMLBuilder.to_musicxml()`
    func toMusicXML(title: String, tempo: Int = 90) -> String {
        let score = XMLNode("score-partwise", [("version", "4.0")])
        let work = score.add("work")
        work.add("work-title", text: title)
        let iden = score.add("identification")
        iden.add("creator", [("type", "composer")], text: "Transcribed by Oemer")
        let partList = score.add("part-list")
        let sp = partList.add("score-part", [("id", "P1")])
        sp.add("part-name", text: "Piano")
        let si = sp.add("score-instrument", [("id", "P1-I1")])
        si.add("instrument-name", text: "Piano")
        si.add("instrument-sound", text: "keyboard.piano")
        let mi = sp.add("midi-instrument", [("id", "P1-I1")])
        mi.add("midi-channel", text: "1")
        mi.add("midi-program", text: "1")
        mi.add("volume", text: "80")
        mi.add("pan", text: "0")
        let part = score.add("part", [("id", "P1")])
        part.add("sound", [("tempo", String(tempo))])

        var state = WriterState()
        var measureEl: XMLNode? = nil
        writtenNotes = []
        for a in actions {
            switch a {
            case .initMeasure(let m):
                state.key = m.getKey()
                state.clefs = m.trackClefs()
                state.initSfnState()
                let el = part.add("measure", [("number", String(m.number))])
                let attr = el.add("attributes")
                attr.add("divisions", text: String(divisionPerQuarter))
                attr.append(keyElement(m.getKey()))
                attr.add("staves", text: String(ctx.totalTrackNums))
                for c in m.trackClefs() { if let c = c { attr.append(clefElement(c)) } }
                measureEl = el
            case .measure(let m, let addBreak):
                state.initSfnState()
                let el = part.add("measure", [("number", String(m.number))])
                if addBreak { el.add("print", [("new-system", "yes")]) }
                measureEl = el
            case .clefChange(let c):
                if c.track < state.clefs.count { state.clefs[c.track] = c }
                let attr = XMLNode("attributes")
                attr.append(clefElement(c))
                measureEl?.append(attr)
            case .keyChange(let k):
                state.key = k
                state.initSfnState()
                let attr = XMLNode("attributes")
                attr.append(keyElement(k))
                measureEl?.append(attr)
            case .note(let n, let chord, let voice):
                let clef = (n.track < state.clefs.count ? state.clefs[n.track]?.label : nil) ?? .gClef
                let ch = chroma(n.staffLinePos, clef)
                let cur = state.sfnState[ch] ?? nil
                if let s = n.sfn, cur != s {
                    state.sfnState[ch] = s
                } else {
                    n.sfn = cur
                }
                if let el = noteElement(n, clef: clef, chord: chord, voice: voice) { measureEl?.append(el) }
            case .rest(let r):
                measureEl?.append(restElement(r))
            case .backup(let d):
                if d != 0 {
                    let b = XMLNode("backup")
                    b.add("duration", text: String(d))
                    measureEl?.append(b)
                }
            case .forward(let d):
                if d != 0 {
                    let f = XMLNode("forward")
                    f.add("duration", text: String(d))
                    measureEl?.append(f)
                }
            }
        }

        var xml = prettyXML(score)
        let doctype = "<!DOCTYPE score-partwise PUBLIC \"-//Recordare//DTD MusicXML 4.0 Partwise//EN\" \"http://www.musicxml.org/dtds/partwise.dtd\">"
        if let r = xml.range(of: "?>") {
            xml = String(xml[..<r.upperBound]) + "\n" + doctype + String(xml[r.upperBound...])
        }
        // Work around for merging the init and the first measure (same regex as the original).
        if let re = try? NSRegularExpression(pattern: "\\s+</measure>\\n\\s+<measure number=\"1\">\\n\\s+<print.+/>") {
            let ns = xml as NSString
            xml = re.stringByReplacingMatches(in: xml, range: NSRange(location: 0, length: ns.length), withTemplate: "")
        }
        return xml
    }
}
