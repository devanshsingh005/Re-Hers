// PianoDemoManager.swift (updated - debugable & reloadable)
import Foundation

class PianoDemoManager {

    private var index = 0
    private(set) var demoChords: [SongChord] = []
    private(set) var isUsingJSON: Bool = false
    private var jsonFilename: String = "sheet_test.json"

    init(loadFrom filename: String = "sheet_test.json") {
        self.jsonFilename = filename
        loadInitialChords()
    }

    private func loadInitialChords() {
        index = 0
        isUsingJSON = false
        demoChords.removeAll()

        do {
            let loaded = try MusicJSONLoader.loadSongChords(fromBundleFilename: jsonFilename,
                                                            defaultTempoBPM: 90,
                                                            defaultDivisions: 6)
            if !loaded.isEmpty {
                demoChords = loaded
                isUsingJSON = true
                print("[PianoDemoManager] ✅ Loaded \(loaded.count) chords from JSON (\(jsonFilename)).")
                if loaded.count <= 10 {
                    print("[PianoDemoManager] chords: \(loaded.map { $0.chordName })")
                } else {
                    print("[PianoDemoManager] first 8 chords: \(loaded.prefix(8).map { $0.chordName })")
                }
                return
            } else {
                print("[PianoDemoManager] ⚠️ JSON loader returned empty array for \(jsonFilename). Falling back to built-in demo.")
            }
        } catch MusicJSONLoaderError.notFound {
            print("[PianoDemoManager] ❌ \(jsonFilename) not found in bundle.")
        } catch {
            print("[PianoDemoManager] ❌ JSON load error: \(error). Falling back to built-in demo.")
        }

        // FALLBACK static list (kept as original fallback)
        demoChords = [
            SongChord(leftHandNotes: ["A2"], rightHandNotes: ["E4","A4","C5"], chordName: "A Minor", duration: 1.1),
            SongChord(leftHandNotes: ["E2"], rightHandNotes: ["E4","G4","B4"], chordName: "E Minor", duration: 1.1),
           
        ]
        isUsingJSON = false
        print("[PianoDemoManager] Using fallback demo with \(demoChords.count) chords.")
    }

    // Public API: reload from bundle filename at runtime (useful while debugging)
    func reload(from filename: String? = nil) {
        if let f = filename { self.jsonFilename = f }
        loadInitialChords()
        reset()
    }

    func next() -> SongChord? {
        guard index < demoChords.count else { return nil }
        let chord = demoChords[index]
        index += 1
        return chord
    }

    func reset() {
        index = 0
    }

    var isFinished: Bool {
        return index >= demoChords.count
    }
}
