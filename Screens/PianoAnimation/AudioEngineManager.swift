import Foundation
import AVFoundation

// MARK: - AudioEngineManager
// Uses AVAudioUnitSampler with system GM DLS when available.
// Falls back to a pure-tone AVAudioPlayerNode synth so sound ALWAYS works.

final class AudioEngineManager {

    static let shared = AudioEngineManager()

    // MARK: - Instrument Types
    enum InstrumentType: CaseIterable {
        case grandPiano, electricPiano

        var displayName: String {
            switch self {
            case .grandPiano:    return "Grand Piano"
            case .electricPiano: return "Electric Piano"
            }
        }

        var sfName: String {
            switch self {
            case .grandPiano:    return "SteinGrandPiano"
            case .electricPiano: return "Wurlitzer210"
            }
        }

        // GM program number for system DLS fallback
        var gmProgram: UInt8 {
            switch self {
            case .grandPiano:    return 0
            case .electricPiano: return 4
            }
        }
    }

    // MARK: - Engine
    private var engine: AVAudioEngine?
    private var sampler: AVAudioUnitSampler?
    private var reverb: AVAudioUnitReverb?
    private var sfLoaded = false
    private var activePlaybackClients = 0

    // Fallback tone synth (used when no soundfont found)
    private var toneNodes: [UInt8: AVAudioPlayerNode] = [:]
    private var useFallback = false

    private var activeNotes: Set<UInt8> = []
    private var samplerChannelsByNote: [UInt8: UInt8] = [:]
    private(set) var isStarted = false
    private var currentInstrument: InstrumentType = .grandPiano

    // MARK: - Init
    private init() {
        setupNotifications()
    }

    private func ensureGraphInitialized() {
        guard engine == nil else { return }

        let engine = AVAudioEngine()
        let sampler = AVAudioUnitSampler()
        let reverb = AVAudioUnitReverb()

        engine.attach(sampler)
        engine.attach(reverb)
        reverb.loadFactoryPreset(.smallRoom)
        reverb.wetDryMix = 15
        engine.connect(sampler, to: reverb, format: nil)
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)
        engine.prepare()

        self.engine = engine
        self.sampler = sampler
        self.reverb = reverb
        self.sfLoaded = false
        self.useFallback = false
    }

    private func teardownGraph() {
        stopAllNotes()

        guard let engine else {
            toneNodes.removeAll()
            sampler = nil
            reverb = nil
            sfLoaded = false
            useFallback = false
            samplerChannelsByNote.removeAll()
            isStarted = false
            return
        }

        for node in toneNodes.values {
            node.stop()
            if engine.attachedNodes.contains(where: { $0 === node }) {
                engine.detach(node)
            }
        }
        toneNodes.removeAll()

        if let sampler, engine.attachedNodes.contains(where: { $0 === sampler }) {
            engine.detach(sampler)
        }
        if let reverb, engine.attachedNodes.contains(where: { $0 === reverb }) {
            engine.detach(reverb)
        }

        engine.stop()
        engine.reset()

        self.engine = nil
        self.sampler = nil
        self.reverb = nil
        self.sfLoaded = false
        self.useFallback = false
        self.samplerChannelsByNote.removeAll()
        self.isStarted = false
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        if type == .began {
            isStarted = false
            engine?.stop()
        } else if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume), activePlaybackClients > 0 {
                    startEngine()
                }
            }
        }
    }

    // MARK: - Ownership
    func acquirePlaybackSession() {
        activePlaybackClients += 1
        startEngine()
    }

    func releasePlaybackSession() {
        if activePlaybackClients > 0 {
            activePlaybackClients -= 1
        }

        guard activePlaybackClients == 0 else { return }

        stopAllNotes()
        teardownGraph()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: - Start
    func startEngine() {
        ensureGraphInitialized()
        guard !isStarted else { return }
        guard let engine else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            try engine.start()
            isStarted = true
            debugLog("🎹 Audio engine started")
        } catch {
            debugLog("❌ Engine start failed:", error); return
        }
        loadSoundFont(for: currentInstrument)
    }

    // MARK: - Load SoundFont
    private func loadSoundFont(for instrument: InstrumentType) {
        guard sampler != nil else { return }
        sfLoaded = false
        useFallback = false

        // 1. Custom bundle SF2/DLS
        for ext in ["sf2", "dls"] {
            if let url = Bundle.main.url(forResource: instrument.sfName, withExtension: ext) {
                if tryLoad(url: url, program: instrument.gmProgram) { return }
            }
        }

        // 2. System General MIDI DLS
        let sysPaths = [
            "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls",
            "/Library/Audio/Sounds/Banks/gs_instruments.dls",
            "/System/Library/Audio/UISounds/New/Classic/NewsFlash.caf" // Just a test to see if system library is readable, though not a DLS
        ]
        for path in sysPaths {
            let url = URL(fileURLWithPath: path)
            if (try? url.checkResourceIsReachable()) == true {
                if tryLoad(url: url, program: instrument.gmProgram) { return }
            }
        }
        if let url = Bundle(identifier: "com.apple.audio.units.components")?
            .url(forResource: "gs_instruments", withExtension: "dls") {
            if tryLoad(url: url, program: instrument.gmProgram) { return }
        }

        // 3. Pure tone fallback — always sounds decent
        debugLog("⚠️ No soundfont found — using sine-wave fallback")
        useFallback = true
        sfLoaded    = true  // allow playback via fallback path
    }

    private func tryLoad(url: URL, program: UInt8) -> Bool {
        guard let sampler else { return false }
        do {
            try sampler.loadSoundBankInstrument(
                at: url, program: program,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0)
            sfLoaded = true
            useFallback = false
            debugLog("🎹 Loaded:", url.lastPathComponent)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Switch Instrument
    func switchInstrument(to instrument: InstrumentType) {
        currentInstrument = instrument
        stopAllNotes()
        if engine != nil {
            loadSoundFont(for: instrument)
        }
    }

    // MARK: - Note On/Off

    func startNote(midi: UInt8, velocity: UInt8 = 90) {
        guard isStarted else { return }

        // If this MIDI note is already active, stop it cleanly first
        // so the sampler channel is freed before we re-allocate it.
        if activeNotes.contains(midi) {
            stopNote(midi: midi)
        }

        if useFallback {
            playTone(midi: midi, velocity: velocity)
        } else {
            guard let sampler, sfLoaded else { return }
            let channel = allocateSamplerChannel(for: midi)
            let vel = UInt8(clamping: Int(velocity) + Int.random(in: -4...4))
            sampler.startNote(midi, withVelocity: vel, onChannel: channel)
        }
        activeNotes.insert(midi)
    }

    func stopNote(midi: UInt8) {
        guard isStarted else { return }
        activeNotes.remove(midi)

        if useFallback {
            stopTone(midi: midi)
        } else {
            guard let sampler else { return }
            let channel = samplerChannelsByNote.removeValue(forKey: midi) ?? 0
            sampler.stopNote(midi, onChannel: channel)
        }
    }

    func stopAllNotes() {
        let snapshot = activeNotes
        for m in snapshot { stopNote(midi: m) }
        activeNotes.removeAll()
    }

    // MARK: - Sine Tone Fallback
    // Generates a clean sine wave at the correct pitch.
    // Each MIDI note gets its own AVAudioPlayerNode playing a looping buffer.

    private func playTone(midi: UInt8, velocity: UInt8) {
        guard let engine else { return }
        let freq = midiToHz(midi)
        guard let buffer = makeSineBuffer(freq: freq, duration: 2.0) else { return }

        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode,
                       format: buffer.format)
        node.scheduleBuffer(buffer, at: nil, options: .loops)

        let gain = Float(velocity) / 127.0 * 0.4
        node.volume = gain
        node.play()
        toneNodes[midi] = node
    }

    private func stopTone(midi: UInt8) {
        guard let node = toneNodes.removeValue(forKey: midi) else { return }
        node.stop()
        if let engine, engine.attachedNodes.contains(where: { $0 === node }) {
            engine.detach(node)
        }
    }

    private func makeSineBuffer(freq: Double, duration: Double) -> AVAudioPCMBuffer? {
        let sampleRate: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        let twoPi = 2.0 * Double.pi
        guard let ch = buffer.floatChannelData?[0] else { return nil }

        // Sine with short attack/decay envelope to avoid clicks
        let attack = Int(sampleRate * 0.01)
        let decay  = Int(sampleRate * 0.1)
        let total  = Int(frameCount)

        for i in 0..<total {
            var amp: Float = 1.0
            if i < attack {
                amp = Float(i) / Float(attack)
            } else if i > total - decay {
                amp = Float(total - i) / Float(decay)
            }
            ch[i] = amp * Float(sin(twoPi * freq * Double(i) / sampleRate))
        }
        return buffer
    }

    private func midiToHz(_ midi: UInt8) -> Double {
        return 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
    }

    private func allocateSamplerChannel(for midi: UInt8) -> UInt8 {
        let melodicChannels = (0...15).map(UInt8.init).filter { $0 != 9 }
        let usedChannels = Set(samplerChannelsByNote.values)
        let channel = melodicChannels.first(where: { !usedChannels.contains($0) }) ?? 0
        samplerChannelsByNote[midi] = channel
        return channel
    }

    // MARK: - Note Name → MIDI
    func midiNumber(from noteName: String) -> UInt8? {
        let s = noteName.trimmingCharacters(in: .whitespaces)
        guard s.count >= 2 else { return nil }

        var note = ""
        var octStr = ""
        for c in s {
            if c.isLetter || c == "#" || c == "b" { note.append(c) }
            else if c.isNumber || (c == "-" && !note.isEmpty) { octStr.append(c) }
        }
        guard !note.isEmpty, let oct = Int(octStr) else { return nil }

        let bases = ["C":0,"D":2,"E":4,"F":5,"G":7,"A":9,"B":11]
        let letter = String(note.prefix(1)).uppercased()
        var semi   = bases[letter] ?? 0
        if note.contains("#") { semi += 1 }
        if note.contains("b") { semi -= 1 }
        let midi = 12 * (oct + 1) + semi
        guard (0...127).contains(midi) else { return nil }
        return UInt8(midi)
    }
}
