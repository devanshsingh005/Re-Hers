import UIKit

// MARK: - Enums

enum HandType { case left, right }

enum KeyboardMode {
    case animation
    case playAlong
}

// MARK: - Piano Key View

final class AnimatedPianoKeyView: UIView {

    enum KeyType { case white, black }

    let keyType: KeyType
    let midiNote: UInt8
    let noteName: String

    private var isPressed = false
    var onTouchStateChanged: ((UInt8, Bool) -> Void)?

    init(keyType: KeyType, midiNote: UInt8, noteName: String) {
        self.keyType = keyType
        self.midiNote = midiNote
        self.noteName = noteName
        super.init(frame: .zero)
        setupView()
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupView() {
        layer.cornerRadius = 4

        switch keyType {
        case .white:
            backgroundColor = UIColor(white: 0.98, alpha: 1)
            layer.borderWidth = 0.5
            layer.borderColor = UIColor(white: 0.8, alpha: 1).cgColor
        case .black:
            backgroundColor = UIColor(white: 0.1, alpha: 1)
        }
    }

    // MARK: - Animations

    func animatePress(hand: HandType? = nil) {
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            self.alpha = 0.7
        }
    }

    func animateRelease() {
        UIView.animate(withDuration: 0.15) {
            self.transform = .identity
            self.alpha = 1.0
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isPressed else { return }
        isPressed = true
        animatePress()
        onTouchStateChanged?(midiNote, true)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        release()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        release()
    }

    private func release() {
        guard isPressed else { return }
        isPressed = false
        animateRelease()
        onTouchStateChanged?(midiNote, false)
    }
}

// MARK: - Keyboard View

final class AnimatedPianoKeyboardView: UIView {

    var mode: KeyboardMode = .animation {
        didSet { updateInteractionMode() }
    }

    private var whiteKeys: [AnimatedPianoKeyView] = []
    private var blackKeys: [AnimatedPianoKeyView] = []

    var onKeyPressed: ((String, Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupKeyboard()
        updateInteractionMode()
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - Keyboard Setup (A0 → C8)

    private func setupKeyboard() {
        let whiteMIDIs = generateWhiteKeys()
        let blackMIDIs = generateBlackKeys()

        for midi in whiteMIDIs {
            let key = AnimatedPianoKeyView(
                keyType: .white,
                midiNote: midi,
                noteName: midiToName(midi)
            )
            configureKey(key)
            whiteKeys.append(key)
            addSubview(key)
        }

        for midi in blackMIDIs {
            let key = AnimatedPianoKeyView(
                keyType: .black,
                midiNote: midi,
                noteName: midiToName(midi)
            )
            configureKey(key)
            blackKeys.append(key)
            addSubview(key)
        }
    }

    private func configureKey(_ key: AnimatedPianoKeyView) {
        key.onTouchStateChanged = { [weak self] midi, pressed in
            guard let self else { return }

            self.onKeyPressed?(key.noteName, pressed)

            guard self.mode == .playAlong else { return }

            if pressed {
                AudioEngineManager.shared.startNote(midi: midi)
            } else {
                AudioEngineManager.shared.stopNote(midi: midi)
            }
        }
    }

    private func updateInteractionMode() {
        let enabled = (mode == .playAlong)
        (whiteKeys + blackKeys).forEach { $0.isUserInteractionEnabled = enabled }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        let whiteWidth = bounds.width / CGFloat(whiteKeys.count)

        for (i, key) in whiteKeys.enumerated() {
            key.frame = CGRect(
                x: CGFloat(i) * whiteWidth,
                y: 0,
                width: whiteWidth,
                height: bounds.height
            )
        }

        let blackWidth = whiteWidth * 0.65
        let blackHeight = bounds.height * 0.65

        for black in blackKeys {
            if let index = indexForBlackKey(black.midiNote) {
                let whiteKey = whiteKeys[index]
                black.frame = CGRect(
                    x: whiteKey.frame.maxX - blackWidth / 2,
                    y: 0,
                    width: blackWidth,
                    height: blackHeight
                )
                bringSubviewToFront(black)
            }
        }
    }

    // MARK: - Public API (USED BY CONTROLLER)

    /// ✅ FINAL API used by PianoAnimationViewController
    func playChord(leftHand: [String], rightHand: [String]) {
        resetAllKeys()

        for note in leftHand {
            findKey(named: note)?.animatePress(hand: .left)
        }

        for note in rightHand {
            findKey(named: note)?.animatePress(hand: .right)
        }
    }

    // MARK: - Helpers

    func resetAllKeys() {
        whiteKeys.forEach { $0.animateRelease() }
        blackKeys.forEach { $0.animateRelease() }
    }

    private func findKey(named name: String) -> AnimatedPianoKeyView? {
        (whiteKeys + blackKeys).first { $0.noteName == name }
    }

    // MARK: - MIDI Helpers

    private func generateWhiteKeys() -> [UInt8] {
        let whiteOffsets = [0, 2, 4, 5, 7, 9, 11]
        return (21...108).compactMap {
            whiteOffsets.contains(Int($0 % 12)) ? UInt8($0) : nil
        }
    }

    private func generateBlackKeys() -> [UInt8] {
        let blackOffsets = [1, 3, 6, 8, 10]
        return (21...108).compactMap {
            blackOffsets.contains(Int($0 % 12)) ? UInt8($0) : nil
        }
    }

    private func indexForBlackKey(_ midi: UInt8) -> Int? {
        let whiteOffsets = [0, 2, 4, 5, 7, 9, 11]
        var count = 0

        for m in 21..<Int(midi) {
            if whiteOffsets.contains(m % 12) {
                count += 1
            }
        }
        return count
    }

    private func midiToName(_ midi: UInt8) -> String {
        let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let note = names[Int(midi) % 12]
        let octave = Int(midi) / 12 - 1
        return "\(note)\(octave)"
    }
}

// MARK: - Chord Display View

final class RealTimeChordDisplayView: UIView {

    private let label: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 26, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor(white: 0.06, alpha: 0.95)
        layer.cornerRadius = 16
        clipsToBounds = true

        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        label.text = "🎹 Ready"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func setSingleChord(_ text: String) {
        UIView.transition(with: label, duration: 0.2, options: .transitionCrossDissolve) {
            self.label.text = text
        }
    }
}




