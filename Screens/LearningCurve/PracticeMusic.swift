//
//  PracticeMusic.swift
//  Re-Hearse_v1
//
//  The music behind each Practice lesson part: correctly spelled pitches (so E major is
//  E G♯ B, not E A♭ B), triads, the chords of a key, progressions and the ear-training rounds.
//  The staff draws these pitches, the piano plays their MIDI notes, and Try Yourself listens
//  for their pitch classes, so all three always agree.
//

import Foundation

/// A written pitch: letter, sharp/flat and octave (C4 is middle C).
struct PracticePitch: Equatable, Hashable {
    static let letters: [Character] = ["C", "D", "E", "F", "G", "A", "B"]
    private static let naturalSemitones = [0, 2, 4, 5, 7, 9, 11]

    let letter: Character
    /// -1 flat, 0 natural, +1 sharp.
    let alter: Int
    let octave: Int

    var letterIndex: Int { Self.letters.firstIndex(of: letter) ?? 0 }
    var midi: Int { 12 * (octave + 1) + Self.naturalSemitones[letterIndex] + alter }
    var pitchClass: Int { ((midi % 12) + 12) % 12 }
    /// Diatonic steps above C0 (C4 = 28), which is what places a note on the staff.
    var diatonic: Int { octave * 7 + letterIndex }

    /// "F#", "Bb" — the spelling the rest of the app parses.
    var ascii: String { "\(letter)\(alter > 0 ? "#" : alter < 0 ? "b" : "")" }
    /// "F♯", "B♭" — for display.
    var display: String { "\(letter)\(alter > 0 ? "♯" : alter < 0 ? "♭" : "")" }

    /// The pitch `letterSteps` letters above this one, adjusted to sit `semitones` above it.
    func above(letterSteps: Int, semitones: Int) -> PracticePitch {
        let target = letterIndex + letterSteps
        let letter = Self.letters[target % 7]
        let octave = octave + target / 7
        let natural = PracticePitch(letter: letter, alter: 0, octave: octave)
        return PracticePitch(letter: letter, alter: midi + semitones - natural.midi, octave: octave)
    }

    /// Parses "C", "F#", "Bb" at `octave`.
    init?(name: String, octave: Int = 4) {
        guard let first = name.first, Self.letters.contains(first) else { return nil }
        let rest = name.dropFirst()
        switch rest {
        case "": alter = 0
        case "#", "♯": alter = 1
        case "b", "♭": alter = -1
        default: return nil
        }
        letter = first
        self.octave = octave
    }

    init(letter: Character, alter: Int, octave: Int) {
        self.letter = letter
        self.alter = alter
        self.octave = octave
    }
}

/// A root-position triad.
struct PracticeChord: Equatable {
    enum Quality: Equatable {
        case major, minor, diminished, augmented

        var suffix: String {
            switch self {
            case .major: return ""
            case .minor: return "m"
            case .diminished: return "dim"
            case .augmented: return "aug"
            }
        }
        var word: String {
            switch self {
            case .major: return "major"
            case .minor: return "minor"
            case .diminished: return "diminished"
            case .augmented: return "augmented"
            }
        }
        /// Semitones from the root to the third and the fifth.
        var intervals: (third: Int, fifth: Int) {
            switch self {
            case .major: return (4, 7)
            case .minor: return (3, 7)
            case .diminished: return (3, 6)
            case .augmented: return (4, 8)
            }
        }
    }

    let root: PracticePitch
    let quality: Quality

    var notes: [PracticePitch] {
        let i = quality.intervals
        return [root, root.above(letterSteps: 2, semitones: i.third), root.above(letterSteps: 4, semitones: i.fifth)]
    }
    /// "F#dim" — matches the lesson content and chip labels.
    var symbol: String { root.ascii + quality.suffix }
    /// "F♯dim"
    var displaySymbol: String { root.display + quality.suffix }
    /// "F♯ diminished"
    var name: String { "\(root.display) \(quality.word)" }

    /// Parses "C", "Dm", "F#dim", "Caug", "Bb" with the root at `octave`.
    init?(symbol: String, octave: Int = 4) {
        let trimmed = symbol.trimmingCharacters(in: .whitespaces)
        var rootName = String(trimmed.prefix(1))
        var rest = trimmed.dropFirst()
        if let accidental = rest.first, accidental == "#" || accidental == "b" {
            rootName.append(accidental)
            rest = rest.dropFirst()
        }
        let quality: Quality
        switch rest {
        case "": quality = .major
        case "m": quality = .minor
        case "dim", "°": quality = .diminished
        case "aug", "+": quality = .augmented
        default: return nil
        }
        guard let root = PracticePitch(name: rootName, octave: octave) else { return nil }
        self.root = root
        self.quality = quality
    }

    init(root: PracticePitch, quality: Quality) {
        self.root = root
        self.quality = quality
    }
}

/// One thing to hear and play: a note, a chord, or one chord of a progression.
struct PracticeStep {
    /// Short name drawn under the staff in a progression ("Am").
    let label: String
    let pitches: [PracticePitch]

    var midiNotes: [Int] { pitches.map(\.midi) }
    var pitchClasses: Set<Int> { Set(pitches.map(\.pitchClass)) }
}

/// What a lesson part (one variant chip) shows, plays and asks the player to play.
struct PracticeItem {
    let chipLabel: String
    /// Big title under the staff ("D minor", "C – G – Am – F").
    let title: String
    /// Second line, e.g. ("Notes: ", "D · F · A").
    let detailPrefix: String
    let detail: String
    /// Played and listened for one after another.
    let steps: [PracticeStep]
    /// What Try Yourself asks for.
    let instruction: String
}

enum PracticeMusic {
    private static let solfege: [Character: String] = [
        "C": "Do", "D": "Re", "E": "Mi", "F": "Fa", "G": "Sol", "A": "La", "B": "Ti",
    ]
    private static let qualityVariants: [String: PracticeChord.Quality] = [
        "Major": .major, "Minor": .minor, "Diminished": .diminished, "Augmented": .augmented,
    ]

    /// The seven triads of a major key, in order I–vii°.
    static func keyChords(tonic: PracticePitch) -> [PracticeChord] {
        let scaleSemitones = [0, 2, 4, 5, 7, 9, 11]
        let qualities: [PracticeChord.Quality] = [.major, .minor, .minor, .major, .major, .minor, .diminished]
        return (0..<7).map { degree in
            let spelled = tonic.above(letterSteps: degree, semitones: scaleSemitones[degree])
            // every root in the tonic's octave, so the chords stay on the staff
            let root = PracticePitch(letter: spelled.letter, alter: spelled.alter, octave: tonic.octave)
            return PracticeChord(root: root, quality: qualities[degree])
        }
    }

    /// "I", "ii", "vii°" → 0…6.
    static func degree(ofNumeral numeral: String) -> Int? {
        let cleaned = numeral.replacingOccurrences(of: "°", with: "").uppercased()
        return ["I", "II", "III", "IV", "V", "VI", "VII"].firstIndex(of: cleaned)
    }

    /// The key a lesson is in ("C major" → C4), from its `noteEnglish`.
    static func tonic(of lesson: MusicLesson) -> PracticePitch {
        let name = lesson.noteEnglish.split(separator: " ").first.map(String.init) ?? "C"
        return PracticePitch(name: name) ?? PracticePitch(letter: "C", alter: 0, octave: 4)
    }

    /// The music for `variant` of `lesson`; nil for the ear-training lesson, which has rounds.
    static func item(for variant: String, in lesson: MusicLesson) -> PracticeItem? {
        // Single notes (Piano Basics)
        if lesson.chordDetails.isEmpty, let pitch = PracticePitch(name: variant), variant.count == 1 {
            let syllable = solfege[pitch.letter] ?? ""
            return PracticeItem(
                chipLabel: pitch.display, title: pitch.display,
                detailPrefix: "Solfège: ", detail: syllable,
                steps: [PracticeStep(label: pitch.display, pitches: [pitch])],
                instruction: "Play \(pitch.display) — \(pitch.letter == "C" ? "middle C, " : "")the note shown on the staff."
            )
        }

        // Chord qualities built on the lesson's key note (Understanding Sound)
        if let quality = qualityVariants[variant] {
            let chord = PracticeChord(root: tonic(of: lesson), quality: quality)
            return chordItem(chord, chip: variant)
        }

        // Progressions in roman numerals (Chord Progressions)
        let numerals = variant
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "–")
            .split(separator: "–").map(String.init)
        if numerals.count > 1 {
            let chords = keyChords(tonic: tonic(of: lesson))
            let picked = numerals.compactMap { degree(ofNumeral: $0).map { chords[$0] } }
            guard picked.count == numerals.count else { return nil }
            let symbols = picked.map(\.displaySymbol)
            return PracticeItem(
                chipLabel: variant,
                title: symbols.joined(separator: " – "),
                detailPrefix: "In \(tonic(of: lesson).display) major: ",
                detail: variant,
                steps: picked.map { PracticeStep(label: $0.displaySymbol, pitches: $0.notes) },
                instruction: "Play the chords in order: \(symbols.joined(separator: ", then "))."
            )
        }

        // A chord of a key family (C Family … E Family)
        if let chord = PracticeChord(symbol: variant) {
            return chordItem(chord, chip: chord.displaySymbol)
        }
        return nil
    }

    private static func chordItem(_ chord: PracticeChord, chip: String) -> PracticeItem {
        let notes = chord.notes.map(\.display)
        return PracticeItem(
            chipLabel: chip, title: chord.name,
            detailPrefix: "Notes: ", detail: notes.joined(separator: " · "),
            steps: [PracticeStep(label: chord.displaySymbol, pitches: chord.notes)],
            instruction: "Play \(notes.dropLast().joined(separator: ", ")) and \(notes.last ?? "") together."
        )
    }

    // MARK: - Ear training

    /// A round: hear the key's home chord, then a mystery chord, and name its role.
    struct EarRound {
        let tonic: PracticePitch
        let answer: String          // "I", "IV", "V" or "vi"
        var reference: PracticeChord { PracticeMusic.keyChords(tonic: tonic)[0] }
        var mystery: PracticeChord {
            PracticeMusic.keyChords(tonic: tonic)[PracticeMusic.degree(ofNumeral: answer) ?? 0]
        }
    }

    static let earOptions = ["I", "IV", "V", "vi"]
    static let earOptionHints = ["I": "Home", "IV": "Lift", "V": "Tension", "vi": "Emotion"]

    /// One round per family variant ("C Family" …), each asking about a different chord.
    static func earRound(for variant: String, index: Int) -> EarRound {
        let keyName = variant.split(separator: " ").first.map(String.init) ?? "C"
        let tonic = PracticePitch(name: keyName) ?? PracticePitch(letter: "C", alter: 0, octave: 4)
        let answers = ["V", "vi", "IV", "V", "vi", "IV"]
        return EarRound(tonic: tonic, answer: answers[index % answers.count])
    }
}
