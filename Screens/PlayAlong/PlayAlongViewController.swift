import UIKit
import AVFoundation

// MARK: - PlayAlongViewController
//
// Practice mode: the score waits for you. Each step lights the keys to play (left hand blue,
// right hand red) with the fingers to use in the corner, and highlights the notes on the page;
// play them on a keyboard connected by USB (MIDI), on your piano (the microphone listens) or on
// the screen keyboard and it moves on. While a MIDI keyboard is connected the microphone is off:
// the keyboard says exactly which keys were played.
// Wrong notes flash red and are marked on the page. The bar at the top shows the notes to
// play, your progress, your tempo against the score's, the microphone, which hands you are
// practising, and a skip button. At the end a report sums up accuracy, mistakes and tempo.
//
// The screen shares Animation's layout: nav bar, page and keyboard in one column.

final class PlayAlongViewController: UIViewController {

    var sheetMusicData: Data?

    // MARK: Views
    private let navBar = PlayAlongNavBar()
    private let sheetMusic = SheetMusicView()
    private let keyboard = PianoAnimationkeyboardViewController()
    private let reportView = PlayAlongReportView()
    private let loadingView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let loadingLabel = UILabel()

    private let column = UILayoutGuide()
    private var columnLeading: NSLayoutConstraint?
    private var columnTrailing: NSLayoutConstraint?
    private var keyboardHeight: NSLayoutConstraint?
    private let kNavH: CGFloat = 40
    private let kGap: CGFloat = 6
    private let kPianoShare: CGFloat = 0.33

    // MARK: State
    private let listener = PianoListener()
    private let midiInput = MIDIKeyboardInput()
    private var usesMIDI: Bool { !midiInput.devices.isEmpty }
    private var session: PlayAlongSession?
    private var timeline: ScoreTimeline?
    private var trackedPracticeSessionStartedAt: Date?
    private var lastHeard: CFTimeInterval = 0

    init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        hidesBottomBarWhenPushed = true
    }

    deinit {
        listener.stop()
        midiInput.stop()
    }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        edgesForExtendedLayout = .all
        view.backgroundColor = ComponentColors.HomeScreen.background
        buildLayout()
        wireCallbacks()
        listener.onFrame = { [weak self] frame in self?.heard(frame) }
        midiInput.onNote = { [weak self] midi, _, time in self?.pressed(midi, at: time) }
        midiInput.onDevicesChanged = { [weak self] _ in self?.inputsChanged() }
        midiInput.start()
        loadScore()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        tabBarController?.tabBar.isHidden = true
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
            (view.window?.windowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene)?
                .requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SupabaseProgressManager.beginTrackedPracticeSessionIfNeeded(&trackedPracticeSessionStartedAt)
        if session != nil, session?.isFinished == false { startInput(askIfNeeded: true) }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        listener.stop()
        tabBarController?.tabBar.isHidden = false
        navigationController?.setNavigationBarHidden(false, animated: false)
        if #available(iOS 16.0, *) {
            (view.window?.windowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene)?
                .requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        SupabaseProgressManager.endTrackedPracticeSession(&trackedPracticeSessionStartedAt, kind: .playAlong)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        additionalSafeAreaInsets = .zero
        let side = max(view.safeAreaInsets.left, view.safeAreaInsets.right)
        let margin = side > 0 ? max(8, side - 10) : 8
        if columnLeading?.constant != margin {
            columnLeading?.constant = margin
            columnTrailing?.constant = -margin
        }
        let height = (min(170, max(110, view.bounds.height * kPianoShare))).rounded()
        if keyboardHeight?.constant != height { keyboardHeight?.constant = height }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    // MARK: Layout

    private func buildLayout() {
        view.addLayoutGuide(column)
        sheetMusic.layer.cornerRadius = 12
        sheetMusic.layer.cornerCurve = .continuous

        addChild(keyboard)
        [navBar, sheetMusic, keyboard.view, reportView, loadingView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        keyboard.didMove(toParent: self)
        keyboard.view.layer.cornerRadius = 12
        keyboard.view.layer.cornerCurve = .continuous
        keyboard.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        keyboard.view.clipsToBounds = true

        let leading = column.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 52)
        let trailing = column.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -52)
        let height = keyboard.view.heightAnchor.constraint(equalToConstant: 130)
        columnLeading = leading; columnTrailing = trailing; keyboardHeight = height

        let loadingStack = UIStackView(arrangedSubviews: [loadingIndicator, loadingLabel])
        loadingStack.axis = .vertical
        loadingStack.alignment = .center
        loadingStack.spacing = 12
        loadingStack.translatesAutoresizingMaskIntoConstraints = false
        loadingView.contentView.addSubview(loadingStack)
        loadingView.contentView.backgroundColor = ComponentColors.HomeScreen.background.withAlphaComponent(0.55)
        loadingLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        loadingLabel.textColor = .label
        loadingLabel.text = "Preparing Play Along…"

        NSLayoutConstraint.activate([
            leading, trailing, height,
            column.topAnchor.constraint(equalTo: view.topAnchor),
            column.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: kGap),
            navBar.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: kNavH),

            sheetMusic.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: kGap),
            sheetMusic.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            sheetMusic.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            sheetMusic.bottomAnchor.constraint(equalTo: keyboard.view.topAnchor, constant: -kGap),

            keyboard.view.leadingAnchor.constraint(equalTo: column.leadingAnchor),
            keyboard.view.trailingAnchor.constraint(equalTo: column.trailingAnchor),
            keyboard.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            reportView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            reportView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            reportView.widthAnchor.constraint(equalToConstant: 440),
            reportView.heightAnchor.constraint(equalToConstant: 300),

            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingStack.centerXAnchor.constraint(equalTo: loadingView.contentView.centerXAnchor),
            loadingStack.centerYAnchor.constraint(equalTo: loadingView.contentView.centerYAnchor)
        ])
        reportView.isHidden = true
        reportView.alpha = 0
        loadingIndicator.startAnimating()
    }

    private func wireCallbacks() {
        navBar.onBack = { [weak self] in self?.close() }
        navBar.onMic = { [weak self] in self?.micTapped() }
        navBar.onHands = { [weak self] in self?.cycleHands() }
        navBar.onSkip = { [weak self] in self?.skip() }
        keyboard.setPlayAlongMode { [weak self] midi in self?.touched(midi) }
        reportView.onRetry = { [weak self] in self?.restart() }
        reportView.onDone = { [weak self] in self?.close() }
        #if DEBUG
        // in the simulator there is no piano: long-press the prompt to play the current step
        navBar.onDebugPlayStep = { [weak self] in
            guard let self, let session = self.session else { return }
            for midi in session.remaining.sorted() { self.touched(midi) }
        }
        #endif
    }

    // MARK: Score

    private func loadScore() {
        guard let data = sheetMusicData else {
            hideLoading()
            presentUnavailable()
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let timeline = try? ScoreTimeline.parse(data: data)
            DispatchQueue.main.async {
                guard let self else { return }
                self.hideLoading()
                guard let timeline else { self.presentUnavailable(); return }
                self.start(with: timeline)
            }
        }
    }

    /// Fades the loading cover out; it stops taking touches at once (a fading blur view still
    /// catches them, which kept the keyboard from working).
    private func hideLoading() {
        loadingView.isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.25) {
            self.loadingView.contentView.alpha = 0
            self.loadingView.effect = nil
        } completion: { _ in
            self.loadingView.isHidden = true
        }
    }

    private func start(with timeline: ScoreTimeline) {
        self.timeline = timeline
        let session = PlayAlongSession(timeline: timeline)
        guard !session.steps.isEmpty else { presentUnavailable(); return }
        self.session = session
        session.restart()
        sheetMusic.load(timeline: timeline)
        // the fingers for every step (one second per step, for the hands' plan)
        var notes: [HandNote] = []
        for (i, step) in session.steps.enumerated() {
            for midi in step.left { notes.append(HandNote(midi: midi, isLeft: true, start: Double(i), release: Double(i) + 0.8)) }
            for midi in step.right { notes.append(HandNote(midi: midi, isLeft: false, start: Double(i), release: Double(i) + 0.8)) }
        }
        keyboard.setHandPerformance(notes)
        navBar.setHands(session.hands.label)
        refresh()
        if view.window != nil { startInput(askIfNeeded: true) }
    }

    /// Shows the current step everywhere.
    private func refresh() {
        guard let session else { return }
        guard let step = session.current else { return }
        let hands = session.hands
        let left = hands == .right ? [] : step.left
        let right = hands == .left ? [] : step.right
        keyboard.showExpected(left: left.filter { !session.hit.contains($0) }, right: right.filter { !session.hit.contains($0) })
        keyboard.showHands(at: Double(session.index) + 0.5)
        sheetMusic.updateToTick(Double(step.tick) + 0.01)
        navBar.setPrompt(left: left, right: right, done: session.hit, names: step.names)
        navBar.setProgress(session.progress)
        navBar.setTempo(played: session.playedBPM, target: session.targetBPM)
    }

    // MARK: Input

    private func heard(_ frame: PianoPitchAnalyzer.Frame) {
        guard !usesMIDI else { return }
        if frame.level > -50 { lastHeard = CACurrentMediaTime() }
        navBar.setMic(.listening(hearing: CACurrentMediaTime() - lastHeard < 0.4))
        guard let session, !session.isFinished, reportView.isHidden else { return }
        handle(session.listen(frame))
    }

    private func pressed(_ midi: Int, at time: Double) {
        guard let session, !session.isFinished, reportView.isHidden else { return }
        handle(session.key(midi, at: time))
    }

    private func touched(_ midi: Int) {
        guard let session, !session.isFinished else { return }
        handle(session.touch(midi, at: CACurrentMediaTime()))
    }

    private func handle(_ events: [PlayAlongSession.Event]) {
        guard let session else { return }
        var moved = false
        for event in events {
            switch event {
            case .hit(let midi):
                keyboard.flash(midi: midi, correct: true)
            case .wrong(let midi):
                keyboard.flash(midi: midi, correct: false)
                if let tick = session.current?.tick { sheetMusic.addWrongNoteMarker(at: Double(tick)) }
                navBar.shakePrompt()
            case .advanced:
                moved = true
            case .finished:
                finish()
                return
            }
        }
        if moved || !events.isEmpty { refresh() }
    }

    private func cycleHands() {
        guard let session else { return }
        let events = session.setHands(session.hands.next)
        navBar.setHands(session.hands.label)
        handle(events)
        refresh()
    }

    private func skip() {
        guard let session, !session.isFinished else { return }
        handle(session.skip(at: CACurrentMediaTime()))
        refresh()
    }

    // MARK: Microphone and MIDI

    /// A MIDI keyboard when one is connected, else the microphone.
    private func startInput(askIfNeeded: Bool) {
        if usesMIDI {
            listener.stop()
            navBar.setMic(.keyboard(midiInput.devices.first?.name ?? "Keyboard"))
        } else {
            startListening(askIfNeeded: askIfNeeded)
        }
    }

    /// A keyboard was plugged in or out.
    private func inputsChanged() {
        guard session != nil, session?.isFinished == false, view.window != nil else {
            if usesMIDI { navBar.setMic(.keyboard(midiInput.devices.first?.name ?? "Keyboard")) }
            return
        }
        startInput(askIfNeeded: false)
    }

    private func startListening(askIfNeeded: Bool) {
        switch PianoListener.permission {
        case .granted:
            if listener.start() {
                navBar.setMic(.listening(hearing: false))
            } else {
                navBar.setMic(.off)
            }
        case .undetermined where askIfNeeded:
            // the system's own prompt only; Play Along also works with the screen keyboard
            PianoListener.requestPermission { [weak self] granted in
                if granted { self?.startListening(askIfNeeded: false) } else { self?.navBar.setMic(.denied) }
            }
        case .denied:
            navBar.setMic(.denied)
        default:
            navBar.setMic(.off)
        }
    }

    private func micTapped() {
        if usesMIDI {
            let names = midiInput.devices.map(\.name).joined(separator: ", ")
            let alert = UIAlertController(title: "Keyboard connected",
                                          message: "Play Along is following \(names). Unplug it to use the microphone instead.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        switch PianoListener.permission {
        case .denied:
            let alert = UIAlertController(title: "Microphone is off",
                                          message: "Allow microphone access in Settings so Play Along can hear your piano. You can also play on the screen keyboard.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            })
            present(alert, animated: true)
        default:
            if listener.isListening {
                listener.stop()
                navBar.setMic(.off)
            } else {
                startListening(askIfNeeded: true)
            }
        }
    }

    // MARK: End

    private func finish() {
        guard let session else { return }
        listener.stop()
        if !usesMIDI { navBar.setMic(.off) }
        navBar.setProgress(1)
        navBar.setPrompt(left: [], right: [], done: [], names: [:])
        keyboard.showExpected(left: [], right: [])
        reportView.configure(session.result)
        reportView.isHidden = false
        reportView.alpha = 0
        reportView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        UIView.animate(withDuration: 0.4, delay: 0.3, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5) {
            self.reportView.alpha = 1
            self.reportView.transform = .identity
        }
    }

    private func restart() {
        guard let session else { return }
        UIView.animate(withDuration: 0.2) { self.reportView.alpha = 0 } completion: { _ in self.reportView.isHidden = true }
        session.restart()
        sheetMusic.resetProgress()
        refresh()
        startInput(askIfNeeded: false)
    }

    private func close() {
        listener.stop()
        midiInput.stop()
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func presentUnavailable() {
        let alert = UIAlertController(title: "Play Along Unavailable",
                                      message: "This song could not be prepared for Play Along. Please try another song or reopen this one.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in self?.close() })
        present(alert, animated: true)
    }
}

// MARK: - PlayAlongNavBar
//
// ( ‹ )  ( Play  C4 · E4 · G4 )  ( ▬▬▬ 42%  ♩ 72/108  🎙  L+R  ⏭ )

final class PlayAlongNavBar: UIView {
    enum Mic { case off, denied, listening(hearing: Bool), keyboard(String) }

    var onBack: (() -> Void)?
    var onMic: (() -> Void)?
    var onHands: (() -> Void)?
    var onSkip: (() -> Void)?
    var onDebugPlayStep: (() -> Void)?

    private let backButton = UIButton(type: .system)
    private let promptLabel = UILabel()
    private let promptPill = UIView()
    private let statusPill = UIView()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private let progressLabel = UILabel()
    private let tempoLabel = UILabel()
    private let micButton = UIButton(type: .system)
    private let handsButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)
    private var progressWidth: NSLayoutConstraint?
    private var progress: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        let backPill = pill(radius: 20)
        let symbol = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: symbol), for: .normal)
        backButton.tintColor = .label
        backButton.addTarget(self, action: #selector(back), for: .touchUpInside)

        promptLabel.font = .systemFont(ofSize: 17, weight: .bold)
        promptLabel.textAlignment = .center
        promptLabel.adjustsFontSizeToFitWidth = true
        promptLabel.minimumScaleFactor = 0.7
        promptLabel.text = "Getting ready…"
        let press = UILongPressGestureRecognizer(target: self, action: #selector(debugPlay(_:)))
        promptPill.addGestureRecognizer(press)

        progressTrack.backgroundColor = UIColor.label.withAlphaComponent(0.08)
        progressTrack.layer.cornerRadius = 3
        progressTrack.clipsToBounds = true
        progressFill.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        progressFill.layer.cornerRadius = 3
        progressLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        progressLabel.textColor = .secondaryLabel
        progressLabel.text = "0%"

        tempoLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        tempoLabel.textColor = .secondaryLabel
        tempoLabel.text = "♩ –"

        let small = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        micButton.setImage(UIImage(systemName: "mic.slash.fill", withConfiguration: small), for: .normal)
        micButton.tintColor = .systemGray
        micButton.addTarget(self, action: #selector(mic), for: .touchUpInside)
        handsButton.setTitle("L+R", for: .normal)
        handsButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .heavy)
        handsButton.tintColor = .label
        handsButton.addTarget(self, action: #selector(hands), for: .touchUpInside)
        skipButton.setImage(UIImage(systemName: "forward.end.fill", withConfiguration: small), for: .normal)
        skipButton.tintColor = .label
        skipButton.addTarget(self, action: #selector(skip), for: .touchUpInside)

        let status = UIStackView(arrangedSubviews: [progressTrack, progressLabel, tempoLabel, micButton, handsButton, skipButton])
        status.axis = .horizontal
        status.alignment = .center
        status.spacing = 10
        status.setCustomSpacing(6, after: progressTrack)

        [backPill, promptPill, statusPill].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        [backButton, promptLabel, status, progressFill].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        backPill.addSubview(backButton)
        promptPill.addSubview(promptLabel)
        statusPill.addSubview(status)
        progressTrack.addSubview(progressFill)
        style(promptPill, radius: 17)
        style(statusPill, radius: 20)

        let width = progressFill.widthAnchor.constraint(equalToConstant: 0)
        progressWidth = width
        NSLayoutConstraint.activate([
            backPill.leadingAnchor.constraint(equalTo: leadingAnchor),
            backPill.centerYAnchor.constraint(equalTo: centerYAnchor),
            backPill.widthAnchor.constraint(equalToConstant: 40),
            backPill.heightAnchor.constraint(equalToConstant: 40),
            backButton.topAnchor.constraint(equalTo: backPill.topAnchor),
            backButton.bottomAnchor.constraint(equalTo: backPill.bottomAnchor),
            backButton.leadingAnchor.constraint(equalTo: backPill.leadingAnchor),
            backButton.trailingAnchor.constraint(equalTo: backPill.trailingAnchor),

            statusPill.trailingAnchor.constraint(equalTo: trailingAnchor),
            statusPill.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusPill.heightAnchor.constraint(equalToConstant: 40),
            status.leadingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: 14),
            status.trailingAnchor.constraint(equalTo: statusPill.trailingAnchor, constant: -12),
            status.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),

            promptPill.leadingAnchor.constraint(equalTo: backPill.trailingAnchor, constant: 8),
            promptPill.trailingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: -8),
            promptPill.centerYAnchor.constraint(equalTo: centerYAnchor),
            promptPill.heightAnchor.constraint(equalToConstant: 34),
            promptLabel.leadingAnchor.constraint(equalTo: promptPill.leadingAnchor, constant: 14),
            promptLabel.trailingAnchor.constraint(equalTo: promptPill.trailingAnchor, constant: -14),
            promptLabel.centerYAnchor.constraint(equalTo: promptPill.centerYAnchor),

            progressTrack.widthAnchor.constraint(equalToConstant: 70),
            progressTrack.heightAnchor.constraint(equalToConstant: 6),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            width,
            progressLabel.widthAnchor.constraint(equalToConstant: 32),
            tempoLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 66),
            micButton.widthAnchor.constraint(equalToConstant: 26),
            handsButton.widthAnchor.constraint(equalToConstant: 34),
            skipButton.widthAnchor.constraint(equalToConstant: 26)
        ])
    }

    private func pill(radius: CGFloat) -> UIView {
        let view = UIView()
        style(view, radius: radius)
        return view
    }

    private func style(_ view: UIView, radius: CGFloat) {
        view.layer.cornerRadius = radius
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.12
        view.layer.shadowOffset = CGSize(width: 0, height: 3)
        view.layer.shadowRadius = 7
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = radius
        blur.layer.borderWidth = 0.5
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        blur.clipsToBounds = true
        blur.isUserInteractionEnabled = false
        view.insertSubview(blur, at: 0)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: view.topAnchor),
            blur.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        progressWidth?.constant = progressTrack.bounds.width * progress
    }

    // MARK: Updates

    /// "Play" and the step's notes, left hand blue and right hand red; played ones dimmed.
    func setPrompt(left: [Int], right: [Int], done: Set<Int>, names: [Int: String]) {
        guard !(left.isEmpty && right.isEmpty) else {
            promptLabel.attributedText = NSAttributedString(string: "Well played!", attributes: [.foregroundColor: UIColor.label])
            return
        }
        let text = NSMutableAttributedString(string: "Play  ", attributes: [
            .foregroundColor: UIColor.secondaryLabel, .font: UIFont.systemFont(ofSize: 15, weight: .semibold)])
        let notes = left.map { ($0, AnimatedPianoKeyView.leftColor) } + right.map { ($0, AnimatedPianoKeyView.rightColor) }
        for (i, (midi, color)) in notes.enumerated() {
            if i > 0 { text.append(NSAttributedString(string: " · ", attributes: [.foregroundColor: UIColor.tertiaryLabel])) }
            let played = done.contains(midi)
            let name = (names[midi] ?? PianoPitchAnalyzer.name(of: midi))
                .replacingOccurrences(of: "#", with: "♯").replacingOccurrences(of: "b", with: "♭")
            text.append(NSAttributedString(string: name, attributes: [
                .foregroundColor: played ? color.withAlphaComponent(0.35) : color,
                .strikethroughStyle: played ? NSUnderlineStyle.single.rawValue : 0]))
        }
        promptLabel.attributedText = text
    }

    func setProgress(_ value: Double) {
        progress = CGFloat(max(0, min(1, value)))
        progressLabel.text = "\(Int((progress * 100).rounded()))%"
        UIView.animate(withDuration: 0.25) {
            self.progressWidth?.constant = self.progressTrack.bounds.width * self.progress
            self.layoutIfNeeded()
        }
    }

    /// The player's tempo against the score's: green within 10%, orange within 25%, else red.
    func setTempo(played: Double?, target: Double) {
        let goal = Int(target.rounded())
        guard let played else {
            tempoLabel.text = "♩ –/\(goal)"
            tempoLabel.textColor = .secondaryLabel
            return
        }
        tempoLabel.text = "♩ \(Int(played.rounded()))/\(goal)"
        let off = abs(played / max(target, 1) - 1)
        tempoLabel.textColor = off <= 0.1 ? .systemGreen : (off <= 0.25 ? .systemOrange : .systemRed)
    }

    func setMic(_ state: Mic) {
        let small = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        switch state {
        case .off:
            micButton.setImage(UIImage(systemName: "mic.slash.fill", withConfiguration: small), for: .normal)
            micButton.tintColor = .systemGray
        case .denied:
            micButton.setImage(UIImage(systemName: "mic.slash.fill", withConfiguration: small), for: .normal)
            micButton.tintColor = .systemRed
        case .listening(let hearing):
            micButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: small), for: .normal)
            micButton.tintColor = hearing ? .systemGreen : .label
        case .keyboard(let name):
            micButton.setImage(UIImage(systemName: "pianokeys", withConfiguration: small), for: .normal)
            micButton.tintColor = .systemGreen
            micButton.accessibilityLabel = "Connected: \(name)"
        }
    }

    func setHands(_ label: String) {
        handsButton.setTitle(label, for: .normal)
    }

    func shakePrompt() {
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -6, 6, -4, 4, 0]
        shake.duration = 0.3
        promptPill.layer.add(shake, forKey: "shake")
    }

    @objc private func back() { onBack?() }
    @objc private func mic() { onMic?() }
    @objc private func hands() { onHands?() }
    @objc private func skip() { onSkip?() }
    @objc private func debugPlay(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began { onDebugPlayStep?() }
    }
}

// MARK: - PlayAlongReportView

final class PlayAlongReportView: UIView {
    var onRetry: (() -> Void)?
    var onDone: (() -> Void)?

    private let titleLabel = UILabel()
    private let scoreLabel = UILabel()
    private let statsStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        clipsToBounds = true
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
        let retry = UIButton(type: .system)
        let done = UIButton(type: .system)
        let buttons = UIStackView(arrangedSubviews: [retry, done])
        [blur, titleLabel, scoreLabel, statsStack, buttons].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }

        titleLabel.text = "Session Report"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textAlignment = .center
        scoreLabel.font = .systemFont(ofSize: 40, weight: .heavy)
        scoreLabel.textAlignment = .center
        scoreLabel.textColor = ComponentColors.HomeScreen.actionButtonFill
        statsStack.axis = .vertical
        statsStack.spacing = 7

        retry.setTitle("Practice Again", for: .normal)
        retry.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        retry.setTitleColor(.white, for: .normal)
        done.setTitle("Done", for: .normal)
        done.backgroundColor = .systemGray5
        done.setTitleColor(.label, for: .normal)
        [retry, done].forEach {
            $0.layer.cornerRadius = 12
            $0.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        }
        retry.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        buttons.axis = .horizontal
        buttons.spacing = 14
        buttons.distribution = .fillEqually

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            scoreLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            scoreLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            statsStack.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 8),
            statsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 36),
            statsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -36),
            buttons.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
            buttons.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            buttons.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            buttons.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    func configure(_ result: PlayAlongSession.Result) {
        scoreLabel.text = "\(result.accuracy)%"
        statsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        add("Notes played", "\(result.correct)")
        add("Wrong notes", "\(result.mistakes)")
        add("Chords right first time", "\(result.cleanSteps) of \(result.steps)")
        let target = Int(result.targetBPM.rounded())
        add("Tempo", result.playedBPM.map { "♩ \(Int($0.rounded())) (score ♩ \(target))" } ?? "score ♩ \(target)")
        if result.skipped > 0 { add("Skipped", "\(result.skipped)") }
    }

    private func add(_ label: String, _ value: String) {
        let name = UILabel()
        name.text = label
        name.font = .systemFont(ofSize: 15)
        name.textColor = .secondaryLabel
        let number = UILabel()
        number.text = value
        number.font = .systemFont(ofSize: 15, weight: .semibold)
        number.textAlignment = .right
        let row = UIStackView(arrangedSubviews: [name, number])
        statsStack.addArrangedSubview(row)
    }

    @objc private func retryTapped() { onRetry?() }
    @objc private func doneTapped() { onDone?() }
}
