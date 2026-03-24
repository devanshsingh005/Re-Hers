//
//  AppChapters.swift
//  Re-Hearse_v1
//
//  All 10 chapters with full music-theory content.
//  Status is always .locked by default — LessonMapViewController
//  applies the real status from Supabase at runtime via applyProgress().
//

import UIKit

// MARK: - Chapter Status

enum ChapterStatus {
    case completed, current, locked
}

// MARK: - Extended Models

struct ChordDetail {
    let name: String
    let notes: [String]
    let type: String
    let emotion: String
    let staffPosition: String
    let commonUse: String
}

struct ProgressionExample {
    let numerals: String
    let chords: String
    let feel: String
}

struct MusicLesson {
    let title: String
    let noteName: String
    let noteEnglish: String
    let description: String
    let variants: [String]
    let familyOverview: String
    let chordDetails: [ChordDetail]
    let listeningGuide: String
    let practiceTasks: [String]
    let progressions: [ProgressionExample]

    init(title: String, noteName: String, noteEnglish: String,
         description: String, variants: [String],
         familyOverview: String = "",
         chordDetails: [ChordDetail] = [],
         listeningGuide: String = "",
         practiceTasks: [String] = [],
         progressions: [ProgressionExample] = []) {
        self.title            = title
        self.noteName         = noteName
        self.noteEnglish      = noteEnglish
        self.description      = description
        self.variants         = variants
        self.familyOverview   = familyOverview
        self.chordDetails     = chordDetails
        self.listeningGuide   = listeningGuide
        self.practiceTasks    = practiceTasks
        self.progressions     = progressions
    }
}

struct MusicChapter {
    let id = UUID()
    let chapterIndex: Int          // 1-based
    let title: String
    let subtitle: String
    let status: ChapterStatus
    let stars: Int
    let lesson: MusicLesson

    /// Returns a copy with a new status and stars — used when applying Supabase progress.
    func with(status: ChapterStatus, stars: Int = 0) -> MusicChapter {
        MusicChapter(
            chapterIndex: chapterIndex,
            title:        title,
            subtitle:     subtitle,
            status:       status,
            stars:        stars,
            lesson:       lesson
        )
    }
}

// MARK: - Progress Application
// Single function that takes the raw allChapters array (all locked)
// and applies saved progress from Supabase to produce the correct statuses.

/// Rebuilds the chapter list from `current_chapter` saved in Supabase.
/// - Parameter currentChapter: the `current_chapter` value from the profiles table (1-based).
/// - Parameter chapterStars: dict of chapterIndex → stars earned, from lesson_events.
/// - Returns: a correctly-statused copy of allChapters.
func applyProgress(currentChapter: Int, chapterStars: [Int: Int] = [:]) -> [MusicChapter] {
    allChapters.map { chapter in
        let idx = chapter.chapterIndex
        if idx < currentChapter {
            // Everything before current chapter is completed
            return chapter.with(status: .completed, stars: chapterStars[idx] ?? chapter.stars)
        } else if idx == currentChapter {
            // This is the active chapter
            return chapter.with(status: .current, stars: 0)
        } else {
            // Future chapters are locked
            return chapter.with(status: .locked, stars: 0)
        }
    }
}

// MARK: - All Chapters (content only — status always .locked as baseline)

let allChapters: [MusicChapter] = [

    // ─────────────────────────────────────────
    // CHAPTER 1 — Piano Basics
    // ─────────────────────────────────────────
    MusicChapter(
        chapterIndex: 1,
        title: "Piano Basics",
        subtitle: "Notes, keys and your first sounds",
        status: .locked, stars: 0,
        lesson: MusicLesson(
            title: "Piano Basics",
            noteName: "C",
            noteEnglish: "C (Do)",
            description: "Music uses seven letter names — A B C D E F G — that repeat up and down the keyboard. A note is a single musical sound. A chord is three or more notes played at the same time. Middle C is the anchor note at the centre of the piano and the perfect place to start.",
            variants: ["C", "D", "E", "F", "G", "A", "B"],
            familyOverview: "The musical alphabet has seven letters: A B C D E F G. After G it starts again at A, one octave higher. The piano keyboard shows this pattern clearly: white keys are the seven letters, black keys are the sharps and flats in between.",
            chordDetails: [],
            listeningGuide: "Play each white key from C to C and listen to how the pitch rises. Notice how the last C sounds the same as the first, only higher. That distance is called an octave.",
            practiceTasks: [
                "Find all the C notes on the keyboard — they sit just to the left of every group of two black keys.",
                "Play C D E F G A B C slowly with your right hand, one finger per note.",
                "Close your eyes and press any white key — then name the note.",
                "Play only the black keys from left to right and listen to the different colour of sound.",
                "Tap a rhythm on Middle C with one finger while counting 1 2 3 4 aloud."
            ],
            progressions: []
        )
    ),

    // ─────────────────────────────────────────
    // CHAPTER 2 — Understanding Sound
    // ─────────────────────────────────────────
    MusicChapter(
        chapterIndex: 2,
        title: "Understanding Sound",
        subtitle: "Major, minor and the emotion of chords",
        status: .locked, stars: 0,
        lesson: MusicLesson(
            title: "Understanding Sound",
            noteName: "C",
            noteEnglish: "C major",
            description: "Chords carry emotion. Major chords sound bright and happy. Minor chords sound sad or serious. Diminished chords sound tense and unstable. Learning to hear the difference is the most important skill in music.",
            variants: ["Major", "Minor", "Diminished", "Augmented"],
            familyOverview: "Every chord has a quality — major, minor, or diminished. That quality determines the emotional colour of the sound. Most songs mix these qualities to tell a musical story.",
            chordDetails: [
                ChordDetail(name: "Major chord", notes: ["Root", "Major 3rd", "Perfect 5th"],
                            type: "major", emotion: "Bright, happy, stable",
                            staffPosition: "Root + 4 semitones + 3 semitones",
                            commonUse: "Happy songs, resolutions, verse chords"),
                ChordDetail(name: "Minor chord", notes: ["Root", "Minor 3rd", "Perfect 5th"],
                            type: "minor", emotion: "Sad, serious, emotional",
                            staffPosition: "Root + 3 semitones + 4 semitones",
                            commonUse: "Emotional songs, dark moods, bridges"),
                ChordDetail(name: "Diminished chord", notes: ["Root", "Minor 3rd", "Diminished 5th"],
                            type: "diminished", emotion: "Tense, unstable, dramatic",
                            staffPosition: "Root + 3 semitones + 3 semitones",
                            commonUse: "Passing chords, tension, horror soundtracks"),
                ChordDetail(name: "Augmented chord", notes: ["Root", "Major 3rd", "Augmented 5th"],
                            type: "augmented", emotion: "Mysterious, dreamlike, unstable",
                            staffPosition: "Root + 4 semitones + 4 semitones",
                            commonUse: "Jazz, film scores, transitional chords"),
            ],
            listeningGuide: "Play C major (C E G) then C minor (C Eb G). The only difference is one note moved down by one semitone — but the emotional shift is huge. That one note is the difference between happy and sad.",
            practiceTasks: [
                "Play C major and C minor back to back five times.",
                "Play G major then G minor. Can you hear the mood shift?",
                "Try to play a sad melody using only minor chords.",
                "Play a happy melody using only major chords.",
                "Play Bdim (B D F) and notice how unsettled it sounds."
            ],
            progressions: [
                ProgressionExample(numerals: "I – vi", chords: "C – Am", feel: "Happy to emotional. Classic shift."),
                ProgressionExample(numerals: "i – VI", chords: "Am – F", feel: "Minor to major. Bittersweet."),
            ]
        )
    ),

    // ─────────────────────────────────────────
    // CHAPTER 3 — C Family
    // ─────────────────────────────────────────
    MusicChapter(
        chapterIndex: 3,
        title: "C Family",
        subtitle: "Key of C major — no sharps or flats",
        status: .locked, stars: 0,
        lesson: MusicLesson(
            title: "Key of C Major",
            noteName: "C",
            noteEnglish: "C major",
            description: "The C major family uses only white keys. It contains seven chords — one built on each note of the scale. These seven chords cover the most popular songs ever written.",
            variants: ["C", "Dm", "Em", "F", "G", "Am", "Bdim"],
            familyOverview: "C major is the most natural key on the piano — all white keys. The seven chords in this family are: C major, D minor, E minor, F major, G major, A minor, and B diminished.",
            chordDetails: [
                ChordDetail(name: "C major (I)", notes: ["C", "E", "G"], type: "major",
                            emotion: "Home — settled and resolved", staffPosition: "C E G",
                            commonUse: "Starting and ending songs in C"),
                ChordDetail(name: "D minor (ii)", notes: ["D", "F", "A"], type: "minor",
                            emotion: "Slightly sad, building tension", staffPosition: "D F A",
                            commonUse: "Pre-dominant — leads naturally to G"),
                ChordDetail(name: "E minor (iii)", notes: ["E", "G", "B"], type: "minor",
                            emotion: "Thoughtful, introspective", staffPosition: "E G B",
                            commonUse: "Passing chord, adds depth to progressions"),
                ChordDetail(name: "F major (IV)", notes: ["F", "A", "C"], type: "major",
                            emotion: "Warm lift, expansion", staffPosition: "F A C",
                            commonUse: "Verse lift, chorus opener"),
                ChordDetail(name: "G major (V)", notes: ["G", "B", "D"], type: "major",
                            emotion: "Tension, momentum, wants to resolve", staffPosition: "G B D",
                            commonUse: "The dominant — always pulls back to C"),
                ChordDetail(name: "A minor (vi)", notes: ["A", "C", "E"], type: "minor",
                            emotion: "Emotional, melancholic", staffPosition: "A C E",
                            commonUse: "Emotional depth, bridges, relative minor"),
                ChordDetail(name: "B diminished (vii°)", notes: ["B", "D", "F"], type: "diminished",
                            emotion: "Tense, dramatic, unstable", staffPosition: "B D F",
                            commonUse: "Passing chord, adds drama before returning to C"),
            ],
            listeningGuide: "Play C – G – Am – F and repeat it. This is the most used chord progression in pop music. Now try Am – F – C – G. Same chords, different starting point — notice how the emotional centre shifts.",
            practiceTasks: [
                "Play all 7 chords in order: C Dm Em F G Am Bdim",
                "Play I–IV–V–I (C F G C) until it feels natural",
                "Play I–V–vi–IV (C G Am F) — identify this in a song you know",
                "Play Am–F–C–G slowly. This is the 'emotional' version of the same family.",
                "Try playing the chords to any song you know in C major."
            ],
            progressions: [
                ProgressionExample(numerals: "I – IV – V", chords: "C – F – G", feel: "Classic rock/pop. Resolved and satisfying."),
                ProgressionExample(numerals: "I – V – vi – IV", chords: "C – G – Am – F", feel: "The modern pop progression. Heard in thousands of songs."),
                ProgressionExample(numerals: "vi – IV – I – V", chords: "Am – F – C – G", feel: "Emotional and cinematic."),
            ]
        )
    ),

    // ─────────────────────────────────────────
    // CHAPTER 4 — G Family
    // ─────────────────────────────────────────
    MusicChapter(
        chapterIndex: 4,
        title: "G Family",
        subtitle: "Key of G major — one sharp (F#)",
        status: .locked, stars: 0,
        lesson: MusicLesson(
            title: "Key of G Major",
            noteName: "G",
            noteEnglish: "G major",
            description: "The G major family has one sharp — F#. It has a bright, energetic sound and is one of the most common keys in rock, folk and country music. The open G chord on guitar makes this key feel natural on stringed instruments.",
            variants: ["G", "Am", "Bm", "C", "D", "Em", "F#dim"],
            familyOverview: "G major shares four chords with C major (Am, C, Em and the notes of D). Adding Bm and D gives it a brighter, more energetic character than C major.",
            chordDetails: [
                ChordDetail(name: "G major (I)", notes: ["G", "B", "D"], type: "major",
                            emotion: "Bright, energetic, confident", staffPosition: "G B D",
                            commonUse: "Home chord in G. Strong rock and folk feel."),
                ChordDetail(name: "A minor (ii)", notes: ["A", "C", "E"], type: "minor",
                            emotion: "Melancholic, emotional", staffPosition: "A C E",
                            commonUse: "Emotional tension before D or C"),
                ChordDetail(name: "B minor (iii)", notes: ["B", "D", "F#"], type: "minor",
                            emotion: "Dark, introspective", staffPosition: "B D F#",
                            commonUse: "Adds minor depth. Used in bridges."),
                ChordDetail(name: "C major (IV)", notes: ["C", "E", "G"], type: "major",
                            emotion: "Warm lift", staffPosition: "C E G",
                            commonUse: "Classic IV lift. Very familiar in pop and rock."),
                ChordDetail(name: "D major (V)", notes: ["D", "F#", "A"], type: "major",
                            emotion: "Tension, drive, momentum", staffPosition: "D F# A",
                            commonUse: "The dominant in G. Always wants to resolve to G."),
                ChordDetail(name: "E minor (vi)", notes: ["E", "G", "B"], type: "minor",
                            emotion: "Emotional, thoughtful", staffPosition: "E G B",
                            commonUse: "Emotional vi chord. Pairs beautifully with C and D."),
                ChordDetail(name: "F# diminished (vii°)", notes: ["F#", "A", "C"], type: "diminished",
                            emotion: "Tense, dramatic", staffPosition: "F# A C",
                            commonUse: "Passing chord. Rare but effective."),
            ],
            listeningGuide: "Play G – D – Em – C. This is G major's version of the most popular pop progression. Notice how the G chord feels settled, D feels like momentum, Em feels emotional, and C feels warm and familiar.",
            practiceTasks: [
                "Play all 7 chords in G: G Am Bm C D Em F#dim",
                "Play I–V–vi–IV in G: G D Em C",
                "Compare C–G–Am–F (in C) with G–D–Em–C (in G). Same pattern, different feel.",
                "Play G – C – D – G. This is the classic G family resolution.",
                "Try transposing a song you know from C major to G major."
            ],
            progressions: [
                ProgressionExample(numerals: "I – V – vi – IV", chords: "G – D – Em – C", feel: "Bright and driving. Standard pop in G."),
                ProgressionExample(numerals: "I – IV – V", chords: "G – C – D", feel: "Rock and folk staple. Endlessly satisfying."),
                ProgressionExample(numerals: "vi – IV – I – V", chords: "Em – C – G – D", feel: "Emotional start. Great for verses."),
            ]
        )
    ),

    // ─────────────────────────────────────────
    // CHAPTER 5 — F Family
    // ─────────────────────────────────────────
    MusicChapter(
        chapterIndex: 5,
        title: "F Family",
        subtitle: "Key of F major — one flat (Bb)",
        status: .locked, stars: 0,
        lesson: MusicLesson(
            title: "Key of F Major",
            noteName: "F",
            noteEnglish: "F major",
            description: "The F major family has one flat — Bb. It has a warm, full sound and is very common in pop, soul and gospel music. The Bb chord gives this key its distinctive warmth.",
            variants: ["F", "Gm", "Am", "Bb", "C", "Dm", "Edim"],
            familyOverview: "F major is the subdominant of C major — meaning F is the IV chord in C. Its own family feels warm and full, especially with the Bb adding a rich, soulful quality.",
            chordDetails: [
                ChordDetail(name: "F major (I)", notes: ["F", "A", "C"], type: "major",
                            emotion: "Warm, full, reassuring", staffPosition: "F A C",
                            commonUse: "Home chord in F. Warm pop and soul feel."),
                ChordDetail(name: "G minor (ii)", notes: ["G", "Bb", "D"], type: "minor",
                            emotion: "Searching, slightly tense", staffPosition: "G Bb D",
                            commonUse: "Pre-dominant. Leads naturally to C."),
                ChordDetail(name: "A minor (iii)", notes: ["A", "C", "E"], type: "minor",
                            emotion: "Introspective", staffPosition: "A C E",
                            commonUse: "Passing chord in F. Adds minor colour."),
                ChordDetail(name: "Bb major (IV)", notes: ["Bb", "D", "F"], type: "major",
                            emotion: "Rich, soulful lift", staffPosition: "Bb D F",
                            commonUse: "The signature sound of F major. Warm and full."),
                ChordDetail(name: "C major (V)", notes: ["C", "E", "G"], type: "major",
                            emotion: "Tension, forward momentum", staffPosition: "C E G",
                            commonUse: "Dominant in F. Resolves cleanly back to F."),
                ChordDetail(name: "D minor (vi)", notes: ["D", "F", "A"], type: "minor",
                            emotion: "Sad, melancholic", staffPosition: "D F A",
                            commonUse: "Emotional heart of F major progressions."),
                ChordDetail(name: "E diminished (vii°)", notes: ["E", "G", "Bb"], type: "diminished",
                            emotion: "Tense, dramatic", staffPosition: "E G Bb",
                            commonUse: "Passing chord. Creates tension before F."),
            ],
            listeningGuide: "Play F – Bb – C – F. Notice how the Bb gives it a richer, warmer sound than the G chord does in C major. This warmth is the defining quality of F major.",
            practiceTasks: [
                "Play all 7 chords: F Gm Am Bb C Dm Edim",
                "Play I–IV–V–I in F: F Bb C F",
                "Play I–V–vi–IV in F: F C Dm Bb",
                "Notice how Bb feels different from G (IV in C). Both are IV chords but Bb is warmer.",
                "Play Dm–Bb–F–C. This is the emotional version of F major."
            ],
            progressions: [
                ProgressionExample(numerals: "I – IV – V", chords: "F – Bb – C", feel: "Warm and gospel-like. Very satisfying."),
                ProgressionExample(numerals: "I – V – vi – IV", chords: "F – C – Dm – Bb", feel: "Modern pop in F. Rich and full."),
                ProgressionExample(numerals: "vi – IV – I – V", chords: "Dm – Bb – F – C", feel: "Emotional and soulful."),
            ]
        )
    ),

    // ─────────────────────────────────────────
    // CHAPTER 6 — D Family
    // ─────────────────────────────────────────
    MusicChapter(
        chapterIndex: 6,
        title: "D Family",
        subtitle: "Key of D major — two sharps (F#, C#)",
        status: .locked, stars: 0,
        lesson: MusicLesson(
            title: "Key of D Major",
            noteName: "D",
            noteEnglish: "D major",
            description: "The D major family has two sharps — F# and C#. It has a bold, triumphant sound and is extremely common in rock and pop. The open D chord on guitar is one of the first chords beginners learn.",
            variants: ["D", "Em", "F#m", "G", "A", "Bm", "C#dim"],
            familyOverview: "D major shares several chords with G major (Em, G, A, Bm). Its bold, open sound makes it a favourite in rock anthems and folk ballads alike.",
            chordDetails: [
                ChordDetail(name: "D major (I)", notes: ["D", "F#", "A"], type: "major",
                            emotion: "Bold, triumphant, confident", staffPosition: "D F# A",
                            commonUse: "Home chord. Strong, open sound."),
                ChordDetail(name: "E minor (ii)", notes: ["E", "G", "B"], type: "minor",
                            emotion: "Thoughtful, slightly melancholic", staffPosition: "E G B",
                            commonUse: "Emotional tension. Very common in D major songs."),
                ChordDetail(name: "F# minor (iii)", notes: ["F#", "A", "C#"], type: "minor",
                            emotion: "Dark, introspective", staffPosition: "F# A C#",
                            commonUse: "Adds minor colour. Used in more complex progressions."),
                ChordDetail(name: "G major (IV)", notes: ["G", "B", "D"], type: "major",
                            emotion: "Familiar lift", staffPosition: "G B D",
                            commonUse: "The lift chord in D. Very comfortable transition."),
                ChordDetail(name: "A major (V)", notes: ["A", "C#", "E"], type: "major",
                            emotion: "Strong tension and drive", staffPosition: "A C# E",
                            commonUse: "Dominant in D. Strong pull back to D."),
                ChordDetail(name: "B minor (vi)", notes: ["B", "D", "F#"], type: "minor",
                            emotion: "Emotional, cinematic", staffPosition: "B D F#",
                            commonUse: "Deep emotional chord. Common in ballads."),
                ChordDetail(name: "C# diminished (vii°)", notes: ["C#", "E", "G"], type: "diminished",
                            emotion: "Tense, dramatic", staffPosition: "C# E G",
                            commonUse: "Passing chord. Creates tension."),
            ],
            listeningGuide: "Play D – A – Bm – G. This is the boldest, most triumphant version of the pop progression. Notice how D sounds open and strong, A sounds like momentum, Bm sounds emotional, and G sounds familiar and warm.",
            practiceTasks: [
                "Play all 7 chords: D Em F#m G A Bm C#dim",
                "Play I–V–vi–IV in D: D A Bm G",
                "Compare G–D–Em–C (G major) with D–A–Bm–G (D major). Same pattern, bolder sound.",
                "Play D – G – A – D. Classic D family resolution.",
                "Try playing 'Sweet Home Alabama' riff: D – C – G (a common D-family variation)."
            ],
            progressions: [
                ProgressionExample(numerals: "I – V – vi – IV", chords: "D – A – Bm – G", feel: "Bold and triumphant. Stadium rock sound."),
                ProgressionExample(numerals: "I – IV – V", chords: "D – G – A", feel: "Rock and country staple in D."),
                ProgressionExample(numerals: "vi – IV – I – V", chords: "Bm – G – D – A", feel: "Cinematic and emotional."),
            ]
        )
    ),

    // ─────────────────────────────────────────
    // CHAPTER 7 — A Family
    // ─────────────────────────────────────────
    MusicChapter(
        chapterIndex: 7,
        title: "A Family",
        subtitle: "Key of A major — three sharps (F#, C#, G#)",
        status: .locked, stars: 0,
        lesson: MusicLesson(
            title: "Key of A Major",
            noteName: "A",
            noteEnglish: "A major",
            description: "The A major family has three sharps. It has a confident, slightly bluesy sound and is one of the most common keys in rock and blues. The open A chord on guitar gives it an immediate, powerful quality.",
            variants: ["A", "Bm", "C#m", "D", "E", "F#m", "G#dim"],
            familyOverview: "A major is one of the great rock keys. Its vi chord (F#m) is particularly emotive, and the E major dominant is one of the strongest pulls in music.",
            chordDetails: [
                ChordDetail(name: "A major (I)", notes: ["A", "C#", "E"], type: "major",
                            emotion: "Confident, slightly bluesy", staffPosition: "A C# E",
                            commonUse: "Home chord. Strong rock and blues feel."),
                ChordDetail(name: "B minor (ii)", notes: ["B", "D", "F#"], type: "minor",
                            emotion: "Thoughtful, searching", staffPosition: "B D F#",
                            commonUse: "Pre-dominant. Common in A major songs."),
                ChordDetail(name: "C# minor (iii)", notes: ["C#", "E", "G#"], type: "minor",
                            emotion: "Dark, intense", staffPosition: "C# E G#",
                            commonUse: "Adds depth. Used in complex progressions."),
                ChordDetail(name: "D major (IV)", notes: ["D", "F#", "A"], type: "major",
                            emotion: "Bold lift", staffPosition: "D F# A",
                            commonUse: "Strong IV chord. Bold and powerful."),
                ChordDetail(name: "E major (V)", notes: ["E", "G#", "B"], type: "major",
                            emotion: "Strong tension", staffPosition: "E G# B",
                            commonUse: "The most powerful dominant. Always wants to go to A."),
                ChordDetail(name: "F# minor (vi)", notes: ["F#", "A", "C#"], type: "minor",
                            emotion: "Deeply emotional, melancholic", staffPosition: "F# A C#",
                            commonUse: "The emotional heart of A major songs."),
                ChordDetail(name: "G# diminished (vii°)", notes: ["G#", "B", "D"], type: "diminished",
                            emotion: "Tense, dramatic", staffPosition: "G# B D",
                            commonUse: "Passing chord."),
            ],
            listeningGuide: "Play A – E – F#m – D. This is the A major pop progression. Notice how A sounds confident, E sounds like powerful tension, F#m sounds deeply emotional, and D sounds bold and lifting.",
            practiceTasks: [
                "Play all 7 chords: A Bm C#m D E F#m G#dim",
                "Play I–V–vi–IV in A: A E F#m D",
                "Play A – D – E – A. Classic rock resolution in A.",
                "Notice how E major (V in A) feels even more powerful than G (V in C).",
                "Try playing a 12-bar blues in A: A A A A / D D A A / E D A E."
            ],
            progressions: [
                ProgressionExample(numerals: "I – V – vi – IV", chords: "A – E – F#m – D", feel: "Rock power progression. Huge with distortion."),
                ProgressionExample(numerals: "I – IV – V", chords: "A – D – E", feel: "Blues and rock staple in A."),
                ProgressionExample(numerals: "vi – IV – I – V", chords: "F#m – D – A – E", feel: "Emotional and driving. Rock ballad sound."),
            ]
        )
    ),

    // ─────────────────────────────────────────
    // CHAPTER 8 — E Family
    // ─────────────────────────────────────────
    MusicChapter(
        chapterIndex: 8,
        title: "E Family",
        subtitle: "Key of E major — four sharps (F#, C#, G#, D#)",
        status: .locked, stars: 0,
        lesson: MusicLesson(
            title: "Key of E Major",
            noteName: "E",
            noteEnglish: "E major",
            description: "The E major family has four sharps. It has a raw, powerful sound and is the signature key of rock guitar. The open E chord is the deepest, most resonant chord on guitar.",
            variants: ["E", "F#m", "G#m", "A", "B", "C#m", "D#dim"],
            familyOverview: "E major is the king of rock keys. Its power comes from the open E string resonance on guitar, and its vi chord (C#m) is one of the most emotive chords in rock music.",
            chordDetails: [
                ChordDetail(name: "E major (I)", notes: ["E", "G#", "B"], type: "major",
                            emotion: "Raw, powerful, electric", staffPosition: "E G# B",
                            commonUse: "The rock chord. Open and powerful."),
                ChordDetail(name: "F# minor (ii)", notes: ["F#", "A", "C#"], type: "minor",
                            emotion: "Emotional tension", staffPosition: "F# A C#",
                            commonUse: "Common in rock ballads in E."),
                ChordDetail(name: "G# minor (iii)", notes: ["G#", "B", "D#"], type: "minor",
                            emotion: "Dark, brooding", staffPosition: "G# B D#",
                            commonUse: "Adds darkness. Less common but effective."),
                ChordDetail(name: "A major (IV)", notes: ["A", "C#", "E"], type: "major",
                            emotion: "Confident lift", staffPosition: "A C# E",
                            commonUse: "Power IV chord in E. The E–A–B progression is iconic."),
                ChordDetail(name: "B major (V)", notes: ["B", "D#", "F#"], type: "major",
                            emotion: "Strong tension", staffPosition: "B D# F#",
                            commonUse: "Dominant in E. Powerful resolution back to E."),
                ChordDetail(name: "C# minor (vi)", notes: ["C#", "E", "G#"], type: "minor",
                            emotion: "Deeply emotional", staffPosition: "C# E G#",
                            commonUse: "The emotional core of E major rock songs."),
                ChordDetail(name: "D# diminished (vii°)", notes: ["D#", "F#", "A"], type: "diminished",
                            emotion: "Tense, dramatic", staffPosition: "D# F# A",
                            commonUse: "Passing chord."),
            ],
            listeningGuide: "Play E – B – C#m – A. This is the E major pop/rock progression. It's used in countless rock anthems. Notice the raw power of E, the tension of B, the emotion of C#m, and the confident feel of A.",
            practiceTasks: [
                "Play all 7 chords: E F#m G#m A B C#m D#dim",
                "Play I–V–vi–IV in E: E B C#m A",
                "Play E – A – B — the classic rock power trio in E.",
                "Play C#m – A – E – B. Notice how starting on the vi chord adds emotion.",
                "Compare the E family feel to C major. Same pattern, completely different character."
            ],
            progressions: [
                ProgressionExample(numerals: "I – IV – V", chords: "E – A – B", feel: "Rock power progression. Huge with distortion."),
                ProgressionExample(numerals: "I – V – vi – IV", chords: "E – B – C#m – A", feel: "Stadium anthem sound."),
                ProgressionExample(numerals: "vi – IV – I – V", chords: "C#m – A – E – B", feel: "Emotional and driving. Rock ballads."),
            ]
        )
    ),

    // ─────────────────────────────────────────
    // CHAPTER 9 — Chord Progressions
    // ─────────────────────────────────────────
    MusicChapter(
        chapterIndex: 9,
        title: "Chord Progressions",
        subtitle: "Why certain chords always sound good together",
        status: .locked, stars: 0,
        lesson: MusicLesson(
            title: "Chord Progressions",
            noteName: "C",
            noteEnglish: "C major",
            description: "A chord progression is a sequence of chords that forms the harmonic foundation of a song. Certain progressions appear in thousands of songs because they create tension, emotion and resolution in a way that feels natural to human ears.",
            variants: ["I–IV–V", "I–V–vi–IV", "ii–V–I", "vi–IV–I–V", "I–vi–IV–V"],
            familyOverview: "Progressions are described with Roman numerals (I II III IV V VI VII) so they work in any key. The I chord is home. The V chord creates tension. The IV chord lifts. The vi chord adds emotion.",
            chordDetails: [
                ChordDetail(name: "I – IV – V", notes: ["I", "IV", "V"], type: "major",
                            emotion: "The foundation of rock, blues and country. Happy, resolved and satisfying.",
                            staffPosition: "In C: C F G. In G: G C D. In A: A D E.",
                            commonUse: "12-bar blues, rock & roll, folk. The most tested progression in history."),
                ChordDetail(name: "I – V – vi – IV", notes: ["I", "V", "vi", "IV"], type: "major",
                            emotion: "Instantly familiar. Sounds emotionally complete.",
                            staffPosition: "In C: C G Am F. In G: G D Em C. In D: D A Bm G.",
                            commonUse: "The most-used pop progression of the last 30 years."),
                ChordDetail(name: "ii – V – I", notes: ["ii", "V", "I"], type: "minor",
                            emotion: "Clean and inevitable. The tension of ii and V makes the I resolution deeply satisfying.",
                            staffPosition: "In C: Dm G C. In G: Am D G. In F: Gm C F.",
                            commonUse: "The cornerstone of jazz. Also used in pop and classical music."),
                ChordDetail(name: "vi – IV – I – V", notes: ["vi", "IV", "I", "V"], type: "minor",
                            emotion: "Emotional and cinematic. Starting on the minor vi gives it depth.",
                            staffPosition: "In C: Am F C G. In G: Em C G D. In A: F#m D A E.",
                            commonUse: "Film scores and emotional pop songs."),
                ChordDetail(name: "I – vi – IV – V", notes: ["I", "vi", "IV", "V"], type: "major",
                            emotion: "Nostalgic and timeless. The 1950s doo-wop sound.",
                            staffPosition: "In C: C Am F G. In G: G Em C D.",
                            commonUse: "Classic rock and roll, doo-wop, and modern retro songs."),
            ],
            listeningGuide: "Play I–V–vi–IV in C (C G Am F) and then play ii–V–I (Dm G C). Notice how the first feels like a loop you could repeat forever, while the second has a clear destination.",
            practiceTasks: [
                "Play I–IV–V in three different keys: C, G and A.",
                "Play I–V–vi–IV in C (C G Am F). Try it at different tempos.",
                "Play the jazz ii–V–I in C (Dm G C) and feel the resolution.",
                "Identify the progression in a song you know by ear.",
                "Transpose C–G–Am–F to the G family: G D Em C."
            ],
            progressions: [
                ProgressionExample(numerals: "I – IV – V", chords: "C – F – G", feel: "Universal. Works in blues, rock, country and pop."),
                ProgressionExample(numerals: "I – V – vi – IV", chords: "C – G – Am – F", feel: "Modern pop standard."),
                ProgressionExample(numerals: "ii – V – I", chords: "Dm – G – C", feel: "Jazz cadence. Clean and resolved."),
                ProgressionExample(numerals: "vi – IV – I – V", chords: "Am – F – C – G", feel: "Emotional and cinematic."),
                ProgressionExample(numerals: "I – vi – IV – V", chords: "C – Am – F – G", feel: "Nostalgic 50s sound."),
            ]
        )
    ),

    // ─────────────────────────────────────────
    // CHAPTER 10 — Ear Training
    // ─────────────────────────────────────────
    MusicChapter(
        chapterIndex: 10,
        title: "Ear Training",
        subtitle: "Hear which family a chord belongs to",
        status: .locked, stars: 0,
        lesson: MusicLesson(
            title: "Recognizing Chord Families",
            noteName: "C",
            noteEnglish: "C major",
            description: "Learning to hear chord families by ear is what separates a beginner from a confident musician. When you can identify the key of a song by ear, you can play along with anything — on the spot, without sheet music.",
            variants: ["C Family", "G Family", "F Family", "D Family", "A Family"],
            familyOverview: "Every key has a unique sound colour. C major sounds clean and neutral. G major sounds bright and energetic. F major sounds warm and full. D major sounds bold and triumphant. A major sounds confident and slightly bluesy.",
            chordDetails: [
                ChordDetail(name: "Recognising Major vs Minor", notes: ["Major", "Minor"], type: "major",
                            emotion: "Major sounds happy and bright. Minor sounds sad and emotional.",
                            staffPosition: "Major: root + 4 semitones + 3 semitones. Minor: root + 3 + 4.",
                            commonUse: "Every song uses this distinction. Train your ear to hear it instantly."),
                ChordDetail(name: "Finding the I chord", notes: ["I chord", "Home base"], type: "major",
                            emotion: "The I chord feels like arriving home. Settled and complete.",
                            staffPosition: "Play the song's most 'finished' or 'resting' chord.",
                            commonUse: "Identify the I chord first. Then you know the key."),
                ChordDetail(name: "Hearing the IV chord", notes: ["IV chord", "Lift"], type: "major",
                            emotion: "The IV chord feels like lifting or expanding.",
                            staffPosition: "Count up 5 white keys from the I chord root.",
                            commonUse: "The IV chord provides harmonic lift in verses and bridges."),
                ChordDetail(name: "Hearing the V chord", notes: ["V chord", "Tension"], type: "major",
                            emotion: "The V chord creates tension and momentum. Always wants to go back to I.",
                            staffPosition: "Count up 7 white keys from the I chord root.",
                            commonUse: "The V chord is the engine of music."),
                ChordDetail(name: "Hearing the vi chord", notes: ["vi chord", "Emotion"], type: "minor",
                            emotion: "The vi chord is always minor and always emotional.",
                            staffPosition: "Count up 9 white keys from the I chord root.",
                            commonUse: "The emotional heart of any progression."),
            ],
            listeningGuide: "Choose any pop song you know. Try to find: (1) Is the key major or minor overall? (2) Can you sing the I chord? (3) When does the music feel tense? That is probably the V chord. (4) When does it feel emotional? That is probably the vi chord.",
            practiceTasks: [
                "Play C and Am back to back. Same notes, completely different mood.",
                "Listen to a song and identify: major key or minor key?",
                "Play I–V–vi–IV in C and name each chord's emotional role.",
                "Try to play along with a song by finding the I chord first.",
                "Close your eyes. Have a friend play any chord from the C family. Name it."
            ],
            progressions: [
                ProgressionExample(numerals: "Ear training 1", chords: "C – F – G – C", feel: "C = home. F = lift. G = tension. C = resolve."),
                ProgressionExample(numerals: "Ear training 2", chords: "Am – F – C – G", feel: "Am = emotional. F = warm. C = home. G = tension."),
                ProgressionExample(numerals: "Ear training 3", chords: "G – D – Em – C", feel: "G = home. D = tension. Em = emotional. C = warm."),
            ]
        )
    ),
]
