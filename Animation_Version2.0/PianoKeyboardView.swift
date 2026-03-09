import UIKit

final class PianoKeyboardView: UIView {

    // MARK: - Public API

    var onKeyTap: ((String) -> Void)?

    func highlightKeys(_ notes: [String]) {
        resetHighlights()
        for note in notes {
            keyViews[note]?.highlight()
        }
    }

    func resetHighlights() {
        keyViews.values.forEach { $0.reset() }
    }

    // MARK: - Private

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private var keyViews: [String: KeyView] = [:]

    // MIDI range A0 (21) → C8 (108)
    private let midiRange = Array(21...108)

    private let blackKeyWidthRatio: CGFloat = 0.6
    private let blackKeyHeightRatio: CGFloat = 0.6

    // How many white keys visible at once
    private let visibleWhiteKeys: CGFloat = 35

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupScroll()
        createKeys()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func setupScroll() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.bounces = true
        
        scrollView.alwaysBounceVertical = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.decelerationRate = .fast

        addSubview(scrollView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        scrollView.addSubview(contentView)
    }

    // MARK: - Create Keys

    private func createKeys() {

        keyViews.values.forEach { $0.removeFromSuperview() }
        keyViews.removeAll()

        for midi in midiRange {
            let noteName = midiToName(UInt8(midi))
            let isBlack = isBlackKey(midi)

            let key = KeyView(note: noteName, type: isBlack ? .black : .white)
            contentView.addSubview(key)
            keyViews[noteName] = key

            key.tapHandler = { [weak self] note in
                self?.onKeyTap?(note)
            }
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        layoutKeys()
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero

    }

    private func layoutKeys() {

        let height = bounds.height

        // Calculate width so ~35 white keys visible
        let whiteKeyWidth = bounds.width / visibleWhiteKeys
        let blackKeyWidth = whiteKeyWidth * blackKeyWidthRatio
        let blackKeyHeight = height * blackKeyHeightRatio

        var whiteIndex: CGFloat = 0

        for midi in midiRange {

            let noteName = midiToName(UInt8(midi))
            guard let key = keyViews[noteName] else { continue }

            if isBlackKey(midi) {
                let x = (whiteIndex * whiteKeyWidth) - (blackKeyWidth / 2)
                key.frame = CGRect(x: x, y: 0, width: blackKeyWidth, height: blackKeyHeight)
                contentView.bringSubviewToFront(key)
            } else {
                let x = whiteIndex * whiteKeyWidth
                key.frame = CGRect(x: x, y: 0, width: whiteKeyWidth, height: height)
                whiteIndex += 1
            }
        }

        
        contentView.frame.origin.x = 0

        contentView.frame = CGRect(
            x: 0,
            y: 0,
            width: whiteIndex * whiteKeyWidth,
            height: height
        )

        scrollView.contentSize = contentView.frame.size
    }

    // MARK: - Helpers

    private func isBlackKey(_ midi: Int) -> Bool {
        let blackOffsets = [1, 3, 6, 8, 10]
        return blackOffsets.contains(midi % 12)
    }

    private func midiToName(_ midi: UInt8) -> String {
        let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let note = names[Int(midi) % 12]
        let octave = Int(midi) / 12 - 1
        return "\(note)\(octave)"
    }
}
private final class KeyView: UIView {

    enum KeyType { case white, black }

    private let type: KeyType
    private let note: String

    var tapHandler: ((String) -> Void)?

    private let highlightLayer = CALayer()

    init(note: String, type: KeyType) {
        self.note = note
        self.type = type
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        layer.cornerRadius = type == .white ? 6 : 4
        clipsToBounds = true

        switch type {
        case .white:
            backgroundColor = UIColor(white: 0.98, alpha: 1)
            layer.borderWidth = 0.5
            layer.borderColor = UIColor(white: 0.85, alpha: 1).cgColor
        case .black:
            backgroundColor = UIColor(white: 0.1, alpha: 1)
        }

        highlightLayer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.25).cgColor
        highlightLayer.frame = bounds
        highlightLayer.opacity = 0
        layer.addSublayer(highlightLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        highlightLayer.frame = bounds
    }

    func highlight() {
        highlightLayer.opacity = 1

        UIView.animate(withDuration: 0.12) {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }
    }

    func reset() {
        highlightLayer.opacity = 0

        UIView.animate(withDuration: 0.12) {
            self.transform = .identity
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        highlight()
        tapHandler?(note)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        reset()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        reset()
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.x < 0 {
            scrollView.contentOffset.x = 0
        }
    }

}
