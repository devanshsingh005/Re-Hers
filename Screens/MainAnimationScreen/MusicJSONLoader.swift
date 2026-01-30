//
//  MusicJSONLoader.swift
//  Re-Hearse_v1
//
//  FINAL – MUSICAL & TEMPO CORRECT (Dynamic Supabase Ready)
//

import Foundation

// MARK: - Internal Event Model (Not exposed)
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
    case networkError
}

// MARK: - Loader
struct MusicJSONLoader {

    /// Load from JSON Data (for URL downloads)
    static func loadSongChords(
        fromData data: Data,
        defaultTempoBPM: Double = 84,
        defaultDivisions: Int = 6
    ) throws -> [SongChord] {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let root = json as? [String: Any] else {
            throw MusicJSONLoaderError.parseError("Root JSON is not a dictionary")
        }
        return try parseSongChords(from: root, defaultTempoBPM: defaultTempoBPM, defaultDivisions: defaultDivisions)
    }

    static func loadSongChords(
        fromBundleFilename filename: String,
        defaultTempoBPM: Double = 84,
        defaultDivisions: Int = 6
    ) throws -> [SongChord] {

        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            throw MusicJSONLoaderError.notFound
        }

        let data = try Data(contentsOf: url)
        return try loadSongChords(
            from: data,
            defaultTempoBPM: defaultTempoBPM,
            defaultDivisions: defaultDivisions
        )
    }

    // ============================================================
    // MARK: 2️⃣ LOAD FROM DATA (Recommended for Supabase)
    // ============================================================
    static func loadSongChords(
        from data: Data,
        defaultTempoBPM: Double = 84,
        defaultDivisions: Int = 6
    ) throws -> [SongChord] {

        let json = try JSONSerialization.jsonObject(with: data)
        guard let root = json as? [String: Any] else {
            throw MusicJSONLoaderError.parseError("Root JSON is not a dictionary")
        }
        
        return try parseSongChords(from: root, defaultTempoBPM: defaultTempoBPM, defaultDivisions: defaultDivisions)
    }
    
    private static func parseSongChords(
        from root: [String: Any],
        defaultTempoBPM: Double,
        defaultDivisions: Int
    ) throws -> [SongChord] {

        return try parseRoot(
            root,
            defaultTempoBPM: defaultTempoBPM,
            defaultDivisions: defaultDivisions
        )
    }

    // ============================================================
    // MARK: 3️⃣ LOAD FROM REMOTE URL (Supabase Signed URL)
    // ============================================================
    static func loadSongChords(
        fromRemoteURL url: URL,
        defaultTempoBPM: Double = 84,
        defaultDivisions: Int = 6
    ) async throws -> [SongChord] {

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw MusicJSONLoaderError.networkError
        }

        return try loadSongChords(
            from: data,
            defaultTempoBPM: defaultTempoBPM,
            defaultDivisions: defaultDivisions
        )
    }

    // ============================================================
    // MARK: 4️⃣ CORE PARSER (Shared Logic)
    // ============================================================
    private static func parseRoot(
        _ root: [String: Any],
        defaultTempoBPM: Double,
        defaultDivisions: Int
    ) throws -> [SongChord] {

        guard let measures = findMeasures(in: root) else {
            throw MusicJSONLoaderError.parseError("Measures not found")
        }

        // Divisions
        var divisions = defaultDivisions
        if let attrs = measures.first?["attributes"] as? [String: Any],
           let d = attrs["divisions"] {
            divisions = Int("\(d)") ?? divisions
        }

        // Tempo math
        let secondsPerDivision = (60.0 / defaultTempoBPM) / Double(divisions)

        // Parse events
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

                if !isChord {
                    voiceTicks[voice, default: startTick] += duration
                    globalTick = max(globalTick, voiceTicks[voice]!)
                }
            }
        }

        // Group notes by start tick
        let grouped = Dictionary(grouping: events, by: { $0.startTick })
        let sortedTicks = grouped.keys.sorted()

        // Build SongChords
        var songChords: [SongChord] = []

        for tick in sortedTicks {
            guard let evts = grouped[tick] else { continue }

            let maxDuration = evts.map { $0.durationTicks }.max() ?? 1
            let durationSeconds = Double(maxDuration) * secondsPerDivision

            let left = evts.filter { $0.staff == "2" }.map { $0.noteName }
            let right = evts.filter { $0.staff != "2" }.map { $0.noteName }

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

    // ============================================================
    // MARK: 5️⃣ HELPERS
    // ============================================================
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
