import UIKit

final class PlayAlongViewController: UIViewController {

    // MARK: - Components
    private let pianoKeyboard = AnimatedPianoKeyboardView()
    private let sheetMusic    = SheetMusicView()
    private let navBar        = PlayAlongNavBar()
    private let reportView    = PlayAlongReportView()

    // MARK: - Logic
    private let engine = PlayAlongEngine()
    private let pitchDetector = PitchDetector()

    private let kPianoH: CGFloat = 136
    private let kNavH:   CGFloat = 54
    private var navBarTopConstraint: NSLayoutConstraint?

    // MARK: - Initializer
    init() {
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.hidesBottomBarWhenPushed = true
    }
    
    deinit {
        print("🧹 Cleaning up PlayAlong session")
        pitchDetector.stopListening()
        AudioEngineManager.shared.stopAllNotes()
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = .all
        setupUI()
        wireCallbacks()
        
        engine.delegate = self
        pitchDetector.delegate = self
        
        pianoKeyboard.mode = .playAlong
        AudioEngineManager.shared.startEngine()
        
        loadSheetData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure no safe-area gap remains from portrait transition
        additionalSafeAreaInsets = .zero
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Auto-simulation disabled to allow microphone testing
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as? MainTabBarController)?.tabBar.isHidden = true
        pitchDetector.startListening()
        forceLandscape()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AudioEngineManager.shared.stopAllNotes()
        pitchDetector.stopListening()
        (tabBarController as? MainTabBarController)?.tabBar.isHidden = false
    }

    // MARK: - Orientation
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    override var shouldAutorotate: Bool { true }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    private func forceLandscape() {
        if #available(iOS 16.0, *) {
            self.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.isHidden = true

        [sheetMusic, pianoKeyboard, navBar, reportView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 64),

            sheetMusic.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 10),
            sheetMusic.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetMusic.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheetMusic.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -kPianoH),

            pianoKeyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pianoKeyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pianoKeyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pianoKeyboard.topAnchor.constraint(equalTo: view.bottomAnchor, constant: -kPianoH),

            reportView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            reportView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            reportView.widthAnchor.constraint(equalToConstant: 450),
            reportView.heightAnchor.constraint(equalToConstant: 320)
        ])

        reportView.alpha = 0
        reportView.isHidden = true
        
        sheetMusic.setProgressBarHidden(true)

        setupGestures()
    }

    private func setupGestures() {
        // Only keep simulation tap on the chord label inside navBar
        navBar.chordDisplay.isUserInteractionEnabled = true
        let infoTap = UITapGestureRecognizer(target: self, action: #selector(simulateSession))
        navBar.chordDisplay.addGestureRecognizer(infoTap)
    }

    private func wireCallbacks() {
        navBar.onBackTap = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        
        sheetMusic.onSeekProgress = { [weak self] p in self?.engine.seek(to: Double(p)) }
        
        pianoKeyboard.onKeyPressed = { [weak self] note, isPressed in
            guard isPressed else { return }
            self?.handleInput(note: note)
        }
        
        reportView.onRetry = { [weak self] in self?.restartSession() }
        reportView.onDone  = { [weak self] in self?.navigationController?.popViewController(animated: true) }
    }

    private func loadSheetData() {
        let parser = MusicJSONLoader()
        if let st = parser.loadJSON(from: "sheet_test") {
            sheetMusic.configure(with: st)
            engine.start(with: st)
        } else {
            print("❌ [PlayAlong] Failed to load sheet_test data")
        }
    }
    
    private func restartSession() {
        let block = {
            self.reportView.alpha = 0
            self.reportView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
        UIView.animate(withDuration: 0.3, animations: block) { _ in
            self.reportView.isHidden = true
            self.reportView.transform = .identity
            self.sheetMusic.resetProgress()
            self.loadSheetData()
        }
    }

    private func handleInput(note: String) {
        let isCorrect = engine.processNote(note)
        
        if let key = pianoKeyboard.findKey(note) {
            let feedbackColor = isCorrect ? UIColor.systemGreen : UIColor.systemRed
            key.animatePress(color: feedbackColor)
            
            // Re-release after a short delay to revert to the hint (Blue) or blank
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                key.animateRelease()
            }
        }
        
        sheetMusic.showFeedback(isCorrect: isCorrect)
    }

    @objc private func simulateSession() {
        print("🚀 Starting Simulator Simulation (sheet_test)...")
        var delay: Double = 0
        // Longer sequence from sheet_test.json
        let notesToPlay = [
            "F5", "F5", "E5", "E5", "D5", "E5", "F5", "E5", "D5", "C5",
            "F5", "E5", "D5", "C5", "D5", "E5", "F5", "G5", "A5", "G5"
        ]
        
        for (i, note) in notesToPlay.enumerated() {
            delay += 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if i == 4 { self.handleInput(note: "D#5") }
                else if i == 12 { self.handleInput(note: "C#5") }
                else { self.handleInput(note: note) }
            }
        }
    }
}

// MARK: - Engine Delegate
extension PlayAlongViewController: PlayAlongEngineDelegate {
    func engineDidUpdateNotes(expected: [String]) {
        navBar.setExpectedNotes(expected)
        pianoKeyboard.showHints(for: expected)
        pianoKeyboard.centerOn(note: expected.first ?? "C4")
    }
    
    func engineDidUpdateTempo(actualBPM: Int) {
        navBar.setActualTempo(actualBPM)
    }
    
    func engineDidUpdateProgress(tick: Int) {
        sheetMusic.updateProgress(to: tick)
        // Update NavBar progress bar safely
        let total = max(1, engine.totalExpectedTicks)
        let progress = Double(tick) / Double(total)
        navBar.setProgress(CGFloat(progress))
    }
    
    func engineDidFinish(correct: Int, mistakes: Int, expected: Int) {
        let acc = expected > 0 ? (correct * 100 / expected) : 100
        reportView.configure(accuracy: acc, correct: correct, mistakes: mistakes)
        
        reportView.isHidden = false
        reportView.alpha = 0
        reportView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        UIView.animate(withDuration: 0.4, delay: 0.5, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.reportView.alpha = 1
            self.reportView.transform = .identity
        }
    }
}

// MARK: - Pitch Detection
extension PlayAlongViewController: PitchDetectorDelegate {
    func pitchDetectorDidDetect(note: String, frequency: Float, amplitude: CGFloat) {
        // Lower threshold for laptop microphones (0.05 -> 0.02)
        guard note != "—" && amplitude > 0.02 else { return }
        handleInput(note: note)
    }
}

// MARK: - PlayAlongEngine
protocol PlayAlongEngineDelegate: AnyObject {
    func engineDidUpdateNotes(expected: [String])
    func engineDidUpdateProgress(tick: Int)
    func engineDidUpdateTempo(actualBPM: Int)
    func engineDidFinish(correct: Int, mistakes: Int, expected: Int)
}

final class PlayAlongEngine {
    weak var delegate: PlayAlongEngineDelegate?
    
    private var dataManager: PianoDataManager?
    private var currentTick: Int = 0
    private var expectedNotes: [String] = []
    
    private var totalCorrect = 0
    private var totalMistakes = 0
    private var totalExpected = 0
    var totalExpectedTicks: Int = 1
    
    private var groupStartTime: Date?
    var requiredBPM: Int = 90 // Default
    
    func start(with musicData: [SongChord]) {
        dataManager = PianoDataManager(scoreData: musicData)
        totalCorrect = 0
        totalMistakes = 0
        totalExpected = 0
        currentTick = 0
        totalExpectedTicks = musicData.last?.globalTick ?? 1
        advance()
    }
    
    func processNote(_ note: String) -> Bool {
        guard !expectedNotes.isEmpty else { return false }
        
        if expectedNotes.contains(note) {
            totalCorrect += 1
            expectedNotes.removeAll { $0 == note }
            
            if expectedNotes.isEmpty {
                calculateTempoPulse()
                currentTick += 50
                advance()
            }
            return true
        } else {
            totalMistakes += 1
            return false
        }
    }
    
    func seek(to p: Double) {
        guard let dm = dataManager else { return }
        let groups = dm.allGroups()
        guard let lastTick = groups.last?.tick, lastTick > 0 else { return }
        
        let target = Int(Double(lastTick) * p)
        currentTick = target
        
        if let idx = groups.firstIndex(where: { $0.tick >= currentTick }) {
            let g = groups[idx]
            currentTick = g.tick
            expectedNotes = g.leftNotes + g.rightNotes
            groupStartTime = Date()
            delegate?.engineDidUpdateNotes(expected: expectedNotes)
            delegate?.engineDidUpdateProgress(tick: currentTick)
        }
    }
    
    private func advance() {
        guard let dm = dataManager else { return }
        let groups = dm.allGroups()
        
        if let idx = groups.firstIndex(where: { $0.tick >= currentTick && (!$0.leftNotes.isEmpty || !$0.rightNotes.isEmpty) }) {
            let g = groups[idx]
            currentTick = g.tick
            expectedNotes = g.leftNotes + g.rightNotes
            totalExpected += expectedNotes.count
            
            groupStartTime = Date()
            delegate?.engineDidUpdateNotes(expected: expectedNotes)
            delegate?.engineDidUpdateProgress(tick: currentTick)
        } else {
            delegate?.engineDidFinish(correct: totalCorrect, mistakes: totalMistakes, expected: totalExpected)
        }
    }
    
    private func calculateTempoPulse() {
        guard let start = groupStartTime else { return }
        let duration = Date().timeIntervalSince(start)
        if duration > 0 {
            let actual = Int(60.0 / duration)
            delegate?.engineDidUpdateTempo(actualBPM: min(actual, 300))
        }
    }
}

// MARK: - PlayAlongNavBar
final class PlayAlongNavBar: UIView {
    var onBackTap: (() -> Void)?
    
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let backButton = UIButton(type: .system)
    let chordDisplay = UILabel()
    
    private let rightStack = UIStackView()
    
    // Progress
    private let progressTrack = UIView()
    private let progressGradient = CAGradientLayer()
    private let progressBar = UIView()
    private let progressLabel = UILabel()
    
    // Tempo
    private let tempoContainer = UIView()
    private let tempoLabel = UILabel()
    private let tempoValueLabel = UILabel()
    private let tempoIndicator = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateGradientFrame()
    }
    
    private func setupUI() {
        addSubview(blurView)
        
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .label
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        
        chordDisplay.font = .systemFont(ofSize: 22, weight: .black)
        chordDisplay.textColor = .label
        chordDisplay.textAlignment = .center
        chordDisplay.text = "🎹 Ready"
        
        // Progress UI
        progressTrack.backgroundColor = UIColor.label.withAlphaComponent(0.05)
        progressTrack.layer.cornerRadius = 6
        progressTrack.clipsToBounds = true
        progressTrack.layer.borderWidth = 1
        progressTrack.layer.borderColor = UIColor.label.withAlphaComponent(0.1).cgColor
        
        progressGradient.colors = [UIColor.systemGreen.cgColor, UIColor.systemTeal.cgColor]
        progressGradient.startPoint = CGPoint(x: 0, y: 0.5)
        progressGradient.endPoint = CGPoint(x: 1, y: 0.5)
        progressBar.layer.addSublayer(progressGradient)
        progressBar.layer.cornerRadius = 6
        progressBar.clipsToBounds = true
        
        progressLabel.font = .systemFont(ofSize: 10, weight: .bold)
        progressLabel.textColor = .secondaryLabel
        progressLabel.text = "0%"
        
        // Tempo UI
        tempoContainer.backgroundColor = UIColor.label.withAlphaComponent(0.05)
        tempoContainer.layer.cornerRadius = 8
        
        tempoLabel.font = .systemFont(ofSize: 9, weight: .bold)
        tempoLabel.textColor = .secondaryLabel
        tempoLabel.text = "TEMPO"
        
        tempoValueLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .black)
        tempoValueLabel.textColor = .label
        tempoValueLabel.text = "0"
        
        tempoIndicator.backgroundColor = .systemGreen
        tempoIndicator.layer.cornerRadius = 3
        
        let tempoStack = UIStackView(arrangedSubviews: [tempoLabel, tempoValueLabel])
        tempoStack.axis = .vertical
        tempoStack.alignment = .center
        tempoStack.spacing = -2
        
        [blurView, backButton, chordDisplay, progressTrack, progressLabel, tempoContainer, tempoIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        
        tempoContainer.addSubview(tempoStack)
        tempoStack.translatesAutoresizingMaskIntoConstraints = false
        
        progressTrack.addSubview(progressBar)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            chordDisplay.centerXAnchor.constraint(equalTo: centerXAnchor),
            chordDisplay.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Progress position
            progressTrack.trailingAnchor.constraint(equalTo: tempoContainer.leadingAnchor, constant: -25),
            progressTrack.centerYAnchor.constraint(equalTo: centerYAnchor),
            progressTrack.widthAnchor.constraint(equalToConstant: 160),
            progressTrack.heightAnchor.constraint(equalToConstant: 12),
            
            progressBar.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressBar.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressBar.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressBar.widthAnchor.constraint(equalToConstant: 0),
            
            progressLabel.centerXAnchor.constraint(equalTo: progressTrack.centerXAnchor),
            progressLabel.topAnchor.constraint(equalTo: progressTrack.bottomAnchor, constant: 2),
            
            // Tempo position
            tempoContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            tempoContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            tempoContainer.widthAnchor.constraint(equalToConstant: 60),
            tempoContainer.heightAnchor.constraint(equalToConstant: 44),
            
            tempoStack.centerXAnchor.constraint(equalTo: tempoContainer.centerXAnchor),
            tempoStack.centerYAnchor.constraint(equalTo: tempoContainer.centerYAnchor),
            
            tempoIndicator.topAnchor.constraint(equalTo: tempoContainer.topAnchor, constant: -4),
            tempoIndicator.centerXAnchor.constraint(equalTo: tempoContainer.centerXAnchor),
            tempoIndicator.widthAnchor.constraint(equalToConstant: 6),
            tempoIndicator.heightAnchor.constraint(equalToConstant: 6)
        ])
    }
    
    private func updateGradientFrame() {
        progressGradient.frame = progressBar.bounds
    }
    
    @objc private func backTapped() { onBackTap?() }
    
    func setActualTempo(_ bpm: Int) {
        tempoValueLabel.text = "\(bpm)"
        let target = 90
        let diff = abs(bpm - target)
        
        let color: UIColor = diff < 10 ? .label : (diff < 20 ? .systemOrange : .systemRed)
        UIView.animate(withDuration: 0.3) {
            self.tempoValueLabel.textColor = color
            self.tempoIndicator.backgroundColor = color
            self.tempoIndicator.transform = diff < 10 ? CGAffineTransform(scaleX: 1.2, y: 1.2) : .identity
        }
    }
    
    func setExpectedNotes(_ notes: [String]) {
        let text = "Play: \(notes.joined(separator: " "))"
        UIView.transition(with: chordDisplay, duration: 0.2, options: .transitionCrossDissolve) {
            self.chordDisplay.text = text
        }
        
        // Micro-animation
        chordDisplay.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5) {
            self.chordDisplay.transform = .identity
        }
    }
    
    func setProgress(_ p: CGFloat) {
        let clamped = max(0, min(1, p))
        progressLabel.text = "\(Int(clamped * 100))%"
        
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            self.progressBar.constraints.forEach { if $0.firstAttribute == .width { self.progressTrack.removeConstraint($0) } }
            self.progressBar.widthAnchor.constraint(equalTo: self.progressTrack.widthAnchor, multiplier: clamped).isActive = true
            self.layoutIfNeeded()
            self.updateGradientFrame()
        }
    }
}

// MARK: - PlayAlongReportView
final class PlayAlongReportView: UIView {
    var onRetry: (() -> Void)?
    var onDone:  (() -> Void)?

    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let titleLabel = UILabel()
    private let statsStack = UIStackView()
    private let retryButton = UIButton(type: .system)
    private let doneButton  = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = .clear
        layer.cornerRadius = 24; clipsToBounds = true
        
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        
        titleLabel.text = "Session Report"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        statsStack.axis = .vertical
        statsStack.spacing = 16
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statsStack)

        let buttonsStack = UIStackView()
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 20
        buttonsStack.distribution = .fillEqually
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buttonsStack)

        retryButton.setTitle("Practice Again", for: .normal)
        retryButton.backgroundColor = .systemBlue
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.layer.cornerRadius = 12
        retryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        doneButton.setTitle("Done", for: .normal)
        doneButton.backgroundColor = .systemGray5
        doneButton.setTitleColor(.label, for: .normal)
        doneButton.layer.cornerRadius = 12
        doneButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        buttonsStack.addArrangedSubview(retryButton)
        buttonsStack.addArrangedSubview(doneButton)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            statsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            statsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            statsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),

            buttonsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -32),
            buttonsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            buttonsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            buttonsStack.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    func configure(accuracy: Int, correct: Int, mistakes: Int) {
        statsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        addStat(label: "Accuracy", value: "\(accuracy)%")
        addStat(label: "Notes Hit", value: "\(correct)")
        addStat(label: "Mistakes",  value: "\(mistakes)")
    }

    private func addStat(label: String, value: String) {
        let row = UIStackView()
        row.axis = .horizontal
        let l = UILabel(); l.text = label; l.font = .systemFont(ofSize: 18); l.textColor = .secondaryLabel
        let v = UILabel(); v.text = value; v.font = .systemFont(ofSize: 20, weight: .bold); v.textColor = .label; v.textAlignment = .right
        row.addArrangedSubview(l); row.addArrangedSubview(v)
        statsStack.addArrangedSubview(row)
    }

    @objc private func retryTapped() { onRetry?() }
    @objc private func doneTapped()  { onDone?()  }
}
