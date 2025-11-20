import Foundation
import AudioToolbox

// MARK: - ChordDetector
class ChordDetector {
    private let chordPatterns: [String: [String]] = [
        "C":  ["C4", "E4", "G4"],
        "Cm": ["C4", "D#4", "G4"],

        "G":  ["G4", "B4", "D5"],
        "Gm": ["G4", "A#4", "D5"],

        "F":  ["F4", "A4", "C5"],
        "Fm": ["F4", "G#4", "C5"],

        "Am": ["A4", "C5", "E5"],
        "A":  ["A4", "C#5", "E5"],

        "Dm": ["D4", "F4", "A4"],
        "D":  ["D4", "F#4", "A4"],

        "Em": ["E4", "G4", "B4"],
        "E":  ["E4", "G#4", "B4"]
    ]

    func detectChord(from notes: [String]) -> String {
        let sortedNotes = notes.sorted()

        for (chord, pattern) in chordPatterns {
            if Set(pattern).isSubset(of: sortedNotes) {
                return chord
            }
        }
        return "Unknown"
    }
}

// MARK: - Piano Sound Player
func playNoteSound(_ note: String) {
    guard let url = Bundle.main.url(forResource: note, withExtension: "wav") else {
        print("Missing sound for \(note)")
        return
    }

    var soundID: SystemSoundID = 0
    AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
    AudioServicesPlaySystemSound(soundID)
}
