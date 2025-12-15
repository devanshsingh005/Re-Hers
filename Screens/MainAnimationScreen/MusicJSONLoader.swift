//
//  MusicJSONLoader.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 13/12/25.
//

// MusicJSONLoader.swift
import Foundation

/// Lightweight event used during parsing
private struct NoteEvent {
    let noteName: String    // e.g., "C4", "G#3"
    let midi: Int
    let startTick: Int
    let durationTicks: Int
}

enum MusicJSONLoaderError: Error {
    case notFound, parseError(String)
}

struct MusicJSONLoader {
    /// Load song chords from sheet_music.json located in main bundle.
    /// If tempo or divisions are missing, falls back to tempoBPM = 90 and divisions = 6.
    static func loadSongChords(fromBundleFilename filename: String = "sheet_music.json",
                               defaultTempoBPM: Double = 90,
                               defaultDivisions: Int = 6) throws -> [SongChord] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            throw MusicJSONLoaderError.notFound
        }
        let data = try Data(contentsOf: url)
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = obj as? [String: Any] else {
            throw MusicJSONLoaderError.parseError("Root JSON not dictionary")
        }

        // Find measures array (robust traversal)
        guard let measures = findMeasures(in: root) else {
            throw MusicJSONLoaderError.parseError("Couldn't find measures in JSON")
        }

        // Determine divisions (default or from attributes in first measure)
        var divisions = defaultDivisions
        if let attrs = measures.first?["attributes"] as? [String: Any],
           let dAny = attrs["divisions"] {
            if let d = dAny as? Int { divisions = d }
            else if let ds = dAny as? String, let di = Int(ds) { divisions = di }
        }

        // Determine tempo if present (direction -> metronome -> per/minute)
        var tempoBPM = defaultTempoBPM
        if let firstMeasure = measures.first,
           let directions = firstMeasure["direction"] as? [[String: Any]] {
            for dir in directions {
                if let sound = dir["sound"] as? [String: Any], let tempoAny = sound["tempo"] {
                    if let t = tempoAny as? Double { tempoBPM = t; break }
                    if let ts = tempoAny as? String, let t = Double(ts) { tempoBPM = t; break }
                }
                // fallback: look for metronome marking
                if let directionType = dir["direction-type"] as? [String: Any],
                   let metronome = directionType["metronome"] as? [String: Any],
                   let beatUnit = metronome["beat-unit"] as? String,
                   let perMinute = metronome["per-minute"] as? String,
                   let t = Double(perMinute) {
                    tempoBPM = t; break
                }
            }
        }

        // Build NoteEvent list scanning measures sequentially
        var events: [NoteEvent] = []
        var currentTick = 0
        for measure in measures {
            if let notes = measure["note"] as? [[String: Any]] {
                for note in notes {
                    // duration
                    var duration = 0
                    if let d = note["duration"] as? Int { duration = d }
                    else if let ds = note["duration"] as? String, let di = Int(ds) { duration = di }

                    // detect chord marker — many JSONs have "chord": "" key or chord true
                    let chordFlag = note["chord"] != nil

                    // pitch
                    if let pitch = note["pitch"] as? [String: Any],
                       let step = (pitch["step"] as? String) {
                        let octaveInt: Int
                        if let oct = pitch["octave"] as? Int { octaveInt = oct }
                        else if let os = pitch["octave"] as? String, let oi = Int(os) { octaveInt = oi }
                        else { octaveInt = 4 }

                        let alter = (pitch["alter"] as? Int) ?? 0

                        let name = noteName(step: step, octave: octaveInt, alter: alter)
                        let midi = midiNumber(step: step, octave: octaveInt, alter: alter)

                        let start = chordFlag ? (events.last?.startTick ?? currentTick) : currentTick
                        let evt = NoteEvent(noteName: name, midi: midi, startTick: start, durationTicks: duration)
                        events.append(evt)

                        if !chordFlag {
                            currentTick += duration
                        }
                    } else {
                        // rests or unsupported entries: advance by duration if present
                        if duration > 0 {
                            currentTick += duration
                        }
                    }
                }
            }
        }

        // Group by startTick -> chords
        var grouped: [Int: [NoteEvent]] = [:]
        for e in events {
            grouped[e.startTick, default: []].append(e)
        }
        let sortedTicks = grouped.keys.sorted()

        // seconds per division
        let secondsPerDivision = (60.0 / tempoBPM) / Double(divisions)

        var chords: [SongChord] = []
        for tick in sortedTicks {
            let evts = grouped[tick]!
            // chord duration = max duration among notes
            let maxDurTicks = evts.map { $0.durationTicks }.max() ?? 1
            let durationSeconds = Double(maxDurTicks) * secondsPerDivision

            // split into left/right using MIDI threshold: <60 left, >=60 right
            var left: [String] = []
            var right: [String] = []
            for e in evts {
                if e.midi < 60 {
                    left.append(e.noteName)
                } else {
                    right.append(e.noteName)
                }
            }
            // If all notes categorized to one hand, it's fine.
            let chordName = evts.map { $0.noteName }.joined(separator: " ")
            let sc = SongChord(leftHandNotes: left, rightHandNotes: right, chordName: chordName, duration: durationSeconds)
            chords.append(sc)
        }

        return chords
    }

    // --- helpers

    private static func noteName(step: String, octave: Int, alter: Int) -> String {
        var s = step.uppercased()
        if alter == 1 { s += "#" }
        if alter == -1 { s += "b" }
        return "\(s)\(octave)"
    }

    private static func midiNumber(step: String, octave: Int, alter: Int) -> Int {
        let base: [String: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        let st = step.uppercased()
        var semitone = base[st] ?? 0
        semitone += alter
        if semitone < 0 { semitone += 12 }
        let midi = 12 * (octave + 1) + semitone
        return midi
    }

    /// Recursively find measures array in a JSON structure
    private static func findMeasures(in dict: [String: Any]) -> [[String: Any]]? {
        for (_, v) in dict {
            if let arr = v as? [[String: Any]], arr.first?["note"] != nil {
                return arr
            } else if let dictV = v as? [String: Any], let found = findMeasures(in: dictV) {
                return found
            } else if let arr2 = v as? [Any] {
                // array of dicts?
                var maybe: [[String: Any]] = []
                for item in arr2 {
                    if let d = item as? [String: Any] { maybe.append(d) }
                }
                if !maybe.isEmpty && maybe.first?["note"] != nil {
                    return maybe
                }
                for item in maybe {
                    if let found = findMeasures(in: item) { return found }
                }
            }
        }
        return nil
    }
}
