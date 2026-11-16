import XCTest
@testable import Rehearse_v1

/// The Practice lessons' notes: spelled and pitched correctly, consistent with each lesson's own
/// theory text, and sounding at that pitch on the app's piano.
final class PracticeMusicTests: XCTestCase {

    private func chapter(_ index: Int) -> MusicChapter {
        allChapters.first { $0.chapterIndex == index }!
    }

    func test_pianoBasics_playsTheWhiteKeysFromMiddleC() {
        let lesson = chapter(1).lesson
        let midis = lesson.variants.compactMap { PracticeMusic.item(for: $0, in: lesson)?.steps.first?.midiNotes }
        XCTAssertEqual(midis, [[60], [62], [64], [65], [67], [69], [71]])
        XCTAssertEqual(PracticeMusic.item(for: "C", in: lesson)?.detail, "Do")
    }

    func test_chordQualities_areBuiltOnC() {
        let lesson = chapter(2).lesson
        func midis(_ v: String) -> [Int]? { PracticeMusic.item(for: v, in: lesson)?.steps.first?.midiNotes }
        XCTAssertEqual(midis("Major"), [60, 64, 67])
        XCTAssertEqual(midis("Minor"), [60, 63, 67])
        XCTAssertEqual(midis("Diminished"), [60, 63, 66])
        XCTAssertEqual(midis("Augmented"), [60, 64, 68])
        XCTAssertEqual(PracticeMusic.item(for: "Minor", in: lesson)?.detail, "C · E♭ · G")
    }

    /// Every family chapter: its chips are the key's seven chords, and each chord's notes are the
    /// ones the lesson's "Chord details" card lists.
    func test_keyFamilies_matchTheirChordDetails() {
        for index in 3...8 {
            let lesson = chapter(index).lesson
            let generated = PracticeMusic.keyChords(tonic: PracticeMusic.tonic(of: lesson)).map(\.symbol)
            XCTAssertEqual(generated, lesson.variants, "chapter \(index) chords")
            for (variant, detail) in zip(lesson.variants, lesson.chordDetails) {
                let chord = PracticeChord(symbol: variant)
                XCTAssertEqual(chord?.notes.map(\.ascii), detail.notes, "chapter \(index) \(variant)")
                XCTAssertNotNil(PracticeMusic.item(for: variant, in: lesson))
            }
        }
    }

    func test_progressions_matchTheCommonProgressionsCard() {
        let lesson = chapter(9).lesson
        for variant in lesson.variants {
            let item = PracticeMusic.item(for: variant, in: lesson)
            XCTAssertNotNil(item, variant)
            let example = lesson.progressions.first {
                $0.numerals.replacingOccurrences(of: " ", with: "") == variant
            }
            XCTAssertEqual(item?.steps.map(\.label).joined(separator: " – "), example?.chords, variant)
        }
    }

    func test_earTraining_roundsAskAboutChordsOfTheirKey() {
        let lesson = chapter(10).lesson
        for (i, variant) in lesson.variants.enumerated() {
            let round = PracticeMusic.earRound(for: variant, index: i)
            XCTAssertTrue(PracticeMusic.earOptions.contains(round.answer))
            XCTAssertEqual(round.reference.root.ascii, String(variant.prefix(while: { $0 != " " })))
            XCTAssertTrue(PracticeMusic.keyChords(tonic: round.tonic).contains(round.mystery))
        }
    }

    /// Renders every note and chord of every lesson on the bundled grand piano and checks the
    /// pitch analyzer hears the intended notes.
    func test_everyLessonStep_soundsAtItsPitch() throws {
        var steps: [[Int]] = []
        for chapter in allChapters where chapter.chapterIndex != 10 {
            for variant in chapter.lesson.variants {
                steps += PracticeMusic.item(for: variant, in: chapter.lesson)?.steps.map(\.midiNotes) ?? []
            }
        }
        for (i, variant) in chapter(10).lesson.variants.enumerated() {
            let round = PracticeMusic.earRound(for: variant, index: i)
            steps += [round.reference.notes.map(\.midi), round.mystery.notes.map(\.midi)]
        }
        let unique = Array(Set(steps.map { $0.sorted() })).sorted { $0.lexicographicallyPrecedes($1) }

        var events: [(midis: [Int], at: Double, length: Double)] = []
        for (i, s) in unique.enumerated() { events.append((s, Double(i) + 0.2, 0.8)) }
        let frames = PianoPitchAnalyzerTests.frames(
            try PianoPitchAnalyzerTests.render(events, duration: Double(unique.count) + 0.6))

        var total = 0, heard = 0, misses: [String] = []
        for (i, s) in unique.enumerated() {
            let from = Double(i) + 0.2, to = from + 0.4
            let window = frames.filter { $0.time >= from && $0.time <= to }
            let sounding = Set(window.flatMap(\.onsets)).union(window.flatMap(\.notes))
            total += s.count
            let got = s.filter { sounding.contains($0) }
            heard += got.count
            if got.count < s.count { misses.append(s.map(PianoPitchAnalyzer.name(of:)).joined(separator: " ")) }
        }
        print("[Practice] \(unique.count) notes/chords, \(heard)/\(total) pitches heard; incomplete: \(misses)")
        XCTAssertGreaterThanOrEqual(Double(heard) / Double(total), 0.95)
    }
}
