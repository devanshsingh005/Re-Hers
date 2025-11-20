
//
//  PianoViews.swift
//  Re-Hearse
//

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
            backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
            layer.borderWidth = 0.5
            layer.borderColor = UIColor(white: 0.8, alpha: 1.0).cgColor
        case .black:
            backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        }
    }
    
    func animatePress(hand: HandType) {
        UIView.animate(withDuration: 0.15, delay: 0, options: [.allowUserInteraction]) {
            switch self.keyType {
            case .white:
                self.backgroundColor = hand == .left ?
                    UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0) :
                    UIColor(red: 1.0, green: 0.95, blue: 0.95, alpha: 1.0)
            case .black:
                self.backgroundColor = hand == .left ?
                    UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0) :
                    UIColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
            }
        }
        // slight scale pop
        UIView.animate(withDuration: 0.12, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: []) {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }
    }
    
    func animateRelease() {
        UIView.animate(withDuration: 0.25, delay: 0, options: [.allowUserInteraction]) {
            switch self.keyType {
            case .white:
                self.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
            case .black:
                self.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
            }
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
        // 52 white keys (7 notes per octave * ~7) - simplified mapping
        for i in 0..<52 {
            let noteName = noteNameForWhiteKey(index: i)
            let key = AnimatedPianoKeyView(keyType: .white, noteName: noteName)
            whiteKeys.append(key)
            addSubview(key)
        }
        // 36 black keys (approx)
        for i in 0..<36 {
            let noteName = noteNameForBlackKey(index: i)
            let key = AnimatedPianoKeyView(keyType: .black, noteName: noteName)
            blackKeys.append(key)
            addSubview(key)
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }
    
    private func noteNameForWhiteKey(index: Int) -> String {
        let notes = ["C", "D", "E", "F", "G", "A", "B"]
        let octave = (index / 7) + 2
        let noteIndex = index % 7
        return "\(notes[noteIndex])\(octave)"
    }
    
    private func noteNameForBlackKey(index: Int) -> String {
        let baseNotes = ["C", "D", "F", "G", "A"]
        let octave = (index / 5) + 2
        let noteIndex = index % 5
        let note = baseNotes[noteIndex]
        return "\(note)#\(octave)"
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let loc = gesture.location(in: self)
        // black keys first (they sit above)
        for key in blackKeys where key.frame.contains(loc) {
            animateKeyPress(key, at: loc)
            return
        }
        for key in whiteKeys where key.frame.contains(loc) {
            animateKeyPress(key, at: loc)
            return
        }
    }
    
    private func animateKeyPress(_ key: AnimatedPianoKeyView, at location: CGPoint) {
        let hand: HandType = location.y < bounds.midY ? .right : .left
        key.animatePress(hand: hand)
        onKeyPressed?(key.noteName, true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            key.animateRelease()
            self.onKeyPressed?(key.noteName, false)
        }
    }
    
    func playChord(_ chord: SongChord) {
        // animate left
        for note in chord.leftHandNotes {
            whiteKeys.first { $0.noteName == note }?.animatePress(hand: .left)
            blackKeys.first { $0.noteName == note }?.animatePress(hand: .left)
        }
        // animate right
        for note in chord.rightHandNotes {
            whiteKeys.first { $0.noteName == note }?.animatePress(hand: .right)
            blackKeys.first { $0.noteName == note }?.animatePress(hand: .right)
        }
        // release after ~70% duration
        DispatchQueue.main.asyncAfter(deadline: .now() + chord.duration * 0.7) {
            self.resetAllKeys()
        }
    }
    
    func resetAllKeys() {
        whiteKeys.forEach { $0.animateRelease() }
        blackKeys.forEach { $0.animateRelease() }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let totalWhite = CGFloat(whiteKeys.count)
        let whiteKeyWidth = bounds.width / totalWhite
        let whiteKeyHeight = bounds.height
        
        for (i, key) in whiteKeys.enumerated() {
            key.frame = CGRect(x: CGFloat(i) * whiteKeyWidth, y: 0, width: whiteKeyWidth, height: whiteKeyHeight)
        }
        
        let blackWidth = whiteKeyWidth * 0.65
        let blackHeight = bounds.height * 0.65
        var blackIndex = 0
        for (whiteIndex, whiteKey) in whiteKeys.enumerated() {
            let noteName = whiteKey.noteName
            // skip black key after E and B
            if !noteName.contains("E") && !noteName.contains("B") && blackIndex < blackKeys.count {
                let blackKey = blackKeys[blackIndex]
                blackKey.frame = CGRect(
                    x: whiteKey.frame.midX - blackWidth/2,
                    y: 0,
                    width: blackWidth,
                    height: blackHeight
                )
                bringSubviewToFront(blackKey)
                blackIndex += 1
            }
        }
    }
}

////////////////////////////////////////////////////////
// RealTimeChordDisplayView
////////////////////////////////////////////////////////
class RealTimeChordDisplayView: UIView {
    private let scrollView = UIScrollView()
    private let stackView: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 25
        s.alignment = .center
        return s
    }()
    private var chordLabels: [UILabel] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        addChord("🎹 Tap keys or watch the demo! 🎹")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupView() {
        backgroundColor = UIColor(white: 0.05, alpha: 0.95)
        layer.cornerRadius = 16
        layer.masksToBounds = true
        
        addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }
    
    func addChord(_ chord: String) {
        let label = UILabel()
        label.text = chord
        label.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.sizeToFit()
        label.frame = label.frame.insetBy(dx: -20, dy: -8)
        
        label.alpha = 0
        label.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        
        stackView.addArrangedSubview(label)
        chordLabels.append(label)
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: []) {
            label.alpha = 1
            label.transform = .identity
        }
        
        DispatchQueue.main.async {
            let offsetX = max(0, self.stackView.frame.width - self.scrollView.bounds.width + 20)
            self.scrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: true)
        }
        
        if chordLabels.count > 8 {
            let first = chordLabels.removeFirst()
            UIView.animate(withDuration: 0.3, animations: {
                first.alpha = 0
                first.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            }) { _ in
                first.removeFromSuperview()
            }
        }
    }
    func setSingleChord(_ chord: String) {
        // Remove old labels
        chordLabels.forEach { $0.removeFromSuperview() }
        chordLabels.removeAll()

        // Create new label
        let label = UILabel()
        label.text = chord
        label.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor(white: 1.0, alpha: 0.12)
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false

        // Fade animation
        label.alpha = 0
        stackView.addArrangedSubview(label)
        chordLabels.append(label)

        UIView.animate(withDuration: 0.25) {
            label.alpha = 1
        }
    }

    
    func clearChords() {
        chordLabels.forEach { $0.removeFromSuperview() }
        chordLabels.removeAll()
        addChord("🎹 Piano Ready! 🎹")
    }
}
