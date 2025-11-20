import Foundation
import AudioToolbox

// MARK: - ChordDetector
class ChordDetector {
    private let chordPatterns: [String: [String]] = [
        "C":  ["C4", "E4", "G4"], "Cm": ["C4", "D#4", "G4"],
        "G":  ["G4", "B4", "D5"], "Gm": ["G4", "A#4", "D5"],
        "D":  ["D4", "F#4", "A4"], "Dm": ["D4", "F4", "A4"],
        "A":  ["A4", "C#5", "E5"], "Am": ["A4", "C5", "E5"],
        "E":  ["E4", "G#4", "B4"], "Em": ["E4", "G4", "B4"],
        "F":  ["F4", "A4", "C5"], "Fm": ["F4", "G#4", "C5"]
    ]
    
    func detectChord(from notes: [String]) -> String {
        guard notes.count >= 3 else { return notes.isEmpty ? "Play a chord!" : "Unknown" }
        for (chordName, chordNotes) in chordPatterns {
            if Set(notes).isSuperset(of: Set(chordNotes)) {
                return chordName
            }
        }
        return "Unknown"
    }
}


// MARK: - Demo Manager (Für Elise sample)
class PianoDemoManager {
    private(set) var demoChords: [SongChord] = []
    private var index: Int = 0
    
    init() {
        loadDemo()
    }
    
    private func loadDemo() {
        demoChords = [
            SongChord(leftHandNotes: ["E2", "B2"], rightHandNotes: ["E5", "D#5"], chordName: "E Minor", duration: 1.0),
            SongChord(leftHandNotes: ["E2", "B2"], rightHandNotes: ["E5", "D#5"], chordName: "E Minor", duration: 1.0),
            SongChord(leftHandNotes: ["E2", "A2"], rightHandNotes: ["E5", "C5"], chordName: "A Minor", duration: 1.0),
            SongChord(leftHandNotes: ["A2", "E3"], rightHandNotes: ["A4", "C5"], chordName: "A Minor", duration: 1.0),
            SongChord(leftHandNotes: ["E2", "G#2"], rightHandNotes: ["B4", "D5"], chordName: "E Major", duration: 1.0),
            SongChord(leftHandNotes: ["E2", "B2"], rightHandNotes: ["C5", "E5"], chordName: "C Major", duration: 1.0),
            SongChord(leftHandNotes: ["E2", "B2"], rightHandNotes: ["A4", "E5"], chordName: "A Minor", duration: 1.0),
            SongChord(leftHandNotes: ["E2", "B2"], rightHandNotes: ["B4", "E5"], chordName: "E Major", duration: 1.0)
        ]
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
}

// MARK: - Sound helper (placeholder)
func playNoteSound(_ noteName: String) {
    // simple system click for demo; replace with AVAudioEngine samples for real piano
    AudioServicesPlaySystemSound(1104)
}
