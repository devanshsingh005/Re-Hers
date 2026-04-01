import Foundation

// MARK: - ChordDetector

final class ChordDetector {
    
    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private let noteNamesFlat = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
    
    /// Detects chord from active notes
    func detectChord(from notes: [String]) -> String {
        guard !notes.isEmpty else { return "Unknown" }
        
        let normalizedNotes = normalizeNotes(notes)
        
        // For single notes
        if normalizedNotes.count == 1 {
            return normalizedNotes[0]
        }
        
        // For two notes (interval)
        if normalizedNotes.count == 2 {
            return detectInterval(from: normalizedNotes)
        }
        
        // For three or more notes (chords)
        return detectComplexChord(from: normalizedNotes)
    }
    
    /// Detect possible chords (multiple options)
    func detectPossibleChords(from notes: [String], limit: Int = 3) -> [String] {
        guard !notes.isEmpty else { return [] }
        
        let normalizedNotes = normalizeNotes(notes)
        var results: [String] = []
        
        // Try different chord qualities for each possible root
        for rootNote in normalizedNotes {
            let chords = tryChordsFromRoot(rootNote, with: normalizedNotes)
            results.append(contentsOf: chords)
        }
        
        // Remove duplicates and limit results
        return Array(Set(results)).prefix(limit).map { $0 }
    }
    
    // MARK: - Private Methods
    
    private func normalizeNotes(_ notes: [String]) -> [String] {
        return notes.map { normalizeNote($0) }
    }
    
    private func normalizeNote(_ note: String) -> String {
        var result = ""
        var hasFlat = false
        
        // Extract components
        for char in note {
            if char.isLetter {
                result.append(char.uppercased())
            } else if char == "#" {
                result.append("#")
            } else if char == "b" {
                hasFlat = true
                result.append("b")
            } else if char.isNumber {
                result.append(char)
            }
        }
        
        // Convert flats to sharps for consistency (optional)
        if hasFlat {
            result = convertFlatToSharp(result)
        }
        
        return result
    }
    
    private func convertFlatToSharp(_ note: String) -> String {
        let flatToSharp: [String: String] = [
            "Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#"
        ]
        
        for (flat, sharp) in flatToSharp {
            if note.hasPrefix(flat) {
                return sharp + String(note.dropFirst(2))
            }
        }
        return note
    }
    
    private func detectInterval(from notes: [String]) -> String {
        guard notes.count == 2 else { return "Unknown" }
        
        let note1 = notes[0]
        let note2 = notes[1]
        
        guard let pitch1 = midiPitch(for: note1),
              let pitch2 = midiPitch(for: note2) else {
            return "\(note1) - \(note2)"
        }
        
        let interval = abs(pitch1 - pitch2) % 12
        
        let intervals: [Int: String] = [
            0: "Unison",
            1: "Minor 2nd",
            2: "Major 2nd",
            3: "Minor 3rd",
            4: "Major 3rd",
            5: "Perfect 4th",
            6: "Tritone",
            7: "Perfect 5th",
            8: "Minor 6th",
            9: "Major 6th",
            10: "Minor 7th",
            11: "Major 7th"
        ]
        
        return intervals[interval] ?? "Interval \(interval)"
    }
    
    private func detectComplexChord(from notes: [String]) -> String {
        let uniqueNotes = Set(notes)
        
        // Check for common chords
        if let chord = checkCommonChords(uniqueNotes) {
            return chord
        }
        
        // Check for major/minor triads
        if let triad = detectTriad(notes) {
            return triad
        }
        
        // Check for seventh chords
        if let seventh = detectSeventhChord(notes) {
            return seventh
        }
        
        // Fallback: note names
        if notes.count <= 4 {
            return notes.joined(separator: " ")
        } else {
            return "Chord (\(notes.count) notes)"
        }
    }
    
    private func checkCommonChords(_ notes: Set<String>) -> String? {
        let commonChords: [String: Set<String>] = [
            // Major chords
            "C": ["C4", "E4", "G4"],
            "C#": ["C#4", "F4", "G#4"],
            "D": ["D4", "F#4", "A4"],
            "D#": ["D#4", "G4", "A#4"],
            "E": ["E4", "G#4", "B4"],
            "F": ["F4", "A4", "C5"],
            "F#": ["F#4", "A#4", "C#5"],
            "G": ["G4", "B4", "D5"],
            "G#": ["G#4", "C5", "D#5"],
            "A": ["A4", "C#5", "E5"],
            "A#": ["A#4", "D5", "F5"],
            "B": ["B4", "D#5", "F#5"],
            
            // Minor chords
            "Cm": ["C4", "D#4", "G4"],
            "C#m": ["C#4", "E4", "G#4"],
            "Dm": ["D4", "F4", "A4"],
            "D#m": ["D#4", "F#4", "A#4"],
            "Em": ["E4", "G4", "B4"],
            "Fm": ["F4", "G#4", "C5"],
            "F#m": ["F#4", "A4", "C#5"],
            "Gm": ["G4", "A#4", "D5"],
            "G#m": ["G#4", "B4", "D#5"],
            "Am": ["A4", "C5", "E5"],
            "A#m": ["A#4", "C#5", "F5"],
            "Bm": ["B4", "D5", "F#5"],
            
            // Diminished
            "Cdim": ["C4", "D#4", "F#4"],
            "Ddim": ["D4", "F4", "G#4"],
            "Edim": ["E4", "G4", "A#4"],
            "Fdim": ["F4", "G#4", "B4"],
            "F#dim": ["F#4", "A4", "C5"],
            "Gdim": ["G4", "A#4", "C#5"],
            "G#dim": ["G#4", "B4", "D5"],
            "Adim": ["A4", "C5", "D#5"],
            "A#dim": ["A#4", "C#5", "E5"],
            "Bdim": ["B4", "D5", "F5"],
            
            // Augmented
            "Caug": ["C4", "E4", "G#4"],
            "Daug": ["D4", "F#4", "A#4"],
            "Eaug": ["E4", "G#4", "C5"],
            "Faug": ["F4", "A4", "C#5"],
            "F#aug": ["F#4", "A#4", "D5"],
            "Gaug": ["G4", "B4", "D#5"],
            "G#aug": ["G#4", "C5", "E5"],
            "Aaug": ["A4", "C#5", "F5"],
            "A#aug": ["A#4", "D5", "F#5"],
            "Baug": ["B4", "D#5", "G5"]
        ]
        
        // Check for exact matches first (ignoring octave)
        for (chordName, chordNotes) in commonChords {
            // Convert both to note names without octave for comparison
            let chordNoteNames = chordNotes.map { String($0.prefix($0.count - 1)) }
            let inputNoteNames = notes.map { String($0.prefix($0.count - 1)) }
            
            if Set(chordNoteNames).isSubset(of: Set(inputNoteNames)) {
                return chordName
            }
        }
        
        return nil
    }
    
    private func detectTriad(_ notes: [String]) -> String? {
        guard notes.count >= 3 else { return nil }
        
        // Get MIDI pitches
        let pitches = notes.compactMap { midiPitch(for: $0) }.sorted()
        
        // Check for triads
        for i in 0..<pitches.count-2 {
            for j in i+1..<pitches.count-1 {
                for k in j+1..<pitches.count {
                    let interval1 = pitches[j] - pitches[i]
                    let interval2 = pitches[k] - pitches[j]
                    
                    if interval1 == 4 && interval2 == 3 {
                        // Major triad
                        return "\(notes[i].prefix(notes[i].count - 1)) Major"
                    } else if interval1 == 3 && interval2 == 4 {
                        // Minor triad
                        return "\(notes[i].prefix(notes[i].count - 1)) Minor"
                    } else if interval1 == 3 && interval2 == 3 {
                        // Diminished triad
                        return "\(notes[i].prefix(notes[i].count - 1)) Dim"
                    } else if interval1 == 4 && interval2 == 4 {
                        // Augmented triad
                        return "\(notes[i].prefix(notes[i].count - 1)) Aug"
                    }
                }
            }
        }
        
        return nil
    }
    
    private func detectSeventhChord(_ notes: [String]) -> String? {
        guard notes.count >= 4 else { return nil }
        
        let pitches = notes.compactMap { midiPitch(for: $0) }.sorted()
        
        // Check for seventh chords (first 4 notes)
        if pitches.count >= 4 {
            let root = pitches[0]
            let third = pitches[1]
            let fifth = pitches[2]
            let seventh = pitches[3]
            
            let i1 = third - root
            let i2 = fifth - third
            let i3 = seventh - fifth
            
            // Major 7th: 4-3-4
            if i1 == 4 && i2 == 3 && i3 == 4 {
                return "\(notes[0].prefix(notes[0].count - 1)) Maj7"
            }
            // Dominant 7th: 4-3-3
            else if i1 == 4 && i2 == 3 && i3 == 3 {
                return "\(notes[0].prefix(notes[0].count - 1))7"
            }
            // Minor 7th: 3-4-3
            else if i1 == 3 && i2 == 4 && i3 == 3 {
                return "\(notes[0].prefix(notes[0].count - 1))m7"
            }
            // Half-diminished: 3-3-4
            else if i1 == 3 && i2 == 3 && i3 == 4 {
                return "\(notes[0].prefix(notes[0].count - 1))m7b5"
            }
            // Diminished 7th: 3-3-3
            else if i1 == 3 && i2 == 3 && i3 == 3 {
                return "\(notes[0].prefix(notes[0].count - 1))dim7"
            }
        }
        
        return nil
    }
    
    private func tryChordsFromRoot(_ rootNote: String, with notes: [String]) -> [String] {
        var results: [String] = []
        
        // Get root note without octave
        let rootName = String(rootNote.prefix(rootNote.count - 1))
        
        // Check different chord types
        let chordTypes = ["", "m", "7", "m7", "maj7", "sus2", "sus4", "dim", "aug"]
        
        for type in chordTypes {
            let chordName = rootName + type
            
            // Try to match based on intervals
            if doesMatchChordType(rootNote: rootNote, notes: notes, type: type) {
                results.append(chordName)
            }
        }
        
        return results
    }
    
    private func doesMatchChordType(rootNote: String, notes: [String], type: String) -> Bool {
        guard let rootPitch = midiPitch(for: rootNote) else { return false }
        
        let notePitches = notes.compactMap { midiPitch(for: $0) }.sorted()
        
        // Expected intervals based on chord type
        let expectedIntervals: [Int]
        
        switch type {
        case "": // Major
            expectedIntervals = [0, 4, 7]
        case "m": // Minor
            expectedIntervals = [0, 3, 7]
        case "7": // Dominant 7th
            expectedIntervals = [0, 4, 7, 10]
        case "m7": // Minor 7th
            expectedIntervals = [0, 3, 7, 10]
        case "maj7": // Major 7th
            expectedIntervals = [0, 4, 7, 11]
        case "sus2": // Suspended 2nd
            expectedIntervals = [0, 2, 7]
        case "sus4": // Suspended 4th
            expectedIntervals = [0, 5, 7]
        case "dim": // Diminished
            expectedIntervals = [0, 3, 6]
        case "aug": // Augmented
            expectedIntervals = [0, 4, 8]
        default:
            expectedIntervals = []
        }
        
        // Check if we have the expected intervals
        let intervalsFromRoot = notePitches.map { ($0 - rootPitch) % 12 }
        
        for expected in expectedIntervals {
            if !intervalsFromRoot.contains(expected) {
                return false
            }
        }
        
        return true
    }
    
    private func midiPitch(for note: String) -> Int? {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        
        // Extract note name and octave
        var noteName = ""
        var octaveStr = ""
        
        for char in note {
            if char.isLetter || char == "#" || char == "b" {
                noteName.append(char)
            } else if char.isNumber {
                octaveStr.append(char)
            }
        }
        
        guard !noteName.isEmpty, let octave = Int(octaveStr) else {
            return nil
        }
        
        // Find note index
        guard let noteIndex = noteNames.firstIndex(of: noteName) else {
            return nil
        }
        
        // MIDI pitch calculation
        return 12 + (octave * 12) + noteIndex
    }
}

// MARK: - Usage Example

extension ChordDetector {
    static func runExamples() {
        let detector = ChordDetector()
        
        let testChords: [[String]] = [
            // Major chords
            ["C4", "E4", "G4"],  // C
            ["G4", "B4", "D5"],  // G
            ["F4", "A4", "C5"],  // F
            ["D4", "F#4", "A4"], // D
            
            // Minor chords
            ["A4", "C5", "E5"],  // Am
            ["E4", "G4", "B4"],  // Em
            ["D4", "F4", "A4"],  // Dm
            
            // Seventh chords
            ["C4", "E4", "G4", "Bb4"],  // C7
            ["C4", "E4", "G4", "B4"],   // Cmaj7
            ["C4", "Eb4", "G4", "Bb4"], // Cm7
            
            // Intervals
            ["C4", "E4"],  // Major 3rd
            ["C4", "G4"],  // Perfect 5th
            
            // Single notes
            ["C4"],
            ["A4"],
            
            // Complex
            ["C4", "Eb4", "Gb4", "A4"], // Cdim7
            ["C4", "E4", "G#4"],        // Caug
            
            // Real examples
            ["A2", "E4", "A4", "C5"],   // Am with bass
            ["E2", "E4", "G4", "B4"],   // Em with bass
        ]
        
        debugLog("🎹 Chord Detection Examples:")
        debugLog("=" * 40)
        
        for (index, notes) in testChords.enumerated() {
            let chord = detector.detectChord(from: notes)
            let possible = detector.detectPossibleChords(from: notes, limit: 2)
            
            debugLog("Test \(index + 1): \(notes.joined(separator: ", "))")
            debugLog("  Detected: \(chord)")
            if !possible.isEmpty {
                debugLog("  Possible: \(possible.joined(separator: ", "))")
            }
            debugLog()
        }
    }
}

// MARK: - Helper

extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
