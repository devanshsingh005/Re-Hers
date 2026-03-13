import UIKit

// MARK: - Enums
enum HandType   { case left, right }
enum KeyboardMode { case animation, playAlong }

// MARK: - Piano Key View
final class AnimatedPianoKeyView: UIView {

    enum KeyType { case white, black }

    let keyType:  KeyType
    let midiNote: UInt8
    let noteName: String
    var currentHand: HandType? = nil

    private var isPressed = false
    var isHinted  = false { didSet { updateAppearance() } }
    var onTouchStateChanged: ((UInt8, Bool) -> Void)?

    private let noteLabel = UILabel()

    init(keyType: KeyType, midiNote: UInt8, noteName: String) {
        self.keyType  = keyType
        self.midiNote = midiNote
        self.noteName = noteName
        super.init(frame: .zero)
        setupAppearance()
        setupKeyLabel()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupAppearance() {
        layer.cornerRadius = keyType == .white ? 6 : 4
        clipsToBounds = false
        resetAppearance()
        // 3D depth shadow for keys
        if keyType == .white {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.18
            layer.shadowRadius = 2.5
            layer.shadowOffset = CGSize(width: 0, height: 2)
        } else {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.45
            layer.shadowRadius = 3
            layer.shadowOffset = CGSize(width: 0, height: 3)
        }
    }

    // MARK: - Plain Text Key Label
    private func setupKeyLabel() {
        noteLabel.text = noteName
        noteLabel.font = .systemFont(ofSize: keyType == .white ? 7 : 5.5, weight: .bold)
        noteLabel.textColor = keyType == .white ? UIColor.darkGray : UIColor.lightGray
        noteLabel.textAlignment = .center
        noteLabel.isUserInteractionEnabled = false
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(noteLabel)

        if keyType == .white {
            NSLayoutConstraint.activate([
                noteLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                noteLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22),
            ])
        } else {
            NSLayoutConstraint.activate([
                noteLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                noteLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            ])
        }
    }

    // MARK: - Colours
    // LEFT hand = blue, RIGHT hand = red

    static let leftColor  = UIColor.systemBlue   // blue for left hand
    static let rightColor = UIColor.systemRed     // red for right hand

    func animatePress(hand: HandType? = nil, color overrideColor: UIColor? = nil) {
        let color: UIColor
        if let ovColor = overrideColor {
            color = ovColor
        } else {
            color = hand == .left ? AnimatedPianoKeyView.leftColor : AnimatedPianoKeyView.rightColor
        }
        
        UIView.animate(withDuration: 0.1) {
            self.backgroundColor = color
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.98)
        }
    }

    func animateRelease() {
        UIView.animate(withDuration: 0.2) {
            self.updateAppearance()
            self.transform = .identity
        }
    }

    private func updateAppearance() {
        if isHinted {
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.4)
            layer.borderColor = UIColor.systemBlue.cgColor
            layer.borderWidth = 1.5
        } else {
            resetAppearance()
        }
    }

    func resetAppearance() {
        switch keyType {
        case .white:
            backgroundColor       = UIColor(white: 0.97, alpha: 1)
            layer.borderWidth     = 0.5
            layer.borderColor     = UIColor(white: 0.82, alpha: 1).cgColor
        case .black:
            backgroundColor       = UIColor(white: 0.08, alpha: 1)
            layer.borderWidth     = 0.5
            layer.borderColor     = UIColor(white: 0.22, alpha: 1).cgColor
        }
    }

    // MARK: - Touch
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isPressed else { return }
        isPressed = true
        animatePress(hand: .right)
        onTouchStateChanged?(midiNote, true)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { release() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { release() }

    private func release() {
        guard isPressed else { return }
        isPressed = false
        animateRelease()
        onTouchStateChanged?(midiNote, false)
    }
}

// MARK: - Keyboard View
final class AnimatedPianoKeyboardView: UIView, UIScrollViewDelegate {

    var mode: KeyboardMode = .animation { didSet { updateInteraction() } }
    var onKeyPressed: ((String, Bool) -> Void)?

    private var whiteKeys: [AnimatedPianoKeyView] = []
    private var blackKeys: [AnimatedPianoKeyView] = []
    private let scrollView  = UIScrollView()
    private let contentView = UIView()

    private var whiteKeyW: CGFloat {
        guard !whiteKeys.isEmpty, bounds.width > 0 else { return 38 }
        return bounds.width / CGFloat(whiteKeys.count)
    }
    private var blackKeyW: CGFloat { whiteKeyW * 0.58 }
    private let blackHRatio: CGFloat = 0.62

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildScrollView()
        buildKeys()
        updateInteraction()
        isMultipleTouchEnabled = true
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Scroll View
    private func buildScrollView() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Build keys (A0=21 … C8=108)
    private func buildKeys() {
        let whiteOffsets = Set([0,2,4,5,7,9,11])
        let blackOffsets = Set([1,3,6,8,10])

        for midi in 21...108 {
            let pc = midi % 12
            let name = midiToName(UInt8(midi))
            if whiteOffsets.contains(pc) {
                let k = AnimatedPianoKeyView(keyType: .white, midiNote: UInt8(midi), noteName: name)
                wire(k); whiteKeys.append(k); contentView.addSubview(k)
            } else if blackOffsets.contains(pc) {
                let k = AnimatedPianoKeyView(keyType: .black, midiNote: UInt8(midi), noteName: name)
                wire(k); blackKeys.append(k); contentView.addSubview(k)
            }
        }
    }

    private func wire(_ key: AnimatedPianoKeyView) {
        key.onTouchStateChanged = { [weak self, weak key] midi, pressed in
            guard let self, let key else { return }
            self.onKeyPressed?(key.noteName, pressed)
            guard self.mode == .playAlong else { return }
            if pressed { AudioEngineManager.shared.startNote(midi: midi) }
            else       { AudioEngineManager.shared.stopNote(midi: midi) }
        }
    }

    private func updateInteraction() {
        let enabled = mode == .playAlong
        (whiteKeys + blackKeys).forEach { $0.isUserInteractionEnabled = enabled }
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        let totalW = whiteKeyW * CGFloat(whiteKeys.count)
        contentView.frame        = CGRect(x: 0, y: 0, width: totalW, height: bounds.height)
        scrollView.contentSize   = CGSize(width: totalW, height: bounds.height)

        // White keys — fill full height (extended +20 to hide bottom corner radius)
        for (i, key) in whiteKeys.enumerated() {
            key.frame = CGRect(x: CGFloat(i) * whiteKeyW, y: 0,
                               width: whiteKeyW - 0.5, height: bounds.height + 20)
        }

        // Black keys — centred on the boundary between white keys
        let blackH = bounds.height * blackHRatio
        for black in blackKeys {
            if let idx = whiteIndexBeforeBlack(black.midiNote) {
                let wx = CGFloat(idx) * whiteKeyW
                black.frame = CGRect(x: wx + whiteKeyW - blackKeyW/2, y: 0,
                                     width: blackKeyW, height: blackH)
                contentView.bringSubviewToFront(black)
            }
        }
    }

    // MARK: - Public API

    /// Highlight keys — left=blue, right=cyan-blue (all look blue as in Image 2)
    func playChord(leftHand: [String], rightHand: [String]) {
        resetAllKeys()
        for n in leftHand  { findKey(n)?.animatePress(color: AnimatedPianoKeyView.leftColor) }
        for n in rightHand { findKey(n)?.animatePress(color: AnimatedPianoKeyView.rightColor) }
    }

    func showHints(for notes: [String]) {
        (whiteKeys + blackKeys).forEach { k in
            k.isHinted = notes.contains(k.noteName) || notes.contains(normalise(k.noteName))
        }
    }

    func resetAllKeys() {
        (whiteKeys + blackKeys).forEach { 
            $0.isHinted = false
            $0.animateRelease() 
        }
    }

    func scrollToNote(_ name: String) {
        guard let key = findKey(name) else { return }
        let mid     = key.frame.midX
        let target  = mid - scrollView.bounds.width / 2
        let maxOff  = scrollView.contentSize.width - scrollView.bounds.width
        UIView.animate(withDuration: 0.3) {
            self.scrollView.contentOffset = CGPoint(x: max(0, min(target, maxOff)), y: 0)
        }
    }

    /// Snap instantly to centre on a note — call after layout for initial position
    func centerOn(note: String) {
        layoutIfNeeded()
        guard let key = findKey(note) else { return }
        let mid    = key.frame.midX
        let target = mid - scrollView.bounds.width / 2
        let maxOff = scrollView.contentSize.width - scrollView.bounds.width
        scrollView.setContentOffset(CGPoint(x: max(0, min(target, maxOff)), y: 0), animated: false)
    }

    func findKey(_ name: String) -> AnimatedPianoKeyView? {
        // normalise: "F#4" and "Gb4" both should match correctly
        let norm = normalise(name)
        return (whiteKeys + blackKeys).first { normalise($0.noteName) == norm }
    }

    // MARK: - Helpers
    private func normalise(_ n: String) -> String {
        // Convert flat to sharp enharmonic equivalent for comparison
        let flatMap: [String:String] = ["Db":"C#","Eb":"D#","Gb":"F#","Ab":"G#","Bb":"A#"]
        var s = n
        for (flat, sharp) in flatMap where s.hasPrefix(flat) {
            s = sharp + s.dropFirst(flat.count); break
        }
        return s
    }

    private func midiToName(_ midi: UInt8) -> String {
        let n = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        return "\(n[Int(midi)%12])\(Int(midi)/12-1)"
    }

    private func whiteIndexBeforeBlack(_ midi: UInt8) -> Int? {
        let whitePC = [0,2,4,5,7,9,11]
        var idx = 0
        for m in 21..<Int(midi) {
            if whitePC.contains(m % 12) { idx += 1 }
        }
        return idx < whiteKeys.count ? idx : nil
    }
}

// MARK: - Chord Display View (kept for play-along mode)
final class RealTimeChordDisplayView: UIView {
    private let label: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 24, weight: .bold)
        l.textColor = .label; l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.cornerRadius = 14; clipsToBounds = true
        
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        addSubview(label)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        label.text = "🎹 Ready"
    }
    required init?(coder: NSCoder) { fatalError() }

    func setSingleChord(_ text: String) {
        UIView.transition(with: label, duration: 0.2, options: .transitionCrossDissolve) {
            self.label.text = text
        }
    }
}
