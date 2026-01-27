import UIKit
import AVFoundation

final class PianoAnimationViewController: UIViewController {

    private let pianoKeyboard = AnimatedPianoKeyboardView()
    private let chordDisplayView = RealTimeChordDisplayView()
    private let chordDetector = ChordDetector()
    private let demoManager = PianoDemoManager()

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

    // Scheduling
    private var nextWorkItem: DispatchWorkItem?
    private var scheduledStopWorkItems: [DispatchWorkItem] = []
    private var currentlyPlayingMIDINotes: Set<UInt8> = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupNavBar()
        setupConstraints()
        setupActions()

        AudioEngineManager.shared.startEngine(loadSoundFont: "Wurlitzer210.sf2")
        startDemoSong()
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
    }

    private func setupNavBar() {
        navBar.isBackButtonVisible = true
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
        chordDisplayView.setSingleChord("🎵 Demo Started")
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
            chordDisplayView.setSingleChord("Demo Complete")
            isPlayingDemo = false
            stopAllPlayingNotes()
            updatePlayPauseUI()
            return
        }

        // 🎹 VISUAL
        pianoKeyboard.playChord(
            leftHand: chord.leftHandNotes,
            rightHand: chord.rightHandNotes
        )

        // 🔊 AUDIO
        let allNotes = chord.leftHandNotes + chord.rightHandNotes
        for note in allNotes {
            if let midi = AudioEngineManager.shared.midiNumber(from: note) {
                AudioEngineManager.shared.startNote(midi: midi)
                currentlyPlayingMIDINotes.insert(midi)
            }
        }

        let stopWork = DispatchWorkItem { [weak self] in
            allNotes.forEach {
                if let midi = AudioEngineManager.shared.midiNumber(from: $0) {
                    AudioEngineManager.shared.stopNote(midi: midi)
                    self?.currentlyPlayingMIDINotes.remove(midi)
                }
            }
        }

        scheduledStopWorkItems.append(stopWork)
        DispatchQueue.main.asyncAfter(deadline: .now() + chord.duration, execute: stopWork)

        chordDisplayView.setSingleChord("🎹 \(chord.chordName)")
        scheduleNextDemoChord(after: chord.duration)
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
