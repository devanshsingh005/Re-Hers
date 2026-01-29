//
//  ChordRecognitionViewController.swift
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

    // MARK: - UI (UNCHANGED)
    private let navBar = TopNavBar.make(
        title: "Chord Recognition"
    )

    private let chordLabel: UILabel = {
        let l = UILabel()
        l.text = "—"
        l.font = .systemFont(ofSize: 46, weight: .bold)
        l.textColor = .black
        l.textAlignment = .center
        return l
    }()

    private let noteLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 20, weight: .medium)
        l.textColor = .darkGray
        l.textAlignment = .center
        return l
    }()

    private let confidenceLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .gray
        l.textAlignment = .center
        return l
    }()

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    
    private let waveView = WaveView()

    private let cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Cancel", for: .normal)
        btn.backgroundColor = UIColor(white: 0.92, alpha: 1)
        btn.setTitleColor(.black, for: .normal)
        btn.layer.cornerRadius = 36
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        return btn
    }()

    private let micButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        b.tintColor = .white
        b.backgroundColor = .systemGreen
        b.layer.cornerRadius = 36
        return b
    }()

    // MARK: - Fake mode
    private var fakeTimer: Timer?
    private var sampleIndex = 0

    private let fakeFrequencies: [[Float]] = [
        [261.63, 329.63, 392.00],
        [293.66, 369.99, 440.00],
        [392.00, 493.88, 587.33],
        [440.00, 554.37, 659.25]
    ]

    // MARK: - Real audio / FFT
    private let audioEngine = AVAudioEngine()
    private var fftSetup: FFTSetup?
    private var bufferSize: Int = 4096
    private var sampleRate: Double = 44100
    private var isListening = false
    private var smoothedAmplitude: CGFloat = 0.01

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupNavBar()
        setupUI()
        configureActions()
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

    // MARK: - NavBar (UNCHANGED)
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

    // MARK: - UI (UNCHANGED)
    private func setupUI() {
        [chordLabel, noteLabel, confidenceLabel, waveView, micButton, cancelButton].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            chordLabel.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 36),
            chordLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            noteLabel.topAnchor.constraint(equalTo: chordLabel.bottomAnchor, constant: 8),
            noteLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            confidenceLabel.topAnchor.constraint(equalTo: noteLabel.bottomAnchor, constant: 6),
            confidenceLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            waveView.topAnchor.constraint(equalTo: confidenceLabel.bottomAnchor, constant: 28),
            waveView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            waveView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            waveView.heightAnchor.constraint(equalToConstant: 140),

            cancelButton.topAnchor.constraint(equalTo: waveView.bottomAnchor, constant: 40),
            cancelButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -28),
            cancelButton.widthAnchor.constraint(equalToConstant: 92),
            cancelButton.heightAnchor.constraint(equalToConstant: 92),

            micButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            micButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 28),
            micButton.widthAnchor.constraint(equalToConstant: 92),
            micButton.heightAnchor.constraint(equalToConstant: 92)
        ])
    }

    private func configureActions() {
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }

    // MARK: - Mic logic
    @objc private func micTapped() {
        if useFakeMode {
            fakeTimer == nil ? startFakeAudio() : stopFakeAudio()
        } else {
            isListening ? stopListening() : startListening()
        }
    }

    @objc private func cancelTapped() {
        stopFakeAudio()
        stopListening()
    }

    // MARK: - Fake mode
    private func startFakeAudio() {
        fakeTimer = Timer.scheduledTimer(timeInterval: 0.15, target: self, selector: #selector(simulateFrequency), userInfo: nil, repeats: true)
        micButton.backgroundColor = .systemYellow
    }

    private func stopFakeAudio() {
        fakeTimer?.invalidate()
        fakeTimer = nil
        micButton.backgroundColor = .systemGreen
    }

    @objc private func simulateFrequency() {
        let freqs = fakeFrequencies[sampleIndex % fakeFrequencies.count]
        sampleIndex += 1
        let note = Self.frequencyToNoteName(freqs[0])
        let chord = Self.guessChord(from: note)

        chordLabel.text = chord
        noteLabel.text = note
        confidenceLabel.text = "Fake"
        waveView.updateAmplitude(CGFloat.random(in: 0.2...0.8))
        waveView.setWaveColor(colorForChord(chord))
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
                }
            }
        }
    }


    private func startEngine() {
        guard !audioEngine.isRunning else { return }
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        sampleRate = format.sampleRate

        let log2n = vDSP_Length(log2(Float(bufferSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

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
    }

    private func stopListening() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        if let setup = fftSetup { vDSP_destroy_fftsetup(setup) }
        fftSetup = nil
        isListening = false
        micButton.backgroundColor = .systemGreen
    }

    private func process(buffer: AVAudioPCMBuffer, window: [Float]) {
        guard let channel = buffer.floatChannelData?[0], let setup = fftSetup else { return }

        var samples = [Float](repeating: 0, count: bufferSize)
        memcpy(&samples, channel, min(Int(buffer.frameLength), bufferSize) * MemoryLayout<Float>.size)

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

        var mags = [Float](repeating: 0, count: half)
        vDSP_zvabs(&split, 1, &mags, 1, vDSP_Length(half))

        let maxIndex = mags.indices.max(by: { mags[$0] < mags[$1] }) ?? 0
        let freq = Float(maxIndex) * Float(sampleRate) / Float(bufferSize)

        DispatchQueue.main.async {
            let note = Self.midiToNoteName(Self.frequencyToMIDINoteNumber(freq))
            let chord = Self.guessChord(from: note)

            self.chordLabel.text = chord
            self.noteLabel.text = note
            self.confidenceLabel.text = "Live"

            let amp = CGFloat(min(1.0, Double(mags[maxIndex]) / 15000))
            self.smoothedAmplitude = self.smoothedAmplitude * 0.85 + amp * 0.15
            self.waveView.updateAmplitude(self.smoothedAmplitude)
            self.waveView.setWaveColor(self.colorForChord(chord))
        }
    }

    // MARK: - Helpers
    private func colorForChord(_ chord: String) -> UIColor {
        switch chord {
        case "Cmaj": return .black
        case "Gmaj": return .systemYellow
        case "Am": return .systemMint
        default: return .lightGray
        }
    }

    private static func frequencyToNoteName(_ f: Float) -> String {
        f < 300 ? "C4" : "A4"
    }

    private static func guessChord(from note: String) -> String {
        note == "C4" ? "Cmaj" : "Am"
    }

    private static func frequencyToMIDINoteNumber(_ f: Float) -> Int {
        Int(round(69 + 12 * log2(f / 440)))
    }

    private static func midiToNoteName(_ midi: Int) -> String {
        ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"][(midi % 12 + 12) % 12]
    }
}
private func configureAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord,
                            mode: .measurement,
                            options: [.defaultToSpeaker, .allowBluetooth])
    try session.setActive(true, options: .notifyOthersOnDeactivation)
}
