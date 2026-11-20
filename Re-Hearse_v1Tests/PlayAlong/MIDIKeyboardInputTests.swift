import XCTest
import CoreMIDI
@testable import Rehearse_v1

/// USB keyboard input. (A virtual MIDI keyboard would need the app's background-audio
/// capability, so the keyboard's messages are built by hand.)
@MainActor
final class MIDIKeyboardInputTests: XCTestCase {

    /// What a keyboard sends: note-ons are read (a chord in one list, any channel); note-offs,
    /// note-ons with velocity 0 and other messages are not.
    func test_noteOns_areReadFromTheKeyboardsMessages() {
        var list = MIDIEventList()
        var packet = MIDIEventListInit(&list, ._1_0)
        let words: [UInt32] = [
            0x2090_3C5A,   // note-on C4, velocity 90, channel 1
            0x2093_4046,   // note-on E4, velocity 70, channel 4
            0x2080_3C40,   // note-off C4
            0x2090_4300,   // note-on G4, velocity 0 (= note-off)
            0x20B0_4060,   // sustain pedal (control change)
            0x2090_4347    // note-on G4, velocity 71
        ]
        for var word in words {
            packet = MIDIEventListAdd(&list, MemoryLayout<MIDIEventList>.size, packet, 0, 1, &word)
        }
        let notes = withUnsafePointer(to: &list) { MIDIKeyboardInput.noteOns(in: $0) }
        XCTAssertEqual(notes.map(\.midi), [60, 64, 67])
        XCTAssertEqual(notes.map(\.velocity), [90, 70, 71])
    }

    /// The listener starts (in the simulator there is no keyboard: no devices, no notes).
    func test_listener_starts_andStops() {
        let input = MIDIKeyboardInput()
        XCTAssertTrue(input.start())
        XCTAssertTrue(input.isRunning)
        input.stop()
        XCTAssertFalse(input.isRunning)
    }

    func test_midiNotes_driveThePlayAlongSession() throws {
        let json: [String: Any] = ["score-partwise": ["part": ["@id": "P1", "measure": [
            ["@number": "1", "attributes": ["divisions": "1", "time": ["beats": "4", "beat-type": "4"]],
             "direction": ["sound": ["@tempo": "60"]],
             "#order": ["attributes", "direction", "note", "note", "note", "note"],
             "note": ["C4", "E4", "G4", "C5"].map { name -> [String: Any] in
                 ["pitch": ["step": String(name.prefix(1)), "octave": String(name.last!)], "duration": "1",
                  "voice": "1", "staff": "1", "type": "quarter"]
             }]
        ]]]]
        let session = PlayAlongSession(timeline: try ScoreTimeline.parse(root: json))
        session.restart()
        // played on the keyboard at ♩ = 60, one second apart; one wrong key in between
        XCTAssertEqual(session.key(60, at: 10), [.hit(midi: 60), .advanced(to: 1)])
        XCTAssertEqual(session.key(65, at: 10.5), [.wrong(midi: 65)])
        XCTAssertEqual(session.key(64, at: 11), [.hit(midi: 64), .advanced(to: 2)])
        XCTAssertEqual(session.key(67, at: 12), [.hit(midi: 67), .advanced(to: 3)])
        XCTAssertEqual(session.key(72, at: 13), [.hit(midi: 72), .finished])
        XCTAssertEqual(session.result.mistakes, 1)
        XCTAssertEqual(session.result.playedBPM ?? 0, 60, accuracy: 0.5)
        XCTAssertEqual(session.result.targetBPM, 60, accuracy: 0.01)
    }
}
