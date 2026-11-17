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
    var currentHand: HandType? = nil { didSet { updateAppearance() } }

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
        layer.cornerRadius = keyType == .white ? 4 : 3
        layer.masksToBounds = false
        
        // Premium Shadow (Deeper for black keys)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2.5)
        layer.shadowRadius = keyType == .white ? 2 : 4
        layer.shadowOpacity = keyType == .white ? 0.12 : 0.5
        
        resetAppearance()
    }

    private func setupKeyLabel() {
        noteLabel.text          = noteName
        noteLabel.numberOfLines = keyType == .white ? 2 : 1   // black keys: 1 line only
        noteLabel.textAlignment = .center
        noteLabel.isUserInteractionEnabled = false
        noteLabel.translatesAutoresizingMaskIntoConstraints = false

        if keyType == .white {
            noteLabel.font      = .systemFont(ofSize: 7, weight: .bold)
            noteLabel.textColor = UIColor.darkGray
        } else {
            // Smaller, single-line label so it fits inside the narrow black key
            noteLabel.font      = .systemFont(ofSize: 4.0, weight: .semibold)
            noteLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        }

        addSubview(noteLabel)

        let bottom = noteLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: keyType == .white ? -22 : -6)
        labelBottom = bottom
        NSLayoutConstraint.activate([
            noteLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            bottom,
        ])
    }

    private var labelBottom: NSLayoutConstraint?

    /// Note names sized to the key: tiny on a phone's 88-key strip, readable on iPad's wide keys.
    func sizeLabel(forWhiteKeyWidth w: CGFloat) {
        if keyType == .white {
            noteLabel.font = .systemFont(ofSize: min(15, max(7, (w * 0.3).rounded())), weight: .bold)
            labelBottom?.constant = w >= 30 ? -max(22, (w * 0.5).rounded()) : -22
        } else {
            noteLabel.font = .systemFont(ofSize: min(11, max(4, (w * 0.2).rounded())), weight: .semibold)
            labelBottom?.constant = w >= 30 ? -10 : -6
        }
    }

    // MARK: - Colours
    // LEFT hand = blue, RIGHT hand = red
    static let leftColor  = UIColor.systemBlue    // blue for left hand
    static let rightColor = UIColor.systemRed      // red for right hand

    func animatePress(hand: HandType? = nil, color overrideColor: UIColor? = nil) {
        let color: UIColor
        if let ovColor = overrideColor {
            color = ovColor
        } else {
            color = hand == .left ? AnimatedPianoKeyView.leftColor : AnimatedPianoKeyView.rightColor
        }
        
        UIView.animate(withDuration: 0.08, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            self.backgroundColor = color
            // Add a "Luminous" glow on press
            self.layer.shadowColor = color.cgColor
            self.layer.shadowOpacity = 0.6
            self.layer.shadowRadius = 8
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.97)
        }
    }

    func animateRelease() {
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseIn, .allowUserInteraction]) {
            self.updateAppearance()
            self.layer.shadowColor = UIColor.black.cgColor
            self.layer.shadowOpacity = self.keyType == .white ? 0.12 : 0.5
            self.layer.shadowRadius = self.keyType == .white ? 2 : 4
            self.transform = .identity
        }
    }

    private func updateAppearance() {
        if isHinted {
            let hintColor: UIColor
            switch currentHand {
            case .left:
                hintColor = AnimatedPianoKeyView.leftColor
            case .right:
                hintColor = AnimatedPianoKeyView.rightColor
            case nil:
                hintColor = BrandColors.brand
            }

            backgroundColor = hintColor.withAlphaComponent(0.25)
            layer.borderColor = hintColor.withAlphaComponent(0.5).cgColor
            layer.borderWidth = 1.5
            
            layer.shadowColor = hintColor.cgColor
            layer.shadowOpacity = 0.3
            layer.shadowRadius = 4
        } else {
            resetAppearance()
        }
    }

    func resetAppearance() {
        layer.borderWidth = 0.5
        switch keyType {
        case .white:
            // Ivory base instead of pure flat gray
            backgroundColor = ComponentColors.HomeScreen.background
            layer.borderColor = UIColor(white: 0.88, alpha: 1).cgColor
        case .black:
            // Obsidian base
            backgroundColor = UIColor(white: 0.05, alpha: 1)
            layer.borderColor = UIColor(white: 0.2, alpha: 1).cgColor
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
    private var keysByMidi: [Int: AnimatedPianoKeyView] = [:]
    private let scrollView  = UIScrollView()
    private let contentView = UIView()

    private let hands = GhostHandsView()
    private var lastLayoutSize = CGSize.zero

    /// As many white keys as the player chose fit the width (all 52 = all 88 keys); with fewer,
    /// the keyboard scrolls.
    private var whiteKeyW: CGFloat {
        guard !whiteKeys.isEmpty, bounds.width > 0 else { return 38 }
        return bounds.width / CGFloat(min(KeyboardSize.visibleWhiteKeys, whiteKeys.count))
    }
    private var blackKeyW: CGFloat { whiteKeyW * 0.58 }
    private let blackHRatio: CGFloat = 0.62

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildScrollView()
        buildKeys()
        buildHands()
        updateInteraction()
        isMultipleTouchEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(visibleKeysChanged),
                                               name: KeyboardSize.didChangeNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    /// The ⋯ menu changed how many keys are on screen: the keys widen or narrow around the
    /// middle of what is shown, then the notes in play are brought into view.
    @objc private func visibleKeysChanged() {
        let oldWidth = scrollView.contentSize.width
        let middle = oldWidth > 0 ? (scrollView.contentOffset.x + scrollView.bounds.width / 2) / oldWidth : 0.5
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            self.setNeedsLayout()
            self.layoutIfNeeded()
            self.scrollTo(middle * self.scrollView.contentSize.width - self.scrollView.bounds.width / 2)
        } completion: { _ in
            self.reveal(self.inPlay, newest: self.inPlay)
        }
        updateInteraction()
    }

    // MARK: - Scroll View
    private func buildScrollView() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.isScrollEnabled = false   // all 88 keys fit the width
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        // laid out by hand in layoutSubviews (with Auto Layout and no constraints its frame
        // collapsed to zero: the keys still drew, but no touch could reach them)
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
        keysByMidi[Int(key.midiNote)] = key
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
        // Animation's keys can't be played, so with fewer keys on screen they can be dragged
        // sideways; Play Along's keys answer at a touch, and the keyboard follows the hints.
        scrollView.isScrollEnabled = mode == .animation && !KeyboardSize.showsAllKeys
    }

    private func buildHands() {
        // the hands sit in a corner of the visible keyboard, so they don't scroll with the keys
        addSubview(hands)
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

        let labelWidth = whiteKeyW
        (whiteKeys + blackKeys).forEach { $0.sizeLabel(forWhiteKeyWidth: labelWidth) }

        hands.frame = bounds
        bringSubviewToFront(hands)
        let layoutKey = CGSize(width: bounds.width, height: whiteKeyW)
        if layoutKey != lastLayoutSize {
            lastLayoutSize = layoutKey
            hands.keyWidth = whiteKeyW
            scrollTo(scrollView.contentOffset.x)   // stay within the (new) keyboard width
        }
    }

    // MARK: - Following the notes (fewer keys on screen)

    /// Keys down in Animation, or to play in Play Along.
    private var inPlay: Set<Int> = []
    /// Keys pressed since the last follow (one chord or step).
    private var justPressed: Set<Int> = []
    private var followScheduled = false

    private func scrollTo(_ x: CGFloat) {
        let maxX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        scrollView.contentOffset = CGPoint(x: max(0, min(maxX, x)).rounded(), y: 0)
    }

    /// Notes pressed together are followed once, after the last of them.
    private func scheduleFollow() {
        guard !followScheduled else { return }
        followScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.followScheduled = false
            self.reveal(self.inPlay, newest: self.justPressed)
            self.justPressed = []
        }
    }

    /// Scrolls so `midis` are on screen, if they aren't: centred on them all, or, when they
    /// don't fit, on the newest ones (the right hand's, the melody, when those don't fit either).
    private func reveal(_ midis: Set<Int>, newest: Set<Int>) {
        let width = scrollView.bounds.width
        guard scrollView.contentSize.width > width + 1, width > 0 else { return }
        func span(_ set: Set<Int>) -> (min: CGFloat, max: CGFloat)? {
            let frames = set.compactMap { keysByMidi[$0]?.frame }
            guard let lo = frames.map(\.minX).min(), let hi = frames.map(\.maxX).max() else { return nil }
            return (lo, hi)
        }
        let margin = whiteKeyW * 0.5
        let fits: ((min: CGFloat, max: CGFloat)) -> Bool = { $0.max - $0.min + 2 * margin <= width }
        var candidates = [midis, newest]
        if let top = newest.max() { candidates.append([top]) }
        guard let target = candidates.lazy.compactMap(span).first(where: fits) ?? span(newest) ?? span(midis)
        else { return }
        let shown = scrollView.contentOffset.x
        if target.min >= shown + margin, target.max <= shown + width - margin { return }
        let x = (target.min + target.max) / 2 - width / 2
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            self.scrollTo(x)
        }
    }

    // MARK: - Ghost hands

    /// Fingers the performance for the ghost hands (Animation).
    func setHandPerformance(_ notes: [HandNote]) {
        hands.setPerformance(notes)
    }

    /// Poses the ghost hands for second `time` of the performance.
    func showHands(at time: Double) {
        hands.show(time: time)
    }


    // MARK: - Public API

    /// Holds a key down in its hand's colour (left blue, right red) until `release`.
    func press(midi: Int, isLeft: Bool) {
        key(midi: midi)?.animatePress(color: isLeft ? AnimatedPianoKeyView.leftColor : AnimatedPianoKeyView.rightColor)
        inPlay.insert(midi)
        justPressed.insert(midi)
        scheduleFollow()
    }

    func release(midi: Int) {
        key(midi: midi)?.animateRelease()
        inPlay.remove(midi)
    }

    private func key(midi: Int) -> AnimatedPianoKeyView? {
        guard (21...108).contains(midi) else { return nil }
        return keysByMidi[midi]
    }

    /// Play Along: the keys to play, in their hand's colour (others cleared).
    func hint(left: [Int], right: [Int]) {
        let l = Set(left), r = Set(right)
        inPlay = l.union(r)
        if !inPlay.isEmpty {
            // the right hand's keys count as the newest: they are kept in view first
            justPressed = r.isEmpty ? l : r
            scheduleFollow()
        }
        for (midi, key) in keysByMidi {
            if l.contains(midi) {
                key.currentHand = .left; key.isHinted = true
            } else if r.contains(midi) {
                key.currentHand = .right; key.isHinted = true
            } else if key.isHinted {
                key.currentHand = nil; key.isHinted = false
            }
        }
    }

    /// Play Along: a key flashes (green right, red wrong) and goes back to its hint.
    func flash(midi: Int, color: UIColor) {
        guard let key = key(midi: midi) else { return }
        key.animatePress(color: color)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak key] in key?.animateRelease() }
    }

    func resetAllKeys() {
        inPlay = []
        (whiteKeys + blackKeys).forEach { 
            $0.currentHand = nil
            $0.isHinted = false
            $0.animateRelease() 
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
        // White keys: plain name (C, D, E…). Black keys: sharp name only (C#, D#…) — no flat enharmonic.
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

// MARK: - Keyboard size

/// How many keys the player wants on screen in Animation and Play Along (both use the same
/// setting): from all 88 down to two octaves. Fewer keys are wider; the keyboard scrolls to
/// keep the notes being played (or to play) in view. Its height doesn't change.
enum KeyboardSize {
    static let didChangeNotification = Notification.Name("KeyboardSizeDidChange")
    /// White keys across the screen, and how many keys (white and black) that shows.
    static let options: [(white: Int, keys: Int)] = [(15, 25), (22, 37), (29, 49), (36, 61), (45, 76), (52, 88)]
    private static let key = "keyboardVisibleKeys"

    private static var index: Int {
        let saved = UserDefaults.standard.object(forKey: key) as? Int ?? 88
        return options.firstIndex { $0.keys == saved } ?? options.count - 1
    }

    static var visibleWhiteKeys: Int { options[index].white }
    static var keyCount: Int { options[index].keys }
    static var showsAllKeys: Bool { index == options.count - 1 }
    static var canShowMore: Bool { index < options.count - 1 }
    static var canShowFewer: Bool { index > 0 }
    /// e.g. "61 keys"
    static var label: String { "\(keyCount) keys" }

    /// More keys on screen (+1) or fewer (-1); posts `didChangeNotification` if it changed.
    static func step(_ delta: Int) {
        let next = max(0, min(options.count - 1, index + delta))
        guard next != index else { return }
        UserDefaults.standard.set(options[next].keys, forKey: key)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}
