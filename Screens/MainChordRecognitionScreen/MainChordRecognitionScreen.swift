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
    private let navBar = TopNavBar.make(title: "Chord Recognition")

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

    // MARK: - Fake mode
    private var fakeTimer: Timer?
    private var sampleIndex = 0

    private let fakeNotes: [String] = ["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"]
    private let fakeFrequencies: [Float] = [261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25]

    // MARK: - Real audio / FFT
    private let pitchDetector = PitchDetector()
    
    // MARK: - Audio processing
    private var lastNote: String = ""
    private var waveUpdateCounter = 0

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupNavBar()
        setupUI()
        configureActions()
        setupWaveLayer()
        pitchDetector.delegate = self
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
        let waveCount = Int(max(2, min(8, frequency / 100))) // Adjust wave density by frequency
        
        let path = UIBezierPath()
        
        // Create natural-looking wave with multiple sine components
        let points = 200
        for i in 0...points {
            let x = CGFloat(i) * width / CGFloat(points)
            
            // Base phase
            let basePhase = CGFloat(i) * CGFloat(waveCount) * 2 * .pi / CGFloat(points)
            
            // Multiple sine waves for natural look - only orange shades
            let y1 = sin(basePhase) * amplitude * 0.7
            let y2 = sin(basePhase * 2 + 0.5) * amplitude * 0.3
            let y3 = sin(basePhase * 3 + 1.0) * amplitude * 0.15
            
            // Natural randomness
            let randomFactor = CGFloat.random(in: 0.9...1.1)
            let y = centerY + (y1 + y2 + y3) * height * 0.4 * randomFactor
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Update wave color with different orange shades based on amplitude
        waveUpdateCounter += 1
        let orangeShade: UIColor
        switch waveUpdateCounter % 4 {
        case 0:
            orangeShade = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0) // Bright orange
        case 1:
            orangeShade = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0) // Pure orange
        case 2:
            orangeShade = UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0) // Light orange
        default:
            orangeShade = UIColor(red: 0.9, green: 0.4, blue: 0.1, alpha: 1.0) // Dark orange
        }
        
        waveLayer.strokeColor = orangeShade.cgColor
        
        // Smooth animation
        let animation = CABasicAnimation(keyPath: "path")
        animation.duration = 0.2
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fromValue = waveLayer.path
        animation.toValue = path.cgPath
        
        CATransaction.begin()
        CATransaction.setDisableActions(false)
        waveLayer.add(animation, forKey: "wavePath")
        waveLayer.path = path.cgPath
        CATransaction.commit()
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
            pitchDetector.isListening ? stopListening() : startListening()
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
        let frequency = fakeFrequencies[sampleIndex % fakeFrequencies.count]
        sampleIndex += 1
        
        updateDisplay(note: note, frequency: frequency, amplitude: CGFloat.random(in: 0.3...0.9))
        statusLabel.text = "Demo Mode"
    }

    // MARK: - Real audio + FFT
    private func startListening() {
        pitchDetector.startListening()
        micButton.backgroundColor = .systemYellow
        showStopButton(true)
        statusLabel.text = "Listening..."
    }

    private func stopListening() {
        pitchDetector.stopListening()
        micButton.backgroundColor = .systemGreen
        showStopButton(false)
        statusLabel.text = "Stopped"
        
        // Clear wave
        if let waveLayer = waveLayer {
            waveLayer.path = nil
        }
    }

    private func updateDisplay(note: String, frequency: Float, amplitude: CGFloat) {
        noteLabel.text = note
        frequencyLabel.text = String(format: "Frequency: %.1f Hz", frequency)
        
        // Update wave with new parameters
        updateWave(with: amplitude, frequency: frequency)
    }
}

extension ChordRecognitionViewController: PitchDetectorDelegate {
    func pitchDetectorDidDetect(note: String, frequency: Float, amplitude: CGFloat) {
        // Only update UI if we receive a valid note
        guard note != "—" else {
            noteLabel.text = "—"
            frequencyLabel.text = "Frequency: — Hz"
            statusLabel.text = "No signal"
            return
        }
        
        updateDisplay(note: note, frequency: frequency, amplitude: amplitude)
        statusLabel.text = "Live"
    }
}
