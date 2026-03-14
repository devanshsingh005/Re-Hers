import Foundation
import AVFoundation
import Accelerate

/// Reports the strongest detected note and its frequency.
public protocol PitchDetectorDelegate: AnyObject {
    func pitchDetectorDidDetect(note: String, frequency: Float, amplitude: CGFloat)
}

/// A reusable real-time FFT pitch detector based on the logic from ChordRecognitionViewController.
public final class PitchDetector {
    
    // MARK: - Properties
    weak var delegate: PitchDetectorDelegate?
    
    private let audioEngine = AVAudioEngine()
    private var fftSetup: FFTSetup?
    private var bufferSize: Int = 4096
    private var sampleRate: Double = 44100
    private(set) var isListening = false
    
    // Audio processing
    private let minMagnitudeThreshold: Float = 0.001
    private var frequencyHistory: [Float] = []
    private let historySize = 3
    
    // MARK: - Init / Deinit
    init() {
        setupNotifications()
    }
    
    deinit {
        stopListening()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Start/Stop
    
    /// Requests microphone permission and starts the audio engine.
    func startListening() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard let self = self, granted else { return }
            
            DispatchQueue.main.async {
                self.startEngine()
            }
        }
    }
    
    /// Stops the audio engine and removes the tap.
    func stopListening() {
        guard isListening else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
        fftSetup = nil
        isListening = false
        print("🛑 [PitchDetector] Stopped listening")
    }
    
    // MARK: - Audio Session & Engine
    
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
    }
    
    private func startEngine() {
        guard !isListening else { return }
        
        do {
            try configureAudioSession()
            
            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            sampleRate = format.sampleRate
            
            let log2n = vDSP_Length(log2(Float(bufferSize)))
            fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
            
            var window = [Float](repeating: 0, count: bufferSize)
            vDSP_hann_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))
            
            input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: format) { [weak self] buffer, _ in
                self?.process(buffer: buffer, window: window)
            }
            
            try audioEngine.start()
            isListening = true
            print("🎙️ [PitchDetector] Started listening")
        } catch {
            print("❌ [PitchDetector] Engine start error:", error)
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        if type == .began {
            stopListening()
        } else if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    startListening()
                }
            }
        }
    }
    
    // MARK: - FFT Processing
    
    private func process(buffer: AVAudioPCMBuffer, window: [Float]) {
        guard let channel = buffer.floatChannelData?[0], let setup = fftSetup else { return }
        
        // Calculate root mean square (RMS) amplitude as a noise gate
        var rms: Float = 0
        vDSP_rmsqv(channel, 1, &rms, vDSP_Length(buffer.frameLength))
        if rms < 0.015 { 
            return // Ignore very quiet background noise 
        }
        
        var samples = [Float](repeating: 0, count: bufferSize)
        let copySize = min(Int(buffer.frameLength), bufferSize)
        // Copy audio data
        memcpy(&samples, channel, copySize * MemoryLayout<Float>.size)
        
        // Apply Hann window
        vDSP_vmul(samples, 1, window, 1, &samples, 1, vDSP_Length(bufferSize))
        
        let half = bufferSize / 2
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var split = DSPSplitComplex(realp: &real, imagp: &imag)
        
        samples.withUnsafeBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
            }
        }
        
        // Perform Forward FFT
        vDSP_fft_zrip(setup, &split, 1, vDSP_Length(log2(Float(bufferSize))), FFTDirection(FFT_FORWARD))
        
        var magnitudes = [Float](repeating: 0, count: half)
        // Convert complex array to magnitudes
        vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(half))
        
        let peaks = findSignificantPeaks(in: magnitudes)
        DispatchQueue.main.async { [weak self] in
            self?.handleDetectedPeaks(peaks)
        }
    }
    
    // MARK: - Peak Analysis
    
    private func findSignificantPeaks(in magnitudes: [Float]) -> [(frequency: Float, magnitude: Float)] {
        var peaks: [(frequency: Float, magnitude: Float)] = []
        
        for i in 2..<(magnitudes.count - 2) {
            let mag = magnitudes[i]
            
            // Local maxima check
            if mag > minMagnitudeThreshold &&
               mag > magnitudes[i-2] &&
               mag > magnitudes[i-1] &&
               mag > magnitudes[i+1] &&
               mag > magnitudes[i+2] {
                
                let frequency = Float(i) * Float(sampleRate) / Float(bufferSize)
                
                // Typical piano/vocal range (C2 ~65Hz, C7 ~2093Hz)
                if frequency >= 60 && frequency <= 2100 {
                    let interpolatedFreq = quadraticInterpolation(
                        index: i,
                        magnitudes: magnitudes,
                        sampleRate: Float(sampleRate),
                        fftSize: bufferSize
                    )
                    peaks.append((frequency: interpolatedFreq, magnitude: mag))
                }
            }
        }
        
        peaks.sort { $0.magnitude > $1.magnitude }
        return peaks.isEmpty ? [] : [peaks[0]] // Return only the strongest peak
    }
    
    private func quadraticInterpolation(index: Int, magnitudes: [Float], sampleRate: Float, fftSize: Int) -> Float {
        guard index > 0 && index < magnitudes.count - 1 else {
            return Float(index) * sampleRate / Float(fftSize)
        }
        let left   = magnitudes[index - 1]
        let center = magnitudes[index]
        let right  = magnitudes[index + 1]
        
        let p = 0.5 * (left - right) / (left - 2 * center + right)
        let interpolatedIndex = Float(index) + p
        return interpolatedIndex * sampleRate / Float(fftSize)
    }
    
    private func handleDetectedPeaks(_ peaks: [(frequency: Float, magnitude: Float)]) {
        guard let strongest = peaks.first else { return }
        
        let frequency = strongest.frequency
        
        // Stabilize over history
        frequencyHistory.append(frequency)
        if frequencyHistory.count > historySize {
            frequencyHistory.removeFirst()
        }
        
        let stableFreq: Float
        if !frequencyHistory.isEmpty {
            stableFreq = frequencyHistory.reduce(0, +) / Float(frequencyHistory.count)
        } else {
            stableFreq = frequency
        }
        
        let note = PitchDetector.frequencyToNoteName(stableFreq)
        let amplitude = CGFloat(min(1.0, Double(strongest.magnitude) * 500))
        
        delegate?.pitchDetectorDidDetect(note: note, frequency: stableFreq, amplitude: amplitude)
    }
    
    // MARK: - Utilities
    
    static func frequencyToNoteName(_ f: Float) -> String {
        guard f > 0 else { return "—" }
        let midi = Int(round(69 + 12 * log2(f / 440.0)))
        let clampedMidi = max(0, min(127, midi))
        
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let index = clampedMidi % 12
        let octave = (clampedMidi / 12) - 1
        
        return "\(names[index])\(octave)"
    }
}
