import XCTest
@testable import Rehearse_v1

final class HandFingeringTests: XCTestCase {

    /// MIDI numbers: C4 = 60.
    private func notes(_ midis: [Int], left: Bool = false, step: Double = 0.5, length: Double = 0.45) -> [HandNote] {
        midis.enumerated().map { i, m in
            HandNote(midi: m, isLeft: left, start: Double(i) * step, release: Double(i) * step + length)
        }
    }

    private func fingers(_ plan: HandPlan) -> [Int: Int] {   // midi start order → finger
        var result: [Int: Int] = [:]
        for (f, presses) in plan.presses.enumerated() {
            for press in presses { result[Int((press.start / 0.5).rounded())] = f }
        }
        return result
    }

    func test_fiveNoteRun_isPlayedByFiveFingers_withoutMoving() {
        let plan = HandFingering.plan(notes([60, 62, 64, 65, 67]), isLeft: false)
        XCTAssertTrue(plan.moves.isEmpty, "C D E F G sit under one hand")
        XCTAssertEqual((0..<5).map { fingers(plan)[$0] }, [0, 1, 2, 3, 4], "thumb to pinky, not one finger hopping")
    }

    func test_leftHand_runsFromPinkyToThumb() {
        let plan = HandFingering.plan(notes([48, 50, 52, 53, 55], left: true), isLeft: true)
        XCTAssertTrue(plan.moves.isEmpty)
        XCTAssertEqual(plan.thumb, 4)
        XCTAssertEqual((0..<5).map { fingers(plan)[$0] }, [0, 1, 2, 3, 4], "left to right: pinky … thumb")
    }

    func test_repeatedNotes_areNotAllPlayedByTheMiddleFinger() {
        let plan = HandFingering.plan(notes([60, 64, 62, 65, 60, 67]), isLeft: false)
        XCTAssertGreaterThan(Set(fingers(plan).values).count, 3)
    }

    func test_chord_usesOneFingerPerKey_inOrder() {
        let chord = [60, 64, 67].map { HandNote(midi: $0, isLeft: false, start: 0, release: 1) }
        let plan = HandFingering.plan(chord, isLeft: false)
        let used = plan.presses.enumerated().filter { !$0.element.isEmpty }.map(\.offset)
        XCTAssertEqual(used.count, 3)
        let byKey = plan.presses.flatMap { $0 }.sorted { $0.key < $1.key }.map(\.finger)
        XCTAssertEqual(byKey, byKey.sorted(), "low notes on the left fingers")
    }

    func test_leap_movesTheHandBeforeTheNote() {
        let plan = HandFingering.plan(notes([60, 62, 84, 86], step: 1), isLeft: false)
        XCTAssertEqual(plan.moves.count, 1)
        let move = plan.moves[0]
        XCTAssertLessThan(move.end, 2.0, "it arrives before the note")
        XCTAssertGreaterThan(move.start, 1.0, "and leaves after the last note there")
        XCTAssertEqual(plan.position(at: 0.5), move.from)
        XCTAssertEqual(plan.position(at: 2.5), move.to)
        let middle = plan.position(at: (move.start + move.end) / 2)
        XCTAssertTrue(middle > move.from && middle < move.to, "glides in between")
    }

    func test_thumb_staysOffBlackKeysWhenItCan() {
        let plan = HandFingering.plan(notes([66]), isLeft: false)   // F#4 alone
        XCTAssertTrue(plan.presses[0].isEmpty)
    }

    func test_heldNote_keepsItsFinger() {
        // a long C held while the hand plays D E above it
        let held = HandNote(midi: 60, isLeft: false, start: 0, release: 3)
        let moving = [62, 64].enumerated().map { HandNote(midi: $1, isLeft: false, start: Double($0 + 1), release: Double($0 + 1) + 0.9) }
        let plan = HandFingering.plan([held] + moving, isLeft: false)
        let cFinger = plan.presses.firstIndex { $0.contains { $0.start == 0 } }
        let others = plan.presses.enumerated().filter { $0.element.contains { $0.start > 0 } }.map(\.offset)
        XCTAssertNotNil(cFinger)
        XCTAssertFalse(others.contains(cFinger!), "the finger holding C is not taken for D or E")
    }

    func test_hands_moveSmoothly_withoutJumps() {
        // a busy, random two-handed piece: runs, leaps, chords, repeated fingers
        var generator = SystemRandomNumberGenerator()
        var all: [HandNote] = []
        for isLeft in [true, false] {
            var t = 0.0, midi = isLeft ? 48 : 67
            for _ in 0..<400 {
                midi = max(isLeft ? 28 : 55, min(isLeft ? 64 : 100, midi + Int.random(in: -9...9, using: &generator)))
                let length = [0.08, 0.12, 0.25, 0.5, 1.0].randomElement(using: &generator)!
                let chord = Int.random(in: 0..<4, using: &generator) == 0 ? [0, 4, 7] : [0]
                for step in chord where midi + step <= 108 {
                    all.append(HandNote(midi: midi + step, isLeft: isLeft, start: t, release: t + length * 0.95))
                }
                t += length
            }
        }
        for isLeft in [true, false] {
            let plan = HandFingering.plan(all, isLeft: isLeft)
            var previous = HandFingering.pose(plan, at: -1)
            var t = -1.0
            var largest = 0.0
            // half a millisecond: a jump stays as big however fine the steps, a fast glide does not
            while t < 250 {
                t += 0.0005
                let pose = HandFingering.pose(plan, at: t)
                largest = max(largest, abs(pose.position - previous.position))
                for f in 0..<5 {
                    largest = max(largest, abs(pose.fingers[f].x - previous.fingers[f].x), abs(pose.fingers[f].y - previous.fingers[f].y) * 4)
                }
                previous = pose
            }
            XCTAssertLessThan(largest, 0.25, "no finger or hand jumps (largest step in 0.5 ms: \(largest) key widths)")
        }
    }

    func test_aFinger_isOnOneKeyAtATime() {
        // more held notes than fingers: some fingers must take a new note while holding one
        let held = (0..<7).map { HandNote(midi: 60 + 2 * $0, isLeft: false, start: Double($0) * 0.3, release: 5) }
        let plan = HandFingering.plan(held, isLeft: false)
        for presses in plan.presses {
            for (a, b) in zip(presses, presses.dropFirst()) {
                XCTAssertLessThanOrEqual(a.release, b.start - b.approach + 1e-9, "let go before heading to the next key")
            }
        }
    }

    func test_rightHand_staysClearOfTheLeftHand() {
        // left hand around C3–G3; the right hand plays E4 then a lone A3 that both could reach
        let left = notes([48, 50, 52, 53, 55, 53, 52, 50], left: true)
        let right = [HandNote(midi: 64, isLeft: false, start: 0, release: 0.4),
                     HandNote(midi: 57, isLeft: false, start: 1, release: 1.4)]
        let leftPlan = HandFingering.plan(left + right, isLeft: true)
        let rightPlan = HandFingering.plan(left + right, isLeft: false, avoiding: leftPlan)
        for t in stride(from: 0.0, through: 3.5, by: 0.05) {
            XCTAssertGreaterThanOrEqual(rightPlan.position(at: t) - leftPlan.position(at: t), 4,
                                        "the hands do not sit on top of each other at \(t)s")
        }
    }

    func test_keys_mapToTheKeyboard() {
        XCTAssertEqual(HandFingering.key(21)?.x, 0.5)           // A0
        XCTAssertEqual(HandFingering.key(22)?.x, 1.0)           // A#0, between A0 and B0
        XCTAssertEqual(HandFingering.key(22)?.isBlack, true)
        XCTAssertEqual(HandFingering.key(108)?.x, 51.5)         // C8, the 52nd white key
        XCTAssertNil(HandFingering.key(20))
    }
}
