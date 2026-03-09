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

final class AnimationViewController: UIViewController {

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

    // MARK: - Layout Constants
  private var kPianoH: CGFloat { 140 + (UIApplication.shared.connectedScenes
    .compactMap { $0 as? UIWindowScene }.first?
    .windows.first?.safeAreaInsets.bottom ?? 0) }  // visual height of piano pane
    private let kNavH:   CGFloat = 54

    // MARK: - Overlay timer
    private var hideTimer:        Timer?
    private var didCenterKeyboard = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground
        buildLayout()
        embedPiano()
        wireCallbacks()
        loadChords()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tabBarController?.tabBar.isHidden = false
        navigationController?.setNavigationBarHidden(false, animated: false)
        stopPlayback(reset: true)
    }

    // MARK: - Fix 1: Force Landscape
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    override var shouldAutorotate: Bool { true }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    // MARK: - Layout
    private func buildLayout() {
        // Sheet card: top → bottom - kPianoH (safe area top respected)
        sheetCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sheetCard)

        // Playback overlay (transparent, full screen)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.alpha = 0
        view.addSubview(overlay)

        // Nav bar (liquid glass, overlaid at top)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)
        navBar.setSongTitle(songTitle)

        NSLayoutConstraint.activate([
            // Sheet card fills top portion
            sheetCard.topAnchor.constraint(equalTo: view.topAnchor),
            sheetCard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetCard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
           sheetCard.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -kPianoH),

            // Overlay = full screen
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Nav bar pinned to top safe area
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: kNavH)
        ])

        // Gestures
        let ld = UITapGestureRecognizer(target: self, action: #selector(leftDbl(_:)))
        ld.numberOfTapsRequired = 2
        view.addGestureRecognizer(ld)

        let rd = UITapGestureRecognizer(target: self, action: #selector(rightDbl(_:)))
        rd.numberOfTapsRequired = 2
        view.addGestureRecognizer(rd)

        let st = UITapGestureRecognizer(target: self, action: #selector(singleT(_:)))
        st.numberOfTapsRequired = 1
        st.require(toFail: ld)
        st.require(toFail: rd)
        view.addGestureRecognizer(st)

        overlay.onPlayPause = { [weak self] in
            guard let s = self else { return }
            s.isPlaying ? s.stopPlayback(reset: false) : s.startPlayback()
        }
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
            if let nc = self?.navigationController { nc.popViewController(animated: true) }
            else { self?.dismiss(animated: true) }
        }
        navBar.onTempoChanged = { [weak self] m in self?.tempoMultiplier = m }
        navBar.onMenuTap      = { [weak self] in self?.showSoundPicker() }
    }

    // MARK: - Chord Loading
    private func loadChords() {
        let mgr: PianoDemoManager
        if let data = sheetMusicData {
            mgr = PianoDemoManager(withData: data)
        } else {
            mgr = PianoDemoManager()
        }
        mgr.loadSong(tempoBPM: 84)

        var arr: [SongChord] = []
        while let c = mgr.next() { arr.append(c) }
        allChords     = arr
        totalDuration = arr.reduce(0) { $0 + $1.duration }
        sheetCard.setChordCount(allChords.count)
        if let data = sheetMusicData { sheetCard.loadData(data) }
        print("🎵 \(allChords.count) chords  ~\(String(format: "%.1f", totalDuration))s")
    }

    // MARK: - Gestures
    @objc private func singleT(_ gr: UITapGestureRecognizer) {
        if isPlaying { stopPlayback(reset: false) } else { startPlayback() }
        setOverlay(visible: true, animated: true)
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

    // MARK: - Overlay
    private func setOverlay(visible: Bool, animated: Bool) {
        let block = { 
            self.overlay.alpha = visible ? 1 : 0 
            // Also hide/show the top nav bar (the "fixed" one user doesn't want during playback)
            self.navBar.alpha = visible ? 1 : 0
        }
        animated ? UIView.animate(withDuration: 0.22, animations: block) : block()
    }
    private func showOverlayBriefly() {
        setOverlay(visible: true, animated: true)
        hideTimer?.invalidate()
        guard isPlaying else { return }
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            self?.hideOverlay()
        }
    }
    private func hideOverlay() {
        hideTimer?.invalidate(); hideTimer = nil
        UIView.animate(withDuration: 0.22) { 
            self.overlay.alpha = 0 
            self.navBar.alpha = 0
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
        hideTimer?.invalidate(); hideTimer = nil
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

        if elapsedInChord >= adjDuration {
            elapsedInChord = 0
            isNewChord = true
            chordIndex += 1
        }
    }

    // MARK: - Sound Picker
    private func showSoundPicker() {
        let alert = UIAlertController(title: "Choose Sound", message: nil, preferredStyle: .actionSheet)
        for inst in AudioEngineManager.InstrumentType.allCases {
            alert.addAction(UIAlertAction(title: inst.displayName, style: .default) { _ in
                AudioEngineManager.shared.switchInstrument(to: inst)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = navBar
            pop.sourceRect = CGRect(x: navBar.bounds.maxX - 40, y: navBar.bounds.midY, width: 1, height: 1)
        }
        present(alert, animated: true)
    }
}

// MARK: - PlaybackOverlay (YouTube-style controls)
final class PlaybackOverlay: UIView {

    var onPlayPause: (() -> Void)?

    private let dimView     = UIView()
    private let btnPlay     = UIButton(type: .system)
    private let leftRipple  = SeekRipple(fwd: false)
    private let rightRipple = SeekRipple(fwd: true)

    override init(frame: CGRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { fatalError() }

    func setPlaying(_ p: Bool) {
        let sym = p ? "pause.fill" : "play.fill"
        let cfg = UIImage.SymbolConfiguration(pointSize: 44, weight: .bold)
        btnPlay.setImage(UIImage(systemName: sym, withConfiguration: cfg), for: .normal)
    }
    func ripple(forward: Bool) { (forward ? rightRipple : leftRipple).show() }

    private func build() {
        // Subtle dim overlay
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Play/Pause button
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
            rightRipple.heightAnchor.constraint(equalToConstant: 40)
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
        UIView.animate(withDuration: 0.15, delay: 0,
                       usingSpringWithDamping: 0.5, initialSpringVelocity: 1) {
            self.lbl.transform = .identity
        }
        UIView.animate(withDuration: 0.3, delay: 0.55) { self.lbl.alpha = 0 }
    }
}
