//
//  MainChordRecognitionScreen.swift
//  Re-Hearse_v1
//

import UIKit
import AVFoundation
import Accelerate

final class ChordRecognitionViewController: UIViewController {

    // MARK: - Toggle mode
    // true  = fake mode (Mac / Simulator)
    // false = real microphone + FFT (iPhone)
    private let useFakeMode = false

    // MARK: - UI Components
    private let navBar = TopNavBar.make(title: "Note Recognition")

    // Main note display
    private let noteContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 24
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        return view
    }()
    
    private let noteLabel: UILabel = {
        let l = UILabel()
        l.text = "—"
        l.font = .systemFont(ofSize: 64, weight: .heavy)
        l.textColor = .black
        l.textAlignment = .center
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.5
        return l
    }()
    
    private let noteTypeLabel: UILabel = {
        let l = UILabel()
        l.text = "DETECTED NOTE"
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .black
        l.textAlignment = .center
        return l
    }()
    
    // Status display
    private let statusLabel: UILabel = {
        let l = UILabel()
        l.text = "Tap to start"
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.textColor = .black
        l.textAlignment = .center
        return l
    }()
    
    private let frequencyLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        l.textColor = .black
        l.textAlignment = .center
        l.text = "Frequency: — Hz"
        return l
    }()

    // Original wave view with orange theme
    private let waveView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.3).cgColor
        return view
    }()
    
    private var waveLayer: CAShapeLayer?
    
    // Control buttons container
    private let controlContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 28
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.15
        view.layer.shadowOffset = CGSize(width: 0, height: 6)
        view.layer.shadowRadius = 16
        return view
    }()

    private let micButton: UIButton = {
        let b = UIButton(type: .custom)
        b.setImage(UIImage(systemName: "mic.circle.fill"), for: .normal)
        b.tintColor = .white
        b.backgroundColor = .systemGreen
        b.layer.cornerRadius = 40
        b.imageView?.contentMode = .scaleAspectFit
        b.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        return b
    }()
    
    private let stopButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage(systemName: "stop.circle.fill"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = .systemRed
        btn.layer.cornerRadius = 40
        btn.imageView?.contentMode = .scaleAspectFit
        btn.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        btn.alpha = 0.7
        return btn
    }()

    // MARK: - Piano Notes (C2 to C6)
    private struct PianoNotes {
        static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        
        // C2 to C6 frequencies (MIDI notes 36 to 84)
        static let noteFrequencies: [Float] = [
            // C2 to B2 (65.41Hz - 123.47Hz)
            65.41, 69.30, 73.42, 77.78, 82.41, 87.31, 92.50, 98.00, 103.83, 110.00, 116.54, 123.47,
            // C3 to B3 (130.81Hz - 246.94Hz)
            130.81, 138.59, 146.83, 155.56, 164.81, 174.61, 185.00, 196.00, 207.65, 220.00, 233.08, 246.94,
            // C4 to B4 (261.63Hz - 493.88Hz)
            261.63, 277.18, 293.66, 311.13, 329.63, 349.23, 369.99, 392.00, 415.30, 440.00, 466.16, 493.88,
            // C5 to B5 (523.25Hz - 987.77Hz)
            523.25, 554.37, 587.33, 622.25, 659.25, 698.46, 739.99, 783.99, 830.61, 880.00, 932.33, 987.77,
            // C6 (1046.50Hz)
            1046.50
        ]
        
        static func noteNameForIndex(_ noteIndex: Int) -> String? {
            guard noteIndex >= 0 && noteIndex < noteFrequencies.count else { return nil }
            let octave = 2 + (noteIndex / 12)
            let noteNameIndex = noteIndex % 12
            guard noteNameIndex < noteNames.count else { return nil }
            return "\(noteNames[noteNameIndex])\(octave)"
        }
        
        static func findClosestNoteIndex(for frequency: Float) -> Int? {
            guard frequency >= 65.0 && frequency <= 1047.0 else { return nil }
            
            var closestIndex = 0
            var smallestDiff = Float.greatestFiniteMagnitude
            
            for (index, noteFreq) in noteFrequencies.enumerated() {
                let diff = abs(frequency - noteFreq)
                if diff < smallestDiff {
                    smallestDiff = diff
                    closestIndex = index
                }
            }
            
            return closestIndex
        }
    }

    // MARK: - Fake mode
    private var fakeTimer: Timer?
    private var sampleIndex = 0

    private let fakeNotes: [String] = ["C2", "D3", "E4", "F4", "G5", "A5", "B5", "C6"]

    // MARK: - Real audio / FFT
    private let audioEngine = AVAudioEngine()
    private var fftSetup: FFTSetup?
    private let bufferSize: Int = 4096
    private var sampleRate: Double = 44100
    private var isListening = false
    
    // MARK: - Audio processing
    private let minMagnitudeThreshold: Float = 0.0005
    private var frequencyHistory: [Float] = []
    private let historySize = 3
    private var waveUpdateCounter = 0
    private var lastDetectedNote: String = ""
    private var noteStableCount = 0

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupNavBar()
        setupUI()
        configureActions()
        setupWaveLayer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            print("Mic permission granted:", granted)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopFakeAudio()
        stopListening()
    }

    // MARK: - Setup
    private func setupNavBar() {
        navBar.isWelcomeTextHidden = true
        navBar.isStreakVisible = false
        navBar.isChordIconVisible = false
        navBar.isBackButtonVisible = true
        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupUI() {
        [noteContainerView, statusLabel, frequencyLabel, waveView, controlContainerView].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        // Add content to note container
        noteContainerView.addSubview(noteLabel)
        noteContainerView.addSubview(noteTypeLabel)
        
        // Add buttons to control container
        controlContainerView.addSubview(micButton)
        controlContainerView.addSubview(stopButton)
        
        // Set translatesAutoresizingMaskIntoConstraints
        [noteLabel, noteTypeLabel, micButton, stopButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            // Note container
            noteContainerView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 40),
            noteContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noteContainerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            noteContainerView.heightAnchor.constraint(equalToConstant: 160),
            
            noteLabel.centerXAnchor.constraint(equalTo: noteContainerView.centerXAnchor),
            noteLabel.centerYAnchor.constraint(equalTo: noteContainerView.centerYAnchor),
            noteLabel.leadingAnchor.constraint(greaterThanOrEqualTo: noteContainerView.leadingAnchor, constant: 20),
            noteLabel.trailingAnchor.constraint(lessThanOrEqualTo: noteContainerView.trailingAnchor, constant: -20),
            
            noteTypeLabel.centerXAnchor.constraint(equalTo: noteContainerView.centerXAnchor),
            noteTypeLabel.bottomAnchor.constraint(equalTo: noteContainerView.bottomAnchor, constant: -20),
            
            // Status label
            statusLabel.topAnchor.constraint(equalTo: noteContainerView.bottomAnchor, constant: 20),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Frequency label
            frequencyLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            frequencyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Wave view
            waveView.topAnchor.constraint(equalTo: frequencyLabel.bottomAnchor, constant: 30),
            waveView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            waveView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            waveView.heightAnchor.constraint(equalToConstant: 120),

            // Control container
            controlContainerView.topAnchor.constraint(equalTo: waveView.bottomAnchor, constant: 40),
            controlContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            controlContainerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
            controlContainerView.heightAnchor.constraint(equalToConstant: 100),
            
            // Mic button
            micButton.centerYAnchor.constraint(equalTo: controlContainerView.centerYAnchor),
            micButton.centerXAnchor.constraint(equalTo: controlContainerView.centerXAnchor),
            micButton.widthAnchor.constraint(equalToConstant: 80),
            micButton.heightAnchor.constraint(equalToConstant: 80),
            
            // Stop button
            stopButton.centerYAnchor.constraint(equalTo: controlContainerView.centerYAnchor),
            stopButton.centerXAnchor.constraint(equalTo: controlContainerView.centerXAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: 80),
            stopButton.heightAnchor.constraint(equalToConstant: 80),
        ])
        
        // Initially hide stop button
        stopButton.isHidden = true
    }
    
    private func setupWaveLayer() {
        let waveLayer = CAShapeLayer()
        waveLayer.fillColor = UIColor.clear.cgColor
        waveLayer.strokeColor = UIColor.systemOrange.cgColor
        waveLayer.lineWidth = 3.0
        waveLayer.lineCap = .round
        waveLayer.lineJoin = .round
        waveView.layer.addSublayer(waveLayer)
        self.waveLayer = waveLayer
    }
    
    private func updateWave(with amplitude: CGFloat, frequency: Float) {
        guard let waveLayer = waveLayer else { return }
        
        let width = waveView.bounds.width
        let height = waveView.bounds.height
        let centerY = height / 2
        
        // Calculate wave parameters based on frequency
        let waveCount = max(2, min(8, Int(frequency / 100)))
        
        let path = UIBezierPath()
        
        // Create natural-looking wave
        let points = 120
        for i in 0...points {
            let x = CGFloat(i) * width / CGFloat(points)
            
            // Base phase
            let basePhase = CGFloat(i) * CGFloat(waveCount) * 2 * .pi / CGFloat(points)
            
            // Simple sine wave for performance
            let y = centerY + sin(basePhase) * amplitude * height * 0.4
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Update wave color with different orange shades
        waveUpdateCounter += 1
        let orangeShade: UIColor
        switch waveUpdateCounter % 4 {
        case 0:
            orangeShade = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        case 1:
            orangeShade = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        case 2:
            orangeShade = UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0)
        default:
            orangeShade = UIColor(red: 0.9, green: 0.4, blue: 0.1, alpha: 1.0)
        }
        
        waveLayer.strokeColor = orangeShade.cgColor
        
        // Simple animation
        waveLayer.path = path.cgPath
    }

    private func configureActions() {
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
    }
    
    private func showStopButton(_ show: Bool) {
        UIView.animate(withDuration: 0.3) {
            self.micButton.isHidden = show
            self.stopButton.isHidden = !show
            self.stopButton.alpha = show ? 1.0 : 0.7
        }
    }

    // MARK: - Mic logic
    @objc private func micTapped() {
        if useFakeMode {
            fakeTimer == nil ? startFakeAudio() : stopFakeAudio()
        } else {
            isListening ? stopListening() : startListening()
        }
    }

    @objc private func stopTapped() {
        stopFakeAudio()
        stopListening()
        showStopButton(false)
    }

    // MARK: - Fake mode
    private func startFakeAudio() {
        fakeTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(simulateNote), userInfo: nil, repeats: true)
        micButton.backgroundColor = .systemYellow
        showStopButton(true)
        statusLabel.text = "Demo Mode"
    }

    private func stopFakeAudio() {
        fakeTimer?.invalidate()
        fakeTimer = nil
        micButton.backgroundColor = .systemGreen
        showStopButton(false)
        statusLabel.text = "Stopped"
    }

    @objc private func simulateNote() {
        let note = fakeNotes[sampleIndex % fakeNotes.count]
        sampleIndex += 1
        
        // Get frequency for the fake note
        var frequency: Float = 440.0
        for i in 0..<PianoNotes.noteFrequencies.count {
            if let noteName = PianoNotes.noteNameForIndex(i), noteName == note {
                frequency = PianoNotes.noteFrequencies[i]
                break
            }
        }
        
        updateDisplay(note: note, frequency: frequency, amplitude: CGFloat.random(in: 0.3...0.9))
        statusLabel.text = "Demo Mode"
    }

    // MARK: - Real audio + FFT
    private func startListening() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard let self = self else { return }

            if !granted {
                print("❌ Microphone permission denied")
                return
            }

            DispatchQueue.main.async {
                do {
                    try self.configureAudioSession()
                    self.startEngine()
                } catch {
                    print("❌ Audio session error:", error)
                    self.statusLabel.text = "Audio Error"
                }
            }
        }
    }
    
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startEngine() {
        guard !audioEngine.isRunning else { return }
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        sampleRate = format.sampleRate

        let log2n = vDSP_Length(log2(Float(bufferSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        // Use Hann window
        var window = [Float](repeating: 0, count: bufferSize)
        vDSP_hann_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))

        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: format) {
            [weak self] buffer, _ in
            self?.process(buffer: buffer, window: window)
        }

        try? AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement)
        try? AVAudioSession.sharedInstance().setActive(true)
        try? audioEngine.start()

        isListening = true
        micButton.backgroundColor = .systemYellow
        showStopButton(true)
        statusLabel.text = "Listening..."
    }

    private func stopListening() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        if let setup = fftSetup { vDSP_destroy_fftsetup(setup) }
        fftSetup = nil
        isListening = false
        micButton.backgroundColor = .systemGreen
        showStopButton(false)
        statusLabel.text = "Stopped"
        
        // Clear wave
        if let waveLayer = waveLayer {
            waveLayer.path = nil
        }
    }

    private func process(buffer: AVAudioPCMBuffer, window: [Float]) {
        guard let channel = buffer.floatChannelData?[0], let setup = fftSetup else { return }

        var samples = [Float](repeating: 0, count: bufferSize)
        let copySize = min(Int(buffer.frameLength), bufferSize)
        memcpy(&samples, channel, copySize * MemoryLayout<Float>.size)

        // Apply window
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

        vDSP_fft_zrip(setup, &split, 1, vDSP_Length(log2(Float(bufferSize))), FFTDirection(FFT_FORWARD))

        var magnitudes = [Float](repeating: 0, count: half)
        vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(half))
        
        // Find the strongest frequency
        if let frequency = findStrongestFrequency(in: magnitudes) {
            DispatchQueue.main.async {
                self.processDetectedFrequency(frequency)
            }
        }
    }
    
    // MARK: - Frequency Detection
    private func findStrongestFrequency(in magnitudes: [Float]) -> Float? {
        var maxMagnitude: Float = 0
        var maxIndex = 0
        
        // Check frequency range 65Hz to 1100Hz (C2 to C6 range)
        let startIndex = Int(65 * Float(bufferSize) / Float(sampleRate))
        let endIndex = Int(1100 * Float(bufferSize) / Float(sampleRate))
        
        for i in startIndex..<min(endIndex, magnitudes.count - 2) {
            if magnitudes[i] > maxMagnitude {
                maxMagnitude = magnitudes[i]
                maxIndex = i
            }
        }
        
        guard maxMagnitude > minMagnitudeThreshold else { return nil }
        
        // Simple interpolation for better accuracy
        let frequency = simpleInterpolation(index: maxIndex, magnitudes: magnitudes)
        return frequency
    }
    
    private func simpleInterpolation(index: Int, magnitudes: [Float]) -> Float {
        guard index > 0 && index < magnitudes.count - 1 else {
            return Float(index) * Float(sampleRate) / Float(bufferSize)
        }
        
        let left = magnitudes[index - 1]
        let center = magnitudes[index]
        let right = magnitudes[index + 1]
        
        // Basic parabolic interpolation
        let delta = (right - left) / (2 * (2 * center - left - right))
        let interpolatedIndex = Float(index) + delta
        return interpolatedIndex * Float(sampleRate) / Float(bufferSize)
    }
    
    // MARK: - Note Mapping
    private func findClosestPianoNote(_ frequency: Float) -> (note: String, cents: Int)? {
        // Check if frequency is in C2 to C6 range
        guard frequency >= 65.0 && frequency <= 1047.0 else { return nil }
        
        // Find closest note index
        guard let closestIndex = PianoNotes.findClosestNoteIndex(for: frequency) else { return nil }
        
        // Get note name
        guard let noteName = PianoNotes.noteNameForIndex(closestIndex) else { return nil }
        
        // Get exact note frequency
        let exactFreq = PianoNotes.noteFrequencies[closestIndex]
        
        // Calculate cents difference
        let cents = Int(round(1200 * log2(frequency / exactFreq)))
        
        return (noteName, cents)
    }
    
    private func processDetectedFrequency(_ frequency: Float) {
        // Update frequency history for stability
        frequencyHistory.append(frequency)
        if frequencyHistory.count > historySize {
            frequencyHistory.removeFirst()
        }
        
        // Use average frequency
        let stableFrequency = frequencyHistory.reduce(0, +) / Float(frequencyHistory.count)
        
        // Find closest piano note
        guard let noteInfo = findClosestPianoNote(stableFrequency) else {
            noteLabel.text = "—"
            frequencyLabel.text = "Frequency: — Hz"
            statusLabel.text = "Out of range"
            return
        }
        
        let noteName = noteInfo.note
        let centsOff = noteInfo.cents
        
        // Simple stability check
        if noteName == lastDetectedNote {
            noteStableCount += 1
        } else {
            lastDetectedNote = noteName
            noteStableCount = 0
        }
        
        // Only update if note is stable or just changed
        if noteStableCount >= 2 || noteName != lastDetectedNote {
            // Prepare display text
            var displayText = noteName
            if abs(centsOff) > 30 {
                let direction = centsOff > 0 ? "+" : ""
                displayText = "\(noteName) (\(direction)\(abs(centsOff))¢)"
            }
            
            // Calculate amplitude based on stability
            let amplitude = CGFloat(min(1.0, 0.5 + Double(noteStableCount) * 0.1))
            
            updateDisplay(
                note: displayText,
                frequency: stableFrequency,
                amplitude: amplitude
            )
            
            // Update status
            if abs(centsOff) < 20 {
                statusLabel.text = "✓ Live"
            } else if abs(centsOff) < 40 {
                statusLabel.text = "≈ Live"
            } else {
                statusLabel.text = "~ Live"
            }
        } else {
            // Just update frequency display
            frequencyLabel.text = String(format: "Frequency: %.1f Hz", stableFrequency)
        }
    }
    
    private func updateDisplay(note: String, frequency: Float, amplitude: CGFloat) {
        noteLabel.text = note
        frequencyLabel.text = String(format: "Frequency: %.1f Hz", frequency)
        
        // Update wave with new parameters
        updateWave(with: amplitude, frequency: frequency)
    }
}
