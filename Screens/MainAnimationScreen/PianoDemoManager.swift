import Foundation

class PianoDemoManager {

    private var index = 0

    // LONG STATIC DEMO LIST (40+ chords)
    private let demoChords: [SongChord] = [

        SongChord(leftHandNotes: ["A2"], rightHandNotes: ["E4","A4","C5"], chordName: "A Minor", duration: 1.1),
        SongChord(leftHandNotes: ["E2"], rightHandNotes: ["E4","G4","B4"], chordName: "E Minor", duration: 1.1),
        SongChord(leftHandNotes: ["D3"], rightHandNotes: ["F#4","A4","D5"], chordName: "D Major", duration: 1.1),
        SongChord(leftHandNotes: ["C3"], rightHandNotes: ["E4","G4","C5"], chordName: "C Major", duration: 1.1),

        SongChord(leftHandNotes: ["F2"], rightHandNotes: ["A4","C5","F5"], chordName: "F Major", duration: 1.1),
        SongChord(leftHandNotes: ["G2"], rightHandNotes: ["B4","D5","G5"], chordName: "G Major", duration: 1.1),

        SongChord(leftHandNotes: ["B2"], rightHandNotes: ["D4","F#4","A4"], chordName: "B Diminished", duration: 1.1),
        SongChord(leftHandNotes: ["E2"], rightHandNotes: ["G#4","B4","E5"], chordName: "E Major", duration: 1.1),

        // Add MORE variety shapes
        SongChord(leftHandNotes: ["C2"], rightHandNotes: ["G3","C4","E4"], chordName: "C/E", duration: 1.1),
        SongChord(leftHandNotes: ["A2"], rightHandNotes: ["A3","C4","E4"], chordName: "Am/E", duration: 1.1),
        SongChord(leftHandNotes: ["D2"], rightHandNotes: ["A3","D4","F#4"], chordName: "D/A", duration: 1.1),
        SongChord(leftHandNotes: ["F2"], rightHandNotes: ["C4","F4","A4"], chordName: "F/C", duration: 1.1),

        // Minor extended
        SongChord(leftHandNotes: ["A2"], rightHandNotes: ["C5","E5","A5"], chordName: "A Minor High", duration: 1.1),
        SongChord(leftHandNotes: ["D3"], rightHandNotes: ["A4","D5","F5"], chordName: "D Minor High", duration: 1.1),

        // Major 7th
        SongChord(leftHandNotes: ["C3"], rightHandNotes: ["B4","E5","G5"], chordName: "Cmaj7", duration: 1.1),
        SongChord(leftHandNotes: ["F2"], rightHandNotes: ["E4","A4","C5"], chordName: "Fmaj7", duration: 1.1),

        // Suspended chords
        SongChord(leftHandNotes: ["G2"], rightHandNotes: ["C5","D5","G5"], chordName: "Gsus4", duration: 1.1),
        SongChord(leftHandNotes: ["D3"], rightHandNotes: ["G4","A4","D5"], chordName: "Dsus2", duration: 1.1)
    ]

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
