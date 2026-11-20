import Foundation
import AVFoundation
import Accelerate

// MARK: - PianoListener
//
// Listens through the microphone and runs PianoPitchAnalyzer on what it hears, off the main
// thread; frames arrive on the main thread, timed with the same clock as CACurrentMediaTime().

final class PianoListener {
    enum StartFailure: LocalizedError {
        case microphonePermissionMissing
        case noInputRouteAvailable
        case audioSessionConfigurationFailed(Error)
        case engineStartFailed(Error)

        var errorDescription: String? {
            switch self {
            case .microphonePermissionMissing:
                return "Microphone access is required before listening can begin."
            case .noInputRouteAvailable:
                return "No microphone input route is currently available."
            case .audioSessionConfigurationFailed(let error):
                return "The audio session could not be configured: \(error.localizedDescription)"
            case .engineStartFailed(let error):
                return "The microphone engine could not start: \(error.localizedDescription)"
            }
        }
    }

    var onFrame: ((PianoPitchAnalyzer.Frame) -> Void)?
    private(set) var isListening = false
    private(set) var lastStartFailure: StartFailure?

    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "rehearse.piano-listener", qos: .userInteractive)
    /// A background start is under way (see `start(completion:)`).
    private var isStarting = false
    private var stopWhenStarted = false
    private var analyzer: PianoPitchAnalyzer?

    static var permission: AVAudioApplication.recordPermission { AVAudioApplication.shared.recordPermission }

    /// Shows the system's microphone prompt (once); `completion` runs on the main thread.
    static func requestPermission(_ completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption),
                                               name: AVAudioSession.interruptionNotification, object: nil)
    }

    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
    }

    @discardableResult
    func start() -> Bool {
        guard !isListening else { return true }
        lastStartFailure = nil
        guard Self.permission == .granted else {
            lastStartFailure = .microphonePermissionMissing
            return false
        }
        // set up in turn with the playback engine (see AudioEngineManager.runExclusively)
        let started = AudioEngineManager.shared.runExclusively { setUpOnAudioQueue() }
        guard started else { return false }
        isListening = true
        return true
    }

    /// As `start()`, but the audio setup (a few hundred milliseconds) runs in the background;
    /// `completion` gets the result on the main thread.
    func start(completion: @escaping (Bool) -> Void) {
        guard !isListening, !isStarting else { completion(isListening); return }
        lastStartFailure = nil
        guard Self.permission == .granted else {
            lastStartFailure = .microphonePermissionMissing
            completion(false)
            return
        }
        isStarting = true
        stopWhenStarted = false
        AudioEngineManager.shared.runExclusivelyLater { [weak self] in
            let started = self?.setUpOnAudioQueue() ?? false
            DispatchQueue.main.async {
                guard let self else { return }
                self.isStarting = false
                if started { self.isListening = true }
                // stopped while starting (the screen closed): stop now that there's something to stop
                if self.stopWhenStarted {
                    self.stop()
                    completion(false)
                    return
                }
                completion(started)
            }
        }
    }

    /// The session, the tap and the engine. Runs on AudioEngineManager's queue.
    private func setUpOnAudioQueue() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            // measurement mode: no automatic gain or voice processing colouring the sound
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers])
            try session.setActive(true)
            AudioEngineManager.shared.setMicrophoneActiveOnQueue(true)
        } catch {
            lastStartFailure = .audioSessionConfigurationFailed(error)
            return false
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            lastStartFailure = .noInputRouteAvailable
            return false
        }
        let analyzer = PianoPitchAnalyzer(sampleRate: format.sampleRate)
        self.analyzer = analyzer
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, when in
            guard let self, let channel = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channel, count: count))
            let end = when.isHostTimeValid ? AVAudioTime.seconds(forHostTime: when.hostTime) : CACurrentMediaTime()
            let start = end - Double(count) / format.sampleRate
            self.queue.async {
                let frames = analyzer.process(samples, at: start)
                guard !frames.isEmpty else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.isListening else { return }
                    frames.forEach { self.onFrame?($0) }
                }
            }
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            lastStartFailure = .engineStartFailed(error)
            return false
        }
        debugLog("🎙️ [PianoListener] listening at \(Int(format.sampleRate)) Hz")
        return true
    
    }

    func stop() {
        if isStarting { stopWhenStarted = true }
        guard isListening else { return }
        AudioEngineManager.shared.runExclusively {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            AudioEngineManager.shared.setMicrophoneActiveOnQueue(false)
        }
        isListening = false
        queue.async { [analyzer] in analyzer?.reset() }
        debugLog("🛑 [PianoListener] stopped")
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began {
            stop()
        } else if let options = info[AVAudioSessionInterruptionOptionKey] as? UInt,
                  AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
            start()
        }
    }
}

// MARK: - PitchDetector

/// Reports the notes heard, strongest first.
public protocol PitchDetectorDelegate: AnyObject {
    /// `notes`: the clearly sounding keys (see `PitchDetector.strongNotes`), strongest first;
    /// `time`: when they were heard, on the CACurrentMediaTime() clock.
    func pitchDetectorDidDetect(notes: [String], frequency: Float, amplitude: CGFloat, time: Double)
}

/// The Try Yourself listener: the notes PianoPitchAnalyzer hears, by name.
public final class PitchDetector {
    typealias StartFailure = PianoListener.StartFailure

    weak var delegate: PitchDetectorDelegate?
    private let listener = PianoListener()

    var isListening: Bool { listener.isListening }
    var lastStartFailure: StartFailure? { listener.lastStartFailure }

    init() {
        listener.onFrame = { [weak self] frame in self?.report(frame) }
    }

    func recordPermissionStatus() -> AVAudioApplication.recordPermission { PianoListener.permission }

    func requestMicrophonePermission(_ completion: @escaping (Bool) -> Void) {
        PianoListener.requestPermission(completion)
    }

    @discardableResult
    func startListening() -> Bool { listener.start() }

    func stopListening() { listener.stop() }

    /// A note this much weaker than the strongest (by salience) is a faint stray detection
    /// (a resonance, a neighbour's ring), not a key the player is holding.
    static let strongShare: Float = 0.25

    /// The frame's notes that are clearly sounding, strongest first (at most six).
    static func strongNotes(in frame: PianoPitchAnalyzer.Frame, share: Float = strongShare) -> [Int] {
        guard let first = frame.notes.first else { return [] }
        let floor = frame.salience(of: first) * share
        return Array(frame.notes.filter { frame.salience(of: $0) >= floor }.prefix(6))
    }

    private func report(_ frame: PianoPitchAnalyzer.Frame) {
        let notes = Self.strongNotes(in: frame)
        guard let first = notes.first else { return }
        let amplitude = CGFloat(max(0, min(1, (frame.level + 60) / 45)))
        delegate?.pitchDetectorDidDetect(notes: notes.map(PianoPitchAnalyzer.name(of:)),
                                         frequency: Float(PianoPitchAnalyzer.frequency(of: first)),
                                         amplitude: amplitude, time: frame.time)
    }
}

// MARK: - ChordHoldMatcher

/// Decides when what the player sounds matches a target chord (or single note), frame by frame:
/// - every target note heard (any octave) within the last `memory` seconds: the analyzer
///   doesn't report every note of a chord in every frame (high triads lose their top note in
///   many frames);
/// - nothing else sounding in this frame: a wrong extra note fails it;
/// - and that for `holdTime`. A dropout shorter than `gapTolerance` (one missed frame) doesn't
///   restart the hold; silence or a longer break does.
struct ChordHoldMatcher {
    var holdTime: Double = 0.15
    var gapTolerance: Double = 0.06
    var memory: Double = 0.3

    enum Verdict: Equatable {
        /// Not matching: which target notes are missing, which other notes are sounding
        /// (pitch classes, C = 0).
        case notMatching(missing: Set<Int>, extra: Set<Int>)
        /// Matching, not yet for `holdTime`: 0…1.
        case holding(progress: Double)
        /// Matched for `holdTime`.
        case matched
    }

    private var matchStart: Double?
    private var lastMatch: Double?
    private var lastHeard: [Int: Double] = [:]   // pitch class → when it was last heard

    /// `heard`: the pitch classes sounding now; `target`: the chord's pitch classes.
    mutating func feed(heard: Set<Int>, target: Set<Int>, at time: Double) -> Verdict {
        for pc in heard { lastHeard[pc] = time }
        let recent = Set(lastHeard.filter { time - $0.value <= memory }.keys)
        let missing = target.subtracting(recent)
        let extra = heard.subtracting(target)
        if !heard.isEmpty, missing.isEmpty, extra.isEmpty, !target.isEmpty {
            if let lastMatch, matchStart != nil, time - lastMatch <= gapTolerance {
                self.lastMatch = time   // still holding
            } else {
                matchStart = time
                lastMatch = time
            }
            let held = time - (matchStart ?? time)
            return held >= holdTime ? .matched : .holding(progress: max(0, min(1, held / holdTime)))
        }
        // a short dropout keeps the hold going
        if let lastMatch, let matchStart, time - lastMatch <= gapTolerance {
            return .holding(progress: max(0, min(1, (time - matchStart) / holdTime)))
        }
        matchStart = nil
        lastMatch = nil
        return .notMatching(missing: missing, extra: extra)
    }

    mutating func reset() {
        matchStart = nil
        lastMatch = nil
        lastHeard = [:]
    }
}
