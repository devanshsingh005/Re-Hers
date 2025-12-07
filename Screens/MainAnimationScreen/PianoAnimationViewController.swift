import UIKit

class PianoAnimationViewController: UIViewController {

    private let pianoKeyboard = AnimatedPianoKeyboardView()
    private let chordDisplayView = RealTimeChordDisplayView()
    private let chordDetector = ChordDetector()
    private let demoManager = PianoDemoManager()

    private var activeNotes: Set<String> = []
    private var isPlayingDemo = false
    private var currentDemoIndex = 0

    // Nav + safe-area bg
    private let navBar = TopNavBar.make(title: "Animation")
    private let safeAreaBG: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // Play / Pause control
    private let playPauseButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .white
        config.image = UIImage(systemName: "pause.fill")
        config.imagePadding = 0
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        b.configuration = config
        b.tintColor = .white
        b.backgroundColor = UIColor(white: 0.06, alpha: 0.9)
        b.layer.cornerRadius = 20
        b.isHidden = false
        return b
    }()

    // To manage scheduled demo steps so we can cancel on pause
    private var nextWorkItem: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavBar()
        setupConstraints()
        setupActions()
        setupDemoSong()
        startDemoSong()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupTabBar()
    }

    // MARK: - UI Setup
    private func setupUI() {
        // nav bar must look native: white background; safe area below black
        view.backgroundColor = .white
        navigationController?.navigationBar.isHidden = true

        // Order matters: safe area background (black) sits below nav; add it first so it's behind chord & keyboard
        view.addSubview(safeAreaBG)

        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(chordDisplayView)
        view.addSubview(pianoKeyboard)

        // play/pause sits visually on top-right of chord display area
        view.addSubview(playPauseButton)

        chordDisplayView.translatesAutoresizingMaskIntoConstraints = false
        pianoKeyboard.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Navbar Setup
    private func setupNavBar() {
        navBar.isWelcomeTextHidden = true
        navBar.isStreakVisible = false
        navBar.isProfileVisible = true
        navBar.isChordIconVisible = true
        navBar.backgroundColor = .white

        // ✅ FIXED: Clean, single backAction — always goes back to previous page
        navBar.isBackButtonVisible = true
        navBar.backAction = { [weak self] in
            guard let self = self else { return }

            if let nav = self.navigationController {
                nav.popViewController(animated: true)
            } else {
                self.dismiss(animated: true)
            }
        }

        navBar.chordAction = { [weak self] in
            guard let self = self else { return }
            let vc = ChordRecognitionViewController()
            if let nav = self.navigationController {
                nav.pushViewController(vc, animated: true)
            } else {
                vc.modalPresentationStyle = .fullScreen
                self.present(vc, animated: true)
            }
        }

        navBar.profileAction = { [weak self] in
            guard let self = self else { return }
            let vc = UserProfileViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }

        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }


    // MARK: - Constraints
    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
           

            // safe area background begins BELOW navbar, fills safe area
//            safeAreaBG.topAnchor.constraint(equalTo: navBar.bottomAnchor),
//            safeAreaBG.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            safeAreaBG.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            safeAreaBG.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // chord display inside the safe area with extra padding (moved lower)
            chordDisplayView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 10), // extra top padding
            chordDisplayView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            chordDisplayView.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            chordDisplayView.heightAnchor.constraint(equalToConstant: 80),

            // keyboard occupies rest of safe area
            pianoKeyboard.topAnchor.constraint(equalTo: chordDisplayView.bottomAnchor, constant: 8),
            pianoKeyboard.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            pianoKeyboard.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            pianoKeyboard.bottomAnchor.constraint(equalTo: safe.bottomAnchor),

            // play/pause button: top-right corner of chordDisplay (overlay)
            playPauseButton.centerYAnchor.constraint(equalTo: chordDisplayView.centerYAnchor),
            playPauseButton.trailingAnchor.constraint(equalTo: chordDisplayView.trailingAnchor, constant: -10),
            playPauseButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            playPauseButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    // MARK: - Actions
    private func setupActions() {
        pianoKeyboard.onKeyPressed = { [weak self] noteName, isPressed in
            self?.handleKeyPress(noteName: noteName, isPressed: isPressed)
        }

        playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
    }

    private func setupTabBar() {
        (self.tabBarController as? MainTabBarController)?.tabBar.isHidden = false
    }

    // MARK: - Demo control
    private func setupDemoSong() {
        // If you want to preload demoManager with static JSON, that stays in demoManager's init.
    }

    private func startDemoSong() {
        guard !isPlayingDemo else { return }
        isPlayingDemo = true
        chordDisplayView.setSingleChord("🎵 Demo Started 🎵")
        currentDemoIndex = 0
        scheduleNextDemoChord(after: 1.0)
        updatePlayPauseUI()
    }

    private func pauseDemoSong() {
        isPlayingDemo = false
        // cancel any scheduled next item
        nextWorkItem?.cancel()
        nextWorkItem = nil
        updatePlayPauseUI()
    }

    private func resumeDemoSong() {
        guard !isPlayingDemo else { return }
        isPlayingDemo = true
        scheduleNextDemoChord(after: 0.2)
        updatePlayPauseUI()
    }

    private func scheduleNextDemoChord(after delay: TimeInterval) {
        nextWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.playNextDemoChord()
        }
        nextWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func playNextDemoChord() {
        guard isPlayingDemo, let chord = demoManager.next() else {

            // demo finished
            chordDisplayView.setSingleChord("Demo Complete")
            isPlayingDemo = false
            updatePlayPauseUI()
            return
        }

        pianoKeyboard.playChord(chord)

        for n in chord.leftHandNotes + chord.rightHandNotes {
            playNoteSound(n)
        }

        chordDisplayView.setSingleChord("🎹 \(chord.chordName)")
        scheduleNextDemoChord(after: chord.duration)
    }

    // MARK: - Play/Pause toggle
    @objc private func togglePlayPause() {

        // CASE 1: Demo finished → replay mode
        if demoManager.isFinished {
            demoManager.reset()
            chordDisplayView.setSingleChord("🎵 Restarting Demo... 🎵")
            startDemoSong()
            return
        }

        // CASE 2: Currently playing → PAUSE
        if isPlayingDemo {
            pauseDemoSong()
            return
        }

        // CASE 3: Currently paused → RESUME
        resumeDemoSong()
    }


    private func updatePlayPauseUI() {

        // DEMO FINISHED → REPLAY ICON
        if demoManager.isFinished {
            playPauseButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
            return
        }

        // Normal play / pause
        let icon = isPlayingDemo ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: icon), for: .normal)
    }


    // MARK: - Live Chord Detection
    private func handleKeyPress(noteName: String, isPressed: Bool) {
        if isPressed {
            activeNotes.insert(noteName)
            playNoteSound(noteName)
        } else {
            activeNotes.remove(noteName)
        }

        let chord = chordDetector.detectChord(from: Array(activeNotes))
        if chord != "Unknown" && chord != "Play a chord!" {
            chordDisplayView.setSingleChord(" \(chord)")
        } else if activeNotes.isEmpty {
            // optional: show default message
            chordDisplayView.setSingleChord("🎹 Animation Ready!")
        }
    }
}

