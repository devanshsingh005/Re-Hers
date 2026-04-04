import UIKit
import AVFoundation

final class PlayAlongViewController: UIViewController {

    // MARK: - Components
    private let pianoKeyboard = AnimatedPianoKeyboardView()
    private let sheetMusic    = SheetMusicView()
    private let navBar        = PlayAlongNavBar()
    private let reportView    = PlayAlongReportView()
    private let loadingView   = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let loadingLabel  = UILabel()

    // Logic
    private let engine = PlayAlongEngine()
    private let pitchDetector = PitchDetector()
    
    var sheetMusicData: Data?

    private let kPianoH: CGFloat = 170
    private var hasAudioPlaybackSession = false
    private var hasStartedSessionForCurrentAppearance = false
    private var sessionStartupWorkItem: DispatchWorkItem?
    private var isPreparingScore = false
    private var hasPreparedScore = false

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
        debugLog("🧹 Cleaning up PlayAlong session")
        sessionStartupWorkItem?.cancel()
        pitchDetector.stopListening()
        AudioEngineManager.shared.stopAllNotes()
        releaseAudioPlaybackSession()
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        }
        self.edgesForExtendedLayout = .all
        setupUI()
        wireCallbacks()
        
        engine.delegate = self
        pitchDetector.delegate = self
        
        pianoKeyboard.mode = .playAlong
        navBar.setMicActive(false)
        setLoadingVisible(true, text: "Preparing Play Along...")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure no safe-area gap remains from portrait transition
        additionalSafeAreaInsets = .zero
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStartedSessionForCurrentAppearance else { return }
        hasStartedSessionForCurrentAppearance = true
        loadSheetDataIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as? MainTabBarController)?.tabBar.isHidden = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hasStartedSessionForCurrentAppearance = false
        sessionStartupWorkItem?.cancel()
        sessionStartupWorkItem = nil
        AudioEngineManager.shared.stopAllNotes()
        releaseAudioPlaybackSession()
        pitchDetector.stopListening()
        (tabBarController as? MainTabBarController)?.tabBar.isHidden = false
    }

    private func acquireAudioPlaybackSessionIfNeeded() {
        guard !hasAudioPlaybackSession else { return }
        AudioEngineManager.shared.acquirePlaybackSession()
        hasAudioPlaybackSession = true
    }

    private func releaseAudioPlaybackSession() {
        guard hasAudioPlaybackSession else { return }
        AudioEngineManager.shared.releasePlaybackSession()
        hasAudioPlaybackSession = false
    }

    // MARK: - Orientation
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    override var shouldAutorotate: Bool { true }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    private func scheduleSessionStartup() {
        sessionStartupWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.isViewLoaded, self.view.window != nil else { return }
            guard self.presentedViewController == nil else { return }

            self.acquireAudioPlaybackSessionIfNeeded()
            self.beginListeningFlow()
        }

        sessionStartupWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func loadSheetDataIfNeeded() {
        guard !hasPreparedScore, !isPreparingScore else {
            if hasPreparedScore {
                scheduleSessionStartup()
            }
            return
        }

        isPreparingScore = true
        setLoadingVisible(true, text: "Preparing Play Along...")

        let inputData = sheetMusicData
        DispatchQueue.global(qos: .userInitiated).async {
            let result: [SongChord]?
            let rawData: Data?

            if let data = inputData {
                rawData = data
                do {
                    result = try MusicJSONLoader.loadSongChords(from: data)
                } catch {
                    debugLog("❌ [PlayAlong] FAILED to parse dynamic data: \(error)")
                    result = nil
                }
            } else {
                rawData = nil
                result = nil
            }

            DispatchQueue.main.async {
                self.isPreparingScore = false

                guard self.isViewLoaded else { return }

                if let data = rawData, let chords = result {
                    self.hasPreparedScore = true
                    self.navBar.resetForSession()
                    self.reportView.isHidden = true
                    self.reportView.alpha = 0
                    self.sheetMusic.resetProgress()
                    self.sheetMusic.loadData(data)
                    self.sheetMusic.configure(with: chords)
                    self.engine.start(with: chords)
                    self.setLoadingVisible(false)
                    self.scheduleSessionStartup()
                } else {
                    debugLog("❌ [PlayAlong] Failed to load any sheet data")
                    self.setLoadingVisible(false)
                    self.presentSheetDataUnavailableAlert()
                }
            }
        }
    }

    private func setLoadingVisible(_ visible: Bool, text: String? = nil) {
        if let text {
            loadingLabel.text = text
        }

        loadingView.isHidden = !visible
        loadingView.alpha = visible ? 1 : 0
        if visible {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = ComponentColors.HomeScreen.background
        navigationController?.navigationBar.isHidden = true

        [sheetMusic, pianoKeyboard, navBar, reportView, loadingView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        let loadingStack = UIStackView(arrangedSubviews: [loadingIndicator, loadingLabel])
        loadingStack.axis = .vertical
        loadingStack.alignment = .center
        loadingStack.spacing = 12
        loadingStack.translatesAutoresizingMaskIntoConstraints = false
        loadingView.contentView.addSubview(loadingStack)
        loadingLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        loadingLabel.textColor = .label
        loadingLabel.textAlignment = .center

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            navBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            navBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            navBar.heightAnchor.constraint(equalToConstant: 54),

            sheetMusic.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 10),
            sheetMusic.leadingAnchor.constraint(equalTo: navBar.leadingAnchor),
            sheetMusic.trailingAnchor.constraint(equalTo: navBar.trailingAnchor),
            sheetMusic.bottomAnchor.constraint(equalTo: pianoKeyboard.topAnchor, constant: -10),

            pianoKeyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pianoKeyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pianoKeyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pianoKeyboard.heightAnchor.constraint(equalToConstant: kPianoH),

            reportView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            reportView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            reportView.widthAnchor.constraint(equalToConstant: 450),
            reportView.heightAnchor.constraint(equalToConstant: 320),

            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingStack.centerXAnchor.constraint(equalTo: loadingView.contentView.centerXAnchor),
            loadingStack.centerYAnchor.constraint(equalTo: loadingView.contentView.centerYAnchor)
        ])

        reportView.alpha = 0
        reportView.isHidden = true
        loadingView.alpha = 0
        loadingView.isHidden = true
        loadingView.contentView.backgroundColor = ComponentColors.HomeScreen.background.withAlphaComponent(0.55)
        
        sheetMusic.setProgressBarHidden(true)

        setupGestures()
    }

    private func setupGestures() {
        #if DEBUG
        navBar.chordDisplay.isUserInteractionEnabled = true
        let infoTap = UITapGestureRecognizer(target: self, action: #selector(simulateSession))
        navBar.chordDisplay.addGestureRecognizer(infoTap)
        #endif
        
        let micTap = UITapGestureRecognizer(target: self, action: #selector(micIndicatorTapped))
        navBar.micIndicator.addGestureRecognizer(micTap)
        navBar.micIndicator.isUserInteractionEnabled = true
    }
    
    @objc private func micIndicatorTapped() {
        debugLog("🎙️ Manual Mic Reset requested")
        beginListeningFlow(forceRestart: true)
    }

    private func beginListeningFlow(forceRestart: Bool = false) {
        switch pitchDetector.recordPermissionStatus() {
        case .granted:
            startListening(forceRestart: forceRestart)
        case .undetermined:
            presentMicrophoneRationale()
        case .denied:
            navBar.setMicActive(false)
            presentMicrophoneSettingsAlert()
        @unknown default:
            navBar.setMicActive(false)
            presentMicrophoneSettingsAlert()
        }
    }

    private func startListening(forceRestart: Bool = false) {
        if forceRestart {
            pitchDetector.stopListening()
        }

        guard pitchDetector.startListening() else {
            navBar.setMicActive(false)
            presentMicrophoneUnavailableAlert()
            return
        }
    }

    private func presentMicrophoneRationale() {
        guard presentedViewController == nil else { return }

        let alert = UIAlertController(
            title: "Use Microphone for Play Along",
            message: "Re-Hearse listens only while Play Along is open so it can detect the notes you play in real time.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { [weak self] _ in
            self?.navBar.setMicActive(false)
        })
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
            self?.pitchDetector.requestMicrophonePermission { granted in
                guard let self else { return }
                granted ? self.startListening() : self.presentMicrophoneSettingsAlert()
            }
        })
        present(alert, animated: true)
    }

    private func presentMicrophoneSettingsAlert() {
        guard presentedViewController == nil else { return }

        let alert = UIAlertController(
            title: "Microphone Access Needed",
            message: "Turn on microphone access in Settings so Play Along can hear the notes you play.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsURL)
        })
        present(alert, animated: true)
    }

    private func presentMicrophoneUnavailableAlert() {
        guard presentedViewController == nil else { return }

        let message = pitchDetector.lastStartFailure?.errorDescription
            ?? "Re-Hearse could not start microphone capture right now. Please try again."

        let alert = UIAlertController(
            title: "Microphone Unavailable",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func wireCallbacks() {
        navBar.onBackTap = { [weak self] in
            if let nc = self?.navigationController, nc.viewControllers.count > 1 {
                nc.popViewController(animated: true)
            } else {
                self?.dismiss(animated: true)
            }
        }
        
        sheetMusic.onSeekProgress = { [weak self] p in self?.engine.seek(to: Double(p)) }
        
        pianoKeyboard.onKeyPressed = { [weak self] note, isPressed in
            guard isPressed else { return }
            self?.handleInput(note: note)
        }
        
        reportView.onRetry = { [weak self] in self?.restartSession() }
        reportView.onDone  = { [weak self] in
            if let nc = self?.navigationController, nc.viewControllers.count > 1 {
                nc.popViewController(animated: true)
            } else {
                self?.dismiss(animated: true)
            }
        }
    }

    private func restartSession() {
        engine.resetRealtimeState()
        hasPreparedScore = false
        acquireAudioPlaybackSessionIfNeeded()
        pitchDetector.stopListening()

        UIView.animate(withDuration: 0.25, animations: {
            self.reportView.alpha = 0
            self.reportView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }) { _ in
            self.reportView.isHidden = true
            self.reportView.transform = .identity
            self.loadSheetDataIfNeeded()
        }
    }

    private func handleInput(note: String) {
        guard engine.isSessionActive else { return }
        let isCorrect = engine.processNote(note)
        
        if let key = pianoKeyboard.findKey(note) {
            let feedbackColor = isCorrect ? UIColor.systemGreen : UIColor.systemRed
            key.animatePress(color: feedbackColor)
            
            if isCorrect {
            }
            
            // Re-release after a short delay to revert to the hint (Blue) or blank
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                key.animateRelease()
            }
        }
        
        sheetMusic.showFeedback(isCorrect: isCorrect)
        
        if !isCorrect {
            // Add a permanent marker on the sheet music for where the mistake happened
            sheetMusic.addWrongNoteMarker(at: Double(engine.currentTick))
        }
    }

    private func presentSheetDataUnavailableAlert() {
        guard presentedViewController == nil else { return }

        let alert = UIAlertController(
            title: "Play Along Unavailable",
            message: "This song could not be prepared for Play Along. Please try another song or reopen this one.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            if let nc = self?.navigationController, nc.viewControllers.count > 1 {
                nc.popViewController(animated: true)
            } else {
                self?.dismiss(animated: true)
            }
        })
        present(alert, animated: true)
    }

    @objc private func simulateSession() {
        #if DEBUG
        debugLog("🚀 Starting Simulator Simulation...")
        var delay: Double = 0
        // Longer sequence from the bundled debug sheet data
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
        #endif
    }
}

// MARK: - Engine Delegate
extension PlayAlongViewController: PlayAlongEngineDelegate {
    func engineDidUpdateNotes(left: [String], right: [String], expected: [String]) {
        navBar.setExpectedNotes(expected)
        pianoKeyboard.showHints(leftHand: left, rightHand: right)
        pianoKeyboard.centerOn(note: expected.first ?? right.first ?? left.first ?? "C4")
    }
    
    func engineDidUpdateTempo(actualBPM: Int) {
        navBar.setActualTempo(actualBPM)
    }
    
    func engineDidUpdateProgress(tick: Int, progress: CGFloat) {
        sheetMusic.updateProgress(to: tick)
        navBar.setProgress(progress)
    }
    
    func engineDidFinish(correct: Int, mistakes: Int, expected: Int) {
        pitchDetector.stopListening()
        navBar.setMicActive(false)
        AudioEngineManager.shared.stopAllNotes()
        releaseAudioPlaybackSession()
        navBar.setProgress(1)

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
    func pitchDetectorDidDetect(notes: [String], frequency: Float, amplitude: CGFloat) {
        // Guard against low amplitude background noise
        guard !notes.isEmpty && amplitude > 0.045 else {
            navBar.setMicActive(false)
            return 
        }
        guard engine.isSessionActive else {
            navBar.setMicActive(false)
            return
        }
        navBar.setMicActive(true)
        
        let now = Date()

        for note in engine.filterAcceptedNotes(from: notes, at: now) {
            handleInput(note: note)
        }
    }
}

// MARK: - PlayAlongEngine
protocol PlayAlongEngineDelegate: AnyObject {
    func engineDidUpdateNotes(left: [String], right: [String], expected: [String])
    func engineDidUpdateProgress(tick: Int, progress: CGFloat)
    func engineDidUpdateTempo(actualBPM: Int)
    func engineDidFinish(correct: Int, mistakes: Int, expected: Int)
}

final class PlayAlongEngine {
    weak var delegate: PlayAlongEngineDelegate?
    
    private var dataManager: PianoDataManager?
    private var playableGroups: [PianoDataManager.NoteGroup] = []
    private var currentGroupIndex = 0
    private var completedGroupCount = 0
    var currentTick: Int = 0 // Changed from private to allow access from ViewController
    private var currentLeftNotes: [String] = []
    private var currentRightNotes: [String] = []
    private var expectedNotes: [String] = []
    private(set) var isSessionActive = false
    
    private var totalCorrect = 0
    private var totalMistakes = 0
    private var totalExpected = 0
    var totalExpectedTicks: Int = 1
    var progressFraction: CGFloat {
        guard !playableGroups.isEmpty else { return 0 }
        return CGFloat(completedGroupCount) / CGFloat(playableGroups.count)
    }
    
    private var groupStartTime: Date?
    var requiredBPM: Int = 90 // Default
    private var recentDetections: [String: Date] = [:]
    private let noteDebounceInterval: TimeInterval = 0.22
    
    func start(with musicData: [SongChord]) {
        dataManager = PianoDataManager(scoreData: musicData)
        playableGroups = dataManager?.allGroups().filter { !$0.leftNotes.isEmpty || !$0.rightNotes.isEmpty } ?? []
        currentGroupIndex = 0
        completedGroupCount = 0
        currentLeftNotes = []
        currentRightNotes = []
        totalCorrect = 0
        totalMistakes = 0
        totalExpected = playableGroups.reduce(0) { $0 + $1.leftNotes.count + $1.rightNotes.count }
        currentTick = 0
        totalExpectedTicks = musicData.last?.globalTick ?? 1
        recentDetections.removeAll()
        isSessionActive = true
        advance()
    }

    func resetRealtimeState() {
        recentDetections.removeAll()
        isSessionActive = true
    }
    
    func processNote(_ note: String) -> Bool {
        guard isSessionActive, !expectedNotes.isEmpty else { return false }

        let normalizedInput = Self.canonicalNoteName(note)

        if let matchedIndex = expectedNotes.firstIndex(where: { Self.canonicalNoteName($0) == normalizedInput }) {
            totalCorrect += 1
            expectedNotes.remove(at: matchedIndex)
            removeMatchedNote(normalizedInput)
            
            if expectedNotes.isEmpty {
                completeGroup()
            } else {
                delegate?.engineDidUpdateNotes(left: currentLeftNotes, right: currentRightNotes, expected: expectedNotes)
            }
            return true
        } else {
            totalMistakes += 1
            return false
        }
    }

    func filterAcceptedNotes(from notes: [String], at time: Date) -> [String] {
        guard isSessionActive else { return [] }

        var accepted: [String] = []

        for note in Array(Set(notes.map(Self.canonicalNoteName))) {
            if let lastTime = recentDetections[note], time.timeIntervalSince(lastTime) < noteDebounceInterval {
                continue
            }

            recentDetections[note] = time
            accepted.append(note)
        }

        return accepted
    }
    
    private func completeGroup() {
        calculateTempoPulse()
        completedGroupCount = min(completedGroupCount + 1, playableGroups.count)
        currentGroupIndex += 1
        advance()
    }
    
    func seek(to p: Double) {
        guard !playableGroups.isEmpty else { return }
        guard let lastTick = playableGroups.last?.tick, lastTick > 0 else { return }
        
        let target = Int(Double(lastTick) * p)
        guard let idx = playableGroups.firstIndex(where: { $0.tick >= target }) else { return }

        currentGroupIndex = idx
        completedGroupCount = idx
        let group = playableGroups[idx]
        currentTick = group.tick
        currentLeftNotes = group.leftNotes
        currentRightNotes = group.rightNotes
        expectedNotes = currentLeftNotes + currentRightNotes
        groupStartTime = Date()
        recentDetections.removeAll()
        delegate?.engineDidUpdateNotes(left: currentLeftNotes, right: currentRightNotes, expected: expectedNotes)
        delegate?.engineDidUpdateProgress(tick: currentTick, progress: progressFraction)
    }
    
    private func advance() {
        guard currentGroupIndex < playableGroups.count else {
            isSessionActive = false
            delegate?.engineDidFinish(correct: totalCorrect, mistakes: totalMistakes, expected: totalExpected)
            return
        }

        let group = playableGroups[currentGroupIndex]
        currentTick = group.tick
        currentLeftNotes = group.leftNotes
        currentRightNotes = group.rightNotes
        expectedNotes = currentLeftNotes + currentRightNotes
        groupStartTime = Date()
        recentDetections.removeAll()
        delegate?.engineDidUpdateNotes(left: currentLeftNotes, right: currentRightNotes, expected: expectedNotes)
        delegate?.engineDidUpdateProgress(tick: currentTick, progress: progressFraction)
    }
    
    private func calculateTempoPulse() {
        guard let start = groupStartTime else { return }
        let duration = Date().timeIntervalSince(start)
        if duration > 0 {
            let actual = Int(60.0 / duration)
            delegate?.engineDidUpdateTempo(actualBPM: min(actual, 300))
        }
    }

    private func removeMatchedNote(_ normalizedInput: String) {
        if let leftIndex = currentLeftNotes.firstIndex(where: { Self.canonicalNoteName($0) == normalizedInput }) {
            currentLeftNotes.remove(at: leftIndex)
            return
        }

        if let rightIndex = currentRightNotes.firstIndex(where: { Self.canonicalNoteName($0) == normalizedInput }) {
            currentRightNotes.remove(at: rightIndex)
        }
    }

    private static func canonicalNoteName(_ note: String) -> String {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return note }

        let flatsToSharps: [String: String] = [
            "CB": "B", "DB": "C#", "EB": "D#", "FB": "E",
            "GB": "F#", "AB": "G#", "BB": "A#", "E#": "F", "B#": "C"
        ]

        var octaveStart = trimmed.endIndex
        while octaveStart > trimmed.startIndex {
            let previous = trimmed.index(before: octaveStart)
            let character = trimmed[previous]
            if character.isNumber || character == "-" {
                octaveStart = previous
            } else {
                break
            }
        }

        let octave = String(trimmed[octaveStart...])
        let pitch = String(trimmed[..<octaveStart])

        if let normalizedPitch = flatsToSharps[pitch] {
            return normalizedPitch + octave
        }

        return trimmed
    }
}

// MARK: - PlayAlongNavBar
final class PlayAlongNavBar: UIView {
    var onBackTap: (() -> Void)?
    
    private let brandOrange = ComponentColors.HomeScreen.actionButtonFill
    
    private let backButton = UIButton(type: .system)
    let chordDisplay = UILabel()
    private let backPill = UIView()
    private let chordPill = UIView()
    private let statusPill = UIView()

    // Progress
    private let progressTrack = UIView()
    private let progressGradient = CAGradientLayer()
    private let progressBar = UIView()
    private let progressLabel = UILabel()
    private var progressWidthConstraint: NSLayoutConstraint?
    private let progressContainer = UIStackView()
    
    // Tempo
    private let tempoContainer = UIView()
    private let tempoLabel = UILabel()
    private let tempoValueLabel = UILabel()
    private let tempoIndicator = UIView()
    
    // Mic Status
    let micIndicator = UIView()
    private let statusStack = UIStackView()
    
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
        backgroundColor = .clear

        let backConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: backConfig), for: .normal)
        backButton.tintColor = .label
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        
        chordDisplay.font = .systemFont(ofSize: 20, weight: .black)
        chordDisplay.textColor = .label
        chordDisplay.textAlignment = .center
        chordDisplay.lineBreakMode = .byTruncatingTail
        chordDisplay.adjustsFontSizeToFitWidth = true
        chordDisplay.minimumScaleFactor = 0.75
        chordDisplay.text = "Play Along Ready"
        
        // Progress UI
        progressTrack.backgroundColor = UIColor.label.withAlphaComponent(0.06)
        progressTrack.layer.cornerRadius = 5
        progressTrack.clipsToBounds = true
        progressTrack.layer.borderWidth = 1
        progressTrack.layer.borderColor = UIColor.label.withAlphaComponent(0.1).cgColor
        
        progressGradient.colors = [brandOrange.cgColor, brandOrange.withAlphaComponent(0.6).cgColor]
        progressGradient.startPoint = CGPoint(x: 0, y: 0.5)
        progressGradient.endPoint = CGPoint(x: 1, y: 0.5)
        progressBar.layer.addSublayer(progressGradient)
        progressBar.layer.cornerRadius = 5
        progressBar.clipsToBounds = true
        
        progressLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        progressLabel.textColor = brandOrange
        progressLabel.text = "0%"
        progressLabel.textAlignment = .center
        
        progressContainer.axis = .vertical
        progressContainer.alignment = .fill
        progressContainer.spacing = 2
        
        // Tempo UI
        tempoContainer.backgroundColor = .clear
        
        tempoLabel.font = .systemFont(ofSize: 8, weight: .bold)
        tempoLabel.textColor = .secondaryLabel
        tempoLabel.text = "TEMPO"
        
        tempoValueLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .black)
        tempoValueLabel.textColor = .label
        tempoValueLabel.text = "0"
        
        tempoIndicator.backgroundColor = .systemGreen
        tempoIndicator.layer.cornerRadius = 3
        
        let tempoStack = UIStackView(arrangedSubviews: [tempoLabel, tempoValueLabel])
        tempoStack.axis = .vertical
        tempoStack.alignment = .center
        tempoStack.spacing = -3

        statusStack.axis = .horizontal
        statusStack.alignment = .center
        statusStack.spacing = 10
        
        [backPill, chordPill, statusPill].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        [backButton, chordDisplay, statusStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        [progressTrack, progressLabel, tempoContainer, tempoIndicator, micIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        backPill.addSubview(backButton)
        chordPill.addSubview(chordDisplay)
        statusPill.addSubview(statusStack)
        
        micIndicator.backgroundColor = .systemRed.withAlphaComponent(0.18)
        micIndicator.layer.cornerRadius = 8
        micIndicator.layer.borderWidth = 1
        micIndicator.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.5).cgColor
        
        let micDot = UIView()
        micDot.backgroundColor = .systemRed
        micDot.layer.cornerRadius = 3
        micDot.translatesAutoresizingMaskIntoConstraints = false
        micIndicator.addSubview(micDot)
        NSLayoutConstraint.activate([
            micDot.centerXAnchor.constraint(equalTo: micIndicator.centerXAnchor),
            micDot.centerYAnchor.constraint(equalTo: micIndicator.centerYAnchor),
            micDot.widthAnchor.constraint(equalToConstant: 6),
            micDot.heightAnchor.constraint(equalToConstant: 6)
        ])
        
        tempoContainer.addSubview(tempoStack)
        tempoStack.translatesAutoresizingMaskIntoConstraints = false
        tempoContainer.addSubview(tempoIndicator)
        
        progressTrack.addSubview(progressBar)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.addArrangedSubview(progressTrack)
        progressContainer.addArrangedSubview(progressLabel)
        statusStack.addArrangedSubview(progressContainer)
        statusStack.addArrangedSubview(micIndicator)
        statusStack.addArrangedSubview(tempoContainer)
        progressWidthConstraint = progressBar.widthAnchor.constraint(equalToConstant: 0)

        stylePill(backPill, cornerRadius: 22)
        stylePill(chordPill, cornerRadius: 18)
        stylePill(statusPill, cornerRadius: 22)
        
        NSLayoutConstraint.activate([
            backPill.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            backPill.centerYAnchor.constraint(equalTo: centerYAnchor),
            backPill.widthAnchor.constraint(equalToConstant: 44),
            backPill.heightAnchor.constraint(equalToConstant: 44),
            
            backButton.centerXAnchor.constraint(equalTo: backPill.centerXAnchor),
            backButton.centerYAnchor.constraint(equalTo: backPill.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            statusPill.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            statusPill.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusPill.heightAnchor.constraint(equalToConstant: 44),
            
            statusStack.topAnchor.constraint(equalTo: statusPill.topAnchor, constant: 5),
            statusStack.bottomAnchor.constraint(equalTo: statusPill.bottomAnchor, constant: -5),
            statusStack.leadingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: 10),
            statusStack.trailingAnchor.constraint(equalTo: statusPill.trailingAnchor, constant: -10),
            
            chordPill.centerYAnchor.constraint(equalTo: centerYAnchor),
            chordPill.leadingAnchor.constraint(equalTo: backPill.trailingAnchor, constant: 16),
            chordPill.trailingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: -16),
            chordPill.heightAnchor.constraint(equalToConstant: 44),
            
            chordDisplay.leadingAnchor.constraint(equalTo: chordPill.leadingAnchor, constant: 20),
            chordDisplay.trailingAnchor.constraint(equalTo: chordPill.trailingAnchor, constant: -20),
            chordDisplay.centerYAnchor.constraint(equalTo: chordPill.centerYAnchor),
            
            progressTrack.widthAnchor.constraint(equalToConstant: 118),
            progressTrack.heightAnchor.constraint(equalToConstant: 10),
            
            progressBar.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressBar.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressBar.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressContainer.widthAnchor.constraint(equalToConstant: 118),
            
            tempoContainer.widthAnchor.constraint(equalToConstant: 58),
            tempoContainer.heightAnchor.constraint(equalToConstant: 32),
            
            tempoStack.centerXAnchor.constraint(equalTo: tempoContainer.centerXAnchor),
            tempoStack.centerYAnchor.constraint(equalTo: tempoContainer.centerYAnchor),
            
            tempoIndicator.topAnchor.constraint(equalTo: tempoContainer.topAnchor, constant: 2),
            tempoIndicator.trailingAnchor.constraint(equalTo: tempoContainer.trailingAnchor, constant: -2),
            tempoIndicator.widthAnchor.constraint(equalToConstant: 6),
            tempoIndicator.heightAnchor.constraint(equalToConstant: 6),
            
            micIndicator.widthAnchor.constraint(equalToConstant: 16),
            micIndicator.heightAnchor.constraint(equalToConstant: 16)
        ])

        progressWidthConstraint?.isActive = true
    }

    private func stylePill(_ view: UIView, cornerRadius: CGFloat) {
        view.backgroundColor = .clear
        view.layer.cornerRadius = cornerRadius
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.15
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = cornerRadius
        blur.layer.borderWidth = 0.5
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        blur.clipsToBounds = true
        view.insertSubview(blur, at: 0)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: view.topAnchor),
            blur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: view.bottomAnchor)
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
        
        let color: UIColor = diff < 10 ? .label : (diff < 20 ? ComponentColors.Toast.warningText : ComponentColors.Toast.errorText)
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
            self.progressWidthConstraint?.constant = self.progressTrack.bounds.width * clamped
            self.layoutIfNeeded()
            self.updateGradientFrame()
        }
    }

    func resetForSession() {
        chordDisplay.text = "Play Along Ready"
        tempoValueLabel.text = "0"
        tempoValueLabel.textColor = .label
        tempoIndicator.backgroundColor = .systemGreen
        tempoIndicator.transform = .identity
        progressLabel.text = "0%"
        progressWidthConstraint?.constant = 0
        layoutIfNeeded()
        updateGradientFrame()
        setMicActive(false)
    }
    
    func setMicActive(_ active: Bool) {
        let color: UIColor = active ? .systemGreen : .systemRed
        UIView.animate(withDuration: 0.3) {
            self.micIndicator.backgroundColor = color.withAlphaComponent(0.2)
            self.micIndicator.layer.borderColor = color.withAlphaComponent(0.4).cgColor
            self.micIndicator.subviews.first?.backgroundColor = color
        }
        
        if active {
            if micIndicator.layer.animation(forKey: "pulse") == nil {
                let pulse = CABasicAnimation(keyPath: "transform.scale")
                pulse.duration = 0.6
                pulse.fromValue = 1.0
                pulse.toValue = 1.2
                pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                micIndicator.layer.add(pulse, forKey: "pulse")
            }
        } else {
            micIndicator.layer.removeAnimation(forKey: "pulse")
            micIndicator.transform = .identity
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
        retryButton.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
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
