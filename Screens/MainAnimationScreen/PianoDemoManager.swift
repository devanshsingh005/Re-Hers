//
//  PianoDemoManager.swift
//  Re-Hearse
//

import Foundation

/// Handles demo playback logic.
/// Gives next chord each time `next()` is called.
class PianoDemoManager {

    private var index = 0

    // ----- Static demo data -----
    // You can modify these chords freely.
    private let demoChords: [SongChord] = [

        SongChord(
            leftHandNotes: ["A2"],
            rightHandNotes: ["E4", "A4", "C5"],
            chordName: "A Minor",
            duration: 1.2
        ),

        SongChord(
            leftHandNotes: ["E2"],
            rightHandNotes: ["E4", "G4", "B4"],
            chordName: "E Minor",
            duration: 1.2
        ),

        SongChord(
            leftHandNotes: ["D3"],
            rightHandNotes: ["F#4", "A4", "D5"],
            chordName: "D Major",
            duration: 1.2
        ),

        SongChord(
            leftHandNotes: ["C3"],
            rightHandNotes: ["E4", "G4", "C5"],
            chordName: "C Major",
            duration: 1.2
        )
    ]

    // ----- Public API -----

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

