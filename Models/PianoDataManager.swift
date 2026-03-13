import Foundation

public final class PianoDataManager {
    
    public struct NoteGroup {
        let tick: Int
        let leftNotes: [String]
        let rightNotes: [String]
    }
    
    private let chords: [SongChord]
    
    init(scoreData: [SongChord]) {
        self.chords = scoreData
    }
    
    func allGroups() -> [NoteGroup] {
        return chords.map { chord in
            NoteGroup(
                tick: chord.globalTick,
                leftNotes: chord.leftHandNotes,
                rightNotes: chord.rightHandNotes
            )
        }
    }
}
