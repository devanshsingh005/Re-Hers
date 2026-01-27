import Foundation

// MARK: - PianoDemoManager
final class PianoDemoManager {

    // MARK: - State
    private var index: Int = 0
    private var chords: [SongChord] = []

    private var jsonFilename: String

    // MARK: - Init
    init(loadFrom filename: String = "sheet_test.json") {
        self.jsonFilename = filename
    }

    // MARK: - Public API (USED BY VIEW CONTROLLER)

    /// Loads / reloads the demo song from JSON.
    /// Call this whenever tempo or sheet data changes.
    func loadSong() {
        index = 0
        chords.removeAll()

        do {
            let loaded = try MusicJSONLoader.loadSongChords(
                fromBundleFilename: jsonFilename,
                defaultTempoBPM: 90,
                defaultDivisions: 6
            )

            if !loaded.isEmpty {
                chords = loaded
                print("[PianoDemoManager] ✅ Loaded \(loaded.count) chords from \(jsonFilename)")
                debugPrintSample(loaded)
                return
            } else {
                print("[PianoDemoManager] ⚠️ JSON returned empty list. Using fallback.")
            }
        } catch {
            print("[PianoDemoManager] ❌ Failed to load JSON:", error)
        }

       // loadFallback()
    

    }

    /// Returns the next chord in sequence
    func next() -> SongChord? {
        guard index < chords.count else { return nil }
        let chord = chords[index]
        index += 1
        return chord
    }

    /// Reset playback index
    func reset() {
        index = 0
    }

    /// Indicates demo completion
    var isFinished: Bool {
        index >= chords.count
    }

    // MARK: - Private Helpers

    private func loadFallback() {
        chords = [
            SongChord(
                leftHandNotes: ["A2"],
                rightHandNotes: ["E4", "A4", "C5"],
                chordName: "A Minor",
                duration: 1.1
            ),
            SongChord(
                leftHandNotes: ["E2"],
                rightHandNotes: ["E4", "G4", "B4"],
                chordName: "E Minor",
                duration: 1.1
            )
        ]
        index = 0
        print("[PianoDemoManager] ⚠️ Using fallback demo (\(chords.count) chords)")
    }

    private func debugPrintSample(_ chords: [SongChord]) {
        if chords.count <= 8 {
            print("[PianoDemoManager] chords:", chords.map { $0.chordName })
        } else {
            print("[PianoDemoManager] first 8 chords:",
                  chords.prefix(8).map { $0.chordName })
        }
    }
}
