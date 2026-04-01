import UIKit

// MARK: - AnimationViewController
//
// Production-ready landscape animation screen.
// Fixes:
//   1. Forced landscape — view overrides orientation + SongDetailsPage forces rotation on push
//   2. Keyboard gap — piano fills to physical bottom edge via bottomAnchor
//   3. Sheet music — rendered in landscape frame with correct spacing
//   4. Backward seek — elapsedTotal is recomputed from chordIndex after seek
//   5. Tempo sync — progress fraction denominator is totalDuration / tempoMultiplier
//   6. iOS-native aesthetic — liquid glass nav, clean layout

final class AnimationViewController: UIViewController, UIGestureRecognizerDelegate {

    // MARK: - Public Input
    /// Set before pushing to drive playback from uploaded sheet data. Nil = demo song.
    var sheetMusicData: Data?
    var songTitle: String = "Animation"

    // MARK: - Playback State
    private var allChords:       [SongChord] = []
    private var chordIndex:      Int    = 0
    private var elapsedInChord:  Double = 0   // seconds elapsed in current chord (real time)
    private var isNewChord:      Bool   = true
    private var isPlaying:       Bool   = false
    private var tempoMultiplier: Double = 1.0
    private var displayLink:     CADisplayLink?
    private var totalDuration:   Double = 0   // natural (1×) total duration in seconds

    // elapsedTotal tracks real-wall time elapsed so progress stays in sync with tempo
    private var elapsedTotal:    Double = 0

    // MARK: - Child Views
    private let pianoVC   = PianoAnimationkeyboardViewController()
    private let sheetCard = SheetMusicView()
    private let navBar    = LessonNavBarView()
    private let overlay   = PlaybackOverlay()

    private let kPianoH: CGFloat = 170  // visual height of piano pane
    private let kNavH:   CGFloat = 54
    private var navBarTopConstraint: NSLayoutConstraint?

    // MARK: - Overlay timers
    private var overlayHideTimer: Timer?
    private var didCenterKeyboard = false

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
        view.backgroundColor = UIColor.systemBackground
        buildLayout()
        embedPiano()
        wireCallbacks()
        loadChords()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure no safe-area gap remains from portrait transition
        additionalSafeAreaInsets = .zero
        
        // Center keyboard on C4 exactly once after layout is done
        if !didCenterKeyboard && pianoVC.view.bounds.width > 0 {
            didCenterKeyboard = true
            pianoVC.centerOnMiddleC()
        }
        if overlay.alpha == 0 && !allChords.isEmpty {
            setOverlay(visible: true, animated: false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
        // Sheet card: top → bottom - kPianoH (safe area top respected)
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

        let topC = navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12)
        navBarTopConstraint = topC

        NSLayoutConstraint.activate([
            // Nav bar pinned to top safe area
            topC,
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: kNavH),

            // Sheet card starts under nar bar
            sheetCard.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 10),
            sheetCard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetCard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheetCard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -kPianoH),

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
    pianoVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
    pianoVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    pianoVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    pianoVC.view.topAnchor.constraint(equalTo: view.bottomAnchor, constant: -kPianoH)
])
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
        }
    }

    // MARK: - Chord Loading
    private func loadChords() {
        let mgr: PianoDemoManager
        if let data = sheetMusicData {
            mgr = PianoDemoManager(withData: data)
        } else {
            #if DEBUG
            mgr = PianoDemoManager()
            #else
            allChords = []
            totalDuration = 0
            sheetCard.setChordCount(0)
            debugLog("⚠️ [Animation] No sheet data provided")
            return
            #endif
        }
        mgr.loadSong(tempoBPM: 84)

        var arr: [SongChord] = []
        while let c = mgr.next() { arr.append(c) }
        allChords     = arr
        totalDuration = arr.reduce(0) { $0 + $1.duration }
        sheetCard.setChordCount(allChords.count)
        if let data = sheetMusicData { sheetCard.loadData(data) }
        debugLog("🎵 \(allChords.count) chords  ~\(String(format: "%.1f", totalDuration))s")
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
        guard !allChords.isEmpty else { return }
        if chordIndex >= allChords.count {
            chordIndex = 0; elapsedInChord = 0; elapsedTotal = 0; isNewChord = true
        }
        isPlaying = true
        overlay.setPlaying(true)
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        displayLink?.add(to: .main, forMode: .common)
        showOverlayBriefly()
    }

    private func stopPlayback(reset: Bool) {
        isPlaying = false
        displayLink?.invalidate(); displayLink = nil
        AudioEngineManager.shared.stopAllNotes()
        if reset {
            pianoVC.resetKeyboard()
            chordIndex = 0; elapsedInChord = 0; elapsedTotal = 0
            isNewChord = true
            sheetCard.resetProgress()
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

    // MARK: - Fix 4: Seek (backward and forward)
    private func seekBy(_ sec: Double) {
        guard totalDuration > 0 else { return }

        // Compute current absolute time from chord index + elapsed-in-chord
        var t = 0.0
        for i in 0..<chordIndex { t += allChords[i].duration }
        t += elapsedInChord * tempoMultiplier   // convert chord-local time to real-wall time

        let newT = max(0, min(totalDuration, t + sec))

        // Walk chords to find new index
        var acc = 0.0
        var found = false
        for i in 0..<allChords.count {
            let d = allChords[i].duration
            if acc + d > newT {
                chordIndex    = i
                // Fix 4: elapsedInChord in chord-local time units
                elapsedInChord = (newT - acc) / tempoMultiplier
                found = true
                break
            }
            acc += d
        }
        if !found {
            chordIndex    = allChords.count - 1
            elapsedInChord = 0
        }

        // Fix 4: recompute elapsedTotal from new chordIndex so progress is consistent
        elapsedTotal = 0
        for i in 0..<chordIndex { elapsedTotal += allChords[i].duration }
        elapsedTotal += elapsedInChord * tempoMultiplier

        isNewChord = true
        AudioEngineManager.shared.stopAllNotes()
        pianoVC.resetKeyboard()

        // Sync sheet directly to the exact interpolated tick
        let cTick = Double(allChords[chordIndex].globalTick)
        let nTick = chordIndex + 1 < allChords.count ? Double(allChords[chordIndex + 1].globalTick) : cTick
        let adjDur = allChords[chordIndex].duration / tempoMultiplier
        let fraction = adjDur > 0 ? min(elapsedInChord / adjDur, 1.0) : 0
        sheetCard.updateToTick(cTick + (nTick - cTick) * fraction)
        
        if totalDuration > 0 {
            navBar.updateProgress(newT / totalDuration)
        }
    }

    private func seekToProgress(_ p: CGFloat) {
        guard totalDuration > 0 else { return }
        let targetTime = totalDuration * Double(max(0, min(1, p)))
        
        // Find chord index
        var acc = 0.0
        var foundIdx = 0
        var foundElapsed = 0.0
        
        for i in 0..<allChords.count {
            let d = allChords[i].duration
            if acc + d > targetTime {
                foundIdx = i
                foundElapsed = (targetTime - acc) / tempoMultiplier
                break
            }
            acc += d
            if i == allChords.count - 1 {
                foundIdx = i
                foundElapsed = 0
            }
        }
        
        chordIndex = foundIdx
        elapsedInChord = foundElapsed
        
        // Match Fix 4 logic for consistency
        elapsedTotal = 0
        for i in 0..<chordIndex { elapsedTotal += allChords[i].duration }
        elapsedTotal += elapsedInChord * tempoMultiplier
        
        isNewChord = true
        AudioEngineManager.shared.stopAllNotes()
        pianoVC.resetKeyboard()
        
        // Update sheet
        let cTick = Double(allChords[chordIndex].globalTick)
        let nTick = chordIndex + 1 < allChords.count ? Double(allChords[chordIndex + 1].globalTick) : cTick
        let adjDur = allChords[chordIndex].duration / tempoMultiplier
        let fraction = adjDur > 0 ? min(elapsedInChord / adjDur, 1.0) : 0
        sheetCard.updateToTick(cTick + (nTick - cTick) * fraction)
        
        navBar.updateProgress(Double(p))
        
        // If we were playing, keep playhead logic moving
        if isPlaying {
            // briefly show overlay to confirm interaction
            showOverlayBriefly()
        } else {
            setOverlay(visible: true, animated: true)
        }
    }

    // MARK: - Fix 5: Tick — tempo-aware progress
    @objc private func tick(_ link: CADisplayLink) {
        guard isPlaying, chordIndex < allChords.count else {
            if isPlaying { stopPlayback(reset: true) }
            return
        }

        let chord = allChords[chordIndex]
        // Adjusted chord duration at current tempo
        let adjDuration = chord.duration / tempoMultiplier

        if isNewChord {
            isNewChord = false
            pianoVC.playChord(left: chord.leftHandNotes, right: chord.rightHandNotes, duration: adjDuration)
        }

        elapsedInChord += link.duration   // real-wall time elapsed in this chord
        elapsedTotal   += link.duration   // real-wall total (at whatever tempo)

        // Perfect Sync: Interpolate exact tick position and map directly to sheet
        let currentTick = Double(chord.globalTick)
        let nextTick: Double
        if chordIndex + 1 < allChords.count {
            nextTick = Double(allChords[chordIndex + 1].globalTick)
        } else {
            nextTick = currentTick + (chord.duration * 10.0) // pad end
        }
        
        let fraction = min(elapsedInChord / adjDuration, 1.0)
        let exactTick = currentTick + (nextTick - currentTick) * fraction
        
        sheetCard.updateToTick(exactTick)
        
        if totalDuration > 0 {
            navBar.updateProgress(Float(elapsedTotal / totalDuration))
        }

        // Safely determine global percentage across the whole song
        if totalDuration > 0 {
            var acc = 0.0
            for i in 0..<chordIndex { acc += allChords[i].duration }
            let absoluteTimeVal = acc + (elapsedInChord * tempoMultiplier)
            let overallProgress = absoluteTimeVal / totalDuration
            navBar.updateProgress(overallProgress)
        }

        if elapsedInChord >= adjDuration {
            elapsedInChord = 0
            isNewChord = true
            chordIndex += 1
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
        case .organ: return "Pipe Organ"
        }
    }

    private func instIcon(for type: AudioEngineManager.InstrumentType) -> String {
        switch type {
        case .grandPiano: return "pianokeys"
        case .electricPiano: return "bolt.fill"
        case .organ: return "music.note.list"
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
