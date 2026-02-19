import Foundation
import AVFoundation

// MARK: - AudioEngineManager
final class AudioEngineManager {

    static let shared = AudioEngineManager()

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private let reverb = AVAudioUnitReverb()

    private(set) var isStarted: Bool = false

    // MARK: - Init
    private init() {
        engine.attach(sampler)
        engine.attach(reverb)

        reverb.loadFactoryPreset(.mediumRoom)
        reverb.wetDryMix = 15

        engine.connect(sampler, to: reverb, format: nil)
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)

        engine.prepare()
    }

    // MARK: - Engine Start
    func startEngine(
        loadSoundFont filename: String,
        preset: UInt8 = 0,
        bankMSB: UInt8 = UInt8(kAUSampler_DefaultMelodicBankMSB)
    ) {

        guard !isStarted else { return }

        // Audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("❌ Audio session failed:", error)
            return
        }

        // Load SoundFont
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            print("❌ SoundFont NOT FOUND:", filename)
            print("➡️ Ensure file exists & target membership is checked")
            return
        }

        print("✅ Found SoundFont:", url.lastPathComponent)

        do {
            try sampler.loadSoundBankInstrument(
                at: url,
                program: preset,
                bankMSB: bankMSB,
                bankLSB: 0
            )
            print("✅ Sampler loaded preset:", preset)
        } catch {
            print("❌ Sampler load failed:", error)
            return
        }

        // Start engine
        do {
            try engine.start()
            isStarted = true
            print("🎹 Audio engine started successfully")
        } catch {
            print("❌ Engine start failed:", error)
        }
    }

    // MARK: - MIDI Control
    func startNote(midi: UInt8, velocity: UInt8 = 110, channel: UInt8 = 0) {
        sampler.startNote(midi, withVelocity: velocity, onChannel: channel)
    }

    func stopNote(midi: UInt8, channel: UInt8 = 0) {
        sampler.stopNote(midi, onChannel: channel)
    }

    // MARK: - Note Name → MIDI
    /// Converts note names like "C4", "D#5", "Bb3" to MIDI numbers
    func midiNumber(from noteName: String) -> UInt8? {

        let trimmed = noteName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }

        var notePart = ""
        var octavePart = ""

        for char in trimmed {
            if char.isLetter || char == "#" || char == "b" {
                notePart.append(char)
            } else if char.isNumber {
                octavePart.append(char)
            }
        }

        guard
            !notePart.isEmpty,
            let octave = Int(octavePart)
        else { return nil }

        let baseOffsets: [String: Int] = [
            "C": 0, "D": 2, "E": 4,
            "F": 5, "G": 7, "A": 9, "B": 11
        ]

        let letter = String(notePart.prefix(1)).uppercased()
        var semitone = baseOffsets[letter] ?? 0

        if notePart.contains("#") { semitone += 1 }
        if notePart.contains("b") { semitone -= 1 }
        if semitone < 0 { semitone += 12 }

        let midi = 12 * (octave + 1) + semitone
        guard midi >= 0 && midi <= 127 else { return nil }

        return UInt8(midi)
    }
}
