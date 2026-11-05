import XCTest
import AVFoundation
@testable import Rehearse_v1

/// Repeatable noise for the rendered audio.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

/// Plays notes and chords on the app's grand piano SoundFont (rendered offline, as a microphone
/// would hear a piano) and checks what the analyzer hears.
final class PianoPitchAnalyzerTests: XCTestCase {

    static let sampleRate = 48_000.0

    /// Renders `events` (notes struck at times, held for a length) on the bundled piano.
    static func render(_ events: [(midis: [Int], at: Double, length: Double)], duration: Double,
                       noise: Float = 0.002) throws -> [Float] {
        let engine = AVAudioEngine()
        let sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.connect(sampler, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "SteinGrandPiano", withExtension: "sf2"))
        try sampler.loadSoundBankInstrument(at: url, program: 0, bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0)
        try engine.start()

        var timeline: [(time: Double, on: Bool, midi: Int)] = []
        for e in events {
            for m in e.midis { timeline.append((e.at, true, m)); timeline.append((e.at + e.length, false, m)) }
        }
        timeline.sort { $0.time < $1.time }
        let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 512)!
        var out: [Float] = []
        var next = 0
        let total = Int(duration * sampleRate)
        var generator = SeededGenerator(seed: 42)
        while out.count < total {
            let now = Double(out.count) / sampleRate
            while next < timeline.count && timeline[next].time <= now {
                let e = timeline[next]
                if e.on { sampler.startNote(UInt8(e.midi), withVelocity: 80, onChannel: 0) }
                else { sampler.stopNote(UInt8(e.midi), onChannel: 0) }
                next += 1
            }
            _ = try engine.renderOffline(512, to: buffer)
            let channel = buffer.floatChannelData![0]
            for i in 0..<Int(buffer.frameLength) {
                out.append(channel[i] + Float.random(in: -noise...noise, using: &generator))
            }
        }
        engine.stop()
        return out
    }

    static func frames(_ samples: [Float]) -> [PianoPitchAnalyzer.Frame] {
        let analyzer = PianoPitchAnalyzer(sampleRate: sampleRate)
        var frames: [PianoPitchAnalyzer.Frame] = []
        var start = 0
        while start < samples.count {
            let chunk = Array(samples[start..<min(samples.count, start + 1024)])
            frames += analyzer.process(chunk, at: Double(start) / sampleRate)
            start += 1024
        }
        return frames
    }

    func test_singleNotes_acrossTheKeyboard() throws {
        let notes = Array(stride(from: 33, through: 96, by: 1))   // A1 … C7
        var events: [(midis: [Int], at: Double, length: Double)] = []
        for (i, m) in notes.enumerated() { events.append(([m], Double(i) * 0.6 + 0.2, 0.5)) }
        let frames = Self.frames(try Self.render(events, duration: Double(notes.count) * 0.6 + 0.6))
        var heard = 0, octaveErrors: [String] = [], misses: [String] = []
        for (i, m) in notes.enumerated() {
            let from = Double(i) * 0.6 + 0.2, to = from + 0.35
            let window = frames.filter { $0.time >= from && $0.time <= to }
            let onsetNotes = window.flatMap(\.onsets)
            if onsetNotes.contains(m) { heard += 1 } else { misses.append(PianoPitchAnalyzer.name(of: m)) }
            for other in Set(onsetNotes) where other != m && abs(other - m) % 12 == 0 {
                octaveErrors.append("\(PianoPitchAnalyzer.name(of: m))→\(PianoPitchAnalyzer.name(of: other))")
            }
        }
        print("[Analyzer] single notes: \(heard)/\(notes.count) heard; missed \(misses); octave errors \(octaveErrors)")
        XCTAssertGreaterThanOrEqual(Double(heard) / Double(notes.count), 0.95)
        XCTAssertLessThanOrEqual(octaveErrors.count, 2)
    }

    func test_chords_areHeardNoteByNote() throws {
        let chords: [[Int]] = [[60, 64, 67], [57, 60, 64], [55, 59, 62, 67], [48, 60], [53, 57, 60, 65],
                               [43, 50, 59], [62, 65, 69], [64, 67, 71, 76], [45, 52, 61], [50, 57, 66]]
        var events: [(midis: [Int], at: Double, length: Double)] = []
        for (i, c) in chords.enumerated() { events.append((c, Double(i) * 1.0 + 0.2, 0.8)) }
        let frames = Self.frames(try Self.render(events, duration: Double(chords.count) + 0.6))
        var total = 0, heard = 0, extra = 0
        for (i, chord) in chords.enumerated() {
            let from = Double(i) + 0.2, to = from + 0.4
            let window = frames.filter { $0.time >= from && $0.time <= to }
            let struck = Set(window.flatMap(\.onsets))
            let sounding = Set(window.flatMap(\.notes))
            total += chord.count
            heard += chord.filter { struck.contains($0) || sounding.contains($0) }.count
            extra += struck.subtracting(chord).count
            print("[Analyzer] chord \(chord.map(PianoPitchAnalyzer.name(of:))): struck \(struck.sorted().map(PianoPitchAnalyzer.name(of:)))")
        }
        print("[Analyzer] chords: \(heard)/\(total) notes heard, \(extra) extra onsets")
        XCTAssertGreaterThanOrEqual(Double(heard) / Double(total), 0.9)
    }

    func test_repeatedNote_isHeardEachTime() throws {
        let events = (0..<6).map { (midis: [60], at: Double($0) * 0.4 + 0.2, length: 0.38) }
        let frames = Self.frames(try Self.render(events, duration: 2.8))
        let onsets = frames.filter { $0.onsets.contains(60) }.map(\.time)
        print("[Analyzer] repeated C4 onsets at \(onsets.map { String(format: "%.2f", $0) })")
        XCTAssertEqual(onsets.count, 6)
    }

    func test_silence_andNoise_reportNothing() throws {
        let frames = Self.frames(try Self.render([], duration: 1.5, noise: 0.01))
        XCTAssertTrue(frames.allSatisfy { $0.onsets.isEmpty })
    }
}
