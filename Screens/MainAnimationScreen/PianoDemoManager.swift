import Foundation

// MARK: - PianoDemoManager

final class PianoDemoManager {

    private var chords:     [SongChord] = []
    private var chordIndex: Int         = 0
    private let jsonFilename: String
    private var externalData: Data?

    var totalSongDuration: Double { chords.reduce(0) { $0 + $1.duration } }
    var isFinished: Bool { chordIndex >= chords.count }

    init(loadFrom filename: String = "sheet_test.json") {
        self.jsonFilename = filename
    }
    init(withData data: Data) {
        self.jsonFilename = ""
        self.externalData = data
    }
    func setExternalData(_ data: Data) { self.externalData = data }

    // MARK: Load
    // Believer: BPM=120, divisions=6
    func loadSong(tempoBPM: Double = 120, divisions: Int = 6) {
        chordIndex = 0; chords.removeAll()
        do {
            let loaded: [SongChord]
            if let data = externalData {
                loaded = try MusicJSONLoader.loadSongChords(from: data,
                    defaultTempoBPM: tempoBPM, defaultDivisions: divisions)
            } else {
                loaded = try MusicJSONLoader.loadSongChords(fromBundleFilename: jsonFilename,
                    defaultTempoBPM: tempoBPM, defaultDivisions: divisions)
            }
            chords = loaded
            print("[PianoDemoManager] ✅ \(loaded.count) chords  dur=\(String(format:"%.1f",totalSongDuration))s")
        } catch {
            print("[PianoDemoManager] ❌", error)
        }
    }

    func next() -> SongChord? {
        guard chordIndex < chords.count else { return nil }
        defer { chordIndex += 1 }
        return chords[chordIndex]
    }

    func reset() { chordIndex = 0 }
}
