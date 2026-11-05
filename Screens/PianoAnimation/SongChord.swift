import Foundation

/// Represents one step of a song in Play Along.
/// A SongChord groups left-hand notes, right-hand notes,
/// a human-readable name, and its duration in seconds.
nonisolated struct SongChord: Sendable {
    let leftHandNotes:  [String]
    let rightHandNotes: [String]
    let chordName:      String
    let duration:       Double   // seconds
    let globalTick:     Int      // ScoreTimeline tick (sheet position)
}
