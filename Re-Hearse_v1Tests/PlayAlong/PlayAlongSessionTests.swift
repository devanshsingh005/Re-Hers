import XCTest
@testable import Rehearse_v1

final class PlayAlongSessionTests: XCTestCase {

    /// A two-staff score: each entry is (right-hand notes, left-hand notes) for one quarter note.
    private func score(_ beats: [([String], [String])], tempo: Int = 100) throws -> ScoreTimeline {
        func note(_ name: String, staff: Int, chord: Bool) -> [String: Any] {
            let step = String(name.prefix(1))
            let alter = name.contains("#") ? "1" : (name.dropFirst().contains("b") ? "-1" : "0")
            let octave = String(name.last!)
            var n: [String: Any] = ["pitch": ["step": step, "alter": alter, "octave": octave],
                                    "duration": "1", "voice": staff == 1 ? "1" : "5", "staff": String(staff), "type": "quarter"]
            if chord { n["chord"] = NSNull() }
            return n
        }
        var measures: [[String: Any]] = []
        for (m, chunk) in stride(from: 0, to: beats.count, by: 4).map({ ($0 / 4, Array(beats[$0..<min(beats.count, $0 + 4)])) }) {
            var order: [String] = []
            var notes: [[String: Any]] = []
            for (right, _) in chunk {
                if right.isEmpty { notes.append(["rest": NSNull(), "duration": "1", "voice": "1", "staff": "1"]); order.append("note") }
                for (i, r) in right.enumerated() { notes.append(note(r, staff: 1, chord: i > 0)); order.append("note") }
            }
            order.append("backup")
            for (_, left) in chunk {
                if left.isEmpty { notes.append(["rest": NSNull(), "duration": "1", "voice": "5", "staff": "2"]); order.append("note") }
                for (i, l) in left.enumerated() { notes.append(note(l, staff: 2, chord: i > 0)); order.append("note") }
            }
            var measure: [String: Any] = ["@number": String(m + 1), "note": notes, "backup": ["duration": String(chunk.count)],
                                          "#order": (m == 0 ? ["attributes", "direction"] : []) + order]
            if m == 0 {
                measure["attributes"] = ["divisions": "1", "time": ["beats": "4", "beat-type": "4"], "staves": "2",
                                         "clef": [["@number": "1", "sign": "G", "line": "2"], ["@number": "2", "sign": "F", "line": "4"]]]
                measure["direction"] = ["sound": ["@tempo": String(tempo)]]
            }
            measures.append(measure)
        }
        return try ScoreTimeline.parse(root: ["score-partwise": ["part": ["@id": "P1", "measure": measures]]])
    }

    private func midi(_ name: String) -> Int {
        let steps = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        var m = steps[String(name.prefix(1))]! + 12 * (Int(String(name.last!))! + 1)
        if name.contains("#") { m += 1 } else if name.dropFirst().contains("b") { m -= 1 }
        return m
    }

    /// Plays every step on the rendered piano at `bpm`, through the analyzer into the session.
    private func play(_ session: PlayAlongSession, timeline: ScoreTimeline, bpm: Double, noise: Float = 0.002,
                      extra: [(midis: [Int], at: Double, length: Double)] = []) throws -> (events: [PlayAlongSession.Event], frames: Int) {
        let beat = 60 / bpm
        var events: [(midis: [Int], at: Double, length: Double)] = extra
        for step in session.steps {
            let at = 0.4 + Double(step.tick) / Double(timeline.ticksPerQuarter) * beat
            events.append((step.left + step.right, at, beat * 0.9))
        }
        let duration = (events.map { $0.at + $0.length }.max() ?? 1) + 0.8
        let samples = try PianoPitchAnalyzerTests.render(events, duration: duration, noise: noise)
        var out: [PlayAlongSession.Event] = []
        let frames = PianoPitchAnalyzerTests.frames(samples)
        for frame in frames { out += session.listen(frame) }
        return (out, frames.count)
    }

    func test_playingThePiece_finishesWithoutFalseMistakes() throws {
        // melody, chords, a repeated note, octaves, both hands, a black key or two
        let timeline = try score([
            (["E4"], ["C3"]), (["G4"], []), (["C5", "E5"], ["C3", "G3"]), (["C5"], []),
            (["D5"], ["G2"]), (["B4"], ["G3"]), (["G4", "B4", "D5"], ["G2", "D3"]), (["G4"], []),
            (["A4"], ["F3"]), (["A4"], ["F3"]), (["C5", "F5"], ["F2", "C3"]), (["F#4"], ["D3"]),
            (["G4", "C5", "E5"], ["C3", "C4"]), (["E5"], []), (["C5"], ["C3"]), (["C4", "C5"], ["C2", "C3"])
        ])
        let session = PlayAlongSession(timeline: timeline)
        session.restart()
        let (events, _) = try play(session, timeline: timeline, bpm: 90)
        let wrong = events.compactMap { if case .wrong(let m) = $0 { return PianoPitchAnalyzer.name(of: m) } else { return nil } }
        print("[Session] reached step \(session.index)/\(session.steps.count), finished \(session.isFinished), wrong \(wrong), result \(session.result)")
        print("[Session] tempo samples \(session.tempoSamples.map { Int($0.rounded()) })")
        XCTAssertEqual(session.result.playedBPM ?? 0, 90, accuracy: 9)
        XCTAssertTrue(session.isFinished, "every step was heard (stopped at step \(session.index), waiting for \(session.remaining.map(PianoPitchAnalyzer.name(of:))))")
        XCTAssertLessThanOrEqual(wrong.count, 1)
    }

    func test_fastAndNoisy_stillFollows() throws {
        let timeline = try score([
            (["E4"], ["C3"]), (["G4"], []), (["C5", "E5"], ["C3", "G3"]), (["C5"], []),
            (["D5"], ["G2"]), (["B4"], ["G3"]), (["G4", "B4", "D5"], ["G2", "D3"]), (["G4"], []),
            (["A4"], ["F3"]), (["A4"], ["F3"]), (["C5", "F5"], ["F2", "C3"]), (["F#4"], ["D3"])
        ])
        let session = PlayAlongSession(timeline: timeline)
        session.restart()
        let (events, _) = try play(session, timeline: timeline, bpm: 140, noise: 0.01)
        let wrong = events.filter { if case .wrong = $0 { return true } else { return false } }.count
        print("[Session] fast & noisy: step \(session.index)/\(session.steps.count), wrong \(wrong), tempo \(session.playedBPM ?? 0)")
        XCTAssertTrue(session.isFinished, "stopped at step \(session.index)")
        XCTAssertEqual(session.playedBPM ?? 0, 140, accuracy: 14)
        XCTAssertLessThanOrEqual(wrong, 1)
    }

    func test_tempo_matchesHowFastItIsPlayed() throws {
        let line = ["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5", "B4", "A4", "G4", "F4", "E4", "D4", "C4", "E4"]
        let timeline = try score(line.map { ([$0], []) }, tempo: 120)
        for bpm in [70.0, 100.0] {
            let session = PlayAlongSession(timeline: timeline)
            session.restart()
            _ = try play(session, timeline: timeline, bpm: bpm)
            let played = try XCTUnwrap(session.playedBPM)
            print("[Session] played at \(bpm): measured \(played), score \(session.result.targetBPM)")
            XCTAssertEqual(played, bpm, accuracy: bpm * 0.1)
            XCTAssertEqual(session.result.targetBPM, 120, accuracy: 0.01)
        }
    }

    func test_wrongNote_isCaught_andDoesNotMoveOn() throws {
        let timeline = try score([(["C4"], []), (["E4"], []), (["G4"], []), (["C5"], [])])
        let session = PlayAlongSession(timeline: timeline)
        session.restart()
        // play C4, then F4 instead of E4, and nothing after
        let samples = try PianoPitchAnalyzerTests.render([([60], 0.3, 0.5), ([65], 1.0, 0.5)], duration: 2)
        var events: [PlayAlongSession.Event] = []
        for frame in PianoPitchAnalyzerTests.frames(samples) { events += session.listen(frame) }
        print("[Session] wrong-note events \(events)")
        XCTAssertTrue(events.contains(.hit(midi: 60)))
        XCTAssertTrue(events.contains(.wrong(midi: 65)))
        XCTAssertEqual(session.index, 1, "still waiting for E4")
        XCTAssertEqual(session.result.mistakes, 1)
    }

    func test_screenKeyboard_andOneHand() {
        let timeline = try! score([(["E4"], ["C3"]), ([], ["G2"]), (["G4"], [])])
        let session = PlayAlongSession(timeline: timeline)
        session.restart()
        XCTAssertEqual(session.expected, [midi("E4"), midi("C3")])
        XCTAssertEqual(session.touch(midi("E4"), at: 1), [.hit(midi: midi("E4"))])
        XCTAssertEqual(session.touch(midi("D4"), at: 1.1), [.wrong(midi: midi("D4"))])
        XCTAssertEqual(session.touch(midi("C3"), at: 1.2), [.hit(midi: midi("C3")), .advanced(to: 1)])
        // right hand only: the left-hand-only step is passed over
        session.setHands(.right)
        XCTAssertEqual(session.index, 2)
        XCTAssertEqual(session.touch(midi("G4"), at: 2), [.hit(midi: midi("G4")), .finished])
        XCTAssertEqual(session.result.accuracy, 75)
    }
}
