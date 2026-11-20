//
//  ScoreCleanup.swift
//  Re-Hearse_v1
//
//  Undoes two recognition errors the recognizer makes on printed piano music, after the pages
//  are merged:
//
//  - Clef changes that are not there. A bass clef "read" on the right hand's staff (or a treble
//    clef on the left hand's) shifts every note after it by an octave and a sixth. A change is
//    taken as false when it puts the right hand below the left (or the left above the right)
//    for as long as it lasts; it is removed and those notes get back the pitches the original
//    clef gives them.
//  - Key signatures that are not there: a change that goes back to the previous key within four
//    measures (composers write such passages with accidentals). It is removed, and notes that
//    took their sharp or flat from the false key take them from the real one.
//

import Foundation

nonisolated enum ScoreCleanup {
    private static let steps = ["C", "D", "E", "F", "G", "A", "B"]
    private static let semitones = [0, 2, 4, 5, 7, 9, 11]

    /// What was undone, for the log.
    struct Report: Equatable {
        var clefs = 0
        var keys = 0
    }

    @discardableResult
    static func clean(_ score: XMLElementNode) -> Report {
        var report = Report()
        for part in score.children(named: "part") {
            let measures = part.children(named: "measure")
            report.keys += removeFalseKeys(measures)
            report.clefs += removeFalseClefs(measures)
        }
        return report
    }

    // MARK: Notes

    private static func pitch(_ note: XMLElementNode) -> (step: Int, octave: Int, alter: Int)? {
        guard let pitch = note.firstChild(named: "pitch"),
              let step = steps.firstIndex(of: pitch.firstChild(named: "step")?.text ?? ""),
              let octave = Int(pitch.firstChild(named: "octave")?.text ?? "") else { return nil }
        return (step, octave, Int(pitch.firstChild(named: "alter")?.text ?? "0") ?? 0)
    }

    private static func midi(_ note: XMLElementNode) -> Int? {
        pitch(note).map { 12 * ($0.octave + 1) + semitones[$0.step] + $0.alter }
    }

    private static func setPitch(_ note: XMLElementNode, step: Int, octave: Int, alter: Int) {
        guard let pitch = note.firstChild(named: "pitch") else { return }
        pitch.firstChild(named: "step")?.text = steps[step]
        pitch.firstChild(named: "octave")?.text = String(octave)
        if let element = pitch.firstChild(named: "alter") {
            element.text = String(alter)
        } else if alter != 0 {
            let element = XMLElementNode(name: "alter")
            element.text = String(alter)
            pitch.children.insert(element, at: 1)
        }
    }

    /// The sharp or flat the key gives a step (0 C … 6 B).
    static func keyAlter(step: Int, fifths: Int) -> Int {
        let sharpOrder = [3, 0, 4, 1, 5, 2, 6]          // F C G D A E B
        if fifths > 0, let i = sharpOrder.firstIndex(of: step), i < fifths { return 1 }
        if fifths < 0, let i = Array(sharpOrder.reversed()).firstIndex(of: step), i < -fifths { return -1 }
        return 0
    }

    // MARK: Keys

    private static func keys(in measure: XMLElementNode) -> [(attributes: XMLElementNode, key: XMLElementNode, fifths: Int)] {
        measure.children(named: "attributes").flatMap { attributes in
            attributes.children(named: "key").compactMap { key in
                Int(key.firstChild(named: "fifths")?.text ?? "").map { (attributes, key, $0) }
            }
        }
    }

    private static func removeFalseKeys(_ measures: [XMLElementNode]) -> Int {
        // the key in force at each measure, and where it changes
        var changes: [(measure: Int, fifths: Int)] = []
        for (m, measure) in measures.enumerated() {
            if let key = keys(in: measure).last { changes.append((m, key.fifths)) }
        }
        guard changes.count >= 3 else { return 0 }
        var removed = 0
        var real = changes[0].fifths
        var i = 1
        while i < changes.count {
            let change = changes[i]
            guard change.fifths != real else { i += 1; continue }
            // a key that goes back to the real one within four measures (or never stays)
            let next = i + 1 < changes.count ? changes[i + 1] : nil
            guard let back = next, back.fifths == real, back.measure - change.measure <= 4 else {
                real = change.fifths
                i += 1
                continue
            }
            // undo: drop both signatures; notes that followed the false key follow the real one
            for m in change.measure..<back.measure {
                for note in measures[m].children(named: "note") {
                    guard let p = pitch(note) else { continue }
                    if p.alter == keyAlter(step: p.step, fifths: change.fifths) {
                        setPitch(note, step: p.step, octave: p.octave, alter: keyAlter(step: p.step, fifths: real))
                    }
                }
            }
            for m in [change.measure, back.measure] {
                for key in keys(in: measures[m]) {
                    key.attributes.children.removeAll { $0 === key.key }
                }
                measures[m].children.removeAll { $0.name == "attributes" && $0.children.isEmpty }
            }
            removed += 1
            i += 2
        }
        return removed
    }

    // MARK: Clefs

    private struct Clef: Equatable {
        let sign: String
        let line: Int
        /// Diatonic index (octave × 7 + step) of the bottom line.
        var bottom: Int {
            switch sign {
            case "F": return 3 * 7 + 3 - 2 * (line - 1)
            case "C": return 4 * 7 - 2 * (line - 1)
            default:  return 4 * 7 + 4 - 2 * (line - 1)
            }
        }
    }

    /// Every pitched note and clef element in reading order: (measure, element).
    private enum Event {
        case note(measure: Int, staff: Int, element: XMLElementNode)
        case clef(measure: Int, staff: Int, clef: Clef, element: XMLElementNode, attributes: XMLElementNode)
    }

    private static func events(_ measures: [XMLElementNode]) -> [Event] {
        var events: [Event] = []
        for (m, measure) in measures.enumerated() {
            for child in measure.children {
                if child.name == "attributes" {
                    for element in child.children(named: "clef") {
                        let clef = Clef(sign: element.firstChild(named: "sign")?.text ?? "G",
                                        line: Int(element.firstChild(named: "line")?.text ?? "") ?? 2)
                        events.append(.clef(measure: m, staff: Int(element.attribute("number") ?? "1") ?? 1,
                                            clef: clef, element: element, attributes: child))
                    }
                } else if child.name == "note", child.firstChild(named: "pitch") != nil {
                    events.append(.note(measure: m, staff: Int(child.firstChild(named: "staff")?.text ?? "1") ?? 1,
                                        element: child))
                }
            }
        }
        return events
    }

    private static func removeFalseClefs(_ measures: [XMLElementNode]) -> Int {
        let all = events(measures)
        var current: [Int: Clef] = [:]
        var firstChange = 0
        // the clefs at the start: the first measure's
        for (k, event) in all.enumerated() {
            guard case .clef(let m, let staff, let clef, _, _) = event, m == 0 else { continue }
            current[staff] = clef
            firstChange = k + 1
        }
        guard current[1] != nil, current[2] != nil else { return 0 }   // piano music only
        var removed = 0
        var undone = Set<ObjectIdentifier>()
        for k in firstChange..<all.count {
            guard case .clef(let m, let staff, let clef, let element, let attributes) = all[k],
                  !undone.contains(ObjectIdentifier(element)), let old = current[staff], clef != old else { continue }
            // the notes this clef governs: until this staff's next clef element
            var end = all.count
            for later in (k + 1)..<all.count {
                if case .clef(_, let s, _, _, _) = all[later], s == staff { end = later; break }
            }
            var mine: [XMLElementNode] = []
            var other: [Int] = []
            for event in all[(k + 1)..<end] {
                guard case .note(_, let s, let note) = event else { continue }
                if s == staff { mine.append(note) } else if let pitch = midi(note) { other.append(pitch) }
            }
            let mineMidi = mine.compactMap(midi)
            guard !mineMidi.isEmpty, !other.isEmpty else { current[staff] = clef; continue }
            let mean = Double(mineMidi.reduce(0, +)) / Double(mineMidi.count)
            let otherMean = Double(other.reduce(0, +)) / Double(other.count)
            // where this hand was playing just before
            var before: [Int] = []
            for event in all[..<k].reversed() where before.count < 8 {
                if case .note(_, let s, let note) = event, s == staff, let pitch = midi(note) { before.append(pitch) }
            }
            let shift = old.bottom - clef.bottom
            let shiftedMean = mean + Double(shift) * 12 / 7
            // false: the hands end up crossed (right hand at or below the left, or the other
            // way round), and undoing it puts this hand back where it was playing
            let crossed = staff == 1 ? mean < otherMean + 4 : mean > otherMean - 4
            let previous = before.isEmpty ? nil : Double(before.reduce(0, +)) / Double(before.count)
            let backInPlace = previous.map { abs(shiftedMean - $0) + 5 < abs(mean - $0) } ?? false
            guard crossed && backInPlace else { current[staff] = clef; continue }

            // undo: the notes go back to where the old clef puts them
            let fifths = keyAt(measures, before: m + 1)
            for note in mine {
                guard let p = pitch(note) else { continue }
                let diatonic = p.octave * 7 + p.step + shift
                let step = ((diatonic % 7) + 7) % 7
                let octave = Int((Double(diatonic) / 7).rounded(.down))
                let followedKey = p.alter == keyAlter(step: p.step, fifths: fifths)
                setPitch(note, step: step, octave: octave, alter: followedKey ? keyAlter(step: step, fifths: fifths) : p.alter)
            }
            attributes.children.removeAll { $0 === element }
            measures[m].children.removeAll { $0.name == "attributes" && $0.children.isEmpty }
            // the old clef stays in force, so a later "change back" to it is no change
            if end < all.count, case .clef(let em, _, let back, let backElement, let backAttributes) = all[end], back == old {
                backAttributes.children.removeAll { $0 === backElement }
                measures[em].children.removeAll { $0.name == "attributes" && $0.children.isEmpty }
                undone.insert(ObjectIdentifier(backElement))
            }
            removed += 1
        }
        return removed
    }

    private static func keyAt(_ measures: [XMLElementNode], before end: Int) -> Int {
        var fifths = 0
        for m in 0..<min(end, measures.count) {
            if let key = keys(in: measures[m]).last { fifths = key.fifths }
        }
        return fifths
    }
}
