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

    // MARK: - Try Yourself's chord check

    func test_chordMatcher_needsTheHold() {
        // frames arrive about every 21 ms
        var m = ChordHoldMatcher()
        let cMajor: Set<Int> = [0, 4, 7]
        var t = 0.0, verdicts: [ChordHoldMatcher.Verdict] = []
        while t <= 0.2 { verdicts.append(m.feed(heard: cMajor, target: cMajor, at: t)); t += 0.021 }
        let firstMatch = verdicts.firstIndex(of: .matched).map { Double($0) * 0.021 }
        XCTAssertNotNil(firstMatch)
        XCTAssertGreaterThanOrEqual(firstMatch ?? 0, 0.15)
        XCTAssertLessThan(firstMatch ?? 1, 0.18)
    }

    func test_chordMatcher_rejectsMissingAndExtraNotes() {
        var m = ChordHoldMatcher()
        let cMajor: Set<Int> = [0, 4, 7]
        XCTAssertEqual(m.feed(heard: [0, 4], target: cMajor, at: 0), .notMatching(missing: [7], extra: []))
        XCTAssertEqual(m.feed(heard: [0, 2, 4, 7], target: cMajor, at: 0.05), .notMatching(missing: [], extra: [2]))
        for t in stride(from: 0.1, through: 1.0, by: 0.02) {
            XCTAssertNotEqual(m.feed(heard: [0, 2, 4, 7], target: cMajor, at: t), .matched)
        }
    }

    func test_chordMatcher_toleratesOneDroppedFrame_notALongGap() {
        let a: Set<Int> = [9]
        // one frame (21 ms) heard as nothing in the middle of the hold
        var m = ChordHoldMatcher()
        var matched = false
        for k in 0..<10 {
            let heard: Set<Int> = k == 4 ? [] : a
            if m.feed(heard: heard, target: a, at: Double(k) * 0.021) == .matched { matched = true }
        }
        XCTAssertTrue(matched)

        // let go for 200 ms: the hold starts again
        var n = ChordHoldMatcher()
        for k in 0..<5 { _ = n.feed(heard: a, target: a, at: Double(k) * 0.021) }
        _ = n.feed(heard: [], target: a, at: 0.3)
        XCTAssertNotEqual(n.feed(heard: a, target: a, at: 0.32), .matched)
    }

    func test_chordMatcher_aChordTappedAndReleased_isNotAccepted() {
        // struck for three frames (~60 ms), then quiet: the memory of its notes must not finish the hold
        var m = ChordHoldMatcher()
        let cMajor: Set<Int> = [0, 4, 7]
        var verdicts: [ChordHoldMatcher.Verdict] = []
        for k in 0..<20 {
            let heard: Set<Int> = k < 3 ? cMajor : []
            verdicts.append(m.feed(heard: heard, target: cMajor, at: Double(k) * 0.021))
        }
        XCTAssertFalse(verdicts.contains(.matched))
    }

    /// Every lesson step (and ear-training chord), played correctly on the bundled piano, is
    /// accepted by Try Yourself's check; with a wrong note added, it isn't.
    func test_everyLessonStep_isAcceptedByTryYourself_andAWrongNoteIsNot() throws {
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
        // the same chords with a wrong note: a whole step above the lowest note, when that isn't in it
        let wrong = unique.compactMap { s -> [Int]? in
            guard s.count >= 3, let low = s.first, !Set(s.map { $0 % 12 }).contains((low + 2) % 12) else { return nil }
            return (s + [low + 2]).sorted()
        }

        func accepted(_ played: [[Int]], targets: [[Int]]) throws -> [Bool] {
            var events: [(midis: [Int], at: Double, length: Double)] = []
            for (i, s) in played.enumerated() { events.append((s, Double(i) + 0.2, 0.8)) }
            let frames = PianoPitchAnalyzerTests.frames(
                try PianoPitchAnalyzerTests.render(events, duration: Double(played.count) + 0.6))
            return targets.enumerated().map { i, target in
                var matcher = ChordHoldMatcher()
                let from = Double(i) + 0.2, to = from + 0.8
                let targetClasses = Set(target.map { $0 % 12 })
                var reasons: [String: Int] = [:]
                let ok = frames.filter { $0.time >= from && $0.time <= to }.contains { frame in
                    let heard = Set(PitchDetector.strongNotes(in: frame).map { $0 % 12 })
                    let verdict = matcher.feed(heard: heard, target: targetClasses, at: frame.time)
                    if case .notMatching(let missing, let extra) = verdict {
                        let why = "missing \(missing.sorted()) extra \(extra.sorted()) strong \(PitchDetector.strongNotes(in: frame).map(PianoPitchAnalyzer.name(of:)))"
                        reasons[why, default: 0] += 1
                    }
                    return verdict == .matched
                }
                if !ok {
                    print("[TryYourself] \(target.map(PianoPitchAnalyzer.name(of:))) not accepted:",
                          reasons.sorted { $0.value > $1.value }.prefix(3).map { "\($0.value)× \($0.key)" })
                }
                return ok
            }
        }

        let right = try accepted(unique, targets: unique)
        let rejected = zip(unique, right).filter { !$0.1 }.map { $0.0.map(PianoPitchAnalyzer.name(of:)).joined(separator: " ") }
        print("[TryYourself] \(right.filter { $0 }.count)/\(unique.count) played correctly accepted; not accepted: \(rejected)")
        XCTAssertGreaterThanOrEqual(Double(right.filter { $0 }.count) / Double(unique.count), 0.95)

        let targetsOfWrong = wrong.map { w in w.filter { $0 != w.first! + 2 } }
        let wrongAccepted = try accepted(wrong, targets: targetsOfWrong)
        print("[TryYourself] \(wrongAccepted.filter { $0 }.count)/\(wrong.count) chords with a wrong note accepted")
        XCTAssertLessThanOrEqual(Double(wrongAccepted.filter { $0 }.count) / Double(max(1, wrong.count)), 0.1)
    }
}
