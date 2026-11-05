import UIKit

// MARK: - AnimationViewController
//
// Production-ready landscape animation screen.
//
// Playback follows the score note by note: the score is parsed once into a ScoreTimeline
// (shared with the sheet view), and every struck note of the performance — repeats taken,
// 1st / 2nd endings chosen, D.C. / D.S. followed — becomes a PlayNote with its own start and
// release in seconds (tempo map, fermatas and ties applied; staccato shortens, slurs and
// tenuto hold) and a velocity from the dynamics. A display-link clock moves `position` through
// the performance. Each frame starts the notes whose time has come and releases the ones that
// have ended, so held notes keep sounding (and their keys stay down) under moving ones. The
// clock adds up real frame times × tempo, so the song never drifts from its tempo.

final class AnimationViewController: UIViewController, UIGestureRecognizerDelegate {

    // MARK: - Public Input
    /// Set before pushing to drive playback from uploaded sheet data. Nil = demo song.
    var sheetMusicData: Data?
    var songTitle: String = "Animation"

    // MARK: - Playback State

    /// One struck note of the performance, in seconds at 1× tempo.
    private struct PlayNote {
        let midi: Int
        let isLeft: Bool
        let velocity: Int
        let start: Double
        let release: Double   // by its articulation; ordinary notes leave a hair of silence
    }

    private var timeline:        ScoreTimeline?
    private var playNotes:       [PlayNote] = []   // sorted by start
    private var position:        Double = 0        // seconds into the score at 1×
    private var nextNoteIndex:   Int    = 0
    private var holding:         [Int]  = []       // playNotes whose keys are down
    private var lastFrameTime:   CFTimeInterval?
    private var isPlaying:       Bool   = false
    private var tempoMultiplier: Double = 1.0
    private var displayLink:     CADisplayLink?
    private var totalDuration:   Double = 0        // 1× length of the score in seconds

    // MARK: - Child Views
    private let pianoVC   = PianoAnimationkeyboardViewController()
    private let sheetCard = SheetMusicView()
    private let navBar    = LessonNavBarView()
    private let overlay   = PlaybackOverlay()

    // nav bar, sheet and keyboard share one column, stacked with small even gaps; the
    // keyboard takes about a third of the height, the rest goes to the music
    private let kPianoShare: CGFloat = 0.33
    private let kNavH:   CGFloat = 40
    private let kGap:    CGFloat = 6
    private var navBarTopConstraint: NSLayoutConstraint?
    private var pianoHeightConstraint: NSLayoutConstraint?
    private let column = UILayoutGuide()
    private var columnLeading: NSLayoutConstraint?
    private var columnTrailing: NSLayoutConstraint?

    // MARK: - Overlay timers
    private var overlayHideTimer: Timer?
    private var didCenterKeyboard = false
    private var trackedPracticeSessionStartedAt: Date?

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
        teardownPlaybackResources(reset: true)
        navBar.onBackTap = nil
        navBar.onMenuTap = nil
        navBar.onSeekProgress = nil
        navBar.onTempoChanged = nil
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        }
        self.edgesForExtendedLayout = .all
        view.backgroundColor = ComponentColors.HomeScreen.background
        buildLayout()
        embedPiano()
        wireCallbacks()
        loadChords()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure no safe-area gap remains from portrait transition
        additionalSafeAreaInsets = .zero
        // the column's sides: clear of the Dynamic Island / notch, not the whole landscape
        // safe area (which leaves wide empty bands), and the same on both sides
        let side = max(view.safeAreaInsets.left, view.safeAreaInsets.right)
        let margin = side > 0 ? max(8, side - 10) : 8
        if columnLeading?.constant != margin {
            columnLeading?.constant = margin
            columnTrailing?.constant = -margin
        }
        let pianoHeight = (min(170, max(110, view.bounds.height * kPianoShare))).rounded()
        if pianoHeightConstraint?.constant != pianoHeight { pianoHeightConstraint?.constant = pianoHeight }
        
        // Center keyboard on C4 exactly once after layout is done
        if !didCenterKeyboard && pianoVC.view.bounds.width > 0 {
            didCenterKeyboard = true
            pianoVC.centerOnMiddleC()
        }
        if overlay.alpha == 0 && !playNotes.isEmpty {
            setOverlay(visible: true, animated: false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SupabaseProgressManager.beginTrackedPracticeSessionIfNeeded(&trackedPracticeSessionStartedAt)
        setOverlay(visible: true, animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        tabBarController?.tabBar.isHidden = true
        forceLandscape()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tabBarController?.tabBar.isHidden = false
        navigationController?.setNavigationBarHidden(false, animated: false)
        teardownPlaybackResources(reset: true)

        // Force portrait on exit so the app doesn't stay stuck in landscape mode
        if #available(iOS 16.0, *) {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        SupabaseProgressManager.endTrackedPracticeSession(
            &trackedPracticeSessionStartedAt,
            kind: .animation
        )
    }

    // MARK: - Fix 1: Force Landscape
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
    }

    // MARK: - Layout
    private func buildLayout() {
        // Sheet card: under the nav bar, down to the keyboard
        sheetCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sheetCard)

        // Playback overlay (transparent, full screen)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.alpha = 0
        view.addSubview(overlay)

        // Nav bar (permanently visible at top)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.alpha = 1
        view.addSubview(navBar)

        view.addLayoutGuide(column)
        let topC = navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: kGap)
        navBarTopConstraint = topC
        columnLeading = column.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 52)
        columnTrailing = column.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -52)

        sheetCard.layer.cornerRadius = 12
        sheetCard.layer.cornerCurve = .continuous

        NSLayoutConstraint.activate([
            columnLeading!, columnTrailing!,
            column.topAnchor.constraint(equalTo: view.topAnchor),
            column.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Nav bar pinned to top safe area
            topC,
            navBar.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: kNavH),

            // Sheet card starts under nar bar (its bottom follows the keyboard, see embedPiano)
            sheetCard.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: kGap),
            sheetCard.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            sheetCard.trailingAnchor.constraint(equalTo: column.trailingAnchor),

            // Overlay = full screen
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Gestures
        let ld = UITapGestureRecognizer(target: self, action: #selector(leftDbl(_:)))
        ld.numberOfTapsRequired = 2
        
        let rd = UITapGestureRecognizer(target: self, action: #selector(rightDbl(_:)))
        rd.numberOfTapsRequired = 2
        
        let st = UITapGestureRecognizer(target: self, action: #selector(singleT(_:)))
        st.numberOfTapsRequired = 1
        st.require(toFail: ld)
        st.require(toFail: rd)
        
        [ld, rd, st].forEach { 
            $0.delegate = self
            view.addGestureRecognizer($0) 
        }

        overlay.onPlayPause = { [weak self] in
            guard let s = self else { return }
            s.isPlaying ? s.stopPlayback(reset: false) : s.startPlayback()
        }

        // Removed swipe up/down gestures since NavBar is always visible
    }

    // MARK: - Fix 2: Piano fills to physical bottom (no gap)
    private func embedPiano() {
        addChild(pianoVC)
        pianoVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pianoVC.view)

       NSLayoutConstraint.activate([
            pianoVC.view.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            pianoVC.view.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            pianoVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sheetCard.bottomAnchor.constraint(equalTo: pianoVC.view.topAnchor, constant: -kGap)
        ])
        // the keyboard is the bottom of the column: rounded like the sheet above it
        pianoVC.view.layer.cornerRadius = 12
        pianoVC.view.layer.cornerCurve = .continuous
        pianoVC.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        pianoVC.view.clipsToBounds = true
        let height = pianoVC.view.heightAnchor.constraint(equalToConstant: 112)
        height.isActive = true
        pianoHeightConstraint = height
        pianoVC.didMove(toParent: self)
        pianoVC.setAnimationMode()

        view.bringSubviewToFront(overlay)
        view.bringSubviewToFront(navBar)
    }

    // MARK: - Callbacks
    private func wireCallbacks() {
        navBar.onBackTap = { [weak self] in
            self?.stopPlayback(reset: true)
            if let nc = self?.navigationController, nc.viewControllers.count > 1 {
                nc.popViewController(animated: true)
            } else {
                self?.dismiss(animated: true)
            }
        }
        navBar.onMenuTap      = { [weak self] in self?.toggleSettingsMenu() }
        navBar.onSeekProgress = { [weak self] fraction in
            self?.seekToProgress(CGFloat(fraction))
        }
        navBar.onTempoChanged = { [weak self] tempo in
            self?.tempoMultiplier = tempo
        }
    }

    // MARK: - Score Loading
    private func loadChords() {
        var data = sheetMusicData
        #if DEBUG
        if data == nil, let url = Bundle.main.url(forResource: "sheet_test", withExtension: "json") {
            data = try? Data(contentsOf: url)
        }
        #endif
        guard let data else {
            debugLog("⚠️ [Animation] No sheet data provided")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let parsed = try? ScoreTimeline.parse(data: data)
            DispatchQueue.main.async {
                guard let self else { return }
                guard let parsed else {
                    debugLog("❌ [Animation] Could not read the score")
                    return
                }
                self.apply(parsed)
            }
        }
    }

    private func apply(_ timeline: ScoreTimeline) {
        self.timeline = timeline
        playNotes = Self.playNotes(in: timeline)
        totalDuration = timeline.performanceSeconds
        pianoVC.setHandPerformance(playNotes.map {
            HandNote(midi: $0.midi, isLeft: $0.isLeft, start: $0.start, release: $0.release)
        })
        pianoVC.showHands(at: 0)
        position = 0
        nextNoteIndex = 0
        holding = []
        sheetCard.load(timeline: timeline)
        sheetCard.updateToTick(0)
        navBar.updateProgress(0)
        if overlay.alpha == 0 { setOverlay(visible: true, animated: true) }
        debugLog("🎵 \(playNotes.count) notes, \(timeline.measures.count) measures (\(timeline.performance.count) played), "
                 + "~\(String(format: "%.1f", totalDuration))s, \(String(format: "%g", timeline.tempos.first?.bpm ?? 0)) BPM"
                 + (timeline.keepsElementOrder ? "" : " (no element order: timing per staff and voice)"))
    }

    private static func playNotes(in timeline: ScoreTimeline) -> [PlayNote] {
        var byMeasure: [Int: [ScoreNote]] = [:]
        for note in timeline.notes where note.isStruck { byMeasure[note.measureIndex, default: []].append(note) }
        let time = timeline.performanceTime
        var notes: [PlayNote] = []
        for performed in timeline.performance {
            let measureStart = timeline.measures[performed.measureIndex].startTick
            for note in byMeasure[performed.measureIndex] ?? [] {
                guard let midi = note.midi else { continue }
                let from = Double(performed.tick + note.startTick - measureStart)
                let start = time.seconds(atTick: from)
                let end = time.seconds(atTick: from + Double(note.soundingTicks))
                let release: Double
                if let held = note.heldFraction {
                    // staccato & co. shorten the note; tenuto and slurs hold it to the next one
                    release = held >= 1 ? end - 0.004 : start + max(0.06, (end - start) * held)
                } else {
                    // a short gap so a repeated key is struck again; long notes keep almost all their length
                    release = end - min(0.05, (end - start) * 0.12)
                }
                notes.append(PlayNote(midi: midi, isLeft: note.isLeftHand, velocity: note.velocity,
                                      start: start, release: max(start + 0.03, release)))
            }
        }
        return notes.sorted { $0.start < $1.start }
    }

    // MARK: - Gestures
    @objc private func singleT(_ gr: UITapGestureRecognizer) {
        if isPlaying { stopPlayback(reset: false) } else { startPlayback() }
        showOverlayBriefly()
    }
    @objc private func leftDbl(_ gr: UITapGestureRecognizer) {
        guard gr.location(in: view).x < view.bounds.width * 0.40 else { return }
        seekBy(-5)
        overlay.ripple(forward: false)
        showOverlayBriefly()
    }
    @objc private func rightDbl(_ gr: UITapGestureRecognizer) {
        guard gr.location(in: view).x > view.bounds.width * 0.60 else { return }
        seekBy(5)
        overlay.ripple(forward: true)
        showOverlayBriefly()
    }

    // MARK: - Overlay & Nav Visibility
    private func setOverlay(visible: Bool, animated: Bool) {
        let block = { self.overlay.alpha = visible ? 1 : 0 }
        animated ? UIView.animate(withDuration: 0.22, animations: block) : block()
    }

    private func showOverlayBriefly() {
        setOverlay(visible: true, animated: true)
        overlayHideTimer?.invalidate()
        // Auto-hide after 2 seconds every time as requested
        overlayHideTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            self?.hideOverlay()
        }
    }

    private func hideOverlay() {
        overlayHideTimer?.invalidate(); overlayHideTimer = nil
        UIView.animate(withDuration: 0.22) { 
            self.overlay.alpha = 0 
        }
    }

    // MARK: - Playback
    private func startPlayback() {
        guard !playNotes.isEmpty else { return }
        if position >= totalDuration { position = 0 }
        // keys of notes already held at this point light up again (silently)
        seek(to: position)
        isPlaying = true
        lastFrameTime = nil
        overlay.setPlaying(true)
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        displayLink?.add(to: .main, forMode: .common)
        showOverlayBriefly()
    }

    private func stopPlayback(reset: Bool) {
        isPlaying = false
        displayLink?.invalidate(); displayLink = nil
        releaseAllNotes()
        if reset {
            position = 0
            nextNoteIndex = 0
            sheetCard.resetProgress()
            navBar.updateProgress(0)
            pianoVC.showHands(at: 0)
        }
        overlay.setPlaying(false)
        setOverlay(visible: true, animated: true)
        overlayHideTimer?.invalidate(); overlayHideTimer = nil
    }

    private func teardownPlaybackResources(reset: Bool) {
        stopPlayback(reset: reset)
        displayLink?.invalidate()
        displayLink = nil
        overlayHideTimer?.invalidate()
        overlayHideTimer = nil
        pianoVC.resetKeyboard()
    }

    private func releaseAllNotes() {
        holding = []
        pianoVC.resetKeyboard()
    }

    // MARK: - Seek (backward and forward)
    private func seekBy(_ sec: Double) {
        guard totalDuration > 0 else { return }
        seek(to: position + sec)
    }

    private func seekToProgress(_ p: CGFloat) {
        guard totalDuration > 0 else { return }
        seek(to: totalDuration * Double(max(0, min(1, p))))
        if isPlaying {
            showOverlayBriefly()
        } else {
            setOverlay(visible: true, animated: true)
        }
    }

    /// Jumps to `seconds`: nothing sounds until the next note starts, but keys of notes held
    /// across that point are shown down.
    private func seek(to seconds: Double) {
        position = max(0, min(totalDuration, seconds))
        releaseAllNotes()
        var lo = 0, hi = playNotes.count
        while lo < hi {
            let mid = (lo + hi) / 2
            // a note starting exactly here is still to come, so playing from here strikes it
            if playNotes[mid].start < position { lo = mid + 1 } else { hi = mid }
        }
        nextNoteIndex = lo
        for i in 0..<nextNoteIndex where playNotes[i].release > position {
            pianoVC.noteOn(midi: playNotes[i].midi, isLeft: playNotes[i].isLeft, velocity: playNotes[i].velocity, sound: false)
            holding.append(i)
        }
        syncViews()
    }

    private func syncViews() {
        guard let timeline else { return }
        let performed = timeline.performanceTime.tick(atSeconds: position)
        sheetCard.updateToTick(timeline.scoreTick(atPerformanceTick: performed))
        pianoVC.showHands(at: position)
        if totalDuration > 0 {
            navBar.updateProgress(position / totalDuration)
        }
    }

    // MARK: - Clock
    @objc private func tick(_ link: CADisplayLink) {
        guard isPlaying else { return }
        // real time since the last frame (capped after a stall), scaled by the tempo setting
        let now = link.timestamp
        if let last = lastFrameTime {
            position += min(now - last, 0.1) * tempoMultiplier
        }
        lastFrameTime = now

        // releases first, so a key struck again in the same frame goes down again
        holding.removeAll { i in
            guard playNotes[i].release <= position else { return false }
            pianoVC.noteOff(midi: playNotes[i].midi, isLeft: playNotes[i].isLeft)
            return true
        }
        while nextNoteIndex < playNotes.count && playNotes[nextNoteIndex].start <= position {
            let note = playNotes[nextNoteIndex]
            pianoVC.noteOn(midi: note.midi, isLeft: note.isLeft, velocity: note.velocity, sound: true)
            holding.append(nextNoteIndex)
            nextNoteIndex += 1
        }
        syncViews()

        if position >= totalDuration && holding.isEmpty {
            stopPlayback(reset: true)
        }
    }

    // MARK: - Song Settings Card
    private var settingsCard: SettingsMenuView?

    private func toggleSettingsMenu() {
        if let card = settingsCard {
            UIView.animate(withDuration: 0.25, animations: {
                card.alpha = 0
                card.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }) { _ in
                card.removeFromSuperview()
                self.settingsCard = nil
                self.overlay.isUserInteractionEnabled = true
            }
            return
        }
        
        overlay.isUserInteractionEnabled = false
        let card = SettingsMenuView()
        card.currentTempo = tempoMultiplier
        card.onTempoChanged = { [weak self] newT in
            self?.tempoMultiplier = newT
        }
        card.onInstrumentChanged = { [weak self] inst in
            AudioEngineManager.shared.switchInstrument(to: inst)
        }
        
        card.translatesAutoresizingMaskIntoConstraints = false
        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        view.addSubview(card)
        view.bringSubviewToFront(card)
        self.settingsCard = card
        
        NSLayoutConstraint.activate([
            card.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            card.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 16),
            card.widthAnchor.constraint(equalToConstant: 240)
        ])
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            card.alpha = 1
            card.transform = .identity
        }
    }

    // MARK: - Gesture Delegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let loc = touch.location(in: view)

        // If settings card is open, we block ALL global gestures
        if settingsCard != nil {
            if let card = settingsCard, card.frame.contains(loc) { return false }
            toggleSettingsMenu()
            return false
        }

        // Robust protection: if the touch is anywhere within the navbar's physical bounds, 
        // prevent the background playback gestures from firing.
        if navBar.frame.contains(loc) { return false }

        let hitView = view.hitTest(loc, with: nil)
        if hitView is UIButton || hitView is UISlider { return false }
        
        return true
    }
}

// MARK: - Custom Settings Card UI (Stateful & Interactive)
private final class SettingsMenuView: UIView {
    enum MenuState { case main, tempo, sound }
    private var state: MenuState = .main

    var currentTempo: Double = 1.0 { didSet { tempoValLbl.text = String(format: "%.2g×", currentTempo) } }
    var onTempoChanged: ((Double) -> Void)?
    var onInstrumentChanged: ((AudioEngineManager.InstrumentType) -> Void)?
    
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let mainStack = UIStackView()
    private let titleLabel = UILabel()
    private let tempoValLbl = UILabel()
    private let backBtn = UIButton(type: .system)

    init() {
        super.init(frame: .zero)
        build()
        renderState(.main)
    }
    required init?(coder: NSCoder) { fatalError() }
    
    private func build() {
        blur.layer.cornerRadius = 24
        blur.layer.borderWidth = 0.33 // Ultra-thin "Airy" border
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.isUserInteractionEnabled = true
        blur.contentView.isUserInteractionEnabled = true
        blur.contentView.backgroundColor = UIColor.label.withAlphaComponent(0.04)
        addSubview(blur)

        titleLabel.font = .systemFont(ofSize: 10, weight: .black)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        
        backBtn.setImage(UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)), for: .normal)
        backBtn.tintColor = .secondaryLabel
        backBtn.addTarget(self, action: #selector(goBack), for: .touchUpInside)

        mainStack.axis = .vertical; mainStack.spacing = 16; mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            mainStack.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 20),
            mainStack.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -20),
            mainStack.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -16)
        ])
    }

    private func renderState(_ newState: MenuState) {
        state = newState
        mainStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Header Row
        let header = UIStackView()
        header.axis = .horizontal; header.spacing = 8; header.alignment = .center
        if state != .main { header.addArrangedSubview(backBtn) }
        header.addArrangedSubview(titleLabel)
        let spacer = UIView(); spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(spacer)
        mainStack.addArrangedSubview(header)

        switch state {
        case .main:
            titleLabel.text = "SETTINGS"
            mainStack.addArrangedSubview(makeMenuRow(title: "Change Tempo", icon: "metronome", action: #selector(showTempo)))
            mainStack.addArrangedSubview(makeMenuRow(title: "Choose Sound", icon: "pianokeys", action: #selector(showSound)))
        case .tempo:
            titleLabel.text = "TEMPO"
            let minus = makeIconBtn(sym: "minus.circle.fill", action: #selector(doMinus))
            let plus = makeIconBtn(sym: "plus.circle.fill", action: #selector(doPlus))
            tempoValLbl.font = .monospacedDigitSystemFont(ofSize: 18, weight: .bold)
            tempoValLbl.textColor = .label
            
            let row = UIStackView(arrangedSubviews: [minus, tempoValLbl, plus])
            row.axis = .horizontal; row.spacing = 24; row.alignment = .center; row.distribution = .equalCentering
            mainStack.addArrangedSubview(row)
        case .sound:
            titleLabel.text = "CHOOSE SOUND"
            let soundList = UIStackView()
            soundList.axis = .vertical; soundList.spacing = 8
            
            for inst in AudioEngineManager.InstrumentType.allCases {
                let btn = makeMenuRow(title: instName(for: inst), icon: instIcon(for: inst), action: #selector(instTapped(_:)))
                btn.tag = AudioEngineManager.InstrumentType.allCases.firstIndex(of: inst) ?? 0
                soundList.addArrangedSubview(btn)
            }
            mainStack.addArrangedSubview(soundList)
        }
        
        UIView.animate(withDuration: 0.2) { self.layoutIfNeeded() }
    }

    private func makeMenuRow(title: String, icon: String, action: Selector) -> UIView {
        let btn = UIButton(type: .system)
        btn.backgroundColor = UIColor.label.withAlphaComponent(0.04)
        btn.layer.cornerRadius = 14
        btn.contentHorizontalAlignment = .leading
        btn.addTarget(self, action: action, for: .touchUpInside)
        
        let img = UIImageView(image: UIImage(systemName: icon))
        img.tintColor = BrandColors.brand; img.contentMode = .scaleAspectFit
        img.widthAnchor.constraint(equalToConstant: 20).isActive = true
        
        let lbl = UILabel()
        lbl.text = title; lbl.font = .systemFont(ofSize: 15, weight: .medium); lbl.textColor = .label
        
        let arrow = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)))
        arrow.tintColor = .tertiaryLabel; arrow.contentMode = .scaleAspectFit
        
        let stack = UIStackView(arrangedSubviews: [img, lbl, UIView(), arrow])
        stack.axis = .horizontal; stack.spacing = 12; stack.alignment = .center; stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        btn.addSubview(stack)
        
        NSLayoutConstraint.activate([
            btn.heightAnchor.constraint(equalToConstant: 48),
            stack.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: btn.centerYAnchor)
        ])
        return btn
    }

    private func makeIconBtn(sym: String, action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: sym, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)), for: .normal)
        b.tintColor = BrandColors.brand; b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    private func instName(for type: AudioEngineManager.InstrumentType) -> String {
        switch type {
        case .grandPiano: return "Grand Piano"
        case .electricPiano: return "Electric Piano"
        }
    }

    private func instIcon(for type: AudioEngineManager.InstrumentType) -> String {
        switch type {
        case .grandPiano: return "pianokeys"
        case .electricPiano: return "bolt.fill"
        }
    }

    @objc private func goBack() { renderState(.main) }
    @objc private func showTempo() { renderState(.tempo) }
    @objc private func showSound() { renderState(.sound) }
    @objc private func doMinus() { adjustTempo(-0.25) }
    @objc private func doPlus() { adjustTempo(0.25) }
    
    private func adjustTempo(_ delta: Double) {
        currentTempo = max(0.5, min(2.0, currentTempo + delta))
        currentTempo = (currentTempo * 4).rounded() / 4
        onTempoChanged?(currentTempo)
    }
    
    @objc private func instTapped(_ sender: UIButton) {
        let type = AudioEngineManager.InstrumentType.allCases[sender.tag]
        onInstrumentChanged?(type)
        
        // Flash feedback
        UIView.animate(withDuration: 0.1) {
            sender.backgroundColor = BrandColors.brand.withAlphaComponent(0.2)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) { sender.backgroundColor = UIColor.label.withAlphaComponent(0.04) }
            self.goBack() 
        }
    }
}

// MARK: - PlaybackOverlay (YouTube-style controls)
final class PlaybackOverlay: UIView {
    var onPlayPause: (() -> Void)?
    private let dimView     = UIView()
    private let btnPlay     = UIButton(type: .system)
    private let leftRipple  = SeekRipple(fwd: false)
    private let rightRipple = SeekRipple(fwd: true)
    private let hintsLabel  = UILabel()

    override init(frame: CGRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { fatalError() }

    func setPlaying(_ p: Bool) {
        let sym = p ? "pause.fill" : "play.fill"
        let cfg = UIImage.SymbolConfiguration(pointSize: 44, weight: .bold)
        btnPlay.setImage(UIImage(systemName: sym, withConfiguration: cfg), for: .normal)
    }
    func ripple(forward: Bool) { (forward ? rightRipple : leftRipple).show() }

    private func build() {
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let cfg = UIImage.SymbolConfiguration(pointSize: 44, weight: .bold)
        btnPlay.setImage(UIImage(systemName: "play.fill", withConfiguration: cfg), for: .normal)
        btnPlay.tintColor = .white
        btnPlay.layer.shadowColor   = UIColor.black.cgColor
        btnPlay.layer.shadowOpacity = 0.6
        btnPlay.layer.shadowRadius  = 6
        btnPlay.addTarget(self, action: #selector(pl), for: .touchUpInside)
        btnPlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(btnPlay)

        leftRipple.translatesAutoresizingMaskIntoConstraints  = false
        rightRipple.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leftRipple)
        addSubview(rightRipple)
        
        hintsLabel.text = "Tap to Play • Double-tap to Seek • Slide Navbar to Scrub"
        hintsLabel.font = .systemFont(ofSize: 11, weight: .medium)
        hintsLabel.textColor = .white.withAlphaComponent(0.8)
        hintsLabel.textAlignment = .center
        hintsLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hintsLabel)

        NSLayoutConstraint.activate([
            btnPlay.centerXAnchor.constraint(equalTo: centerXAnchor),
            btnPlay.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftRipple.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            leftRipple.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftRipple.widthAnchor.constraint(equalToConstant: 70),
            leftRipple.heightAnchor.constraint(equalToConstant: 40),
            rightRipple.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            rightRipple.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightRipple.widthAnchor.constraint(equalToConstant: 70),
            rightRipple.heightAnchor.constraint(equalToConstant: 40),
            hintsLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            hintsLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }
    @objc private func pl() { onPlayPause?() }
}

// MARK: - SeekRipple (±5 s feedback label)
final class SeekRipple: UIView {
    private let lbl = UILabel()
    init(fwd: Bool) {
        super.init(frame: .zero)
        lbl.text          = fwd ? "▷▷ 5s" : "5s ◁◁"
        lbl.font          = .systemFont(ofSize: 14, weight: .semibold)
        lbl.textColor     = .white
        lbl.textAlignment = .center
        lbl.alpha         = 0
        lbl.layer.shadowColor   = UIColor.black.cgColor
        lbl.layer.shadowOpacity = 0.75
        lbl.layer.shadowRadius  = 3
        lbl.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: topAnchor),
            lbl.leadingAnchor.constraint(equalTo: leadingAnchor),
            lbl.trailingAnchor.constraint(equalTo: trailingAnchor),
            lbl.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func show() {
        lbl.alpha     = 1
        lbl.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 1) {
            self.lbl.transform = .identity
        }
        UIView.animate(withDuration: 0.3, delay: 0.55) { self.lbl.alpha = 0 }
    }
}
