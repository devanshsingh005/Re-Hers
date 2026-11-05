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
        do {
            let session = AVAudioSession.sharedInstance()
            // measurement mode: no automatic gain or voice processing colouring the sound
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers])
            try session.setActive(true)
            AudioEngineManager.shared.microphoneIsActive = true
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
        isListening = true
        debugLog("🎙️ [PianoListener] listening at \(Int(format.sampleRate)) Hz")
        return true
    }

    func stop() {
        guard isListening else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isListening = false
        queue.async { [analyzer] in analyzer?.reset() }
        AudioEngineManager.shared.microphoneIsActive = false
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
    func pitchDetectorDidDetect(notes: [String], frequency: Float, amplitude: CGFloat)
}

/// The chord-recognition screen's listener: the notes PianoPitchAnalyzer hears, by name.
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

    private func report(_ frame: PianoPitchAnalyzer.Frame) {
        guard let first = frame.notes.first else { return }
        let names = frame.notes.prefix(4).map(PianoPitchAnalyzer.name(of:))
        let amplitude = CGFloat(max(0, min(1, (frame.level + 60) / 45)))
        delegate?.pitchDetectorDidDetect(notes: names, frequency: Float(PianoPitchAnalyzer.frequency(of: first)),
                                         amplitude: amplitude)
    }

    static func frequencyToNoteName(_ f: Float) -> String {
        guard f > 0 else { return "—" }
        let midi = max(0, min(127, Int((69 + 12 * log2(f / 440)).rounded())))
        return PianoPitchAnalyzer.name(of: midi)
    }
}
