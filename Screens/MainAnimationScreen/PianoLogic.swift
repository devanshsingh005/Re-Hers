import Foundation

// MARK: - ChordDetector
final class ChordDetector {

    /// Canonical chord definitions (normalized, octave-aware)
    private let chordPatterns: [String: Set<String>] = [
        "C":  ["C4", "E4", "G4"],
        "Cm": ["C4", "D#4", "G4"],

        "G":  ["G4", "B4", "D5"],
        "Gm": ["G4", "A#4", "D5"],

        "F":  ["F4", "A4", "C5"],
        "Fm": ["F4", "G#4", "C5"],

        "A":  ["A4", "C#5", "E5"],
        "Am": ["A4", "C5", "E5"],

        "D":  ["D4", "F#4", "A4"],
        "Dm": ["D4", "F4", "A4"],

        "E":  ["E4", "G#4", "B4"],
        "Em": ["E4", "G4", "B4"]
    ]

    /// Detects chord from active notes.
    /// - Parameter notes: Active note names (e.g. ["C4","E4","G4"])
    /// - Returns: Chord name or "Unknown"
    func detectChord(from notes: [String]) -> String {

        // Early exit
        guard notes.count >= 3 else { return "Unknown" }

        let noteSet = Set(notes)

        for (chord, pattern) in chordPatterns {
            if pattern.isSubset(of: noteSet) {
                return chord
            }
        }

        return "Unknown"
    }
}
