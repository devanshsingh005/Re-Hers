//
//  MusicJSONLoader.swift
//  Re-Hearse_v1
//
//  FINAL – MUSICAL & TEMPO CORRECT
//

import Foundation

// MARK: - Internal Event Model
private struct NoteEvent {
    let noteName: String
    let staff: String        // "1" = Right hand, "2" = Left hand
    let startTick: Int
    let durationTicks: Int
}

// MARK: - Errors
enum MusicJSONLoaderError: Error {
    case notFound
    case parseError(String)
}

// MARK: - Loader
struct MusicJSONLoader {

    static func loadSongChords(
        fromBundleFilename filename: String = "sheet_test.json",
        defaultTempoBPM: Double = 84,     // Happy Birthday tempo
        defaultDivisions: Int = 6
    ) throws -> [SongChord] {

        // MARK: - Load JSON
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            throw MusicJSONLoaderError.notFound
        }

        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let root = json as? [String: Any] else {
            throw MusicJSONLoaderError.parseError("Root JSON is not a dictionary")
        }

        // MARK: - Locate Measures
        guard let measures = findMeasures(in: root) else {
            throw MusicJSONLoaderError.parseError("Measures not found")
        }

        // MARK: - Divisions
        var divisions = defaultDivisions
        if let attrs = measures.first?["attributes"] as? [String: Any],
           let d = attrs["divisions"] {
            divisions = Int("\(d)") ?? divisions
        }

        // MARK: - Tempo
        let tempoBPM = defaultTempoBPM
        let secondsPerDivision = (60.0 / tempoBPM) / Double(divisions)

        // MARK: - Parse Notes
        var events: [NoteEvent] = []
        var voiceTicks: [String: Int] = [:]
        var globalTick = 0

        for measure in measures {
            guard let notes = measure["note"] as? [[String: Any]] else { continue }

            for note in notes {

                let voice = (note["voice"] as? String) ?? "1"
                let staff = (note["staff"] as? String) ?? "1"
                let duration = Int("\(note["duration"] ?? "0")") ?? 0
                let isChord = note["chord"] != nil

                let startTick = isChord
                    ? (events.last?.startTick ?? voiceTicks[voice, default: globalTick])
                    : voiceTicks[voice, default: globalTick]

                // Pitch
                if let pitch = note["pitch"] as? [String: Any],
                   let step = pitch["step"] as? String {

                    let octave = Int("\(pitch["octave"] ?? "4")") ?? 4
                    let alter = Int("\(pitch["alter"] ?? "0")") ?? 0

                    events.append(
                        NoteEvent(
                            noteName: makeNoteName(step: step, octave: octave, alter: alter),
                            staff: staff,
                            startTick: startTick,
                            durationTicks: duration
                        )
                    )
                }

                // Advance time per voice
                if !isChord {
                    voiceTicks[voice, default: startTick] += duration
                    globalTick = max(globalTick, voiceTicks[voice]!)
                }
            }
        }

        // MARK: - Group by Time
        let grouped = Dictionary(grouping: events, by: { $0.startTick })
        let sortedTicks = grouped.keys.sorted()

        // MARK: - Build SongChords
        var songChords: [SongChord] = []

        for tick in sortedTicks {
            guard let evts = grouped[tick] else { continue }

            let maxDuration = evts.map { $0.durationTicks }.max() ?? 1
            let durationSeconds = Double(maxDuration) * secondsPerDivision

            let left = evts.filter { $0.staff == "2" }.map { $0.noteName }
            let right = evts.filter { $0.staff != "2" }.map { $0.noteName }

            // Ignore melody-only artifacts
           // if left.isEmpty && right.count <= 1 { continue }

            songChords.append(
                SongChord(
                    leftHandNotes: left,
                    rightHandNotes: right,
                    chordName: (left + right).joined(separator: " "),
                    duration: durationSeconds
                )
            )
        }

        return songChords
    }

    // MARK: - Helpers

    private static func makeNoteName(step: String, octave: Int, alter: Int) -> String {
        var s = step.uppercased()
        if alter == 1 { s += "#" }
        if alter == -1 { s += "b" }
        return "\(s)\(octave)"
    }

    private static func findMeasures(in dict: [String: Any]) -> [[String: Any]]? {
        for (_, value) in dict {
            if let arr = value as? [[String: Any]],
               arr.first?["note"] != nil {
                return arr
            }
            if let subDict = value as? [String: Any],
               let found = findMeasures(in: subDict) {
                return found
            }
            if let arr = value as? [Any] {
                for item in arr {
                    if let d = item as? [String: Any],
                       let found = findMeasures(in: d) {
                        return found
                    }
                }
            }
        }
        return nil
    }
}
