import Foundation

// MARK: - Errors
enum MusicJSONLoaderError: Error {
    case notFound
    case parseError(String)
    case networkError
}

// MARK: - Internal Event
private struct NoteEvent {
    let noteName:      String
    let staff:         String   // "1" = treble/right, "2" = bass/left
    let globalTick:    Int
    let durationTicks: Int
}

// MARK: - MusicJSONLoader
struct MusicJSONLoader {

    // MARK: - Public API

    static func loadSongChords(
        fromBundleFilename filename: String,
        defaultTempoBPM: Double = 84,
        defaultDivisions: Int = 6
    ) throws -> [SongChord] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil)
                     ?? Bundle.main.url(
                            forResource: (filename as NSString).deletingPathExtension,
                            withExtension: (filename as NSString).pathExtension)
        else { throw MusicJSONLoaderError.notFound }
        return try loadSongChords(from: try Data(contentsOf: url),
                                  defaultTempoBPM: defaultTempoBPM,
                                  defaultDivisions: defaultDivisions)
    }

    static func loadSongChords(
        from data: Data,
        defaultTempoBPM: Double = 84,
        defaultDivisions: Int = 6
    ) throws -> [SongChord] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw MusicJSONLoaderError.parseError("Invalid JSON") }
        return try parse(root, defaultBPM: defaultTempoBPM, defaultDivisions: defaultDivisions)
    }

    static func loadSongChords(fromRemoteURL url: URL,
                               defaultTempoBPM: Double = 84,
                               defaultDivisions: Int = 6) async throws -> [SongChord] {
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let h = resp as? HTTPURLResponse, (200...299).contains(h.statusCode)
        else { throw MusicJSONLoaderError.networkError }
        return try loadSongChords(from: data, defaultTempoBPM: defaultTempoBPM,
                                  defaultDivisions: defaultDivisions)
    }

    // MARK: - Core Parser
    //
    // KEY FIX vs old code:
    //   OLD: single voiceTick dict shared across ALL measures → backup collapses all
    //        notes onto same ticks → only 12 chords produced
    //   NEW: globalTick advances by (beats × divisions) per measure
    //        localTick is reset each measure and is relative within that measure
    //        This correctly yields 90 distinct chord events for 16 measures
    //
    private static func parse(_ root: [String: Any],
                               defaultBPM: Double,
                               defaultDivisions: Int) throws -> [SongChord] {

        guard let measures = findMeasures(in: root), !measures.isEmpty
        else { throw MusicJSONLoaderError.parseError("No measures found") }

        // --- Read divisions from first measure attributes ---
        var divisions = defaultDivisions
        for m in measures {
            if let a = m["attributes"] as? [String: Any], let d = a["divisions"] {
                if let v = intVal(d) { divisions = v; break }
            }
        }

        // --- Read tempo from first direction/sound/@tempo ---
        var bpm = defaultBPM
        outerLoop: for m in measures {
            for t in temposIn(measure: m) { bpm = t; break outerLoop }
        }

        let spt = (60.0 / bpm) / Double(divisions)   // seconds per tick

        // --- Infer beats-per-measure from first measure's total note ticks ---
        // (Used when no explicit <time> element is present in the JSON)
        var defaultBeats: Int = {
            // Try to read from attributes first
            for m in measures {
                if let a = m["attributes"] as? [String: Any],
                   let t = a["time"] as? [String: Any],
                   let b = intVal(t["beats"]) { return b }
            }
            // Infer from first measure's total non-chord note durations
            if let first = measures.first {
                let notes = notesIn(measure: first)
                var total = 0
                for n in notes where n["chord"] == nil {
                    total += intVal(n["duration"]) ?? 0
                }
                if total > 0 && divisions > 0 { return total / divisions }
            }
            return 4
        }()

        // --- Iterate measures, accumulate events ---
        var events:     [NoteEvent] = []
        var globalTick: Int         = 0

        for measure in measures {
            // Local tick per staff-voice — offsets within this measure only
            // Using staff-voice key ensures each staff is independently timed
            var localTick: [String: Int] = [:]
            var lastLocalDur: [String: Int] = [:]

            let notes = notesIn(measure: measure)

            for note in notes {
                let voice   = strVal(note["voice"]) ?? "1"
                let staff   = strVal(note["staff"]) ?? "1"
                let dur     = intVal(note["duration"]) ?? 0
                let isChord = note["chord"] != nil
                let isRest  = note["rest"]  != nil

                let tickKey    = "\(staff)-\(voice)"
                let localCur   = localTick[tickKey, default: 0]
                let prevDur    = lastLocalDur[tickKey, default: 0]
                let localStart = isChord ? max(0, localCur - prevDur) : localCur

                if !isRest, let pitch = note["pitch"] as? [String: Any],
                   let step = pitch["step"] as? String {
                    let oct   = intVal(pitch["octave"]) ?? 4
                    let alter = intVal(pitch["alter"])  ?? 0
                    let name  = step + (alter == 1 ? "#" : alter == -1 ? "b" : "") + "\(oct)"
                    events.append(NoteEvent(
                        noteName:      name,
                        staff:         staff,
                        globalTick:    globalTick + localStart,
                        durationTicks: dur
                    ))
                }

                if !isChord {
                    localTick[tickKey] = localCur + dur
                    lastLocalDur[tickKey] = dur
                }
            }

            // Apply backup (resets local ticks within measure — does NOT affect globalTick)
            let backupTotal = backupTicks(in: measure)
            if backupTotal > 0 {
                for k in localTick.keys {
                    localTick[k] = max(0, (localTick[k] ?? 0) - backupTotal)
                }
            }

            // Read time signature if present in this measure
            if let a = measure["attributes"] as? [String: Any],
               let t = a["time"] as? [String: Any],
               let b = intVal(t["beats"]) {
                defaultBeats = b
            }

            // Advance global tick by full measure length
            globalTick += defaultBeats * divisions
        }

        // --- Group by globalTick → SongChords ---
        events.sort { $0.globalTick < $1.globalTick }
        let grouped     = Dictionary(grouping: events) { $0.globalTick }
        let sortedTicks = grouped.keys.sorted()

        var chords: [SongChord] = []
        for (i, tick) in sortedTicks.enumerated() {
            guard let evts = grouped[tick], !evts.isEmpty else { continue }

            // Deduplicate note names per hand
            var left:  [String] = []
            var right: [String] = []
            var seenL  = Set<String>(); var seenR = Set<String>()
            for e in evts {
                if e.staff == "2" { if seenL.insert(e.noteName).inserted { left.append(e.noteName) } }
                else              { if seenR.insert(e.noteName).inserted { right.append(e.noteName) } }
            }
            
            // Fix: duration is the exact time until the NEXT chord, ensuring rests aren't skipped
            let duration: Double
            if i + 1 < sortedTicks.count {
                let nextTick = sortedTicks[i + 1]
                duration = max(Double(nextTick - tick) * spt, 0.08)
            } else {
                let maxDur = evts.map { $0.durationTicks }.max() ?? 1
                duration = max(Double(maxDur) * spt, 0.08)
            }

            chords.append(SongChord(
                leftHandNotes:  left,
                rightHandNotes: right,
                chordName:      (left + right).prefix(4).joined(separator: " "),
                duration:       duration,
                globalTick:     tick
            ))
        }

        print("[MusicJSONLoader] ✅ \(chords.count) chords | bpm=\(bpm) | divs=\(divisions) | dur≈\(String(format:"%.1f",chords.reduce(0){$0+$1.duration}))s")
        return chords
    }

    // MARK: - Helpers

    private static func notesIn(measure: [String: Any]) -> [[String: Any]] {
        if let a = measure["note"] as? [[String: Any]] { return a }
        if let o = measure["note"] as? [String: Any]   { return [o] }
        return []
    }

    private static func backupTicks(in measure: [String: Any]) -> Int {
        if let a = measure["backup"] as? [[String: Any]] {
            return a.compactMap { intVal($0["duration"]) }.reduce(0, +)
        }
        if let o = measure["backup"] as? [String: Any] { return intVal(o["duration"]) ?? 0 }
        return 0
    }

    private static func temposIn(measure: [String: Any]) -> [Double] {
        func fromDir(_ d: [String: Any]) -> Double? {
            if let s = d["sound"] as? [String: Any], let t = s["@tempo"] { return doubleVal(t) }
            return nil
        }
        if let a = measure["direction"] as? [[String: Any]] { return a.compactMap { fromDir($0) } }
        if let o = measure["direction"] as? [String: Any]   { return [fromDir(o)].compactMap{$0} }
        return []
    }

    private static func findMeasures(in dict: [String: Any]) -> [[String: Any]]? {
        // Direct hit: this dict has a "measure" array
        if let arr = dict["measure"] as? [[String: Any]], !arr.isEmpty { return arr }

        // The JSON structure is: score-partwise → part (Array) → each element has "measure"
        // We must recurse into both sub-dicts AND arrays of dicts.
        for (_, v) in dict {
            // Recurse into a nested dict
            if let sub = v as? [String: Any], let f = findMeasures(in: sub) { return f }
            // Recurse into an array of dicts — collect & flatten all parts' measures
            if let arr = v as? [[String: Any]] {
                let allMeasures = arr.compactMap { findMeasures(in: $0) }.flatMap { $0 }
                if !allMeasures.isEmpty { return allMeasures }
            }
        }
        return nil
    }

    // MARK: - Type coercion

    static func intVal(_ v: Any?) -> Int? {
        guard let v else { return nil }
        if let i = v as? Int      { return i }
        if let d = v as? Double   { return Int(d) }
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String   { return Int(s) }
        return nil
    }
    static func doubleVal(_ v: Any?) -> Double? {
        guard let v else { return nil }
        if let d = v as? Double   { return d }
        if let i = v as? Int      { return Double(i) }
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String   { return Double(s) }
        return nil
    }
    static func strVal(_ v: Any?) -> String? {
        guard let v else { return nil }
        if let s = v as? String { return s }
        if let i = v as? Int    { return "\(i)" }
        if let d = v as? Double { return "\(Int(d))" }
        return nil
    }
}