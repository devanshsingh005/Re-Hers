//
//  SongChord.swift
//  Re-Hearse
//

import Foundation

/// Represents one “step” of the demo song.
/// A chord is simply left-hand notes + right-hand notes + a readable chord name + duration.
struct SongChord {
    let leftHandNotes: [String]
    let rightHandNotes: [String]
    let chordName: String
    let duration: Double   // seconds
}
