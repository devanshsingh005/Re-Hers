import UIKit
import AVFoundation

final class PianoAnimationViewController: UIViewController {

    // MARK: - Keyboard
    private let pianoKeyboard = AnimatedPianoKeyboardView()

    // MARK: - State
    private var activeNotes: Set<String> = []

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
        setupActions()

        // Start audio engine (only if you want sound on tap)
        AudioEngineManager.shared.startEngine(loadSoundFont: "Wurlitzer210.sf2")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pianoKeyboard.layoutIfNeeded()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .clear
        navigationController?.navigationBar.isHidden = true

        view.addSubview(pianoKeyboard)
        pianoKeyboard.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            pianoKeyboard.topAnchor.constraint(equalTo: view.topAnchor),
            pianoKeyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pianoKeyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pianoKeyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Keyboard Events
    private func setupActions() {
        pianoKeyboard.onKeyPressed = { [weak self] note, pressed in
            self?.handleKeyPress(noteName: note, isPressed: pressed)
        }
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
}
