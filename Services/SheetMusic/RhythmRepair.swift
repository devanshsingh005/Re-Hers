//
//  RhythmRepair.swift
//  Re-Hearse_v1
//
//  Fixes measures the recognizer made too long, after the pages are merged. The recognizer reads
//  pitches well but often gets note lengths wrong (a sixteenth read as an eighth, a dot that isn't
//  there, a stray rest), and since every staff is lined up with the others, one wrong length
//  makes the whole measure longer than its time signature. Notes then sound and show late
//  against the beat, more so the further into the measure they are.
//
//  - A measure that is too long and begins with a moment where every staff only rests (the
//    note of a metronome mark taken for music and hidden, plus the rest the recognizer padded
//    the other staff with) loses that moment.
//  - A measure still too long is re-timed to the measure's length: its notes keep their order,
//    on a sixteenth grid (thirty-seconds where the measure has them); the time between notes is
//    kept where it can be and otherwise changed as little as possible, preferring plain note
//    values; lengths, note values and dots are rewritten to match.
//
//  The measure's length is the written time signature, else the length most measures have.
//  Measures with tuplets, and measures more than 60% too long (probably a barline that was
//  missed), are left as they are.
//

import Foundation

nonisolated enum RhythmRepair {
    struct Report: Equatable {
        var leadingGaps = 0
        var refitted = 0
    }

    @discardableResult
    static func repair(_ score: XMLElementNode) -> Report {
        var report = Report()
        for part in score.children(named: "part") {
            let measures = part.children(named: "measure")
            var divisions = 1
            var parsed: [(measure: XMLElementNode, content: MeasureContent, divisions: Int, written: Int?)] = []
            var written: Int?
            for measure in measures {
                for attributes in measure.children(named: "attributes") {
                    if let d = Int(attributes.firstChild(named: "divisions")?.text ?? ""), d > 0 { divisions = d }
                    if let time = attributes.firstChild(named: "time"),
                       let beats = Int(time.firstChild(named: "beats")?.text ?? ""),
                       let type = Int(time.firstChild(named: "beat-type")?.text ?? ""), type > 0 {
                        written = beats * divisions * 4 / type
                    }
                }
                parsed.append((measure, MeasureContent(measure), divisions, written))
            }
            guard let expected = expectedLength(parsed.map { ($0.content.length, $0.written) }) else { continue }
            for item in parsed {
                var content = item.content
                let length = item.written ?? expected
                guard content.length > length, content.length * 10 <= length * 16, !content.hasTuplets else { continue }
                var changed = false
                if content.dropLeadingRests() {
                    report.leadingGaps += 1
                    changed = true
                }
                if content.length > length, content.refit(to: length, divisions: item.divisions) {
                    report.refitted += 1
                    changed = true
                }
                if changed { content.write(into: item.measure, divisions: item.divisions) }
            }
        }
        return report
    }

    /// The written length if there is one, else the most common measure length (in a longer
    /// piece the first and last measure don't vote: a pickup, an ending).
    private static func expectedLength(_ measures: [(length: Int, written: Int?)]) -> Int? {
        if let written = measures.compactMap(\.written).first { return written }
        let voting = measures.count > 4 ? Array(measures.dropFirst().dropLast()) : measures
        var counts: [Int: Int] = [:]
        for m in voting where m.length > 0 { counts[m.length, default: 0] += 1 }
        return counts.max { ($0.value, $0.key) < ($1.value, $1.key) }?.key
    }
}

// MARK: - One measure as timed events

/// A measure's notes with their times, and everything else in it, so it can be re-timed and
/// written back (each staff and voice in turn, joined by <backup> and <forward>).
private nonisolated struct MeasureContent {
    struct Event {
        let note: XMLElementNode
        var chordTones: [XMLElementNode] = []
        let staff: Int
        var voice: String
        var start: Int
        var duration: Int
        let isRest: Bool
        let isGrace: Bool
    }

    var events: [Event] = []
    /// Attributes, directions, sounds… (written first) and right-hand barlines (written last).
    var leading: [XMLElementNode] = []
    var trailing: [XMLElementNode] = []
    var length = 0
    var hasTuplets = false

    init(_ measure: XMLElementNode) {
        var cursor = 0
        for child in measure.children {
            switch child.name {
            case "note":
                if child.firstChild(named: "time-modification") != nil { hasTuplets = true }
                if child.firstChild(named: "chord") != nil, !events.isEmpty {
                    events[events.count - 1].chordTones.append(child)
                    continue
                }
                let isGrace = child.firstChild(named: "grace") != nil
                let duration = isGrace ? 0 : max(0, Int(child.firstChild(named: "duration")?.text ?? "") ?? 0)
                events.append(Event(note: child, staff: Int(child.firstChild(named: "staff")?.text ?? "") ?? 1,
                                    voice: child.firstChild(named: "voice")?.text ?? "",
                                    start: cursor, duration: duration,
                                    isRest: child.firstChild(named: "rest") != nil, isGrace: isGrace))
                cursor += duration
                length = max(length, cursor)
            case "backup":
                cursor -= Int(child.firstChild(named: "duration")?.text ?? "") ?? 0
                cursor = max(0, cursor)
            case "forward":
                cursor += Int(child.firstChild(named: "duration")?.text ?? "") ?? 0
                length = max(length, cursor)
            case "barline" where child.attribute("location") != "left":
                trailing.append(child)
            default:
                leading.append(child)
            }
        }
        // rests written without a voice belong to their staff's own voice
        var voiceOfStaff: [Int: String] = [:]
        for e in events where !e.voice.isEmpty && voiceOfStaff[e.staff] == nil { voiceOfStaff[e.staff] = e.voice }
        for i in events.indices where events[i].voice.isEmpty { events[i].voice = voiceOfStaff[events[i].staff] ?? "1" }
    }

    /// Removes a stretch at the start where every staff only rests. True when something went.
    mutating func dropLeadingRests() -> Bool {
        guard let firstNote = events.filter({ !$0.isRest && !$0.isGrace }).map(\.start).min(), firstNote > 0,
              events.allSatisfy({ $0.start >= firstNote || $0.isRest })
        else { return false }
        events = events.compactMap { e in
            var e = e
            if e.start < firstNote {
                let end = e.start + e.duration
                guard end > firstNote else { return nil }      // wholly inside the gap
                e.duration = end - firstNote                    // a rest reaching past it is cut
                e.start = firstNote
            }
            e.start -= firstNote
            return e
        }
        length -= firstNote
        return true
    }

    /// Re-times the measure to `target` ticks. False when its notes can't be placed on the grid.
    mutating func refit(to target: Int, divisions: Int) -> Bool {
        guard length > 0, target > 0 else { return false }
        let sixteenth = max(1, divisions / 4)
        let usesShorter = events.contains { !$0.isGrace && $0.duration > 0 && $0.duration < sixteenth }
        for grid in usesShorter ? [max(1, divisions / 8)] : [sixteenth, max(1, divisions / 8)] {
            if let map = timeMap(target: target, grid: grid) {
                for i in events.indices {
                    let start = map[events[i].start] ?? 0
                    let end = events[i].isGrace ? start : (map[events[i].start + events[i].duration] ?? target)
                    events[i].start = start
                    events[i].duration = events[i].isGrace ? 0 : max(grid, end - start)
                }
                length = target
                return true
            }
        }
        return false
    }

    /// New times for every start and end in the measure, on `grid` and adding up to `target`.
    /// The gaps between successive moments are chosen together: each stays as it was where it
    /// can, else shrinks (or grows) as little as possible, preferring lengths that are plain note
    /// values (a quarter, a dotted eighth) over odd ones (five sixteenths). Nil when they can't fit.
    private func timeMap(target: Int, grid: Int) -> [Int: Int]? {
        var times = Set<Int>([0, length])
        for e in events { times.insert(e.start); times.insert(e.start + e.duration) }
        let sorted = times.filter { $0 >= 0 && $0 <= length }.sorted()
        let gaps = zip(sorted, sorted.dropFirst()).map { max(1.0, Double($1 - $0) / Double(grid)) }
        let slots = target / grid
        guard target % grid == 0, !gaps.isEmpty, gaps.count <= slots else { return nil }

        // plain lengths in grid units: 1, 2, 3, 4, 6, 8, 12, 16… sixteenths (or thirty-seconds)
        let plain = Set([1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64])
        func cost(_ old: Double, _ new: Int) -> Double {
            if Double(new) == old { return 0 }
            return 0.15 + abs(log(Double(new) / old)) + (plain.contains(new) ? 0 : 0.6)
        }
        // best[k][s]: least cost giving the first k gaps s units in all
        let count = gaps.count
        var best = [[Double]](repeating: [Double](repeating: .infinity, count: slots + 1), count: count + 1)
        var choice = [[Int]](repeating: [Int](repeating: 0, count: slots + 1), count: count + 1)
        best[0][0] = 0
        for k in 0..<count {
            let remaining = count - k - 1                 // every later gap needs a unit at least
            for s in 0...slots where best[k][s] < .infinity {
                let most = slots - s - remaining
                guard most >= 1 else { continue }
                for x in 1...most {
                    let c = best[k][s] + cost(gaps[k], x)
                    if c < best[k + 1][s + x] {
                        best[k + 1][s + x] = c
                        choice[k + 1][s + x] = x
                    }
                }
            }
        }
        guard best[count][slots] < .infinity else { return nil }
        var widths = [Int](repeating: 0, count: count)
        var s = slots
        for k in stride(from: count, to: 0, by: -1) {
            widths[k - 1] = choice[k][s]
            s -= choice[k][s]
        }
        var map: [Int: Int] = [sorted[0]: 0]
        var t = 0
        for (k, w) in widths.enumerated() {
            t += w * grid
            map[sorted[k + 1]] = t
        }
        return map
    }

    /// Writes the events back into `measure`: each staff and voice in turn.
    func write(into measure: XMLElementNode, divisions: Int) {
        var children = leading
        var lanes: [String: [Event]] = [:]
        for e in events { lanes["\(e.staff)|\(e.voice)", default: []].append(e) }
        let order = lanes.keys.sorted { a, b in
            let (sa, sb) = (Int(a.split(separator: "|")[0]) ?? 0, Int(b.split(separator: "|")[0]) ?? 0)
            return sa != sb ? sa < sb : a < b
        }
        var cursor = 0
        for (k, key) in order.enumerated() {
            if k > 0, cursor > 0 { children.append(Self.timing("backup", cursor)); cursor = 0 }
            for e in lanes[key]!.sorted(by: { $0.start < $1.start }) {
                if e.start > cursor { children.append(Self.timing("forward", e.start - cursor)) }
                if e.start < cursor { children.append(Self.timing("backup", cursor - e.start)) }
                Self.setDuration(e.note, ticks: e.duration, divisions: divisions, grace: e.isGrace)
                for tone in e.chordTones { Self.setDuration(tone, ticks: e.duration, divisions: divisions, grace: e.isGrace) }
                children.append(e.note)
                children.append(contentsOf: e.chordTones)
                cursor = e.start + e.duration
            }
        }
        if cursor < length { children.append(Self.timing("forward", length - cursor)) }
        children.append(contentsOf: trailing)
        measure.children = children
    }

    private static func timing(_ name: String, _ ticks: Int) -> XMLElementNode {
        let element = XMLElementNode(name: name)
        let duration = XMLElementNode(name: "duration")
        duration.text = String(ticks)
        element.children = [duration]
        return element
    }

    /// Sets a note's <duration>, and its <type> and dots to the value that length is.
    static func setDuration(_ note: XMLElementNode, ticks: Int, divisions: Int, grace: Bool) {
        guard !grace else { return }
        if let duration = note.firstChild(named: "duration") { duration.text = String(ticks) }
        let quarters = Double(ticks) / Double(max(1, divisions))
        let values: [(String, Double)] = [("whole", 4), ("half", 2), ("quarter", 1), ("eighth", 0.5),
                                          ("16th", 0.25), ("32nd", 0.125), ("64th", 0.0625)]
        var choice: (type: String, dots: Int)?
        outer: for (type, base) in values {
            for dots in 0...2 {
                let length = base * (dots == 0 ? 1 : dots == 1 ? 1.5 : 1.75)
                if abs(length - quarters) < 1e-9 { choice = (type, dots); break outer }
            }
        }
        // not a single note value (five sixteenths…): the largest value that fits
        let picked = choice ?? (values.first { $0.1 <= quarters + 1e-9 }.map { ($0.0, 0) } ?? ("64th", 0))
        let isMeasureRest = note.firstChild(named: "rest")?.attribute("measure") == "yes"
        note.children.removeAll { $0.name == "dot" }
        if isMeasureRest { return }
        if let type = note.firstChild(named: "type") {
            type.text = picked.type
        } else if let at = note.children.firstIndex(where: { $0.name == "duration" }) {
            let type = XMLElementNode(name: "type")
            type.text = picked.type
            note.children.insert(type, at: at + 1)
        }
        if let at = note.children.firstIndex(where: { $0.name == "type" }) {
            for k in 0..<picked.dots { note.children.insert(XMLElementNode(name: "dot"), at: at + 1 + k) }
        }
    }
}
