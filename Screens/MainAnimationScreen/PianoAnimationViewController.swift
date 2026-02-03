import UIKit
import AVFoundation

final class PianoAnimationViewController: UIViewController {

    private let pianoKeyboard = AnimatedPianoKeyboardView()
    private let chordDisplayView = RealTimeChordDisplayView()
    private let chordDetector = ChordDetector()
    private var demoManager = PianoDemoManager()
    
    /// External JSON data to load (from URL)
    var sheetMusicData: Data?

    private var activeNotes: Set<String> = []
    private var isPlayingDemo = false

    // Nav + safe-area bg
    private let navBar = TopNavBar.make(title: "Animation")
    private let safeAreaBG: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // Play / Pause control
    private let playPauseButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .white
        config.image = UIImage(systemName: "pause.fill")
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        b.configuration = config
        b.backgroundColor = UIColor(white: 0.06, alpha: 0.9)
        b.layer.cornerRadius = 20
        return b
    }()

    // MARK: - Tempo UI
    private let tempoContainer = UIView()
    private let tempoLabel = UILabel()
    private let tempoSlider = UISlider()
    
    private var tempoMultiplier: Float = 1.0 {
        didSet {
            tempoLabel.text = String(format: "Tempo %.2fx", tempoMultiplier)
        }
    }

    // Scheduling
    private var nextWorkItem: DispatchWorkItem?
    private var scheduledStopWorkItems: [DispatchWorkItem] = []
    private var currentlyPlayingMIDINotes: Set<UInt8> = []

    // MARK: - Orientation Support
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeRight
    }
    
    override var shouldAutorotate: Bool {
        return true
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupNavBar()
        setupConstraints()
        setupActions()
        
        // If external data is provided, use it
        if let data = sheetMusicData {
            demoManager = PianoDemoManager(withData: data)
        }

        AudioEngineManager.shared.startEngine(loadSoundFont: "Wurlitzer210.sf2")
        startDemoSong()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Force landscape orientation
        let value = UIInterfaceOrientation.landscapeRight.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Reset to portrait when leaving
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pianoKeyboard.layoutIfNeeded()
    }

    deinit {
        stopAllPlayingNotes()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .white
        navigationController?.navigationBar.isHidden = true

        view.addSubview(safeAreaBG)
        view.addSubview(navBar)
        view.addSubview(chordDisplayView)
        view.addSubview(pianoKeyboard)
        view.addSubview(playPauseButton)

        navBar.translatesAutoresizingMaskIntoConstraints = false
        chordDisplayView.translatesAutoresizingMaskIntoConstraints = false
        pianoKeyboard.translatesAutoresizingMaskIntoConstraints = false
        
        setupTempoUI()
    }
    
    // MARK: - Tempo UI Setup
    private func setupTempoUI() {
        tempoContainer.translatesAutoresizingMaskIntoConstraints = false
        chordDisplayView.addSubview(tempoContainer)

        NSLayoutConstraint.activate([
            tempoContainer.trailingAnchor.constraint(equalTo: chordDisplayView.trailingAnchor, constant: -60),
            tempoContainer.centerYAnchor.constraint(equalTo: chordDisplayView.centerYAnchor),
            tempoContainer.widthAnchor.constraint(equalToConstant: 160),
            tempoContainer.heightAnchor.constraint(equalToConstant: 80)
        ])

        tempoLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        tempoLabel.textColor = .white
        tempoLabel.textAlignment = .right
        tempoLabel.text = "Tempo 1.00x"
        tempoLabel.translatesAutoresizingMaskIntoConstraints = false

        tempoSlider.minimumValue = 0.5
        tempoSlider.maximumValue = 1.5
        tempoSlider.value = 1.0
        tempoSlider.minimumTrackTintColor = .systemBlue
        tempoSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        tempoSlider.addTarget(self, action: #selector(tempoChanged(_:)), for: .valueChanged)
        tempoSlider.translatesAutoresizingMaskIntoConstraints = false

        tempoContainer.addSubview(tempoLabel)
        tempoContainer.addSubview(tempoSlider)

        NSLayoutConstraint.activate([
            tempoLabel.topAnchor.constraint(equalTo: tempoContainer.topAnchor),
            tempoLabel.trailingAnchor.constraint(equalTo: tempoContainer.trailingAnchor),

            tempoSlider.topAnchor.constraint(equalTo: tempoLabel.bottomAnchor, constant: 4),
            tempoSlider.leadingAnchor.constraint(equalTo: tempoContainer.leadingAnchor),
            tempoSlider.trailingAnchor.constraint(equalTo: tempoContainer.trailingAnchor),
            tempoSlider.bottomAnchor.constraint(equalTo: tempoContainer.bottomAnchor)
        ])
    }
    
    // MARK: - Tempo Action
    @objc private func tempoChanged(_ sender: UISlider) {
        tempoMultiplier = sender.value
    }

    private func setupNavBar() {
        navBar.isBackButtonVisible = true
        navBar.isWelcomeTextHidden = true
        navBar.isStreakVisible = false
        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: safe.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            chordDisplayView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 10),
            chordDisplayView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            chordDisplayView.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            chordDisplayView.heightAnchor.constraint(equalToConstant: 80),

            pianoKeyboard.topAnchor.constraint(equalTo: chordDisplayView.bottomAnchor, constant: 8),
            pianoKeyboard.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            pianoKeyboard.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            pianoKeyboard.bottomAnchor.constraint(equalTo: safe.bottomAnchor),

            playPauseButton.centerYAnchor.constraint(equalTo: chordDisplayView.centerYAnchor),
            playPauseButton.trailingAnchor.constraint(equalTo: chordDisplayView.trailingAnchor, constant: -10),
            playPauseButton.widthAnchor.constraint(equalToConstant: 40),
            playPauseButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func setupActions() {
        playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)

        pianoKeyboard.onKeyPressed = { [weak self] note, pressed in
            self?.handleKeyPress(noteName: note, isPressed: pressed)
        }
    }

    // MARK: - Demo Control
    private func startDemoSong() {
        demoManager.loadSong()
        isPlayingDemo = true
        chordDisplayView.setSingleChord("🎵 Start")
        scheduleNextDemoChord(after: 0)
        updatePlayPauseUI()
    }

    private func pauseDemoSong() {
        isPlayingDemo = false
        nextWorkItem?.cancel()
        scheduledStopWorkItems.forEach { $0.cancel() }
        scheduledStopWorkItems.removeAll()
        stopAllPlayingNotes()
        updatePlayPauseUI()
    }

    private func resumeDemoSong() {
        isPlayingDemo = true
        scheduleNextDemoChord(after: 0)
        updatePlayPauseUI()
    }

    private func scheduleNextDemoChord(after delay: TimeInterval) {
        nextWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.playNextDemoChord()
        }
        nextWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func playNextDemoChord() {
        guard isPlayingDemo, let chord = demoManager.next() else {
            chordDisplayView.setSingleChord("Completed")
            isPlayingDemo = false
            stopAllPlayingNotes()
            updatePlayPauseUI()
            return
        }

        // 🎹 VISUAL ANIMATIONS
        animateChordWithHandColors(chord: chord)
        
        // Auto-scroll to the lowest note (usually bass/left hand)
        if let lowestNote = findLowestNote(chord) {
            scrollToNote(lowestNote)
        }

        // 🔊 AUDIO
        let allNotes = chord.leftHandNotes + chord.rightHandNotes
        for note in allNotes {
            if let midi = AudioEngineManager.shared.midiNumber(from: note) {
                AudioEngineManager.shared.startNote(midi: midi)
                currentlyPlayingMIDINotes.insert(midi)
            }
        }

        // Apply tempo multiplier to duration (lower multiplier = slower = longer duration)
        let adjustedDuration = chord.duration / Double(tempoMultiplier)
        
        let stopWork = DispatchWorkItem { [weak self] in
            allNotes.forEach {
                if let midi = AudioEngineManager.shared.midiNumber(from: $0) {
                    AudioEngineManager.shared.stopNote(midi: midi)
                    self?.currentlyPlayingMIDINotes.remove(midi)
                }
            }
        }

        scheduledStopWorkItems.append(stopWork)
        DispatchQueue.main.asyncAfter(deadline: .now() + adjustedDuration, execute: stopWork)

        chordDisplayView.setSingleChord("🎹 \(chord.chordName)")
        scheduleNextDemoChord(after: adjustedDuration)
    }

    // MARK: - Hand-Specific Animations
    private func animateChordWithHandColors(chord: SongChord) {
        // Reset all keys first
        pianoKeyboard.resetAllKeys()
        
        // Animate left hand notes with red color
        for note in chord.leftHandNotes {
            if let key = pianoKeyboard.findKey(named: note) {
                animateKeyWithHandColor(key: key, hand: .left)
            }
        }
        
        // Animate right hand notes with green color
        for note in chord.rightHandNotes {
            if let key = pianoKeyboard.findKey(named: note) {
                animateKeyWithHandColor(key: key, hand: .right)
            }
        }
    }
    
    private func animateKeyWithHandColor(key: AnimatedPianoKeyView, hand: HandType) {
        // Save original color
        let originalColor = key.backgroundColor
        
        // Set hand-specific color
        let handColor: UIColor
        switch hand {
        case .left:
            handColor = UIColor.red.withAlphaComponent(0.7)
        case .right:
            handColor = UIColor.green.withAlphaComponent(0.7)
        }
        
        // Animation
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseInOut]) {
            key.backgroundColor = handColor
            key.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            // Return to original color after a slight delay
            UIView.animate(withDuration: 0.1, delay: 0.1, options: [.curveEaseOut]) {
                key.backgroundColor = originalColor
                key.transform = .identity
            }
        }
    }
    
    // MARK: - Auto-Scrolling
    private func findLowestNote(_ chord: SongChord) -> String? {
        let allNotes = chord.leftHandNotes + chord.rightHandNotes
        
        // Helper to extract octave number from note string (e.g., "C4" -> 4)
        func octaveFromNote(_ note: String) -> Int {
            if let lastChar = note.last, let octave = Int(String(lastChar)) {
                return octave
            }
            return 4 // Default if can't parse
        }
        
        // Helper to get base note position (A=0, B=1, etc.)
        func baseNoteValue(_ note: String) -> Int {
            let baseNote = String(note.prefix(1)).uppercased()
            let noteValues: [String: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
            return noteValues[baseNote] ?? 0
        }
        
        // Find the note with lowest octave, then lowest pitch
        return allNotes.min(by: { note1, note2 in
            let octave1 = octaveFromNote(note1)
            let octave2 = octaveFromNote(note2)
            
            if octave1 != octave2 {
                return octave1 < octave2
            }
            
            return baseNoteValue(note1) < baseNoteValue(note2)
        })
    }
    
    private func scrollToNote(_ noteName: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pianoKeyboard.scrollToNote(noteName)
        }
    }

    // MARK: - Play / Pause
    @objc private func togglePlayPause() {
        if demoManager.isFinished {
            startDemoSong()
        } else if isPlayingDemo {
            pauseDemoSong()
        } else {
            resumeDemoSong()
        }
    }

    private func updatePlayPauseUI() {
        let icon = isPlayingDemo ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: icon), for: .normal)
    }

    // MARK: - Live Play
    private func handleKeyPress(noteName: String, isPressed: Bool) {
        if isPressed {
            activeNotes.insert(noteName)
            if let midi = AudioEngineManager.shared.midiNumber(from: noteName) {
                AudioEngineManager.shared.startNote(midi: midi)
            }
        } else {
            activeNotes.remove(noteName)
            if let midi = AudioEngineManager.shared.midiNumber(from: noteName) {
                AudioEngineManager.shared.stopNote(midi: midi)
            }
        }
    }

    private func stopAllPlayingNotes() {
        for midi in currentlyPlayingMIDINotes {
            AudioEngineManager.shared.stopNote(midi: midi)
        }
        currentlyPlayingMIDINotes.removeAll()
    }
}

