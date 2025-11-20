import UIKit

// MARK: - Hand Type
enum HandType { case left, right }

////////////////////////////////////////////////////////
// AnimatedPianoKeyView
////////////////////////////////////////////////////////

class AnimatedPianoKeyView: UIView {
    enum KeyType { case white, black }
    let keyType: KeyType
    let noteName: String
    
    init(keyType: KeyType, noteName: String) {
        self.keyType = keyType
        self.noteName = noteName
        super.init(frame: .zero)
        setupView()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
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
    
    func animatePress(hand: HandType) {
        UIView.animate(withDuration: 0.12) {
            if self.keyType == .white {
                self.backgroundColor = hand == .left
                ? UIColor(red: 0.9, green: 0.95, blue: 1, alpha: 1)
                : UIColor(red: 1, green: 0.93, blue: 0.93, alpha: 1)
            } else {
                self.backgroundColor = hand == .left
                ? UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)
                : UIColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1)
            }
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }
    }
    
    func animateRelease() {
        UIView.animate(withDuration: 0.25) {
            self.backgroundColor = self.keyType == .white
                ? UIColor(white: 0.98, alpha: 1)
                : UIColor(white: 0.1, alpha: 1)
            self.transform = .identity
        }
    }
}

////////////////////////////////////////////////////////
// AnimatedPianoKeyboardView
////////////////////////////////////////////////////////

class AnimatedPianoKeyboardView: UIView {

    private var whiteKeys: [AnimatedPianoKeyView] = []
    private var blackKeys: [AnimatedPianoKeyView] = []

    var onKeyPressed: ((String, Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupKeyboard()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupKeyboard() {

        // white keys
        for i in 0..<52 {
            let note = whiteKeyName(i)
            let key = AnimatedPianoKeyView(keyType: .white, noteName: note)
            whiteKeys.append(key)
            addSubview(key)
        }

        // black keys
        for i in 0..<36 {
            let note = blackKeyName(i)
            let key = AnimatedPianoKeyView(keyType: .black, noteName: note)
            blackKeys.append(key)
            addSubview(key)
        }

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
    }

    private func whiteKeyName(_ i: Int) -> String {
        let notes = ["C","D","E","F","G","A","B"]
        return "\(notes[i % 7])\(2 + i / 7)"
    }

    private func blackKeyName(_ i: Int) -> String {
        let notes = ["C","D","F","G","A"]
        return "\(notes[i % 5])#\(2 + i / 5)"
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        let point = g.location(in: self)

        for key in blackKeys where key.frame.contains(point) {
            animateKeyPress(key, point)
            return
        }
        for key in whiteKeys where key.frame.contains(point) {
            animateKeyPress(key, point)
            return
        }
    }

    private func animateKeyPress(_ key: AnimatedPianoKeyView, _ loc: CGPoint) {
        let hand: HandType = loc.y < bounds.midY ? .right : .left

        key.animatePress(hand: hand)
        onKeyPressed?(key.noteName, true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            key.animateRelease()
            self.onKeyPressed?(key.noteName, false)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let whiteW = bounds.width / CGFloat(whiteKeys.count)
        for (i, key) in whiteKeys.enumerated() {
            key.frame = CGRect(x: CGFloat(i)*whiteW, y: 0, width: whiteW, height: bounds.height)
        }

        let blackW = whiteW * 0.65
        let blackH = bounds.height * 0.65

        var idx = 0
        for (i, wKey) in whiteKeys.enumerated() {
            let note = wKey.noteName
            if !note.contains("E") && !note.contains("B"), idx < blackKeys.count {
                let b = blackKeys[idx]
                b.frame = CGRect(
                    x: wKey.frame.midX - blackW/2,
                    y: 0,
                    width: blackW,
                    height: blackH
                )
                bringSubviewToFront(b)
                idx += 1
            }
        }
    }

    func playChord(_ chord: SongChord) {
        for n in chord.leftHandNotes {
            whiteKeys.first(where: { $0.noteName == n })?.animatePress(hand: .left)
            blackKeys.first(where: { $0.noteName == n })?.animatePress(hand: .left)
        }

        for n in chord.rightHandNotes {
            whiteKeys.first(where: { $0.noteName == n })?.animatePress(hand: .right)
            blackKeys.first(where: { $0.noteName == n })?.animatePress(hand: .right)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + chord.duration * 0.7) {
            self.resetAllKeys()
        }
    }

    func resetAllKeys() {
        whiteKeys.forEach { $0.animateRelease() }
        blackKeys.forEach { $0.animateRelease() }
    }
}

////////////////////////////////////////////////////////
// Single-Chord Display
////////////////////////////////////////////////////////

class RealTimeChordDisplayView: UIView {

    private let label: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 26, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setSingleChord("🎹 Ready!")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        backgroundColor = UIColor(white: 0.06, alpha: 0.95)
        layer.cornerRadius = 16
        clipsToBounds = true

        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    // MARK: — REPLACES old addChord()
    func setSingleChord(_ text: String) {
        UIView.transition(with: label, duration: 0.25, options: .transitionCrossDissolve) {
            self.label.text = text
        }
    }
}
