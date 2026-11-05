import UIKit

final class PianoAnimationkeyboardViewController: UIViewController {

    // MARK: - Views
    private let pianoKeyboard = AnimatedPianoKeyboardView()
    private let leftLabel     = UILabel()
    private let rightLabel    = UILabel()

    // MARK: - State
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

    // MARK: - Notes
    //
    // Animation turns notes on and off one by one, each for as long as it sounds. A key held by
    // two voices at once stays down until both let go.

    private var heldCounts: [Int: Int] = [:]          // midi → notes holding the key
    private var heldLeft = 0
    private var heldRight = 0

    /// Presses the key in its hand's colour and, unless `sound` is false (after a seek or on
    /// resume), plays it at `velocity` (from the score's dynamics).
    func noteOn(midi: Int, isLeft: Bool, velocity: Int, sound: Bool) {
        heldCounts[midi, default: 0] += 1
        if isLeft { heldLeft += 1 } else { heldRight += 1 }
        if sound, let m = UInt8(exactly: midi) {
            AudioEngineManager.shared.startNote(midi: m, velocity: UInt8(max(1, min(127, velocity))))
        }
        pianoKeyboard.press(midi: midi, isLeft: isLeft)
        updateHandLabels()
    }

    func noteOff(midi: Int, isLeft: Bool) {
        guard let count = heldCounts[midi] else { return }
        if isLeft { heldLeft = max(0, heldLeft - 1) } else { heldRight = max(0, heldRight - 1) }
        if count > 1 {
            heldCounts[midi] = count - 1
        } else {
            heldCounts[midi] = nil
            if let m = UInt8(exactly: midi) { AudioEngineManager.shared.stopNote(midi: m) }
            pianoKeyboard.release(midi: midi)
        }
        updateHandLabels()
    }

    private func updateHandLabels() {
        let showLeft = heldLeft > 0, showRight = heldRight > 0
        guard (leftLabel.alpha > 0) != showLeft || (rightLabel.alpha > 0) != showRight else { return }
        UIView.animate(withDuration: 0.10) {
            self.leftLabel.alpha  = showLeft ? 1 : 0
            self.rightLabel.alpha = showRight ? 1 : 0
        }
    }

    // MARK: - Ghost hands

    /// Fingers the performance for the ghost hands.
    func setHandPerformance(_ notes: [HandNote]) {
        pianoKeyboard.setHandPerformance(notes)
    }

    /// Poses the ghost hands for second `time` of the performance (at 1× tempo).
    func showHands(at time: Double) {
        pianoKeyboard.showHands(at: time)
    }

    // MARK: - Reset
    func resetKeyboard() {
        heldCounts = [:]
        heldLeft = 0
        heldRight = 0
        AudioEngineManager.shared.stopAllNotes()
        pianoKeyboard.resetAllKeys()
        UIView.animate(withDuration: 0.2) {
            self.leftLabel.alpha  = 0
            self.rightLabel.alpha = 0
        }
    }
}
