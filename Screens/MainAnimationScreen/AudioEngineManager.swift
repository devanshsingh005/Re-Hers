//
//  AudioEngineManager.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 13/12/25.
//

// AudioEngineManager.swift
import Foundation
import AVFoundation

final class AudioEngineManager {
    static let shared = AudioEngineManager()
    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private(set) var isStarted = false

    private init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        engine.prepare()
    }

    /// Start audio engine and optionally load a .sf2 soundfont placed in the bundle (e.g. "GeneralUser GS.sf2").
    func startEngine(loadSoundFont filename: String? = nil, preset: UInt8 = 0,
                     bankMSB: UInt8 = UInt8(kAUSampler_DefaultMelodicBankMSB)) throws {
        guard !isStarted else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)

        if let fn = filename {
            if let url = Bundle.main.url(forResource: fn, withExtension: nil) {
                try sampler.loadSoundBankInstrument(at: url, program: preset, bankMSB: bankMSB, bankLSB: 0)
            } else {
                print("AudioEngineManager: soundfont \(fn) not found in bundle.")
            }
        }

        try engine.start()
        isStarted = true
    }

    /// Start a MIDI note (0..127)
    func startNote(midi: UInt8, velocity: UInt8 = 100, channel: UInt8 = 0) {
        sampler.startNote(midi, withVelocity: velocity, onChannel: channel)
    }

    /// Stop a MIDI note (0..127)
    func stopNote(midi: UInt8, channel: UInt8 = 0) {
        sampler.stopNote(midi, onChannel: channel)
    }

    // Convenience: convert note name "C#4" or "Db3" to MIDI number 0..127
    func midiNumber(from noteName: String) -> UInt8? {
        // parse like "C4", "C#4", "Db3"
        let name = noteName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2 else { return nil }

        // Extract letter(s) and octave
        var letterPart = ""
        var octavePart = ""
        for ch in name {
            if ch.isLetter || ch == "#" || ch == "b" { letterPart.append(ch) }
            else if ch.isNumber { octavePart.append(ch) }
        }
        guard !letterPart.isEmpty, let octave = Int(octavePart) else { return nil }

        let baseOffsets: [String: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        let letter = String(letterPart.prefix(1)).uppercased()
        var semitone = baseOffsets[letter] ?? 0
        if letterPart.contains("#") { semitone += 1 }
        if letterPart.contains("b") { semitone -= 1 }
        // handle wrap
        if semitone < 0 { semitone += 12 }

        // MIDI: note = 12 * (octave + 1) + semitone (Middle C C4 -> 60)
        let midi = 12 * (octave + 1) + semitone
        guard midi >= 0 && midi <= 127 else { return nil }
        return UInt8(midi)
    }
}

