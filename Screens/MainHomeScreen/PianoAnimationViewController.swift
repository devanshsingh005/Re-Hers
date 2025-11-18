import UIKit
import AVFoundation

struct SongChord {
    let leftHandNotes: [String]
    let rightHandNotes: [String]
    let chordName: String
    let duration: TimeInterval
}

enum HandType {
    case left, right
}

class AnimatedPianoKeyView: UIView {
    enum KeyType {
        case white, black
    }
    
    let keyType: KeyType
    let noteName: String
    
    init(keyType: KeyType, noteName: String) {
        self.keyType = keyType
        self.noteName = noteName
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        switch keyType {
        case .white:
            backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
            layer.borderWidth = 0.5
            layer.borderColor = UIColor(white: 0.8, alpha: 1.0).cgColor
        case .black:
            backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        }
        layer.cornerRadius = 4
    }
    
    func animatePress(hand: HandType) {
        UIView.animate(withDuration: 0.15) {
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
    }
    
    func animateRelease() {
        UIView.animate(withDuration: 0.2) {
            switch self.keyType {
            case .white:
                self.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
            case .black:
                self.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
            }
        }
    }
}

class AnimatedPianoKeyboardView: UIView {
    private var whiteKeys: [AnimatedPianoKeyView] = []
    private var blackKeys: [AnimatedPianoKeyView] = []
    
    var onKeyPressed: ((String, Bool) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupKeyboard()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupKeyboard() {
        for i in 0..<52 {
            let noteName = noteNameForWhiteKey(index: i)
            let key = AnimatedPianoKeyView(keyType: .white, noteName: noteName)
            whiteKeys.append(key)
            addSubview(key)
        }
        
        for i in 0..<36 {
            let noteName = noteNameForBlackKey(index: i)
            let key = AnimatedPianoKeyView(keyType: .black, noteName: noteName)
            blackKeys.append(key)
            addSubview(key)
        }
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapRecognizer)
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
        let location = gesture.location(in: self)
        
        for key in blackKeys where key.frame.contains(location) {
            animateKeyPress(key, at: location)
            return
        }
        
        for key in whiteKeys where key.frame.contains(location) {
            animateKeyPress(key, at: location)
            return
        }
    }
    
    private func animateKeyPress(_ key: AnimatedPianoKeyView, at location: CGPoint) {
        let hand: HandType = location.y < bounds.midY ? .right : .left
        key.animatePress(hand: hand)
        self.onKeyPressed?(key.noteName, true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            key.animateRelease()
            self.onKeyPressed?(key.noteName, false)
        }
    }
    
    func playChord(_ chord: SongChord) {
        for noteName in chord.leftHandNotes {
            whiteKeys.first { $0.noteName == noteName }?.animatePress(hand: .left)
            blackKeys.first { $0.noteName == noteName }?.animatePress(hand: .left)
        }
        
        for noteName in chord.rightHandNotes {
            whiteKeys.first { $0.noteName == noteName }?.animatePress(hand: .right)
            blackKeys.first { $0.noteName == noteName }?.animatePress(hand: .right)
        }
        
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
        let totalWhiteKeys = CGFloat(whiteKeys.count)
        let whiteKeyWidth = bounds.width / totalWhiteKeys
        let whiteKeyHeight = bounds.height
        
        for (index, key) in whiteKeys.enumerated() {
            key.frame = CGRect(
                x: CGFloat(index) * whiteKeyWidth,
                y: 0,
                width: whiteKeyWidth,
                height: whiteKeyHeight
            )
        }
        
        let blackKeyWidth = whiteKeyWidth * 0.65
        let blackKeyHeight = bounds.height * 0.65
        
        var blackKeyIndex = 0
        for (whiteIndex, whiteKey) in whiteKeys.enumerated() {
            let noteName = whiteKey.noteName
            if !noteName.contains("E") && !noteName.contains("B") && blackKeyIndex < blackKeys.count {
                let blackKey = blackKeys[blackKeyIndex]
                blackKey.frame = CGRect(
                    x: whiteKey.frame.midX - blackKeyWidth / 2,
                    y: 0,
                    width: blackKeyWidth,
                    height: blackKeyHeight
                )
                bringSubviewToFront(blackKey)
                blackKeyIndex += 1
            }
        }
    }
}

class RealTimeChordDisplayView: UIView {
    private let scrollView = UIScrollView()
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 25
        stack.alignment = .center
        return stack
    }()
    
    private var chordLabels: [UILabel] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
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
        
        addChord("🎹 Tap keys or watch the demo! 🎹")
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
        label.textAlignment = .center
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
            let firstLabel = chordLabels.removeFirst()
            UIView.animate(withDuration: 0.3, animations: {
                firstLabel.alpha = 0
                firstLabel.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            }) { _ in
                firstLabel.removeFromSuperview()
            }
        }
    }
    
    func clearChords() {
        chordLabels.forEach { $0.removeFromSuperview() }
        chordLabels.removeAll()
        addChord("🎹 Piano Ready! 🎹")
    }
}

class PianoAnimationViewController: UIViewController {
    private let pianoKeyboard = AnimatedPianoKeyboardView()
    private let chordDisplayView = RealTimeChordDisplayView()
    private var activeNotes: Set<String> = []
    private let chordDetector = ChordDetector()
    private var isPlayingDemo = false
    private var demoChords: [SongChord] = []
    private var currentDemoIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupUI()
        setupConstraints()
        setupActions()
        setupDemoSong()
        startDemoSong()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupTabBar()
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeRight
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    // MARK: - Navigation & Tab Bar Setup
    private func setupNavigationBar() {
        title = "Piano Player"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = UIColor(red: 0.96, green: 0.71, blue: 0.34, alpha: 1.0)
    }
    
    private func setupTabBar() {
        if let tabBarController = self.tabBarController as? MainTabBarController {
            // Tab bar is already configured by MainTabBarController
            tabBarController.tabBar.isHidden = false
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(white: 0.05, alpha: 1.0).cgColor,
            UIColor(white: 0.1, alpha: 1.0).cgColor
        ]
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        view.addSubview(chordDisplayView)
        view.addSubview(pianoKeyboard)
        
        pianoKeyboard.translatesAutoresizingMaskIntoConstraints = false
        chordDisplayView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            chordDisplayView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
            chordDisplayView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),
            chordDisplayView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 8),
            chordDisplayView.heightAnchor.constraint(equalToConstant: 80),
            
            pianoKeyboard.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            pianoKeyboard.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            pianoKeyboard.topAnchor.constraint(equalTo: chordDisplayView.bottomAnchor, constant: 8),
            pianoKeyboard.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
        ])
    }
    
    private func setupActions() {
        pianoKeyboard.onKeyPressed = { [weak self] noteName, isPressed in
            self?.handleKeyPress(noteName: noteName, isPressed: isPressed)
        }
    }
    
    private func setupDemoSong() {
        // JSON format for Für Elise by Beethoven
        let furEliseChordsJSON = """
        {
            "song": "Für Elise",
            "composer": "Ludwig van Beethoven",
            "chords": [
                {
                    "leftHandNotes": ["E2", "B2"],
                    "rightHandNotes": ["E5", "D#5"],
                    "chordName": "E Minor",
                    "duration": 1.0
                },
                {
                    "leftHandNotes": ["E2", "B2"],
                    "rightHandNotes": ["E5", "D#5"],
                    "chordName": "E Minor",
                    "duration": 1.0
                },
                {
                    "leftHandNotes": ["E2", "A2"],
                    "rightHandNotes": ["E5", "C5"],
                    "chordName": "A Minor",
                    "duration": 1.0
                },
                {
                    "leftHandNotes": ["A2", "E3"],
                    "rightHandNotes": ["A4", "C5"],
                    "chordName": "A Minor",
                    "duration": 1.0
                },
                {
                    "leftHandNotes": ["E2", "G#2"],
                    "rightHandNotes": ["B4", "D5"],
                    "chordName": "E Major",
                    "duration": 1.0
                },
                {
                    "leftHandNotes": ["E2", "B2"],
                    "rightHandNotes": ["C5", "E5"],
                    "chordName": "C Major",
                    "duration": 1.0
                },
                {
                    "leftHandNotes": ["E2", "B2"],
                    "rightHandNotes": ["A4", "E5"],
                    "chordName": "A Minor",
                    "duration": 1.0
                },
                {
                    "leftHandNotes": ["E2", "B2"],
                    "rightHandNotes": ["B4", "E5"],
                    "chordName": "E Major",
                    "duration": 1.0
                }
            ]
        }
        """
        
        demoChords = [
            SongChord(leftHandNotes: ["E2", "B2"], rightHandNotes: ["E5", "D#5"], chordName: "E Minor", duration: 1.0),
            SongChord(leftHandNotes: ["E2", "B2"], rightHandNotes: ["E5", "D#5"], chordName: "E Minor", duration: 1.0),
            SongChord(leftHandNotes: ["E2", "A2"], rightHandNotes: ["E5", "C5"], chordName: "A Minor", duration: 1.0),
            SongChord(leftHandNotes: ["A2", "E3"], rightHandNotes: ["A4", "C5"], chordName: "A Minor", duration: 1.0),
            SongChord(leftHandNotes: ["E2", "G#2"], rightHandNotes: ["B4", "D5"], chordName: "E Major", duration: 1.0),
            SongChord(leftHandNotes: ["E2", "B2"], rightHandNotes: ["C5", "E5"], chordName: "C Major", duration: 1.0),
            SongChord(leftHandNotes: ["E2", "B2"], rightHandNotes: ["A4", "E5"], chordName: "A Minor", duration: 1.0),
            SongChord(leftHandNotes: ["E2", "B2"], rightHandNotes: ["B4", "E5"], chordName: "E Major", duration: 1.0)
        ]
    }
    
    private func startDemoSong() {
        isPlayingDemo = true
        currentDemoIndex = 0
        chordDisplayView.clearChords()
        chordDisplayView.addChord("🎵 Für Elise Demo Started! 🎵")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.playNextDemoChord()
        }
    }
    
    private func playNextDemoChord() {
        guard isPlayingDemo, currentDemoIndex < demoChords.count else {
            chordDisplayView.addChord("🎉 Demo Complete! 🎉")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.chordDisplayView.addChord("🔄 Restarting...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.startDemoSong()
                }
            }
            return
        }
        
        let chord = demoChords[currentDemoIndex]
        pianoKeyboard.playChord(chord)
        
        for note in chord.leftHandNotes + chord.rightHandNotes {
            playNoteSound(note)
        }
        
        let displayText = "🎹 \(chord.chordName) • 🟦 Left + 🟥 Right"
        chordDisplayView.addChord(displayText)
        
        currentDemoIndex += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + chord.duration) { [weak self] in
            self?.playNextDemoChord()
        }
    }
    
    private func handleKeyPress(noteName: String, isPressed: Bool) {
        if isPressed {
            activeNotes.insert(noteName)
            playNoteSound(noteName)
        } else {
            activeNotes.remove(noteName)
        }
        
        updateChordDisplay()
    }
    
    private func updateChordDisplay() {
        let chord = chordDetector.detectChord(from: Array(activeNotes))
        if chord != "Unknown" && chord != "Play a chord!" {
            chordDisplayView.addChord("🎹 \(chord)")
        }
    }
    
    private func playNoteSound(_ noteName: String) {
        AudioServicesPlaySystemSound(1104)
    }
}

class ChordDetector {
    private let chordPatterns: [String: [String]] = [
        "C": ["C4", "E4", "G4"], "Cm": ["C4", "D#4", "G4"],
        "G": ["G4", "B4", "D5"], "Gm": ["G4", "A#4", "D5"],
        "D": ["D4", "F#4", "A4"], "Dm": ["D4", "F4", "A4"],
        "A": ["A4", "C#5", "E5"], "Am": ["A4", "C5", "E5"],
        "E": ["E4", "G#4", "B4"], "Em": ["E4", "G4", "B4"],
        "F": ["F4", "A4", "C5"], "Fm": ["F4", "G#4", "C5"]
    ]
    
    func detectChord(from notes: [String]) -> String {
        guard notes.count >= 3 else { return notes.isEmpty ? "Play a chord!" : "Unknown" }
        
        for (chordName, chordNotes) in chordPatterns {
            if Set(notes).isSuperset(of: Set(chordNotes)) {
                return chordName
            }
        }
        
        return "Unknown"
    }
}
