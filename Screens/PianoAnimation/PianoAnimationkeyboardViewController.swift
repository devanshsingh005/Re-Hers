import UIKit

final class PianoAnimationkeyboardViewController: UIViewController {

    // MARK: - Views
    private let pianoKeyboard = AnimatedPianoKeyboardView()
    private let leftLabel     = UILabel()
    private let rightLabel    = UILabel()

    // MARK: - State
    private var pendingNoteOff: DispatchWorkItem?
    private var lastLeadNote: String?
    private var hasAudioPlaybackSession = false

    // MARK: - Orientation
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    override var shouldAutorotate: Bool { true }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        buildKeyboard()
        buildLabels()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !hasAudioPlaybackSession else { return }
        AudioEngineManager.shared.acquirePlaybackSession()
        hasAudioPlaybackSession = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        releaseAudioPlaybackSession()
    }

    deinit {
        pendingNoteOff?.cancel()
        pendingNoteOff = nil
        AudioEngineManager.shared.stopAllNotes()
        releaseAudioPlaybackSession()
    }

    private func releaseAudioPlaybackSession() {
        guard hasAudioPlaybackSession else { return }
        AudioEngineManager.shared.stopAllNotes()
        AudioEngineManager.shared.releasePlaybackSession()
        hasAudioPlaybackSession = false
    }

    // MARK: - Keyboard
    private func buildKeyboard() {
        // Liquid glass background for 3D depth
        let glassBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        glassBlur.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(glassBlur)

        // Gradient shimmer overlay
        let shimmer = UIView()
        shimmer.translatesAutoresizingMaskIntoConstraints = false
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.white.withAlphaComponent(0.15).cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.06).cgColor
        ]
        gradient.locations = [0, 0.4, 1.0]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        shimmer.layer.addSublayer(gradient)
        glassBlur.contentView.addSubview(shimmer)

        // Top highlight edge (glass shine)
        let topEdge = UIView()
        topEdge.backgroundColor = UIColor.white.withAlphaComponent(0.55)
        topEdge.translatesAutoresizingMaskIntoConstraints = false
        glassBlur.contentView.addSubview(topEdge)

        NSLayoutConstraint.activate([
            glassBlur.topAnchor.constraint(equalTo: view.topAnchor),
            glassBlur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            glassBlur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            glassBlur.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            shimmer.topAnchor.constraint(equalTo: glassBlur.topAnchor),
            shimmer.leadingAnchor.constraint(equalTo: glassBlur.leadingAnchor),
            shimmer.trailingAnchor.constraint(equalTo: glassBlur.trailingAnchor),
            shimmer.bottomAnchor.constraint(equalTo: glassBlur.bottomAnchor),

            topEdge.topAnchor.constraint(equalTo: glassBlur.topAnchor),
            topEdge.leadingAnchor.constraint(equalTo: glassBlur.leadingAnchor),
            topEdge.trailingAnchor.constraint(equalTo: glassBlur.trailingAnchor),
            topEdge.heightAnchor.constraint(equalToConstant: 1)
        ])

        // Size the gradient layer after layout
        DispatchQueue.main.async {
            gradient.frame = shimmer.bounds
        }

        pianoKeyboard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pianoKeyboard)
        NSLayoutConstraint.activate([
            pianoKeyboard.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
            pianoKeyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pianoKeyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pianoKeyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        pianoKeyboard.onKeyPressed = { [weak self] note, pressed in
            guard self != nil else { return }
            if let m = AudioEngineManager.shared.midiNumber(from: note) {
                pressed ? AudioEngineManager.shared.startNote(midi: m)
                        : AudioEngineManager.shared.stopNote(midi: m)
            }
        }
    }

    // MARK: - L / R Labels
    private func buildLabels() {
        configureLabel(leftLabel,  text: "L", color: BrandColors.brand)
        configureLabel(rightLabel, text: "R", color: .systemRed)

        [leftLabel, rightLabel].forEach { $0.alpha = 0; view.addSubview($0) }

        leftLabel.translatesAutoresizingMaskIntoConstraints  = false
        rightLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            leftLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            leftLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            leftLabel.widthAnchor.constraint(equalToConstant: 20),
            leftLabel.heightAnchor.constraint(equalToConstant: 16),

            rightLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            rightLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            rightLabel.widthAnchor.constraint(equalToConstant: 20),
            rightLabel.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    private func configureLabel(_ l: UILabel, text: String, color: UIColor) {
        l.text            = text
        l.font            = .systemFont(ofSize: 10, weight: .bold)
        l.textColor       = color
        l.textAlignment   = .center
        l.backgroundColor = color.withAlphaComponent(0.12)
        l.layer.cornerRadius = 4
        l.clipsToBounds   = true
    }

    // MARK: - Mode
    func setAnimationMode() { pianoKeyboard.mode = .animation }

    // MARK: - Center keyboard on C4 (middle C)
    func centerOnMiddleC() {
        pianoKeyboard.centerOn(note: "C4")
    }

    // MARK: - Play Chord
    func playChord(left: [String], right: [String], duration: Double) {
        // ✅ FIX 1: Stop the pending note-off timer AND flush active notes immediately.
        // Old code cancelled the work item silently, leaving previous notes ringing.
        if let pending = pendingNoteOff {
            pending.cancel()
            pendingNoteOff = nil
        }
        // Stop whatever is currently sounding before starting the new chord
        AudioEngineManager.shared.stopAllNotes()

        // Highlight keys
        pianoKeyboard.playChord(leftHand: left, rightHand: right)

        let all = (left + right).filter { !$0.isEmpty }
        guard !all.isEmpty else { return }

        // ✅ FIX 2: Small pre-attack gap so the audio engine fully releases
        // previous resonance before the new chord sounds. Avoids muddy chord blending.
        let attackDelay = 0.015
        DispatchQueue.main.asyncAfter(deadline: .now() + attackDelay) {
            for n in all {
                if let m = AudioEngineManager.shared.midiNumber(from: n) {
                    AudioEngineManager.shared.startNote(midi: m)
                }
            }
        }

        // Show hand labels
        UIView.animate(withDuration: 0.10) {
            self.leftLabel.alpha  = left.isEmpty  ? 0 : 1
            self.rightLabel.alpha = right.isEmpty ? 0 : 1
        }

        // ✅ FIX 3: Note-off timing — use 85% of duration for crisp articulation.
        // For very short notes (< 0.15s) use 80% so fast runs don't blur together.
        let noteFraction: Double = duration < 0.15 ? 0.80 : 0.85
        let stopAt = max(0.05, duration * noteFraction)

        let work = DispatchWorkItem { [weak self] in
            AudioEngineManager.shared.stopAllNotes()
            self?.pendingNoteOff = nil
        }
        pendingNoteOff = work
        DispatchQueue.main.asyncAfter(deadline: .now() + attackDelay + stopAt, execute: work)
    }

    // MARK: - Reset
    func resetKeyboard() {
        pendingNoteOff?.cancel(); pendingNoteOff = nil
        AudioEngineManager.shared.stopAllNotes()
        pianoKeyboard.resetAllKeys()
        lastLeadNote = nil
        UIView.animate(withDuration: 0.2) {
            self.leftLabel.alpha  = 0
            self.rightLabel.alpha = 0
        }
    }
}
