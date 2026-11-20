import Foundation

// MARK: - MusicJSONLoader
//
// Play Along's step-by-step view of a score: one SongChord per moment where at least one note
// is struck. Built from ScoreTimeline, so ties, grace notes, time signatures, pickups and
// tempo changes are handled the same way as in Animation, and `globalTick` is the tick the
// sheet view scrolls to.
nonisolated struct MusicJSONLoader {

    static func loadSongChords(
        from data: Data,
        defaultTempoBPM: Double = 84,
        defaultDivisions: Int = 6
    ) throws -> [SongChord] {
        let timeline = try ScoreTimeline.parse(data: data, defaultTempoBPM: defaultTempoBPM,
                                               defaultDivisions: defaultDivisions)
        return songChords(from: timeline)
    }

    static func songChords(from timeline: ScoreTimeline) -> [SongChord] {
        let struck = timeline.struckNotes
        let onsets = Dictionary(grouping: struck, by: \.startTick)
        let ticks = onsets.keys.sorted()

        var chords: [SongChord] = []
        for (i, tick) in ticks.enumerated() {
            let notes = onsets[tick] ?? []
            var left: [String] = []
            var right: [String] = []
            for note in notes {
                guard let name = note.keyName else { continue }
                if note.isLeftHand {
                    if !left.contains(name) { left.append(name) }
                } else if !right.contains(name) {
                    right.append(name)
                }
            }
            // a chord lasts until the next one starts, so rests between them are kept
            let start = timeline.seconds(atTick: Double(tick))
            let end: Double
            if i + 1 < ticks.count {
                end = timeline.seconds(atTick: Double(ticks[i + 1]))
            } else {
                end = timeline.seconds(atTick: Double(notes.map(\.soundingEndTick).max() ?? tick))
            }
            chords.append(SongChord(
                leftHandNotes: left,
                rightHandNotes: right,
                chordName: (left + right).prefix(4).joined(separator: " "),
                duration: max(end - start, 0.08),
                globalTick: tick
            ))
        }
        return chords
    }
}
