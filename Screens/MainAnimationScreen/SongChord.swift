import Foundation

/// Represents one step of a demo song.
/// A SongChord groups left-hand notes, right-hand notes,
/// a human-readable name, and its duration in seconds.
struct SongChord {
    let leftHandNotes:  [String]
    let rightHandNotes: [String]
    let chordName:      String
    let duration:       Double   // seconds
    let globalTick:     Int      // precise sheet music position
}
