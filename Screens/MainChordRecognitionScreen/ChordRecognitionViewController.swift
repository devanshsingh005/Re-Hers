//
//  ChordRecognitionViewController.swift
//  Re-Hearse_v1
//
//  Unified file — UI + Fake audio mode (default) + commented Real AV code
//

import UIKit
// If you want real microphone + FFT later, uncomment these:
// import AVFoundation
// import Accelerate

final class ChordRecognitionViewController: UIViewController {

    // MARK: - Toggle mode
    // true = use fake/static data (works on Mac without a device)
    // false = use real microphone (you must uncomment the AVFoundation/Accelerate imports
    // and the AV audio sections below)
    private let useFakeMode = true

    // MARK: - UI
    private let navBar = TopNavBar.make(
        appTitle: "Chord Recognition",
        dayText: "",
        welcomeText: "",
        profileImage: nil
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
        l.text = ""
        l.font = .systemFont(ofSize: 20, weight: .medium)
        l.textColor = .darkGray
        l.textAlignment = .center
        return l
    }()

    private let confidenceLabel: UILabel = {
        let l = UILabel()
        l.text = ""
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .gray
        l.textAlignment = .center
        return l
    }()

    private let waveView = ChordWaveView() // included below
   

    // Cancel button → stop listening (does NOT pop)
    private let cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Cancel", for: .normal)
        btn.backgroundColor = UIColor(white: 0.92, alpha: 1)
        btn.setTitleColor(.black, for: .normal)
        btn.layer.cornerRadius = 36
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        return btn
    }()

    // Mic button → start/stop listening (fake or real)
    private let micButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        b.tintColor = .white
        b.backgroundColor = .systemGreen
        b.layer.cornerRadius = 36
        return b
    }()

    // Back button → go back to previous screen (explicit)
    private let backButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Back", for: .normal)
        b.backgroundColor = .black
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 14
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        return b
    }()

    // MARK: - Fake audio simulation (for local testing)
    private var fakeTimer: Timer?
    private var sampleIndex = 0
    // A short cyclic fake frequency dataset (Hz)
   

        private let fakeFrequencies: [[Float]] = [
            [261.63, 329.63, 392.00],   // C major
            [293.66, 369.99, 440.00],   // D major
            [329.63, 415.30, 493.88],   // E major
            [349.23, 440.00, 523.25],   // F major
            [392.00, 493.88, 587.33],   // G major
            [440.00, 554.37, 659.25],   // A major
            [493.88, 622.25, 739.99]    // B major
          ]
        
    private func colorForChord(_ chord: String) -> UIColor {
        switch chord {
        case "Cmaj", "C":
            return UIColor.black
        case "Dmaj", "D":
            return UIColor.systemPurple
        case "Emaj", "E":
            return UIColor.systemRed
        case "Fmaj", "F":
            return UIColor.systemTeal
        case "Gmaj", "G":
            return UIColor.systemYellow
        case "Amaj", "A":
            return UIColor.systemGreen
        case "Bmaj", "B":
            return UIColor.systemOrange

        case "Am":
            return UIColor.systemMint
        case "Dm":
            return UIColor.systemPink
        case "Em":
            return UIColor.systemRed
        case "Gm":
            return UIColor.brown

        default:
            return UIColor.lightGray
        }
    }
    private func updateWaveColor(for chord: String) {
        let color = colorForChord(chord)
        waveView.setWaveColor(color)
    }


    // MARK: - (Optional) Real audio / FFT properties (commented)
    /*
    private let audioEngine = AVAudioEngine()
    private var fftSetup: FFTSetup?
    private var log2n: vDSP_Length = 0
    private var bufferSize: Int = 4096
    private var sampleRate: Double = 44100
    private var isListening = false
    private var smoothedAmplitude: CGFloat = 0.01
    */

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupNavBar()
        setupUI()
        configureActions()

        if !useFakeMode {
            // If you want to use real mode now, change useFakeMode = false and
            // uncomment the AV code blocks near the bottom of this file.
            // For now we default to fake mode so it works on Mac without a device.
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopFakeAudio()
        // stopListening() // enable when real mode enabled
    }

    // MARK: - Setup UI / NavBar
    private func setupNavBar() {
        navBar.isWelcomeTextHidden = true
        navBar.isStreakVisible = false
        navBar.isChordIconVisible = false

        // Optional: allow dayBadgeAction to act as a "back" affordance
        navBar.dayBadgeAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
            self?.navBar.chordAction = { [weak self] in
                let vc = ChordRecognitionViewController()
                self?.navigationController?.pushViewController(vc, animated: true)
            }

        }

        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // If the selected tab is NOT the tab that owns this VC → close it
        if let tab = tabBarController,
           let nav = navigationController,
           tab.selectedViewController !== nav {

            nav.popViewController(animated: false)
        }
    }


    private func setupUI() {
        // Add subviews
        [chordLabel, noteLabel, confidenceLabel, waveView, micButton, cancelButton, backButton].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        // Layout constraints — all in same view hierarchy
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

            // cancel & mic side-by-side centered around centerX
            cancelButton.topAnchor.constraint(equalTo: waveView.bottomAnchor, constant: 40),
            cancelButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -28),
            cancelButton.widthAnchor.constraint(equalToConstant: 92),
            cancelButton.heightAnchor.constraint(equalToConstant: 92),

            micButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            micButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 28),
            micButton.widthAnchor.constraint(equalToConstant: 92),
            micButton.heightAnchor.constraint(equalToConstant: 92),

            // back button below controls
            backButton.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 20),
            backButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 200),
            backButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    private func configureActions() {
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    }

    @objc private func backTapped() {
        stopFakeAudio()
        // stopListening() // for real mode
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Fake audio simulation (default mode)
    @objc private func micTapped() {
        if useFakeMode {
            if fakeTimer == nil {
                startFakeAudio()
            } else {
                stopFakeAudio()
            }
        } else {
            // Real mode: start/stop audio engine
            // toggleListening()
        }
    }

    private func startFakeAudio() {
        stopFakeAudio()
        sampleIndex = 0
        // schedule timer
        fakeTimer = Timer.scheduledTimer(timeInterval: 0.15,
                                         target: self,
                                         selector: #selector(simulateFrequency),
                                         userInfo: nil,
                                         repeats: true)
        // show visual "listening" state
        micButton.backgroundColor = UIColor(red: 1.0, green: 0.88, blue: 0.5, alpha: 1)
    }

    @objc private func stopFakeAudio() {
        fakeTimer?.invalidate()
        fakeTimer = nil
        micButton.backgroundColor = .systemGreen

        // reset UI
        chordLabel.text = "—"
        noteLabel.text = ""
        confidenceLabel.text = ""
        waveView.updateAmplitude(0.02)
    }

    @objc private func cancelTapped() {
        // Cancel should stop listening but NOT navigate away
        stopFakeAudio()
        // if real mode: stopListening()
    }

    @objc private func simulateFrequency() {
        let freqs = fakeFrequencies[sampleIndex % fakeFrequencies.count]
        sampleIndex += 1

        // Use the first frequency in the triad as the representative/root
        guard let rootFreq = freqs.first else { return }
        let note = Self.frequencyToNoteName(rootFreq)
        let chord = Self.guessChord(from: note)

        // update UI
        chordLabel.text = chord
        let freqText = freqs.map { String(Int($0)) }.joined(separator: ", ")
        noteLabel.text = "\(note) — [\(freqText)] Hz"
        confidenceLabel.text = "Confidence: 100%"
       
        // amplitude proportional-ish to frequency value (simple mapping)
        // higher frequency → slightly higher amplitude (just for demo)
        // ADD THIS ↓↓↓
            let amp = CGFloat.random(in: 0.1...1.0)
            waveView.updateAmplitude(amp)

            // UPDATE WAVE COLOR ALSO
            let color = colorForChord(chord)
            waveView.setWaveColor(color)
        
        
    }

    // MARK: - Simple mapping for fake data
    private static func frequencyToNoteName(_ f: Float) -> String {
        switch f {
        case 250...275: return "C4"
        case 320...350: return "E4"
        case 380...410: return "G4"
        case 430...450: return "A4"
        default: return "—"
        }
    }

    private static func guessChord(from note: String) -> String {
        switch note {
        case "C4": return "Cmaj"
        case "E4": return "Cmaj"
        case "G4": return "Cmaj"
        case "A4": return "Am"
        default: return "—"
        }
    }

    // MARK: - (OPTIONAL) Real audio + FFT code
    /*
    // If you later want to enable the microphone + FFT:
    // 1) Set useFakeMode = false
    // 2) Uncomment imports at top (AVFoundation + Accelerate)
    // 3) Uncomment the properties at top that relate to audioEngine, fft
    // 4) Uncomment startListening(), stopListening(), process(buffer:window:) implementation below
    // 5) Make sure you request microphone permission (AVAudioSession) before starting

    private func toggleListening() {
        isListening ? stopListening() : startListening()
    }

    private func startListening() {
        guard !isListening else { return }
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        sampleRate = format.sampleRate
        bufferSize = 4096
        log2n = vDSP_Length(log2(Float(bufferSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        var window = [Float](repeating: 0, count: bufferSize)
        vDSP_hann_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))

        input.installTap(onBus: 0,
                         bufferSize: AVAudioFrameCount(bufferSize),
                         format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.process(buffer: buffer, window: window)
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            try audioEngine.start()
            isListening = true
            DispatchQueue.main.async { self.micButton.backgroundColor = UIColor(red: 1.0, green: 0.88, blue: 0.5, alpha: 1) }
        } catch {
            print("Audio engine start failed:", error)
        }
    }

    private func stopListening() {
        guard isListening else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
            fftSetup = nil
        }
        isListening = false
        DispatchQueue.main.async { self.micButton.backgroundColor = .systemGreen }
    }

    private func process(buffer: AVAudioPCMBuffer, window: [Float]) {
        guard let channelData = buffer.floatChannelData?[0], let setup = fftSetup else { return }
        let frameLength = Int(buffer.frameLength)
        var input = [Float](repeating: 0, count: bufferSize)
        memcpy(&input, channelData, min(frameLength, bufferSize) * MemoryLayout<Float>.size)

        vDSP_vmul(input, 1, window, 1, &input, 1, vDSP_Length(bufferSize))

        let half = bufferSize / 2
        var realp = [Float](repeating: 0, count: half)
        var imagp = [Float](repeating: 0, count: half)
        var split = DSPSplitComplex(realp: &realp, imagp: &imagp)

        // pack interleaved
        var interleaved = [DSPComplex](repeating: DSPComplex(real: 0, imag: 0), count: half)
        for i in 0..<half {
            interleaved[i] = DSPComplex(real: input[2*i], imag: input[2*i+1])
        }

        interleaved.withUnsafeBufferPointer { ptr in
            var tmp = split
            vDSP_ctoz(ptr.baseAddress!, 2, &tmp, 1, vDSP_Length(half))
        }

        vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))

        var scale: Float = 1.0 / Float(2 * half)
        vDSP_vsmul(split.realp, 1, &scale, split.realp, 1, vDSP_Length(half))
        vDSP_vsmul(split.imagp, 1, &scale, split.imagp, 1, vDSP_Length(half))

        var mags = [Float](repeating: 0, count: half)
        vDSP_zvabs(&split, 1, &mags, 1, vDSP_Length(half))

        // find peak
        let maxIndex = mags.indices.dropFirst().max(by: { mags[$0] < mags[$1] }) ?? 1
        let maxMag = mags[maxIndex]
        let freq = Float(maxIndex) * Float(sampleRate) / Float(bufferSize)

        DispatchQueue.main.async {
            self.chordLabel.text = "\(Int(freq)) Hz"
            let amp = CGFloat(min(1.0, Double(maxMag) / 15000.0))
            self.smoothedAmplitude = self.smoothedAmplitude * 0.85 + amp * 0.15
            self.waveView.updateAmplitude(self.smoothedAmplitude)
        }
    }
    */

    // MARK: - Helpers (static mapping for fake mode)
    private static func frequencyToMIDINoteNumber(_ frequency: Float) -> Int {
        guard frequency > 0 else { return 0 }
        let midi = 69 + 12 * log2f(frequency / 440.0)
        return Int(roundf(midi))
    }

    private static func midiToNoteName(_ midi: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let pitchClass = (midi % 12 + 12) % 12
        let octave = (midi / 12) - 1
        return "\(names[pitchClass])\(octave)"
    }
}

// MARK: - ChordWaveView: simple waveform that reacts to amplitude
final class ChordWaveView: UIView {
    private let shapeLayer = CAShapeLayer()
    private var amplitude: CGFloat = 0.05
    private var displayLink: CADisplayLink?
    private var phase: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor.systemBlue.cgColor
        shapeLayer.lineWidth = 2.0
        layer.addSublayer(shapeLayer)

        displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink?.add(to: .main, forMode: .common)
        displayLink?.isPaused = true // start paused until amplitude > small threshold
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
    }

    @objc private func step() {
        phase += 0.05
        shapeLayer.path = waveformPath().cgPath
    }

    func updateAmplitude(_ amp: CGFloat) {
        // smooth and clamp
        amplitude = max(0.01, min(1.2, amp))
        displayLink?.isPaused = amplitude < 0.02
        // force immediate redraw
        shapeLayer.path = waveformPath().cgPath
    }

    func setWaveColor(_ color: UIColor) {
        // Update the stroke color of the waveform
        shapeLayer.strokeColor = color.cgColor
    }

    private func waveformPath() -> UIBezierPath {
        let path = UIBezierPath()
        let w = bounds.width
        let h = bounds.height
        guard w > 0 && h > 0 else { return path }

        let midY = h / 2
        let wavelength: CGFloat = w / 1.2   // smooth long wave
        let ampPx = amplitude * (h / 2) * 0.8   // amplitude controls height only

        for x in stride(from: 0, through: w, by: 1) {
            let y = sin((x / wavelength) * .pi * 2 + phase) * ampPx + midY
            let pt = CGPoint(x: x, y: y)
            if x == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }

        return path
    }

    deinit {
        displayLink?.invalidate()
    }
}

