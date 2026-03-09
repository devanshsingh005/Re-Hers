import UIKit

final class PlayAlongViewController: UIViewController {

    // MARK: - Core UI
    private let pianoKeyboard = AnimatedPianoKeyboardView()
    private let infoBar       = RealTimeChordDisplayView()

    // MARK: - Progress Bar
    private let progressContainer = UIView()
    private let progressTrack     = UIView()
    private let progressFill      = UIView()

    // MARK: - Instrument Picker
    private let instrumentSegment = UISegmentedControl(
        items: AudioEngineManager.InstrumentType.allCases.map { $0.displayName }
    )

    // MARK: - Tempo UI
    private let tempoContainer = UIView()
    private let tempoLabel     = UILabel()
    private let tempoSlider    = UISlider()

    // MARK: - Navigation
    private let navBar = TopNavBar.make(title: "Play Along")

    // MARK: - State
    private var tempoMultiplier: Float = 1.0 {
        didSet { tempoLabel.text = String(format: "Tempo %.2fx", tempoMultiplier) }
    }
    private var notesPressed: [String] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupNavBar()
        setupConstraints()
        setupKeyboardCallbacks()

        pianoKeyboard.mode = .playAlong

        // Fix: startEngine() takes no arguments
        AudioEngineManager.shared.startEngine()

        infoBar.setSingleChord("🎹 Touch a key to play")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as? MainTabBarController)?.tabBar.isHidden = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AudioEngineManager.shared.stopAllNotes()
        (tabBarController as? MainTabBarController)?.tabBar.isHidden = false
    }

    // MARK: - Orientation (landscape only)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .white
        navigationController?.navigationBar.isHidden = true

        view.addSubview(navBar)
        view.addSubview(infoBar)
        view.addSubview(instrumentSegment)
        view.addSubview(pianoKeyboard)
        view.addSubview(progressContainer)

        navBar.translatesAutoresizingMaskIntoConstraints             = false
        infoBar.translatesAutoresizingMaskIntoConstraints            = false
        instrumentSegment.translatesAutoresizingMaskIntoConstraints  = false
        pianoKeyboard.translatesAutoresizingMaskIntoConstraints      = false
        progressContainer.translatesAutoresizingMaskIntoConstraints  = false

        setupInstrumentPicker()
        setupProgressBarUI()
        setupTempoUI()
    }

    // MARK: - Navbar
    private func setupNavBar() {
        navBar.isBackButtonVisible  = true
        navBar.isProfileVisible     = false
        navBar.isChordIconVisible   = false
        navBar.isWelcomeTextHidden  = true
        navBar.isStreakVisible      = false
        navBar.backgroundColor      = .white

        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - Instrument Picker
    private func setupInstrumentPicker() {
        instrumentSegment.selectedSegmentIndex = 0
        instrumentSegment.backgroundColor      = UIColor.systemGray6
        instrumentSegment.selectedSegmentTintColor = UIColor(red: 0.96, green: 0.71, blue: 0.13, alpha: 1)
        instrumentSegment.setTitleTextAttributes([.foregroundColor: UIColor.darkGray], for: .normal)
        instrumentSegment.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)], for: .selected)
        instrumentSegment.addTarget(self, action: #selector(instrumentChanged(_:)), for: .valueChanged)
    }

    // MARK: - Constraints
    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            // Navbar
            navBar.topAnchor.constraint(equalTo: safe.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Info bar
            infoBar.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 6),
            infoBar.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            infoBar.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            infoBar.heightAnchor.constraint(equalToConstant: 64),

            // Instrument picker
            instrumentSegment.topAnchor.constraint(equalTo: infoBar.bottomAnchor, constant: 6),
            instrumentSegment.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instrumentSegment.widthAnchor.constraint(equalToConstant: 340),
            instrumentSegment.heightAnchor.constraint(equalToConstant: 30),

            // Keyboard
            pianoKeyboard.topAnchor.constraint(equalTo: instrumentSegment.bottomAnchor, constant: 8),
            pianoKeyboard.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            pianoKeyboard.trailingAnchor.constraint(equalTo: safe.trailingAnchor),

            // Progress bar
            progressContainer.topAnchor.constraint(equalTo: pianoKeyboard.bottomAnchor, constant: 8),
            progressContainer.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            progressContainer.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            progressContainer.heightAnchor.constraint(equalToConstant: 14),
            progressContainer.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor, constant: -6)
        ])

        // Keyboard height
        let keyboardHeight = pianoKeyboard.heightAnchor.constraint(
            equalTo: safe.heightAnchor, multiplier: 0.44
        )
        keyboardHeight.priority = .defaultHigh

        let keyboardMaxHeight = pianoKeyboard.heightAnchor.constraint(
            lessThanOrEqualToConstant: 260
        )
        NSLayoutConstraint.activate([keyboardHeight, keyboardMaxHeight])
    }

    // MARK: - Progress Bar UI
    private func setupProgressBarUI() {
        progressContainer.backgroundColor    = UIColor(white: 0.92, alpha: 1)
        progressContainer.layer.cornerRadius = 7
        progressContainer.clipsToBounds      = true

        progressTrack.backgroundColor = UIColor(white: 0.87, alpha: 1)
        progressFill.backgroundColor  = UIColor(red: 0.96, green: 0.71, blue: 0.13, alpha: 1)

        progressContainer.addSubview(progressTrack)
        progressContainer.addSubview(progressFill)
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressFill.translatesAutoresizingMaskIntoConstraints  = false

        NSLayoutConstraint.activate([
            progressTrack.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressTrack.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            progressTrack.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressTrack.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),

            progressFill.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressContainer.widthAnchor, multiplier: 0.0)
        ])
    }

    // MARK: - Tempo UI (inside infoBar)
    private func setupTempoUI() {
        tempoContainer.translatesAutoresizingMaskIntoConstraints = false
        infoBar.addSubview(tempoContainer)

        NSLayoutConstraint.activate([
            tempoContainer.trailingAnchor.constraint(equalTo: infoBar.trailingAnchor, constant: -12),
            tempoContainer.centerYAnchor.constraint(equalTo: infoBar.centerYAnchor),
            tempoContainer.widthAnchor.constraint(equalToConstant: 150),
            tempoContainer.heightAnchor.constraint(equalToConstant: 52)
        ])

        tempoLabel.font          = .systemFont(ofSize: 11, weight: .semibold)
        tempoLabel.textColor     = .white
        tempoLabel.textAlignment = .right
        tempoLabel.text          = "Tempo 1.00x"
        tempoLabel.translatesAutoresizingMaskIntoConstraints = false

        tempoSlider.minimumValue          = 0.5
        tempoSlider.maximumValue          = 1.5
        tempoSlider.value                 = 1.0
        tempoSlider.minimumTrackTintColor = UIColor(red: 0.96, green: 0.71, blue: 0.13, alpha: 1)
        tempoSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        tempoSlider.addTarget(self, action: #selector(tempoChanged(_:)), for: .valueChanged)
        tempoSlider.translatesAutoresizingMaskIntoConstraints = false

        tempoContainer.addSubview(tempoLabel)
        tempoContainer.addSubview(tempoSlider)

        NSLayoutConstraint.activate([
            tempoLabel.topAnchor.constraint(equalTo: tempoContainer.topAnchor),
            tempoLabel.trailingAnchor.constraint(equalTo: tempoContainer.trailingAnchor),

            tempoSlider.topAnchor.constraint(equalTo: tempoLabel.bottomAnchor, constant: 4),
            tempoSlider.leadingAnchor.constraint(equalTo: tempoContainer.leadingAnchor),
            tempoSlider.trailingAnchor.constraint(equalTo: tempoContainer.trailingAnchor),
            tempoSlider.bottomAnchor.constraint(equalTo: tempoContainer.bottomAnchor)
        ])
    }

    // MARK: - Keyboard Callbacks
    private func setupKeyboardCallbacks() {
        pianoKeyboard.onKeyPressed = { [weak self] note, isPressed in
            guard let self = self else { return }

            if isPressed {
                // Play note via AudioEngine
                if let midi = AudioEngineManager.shared.midiNumber(from: note) {
                    AudioEngineManager.shared.startNote(midi: midi)
                }
                // Track held notes
                if !self.notesPressed.contains(note) {
                    self.notesPressed.append(note)
                }
            } else {
                // Stop note
                if let midi = AudioEngineManager.shared.midiNumber(from: note) {
                    AudioEngineManager.shared.stopNote(midi: midi)
                }
                self.notesPressed.removeAll { $0 == note }
            }

            // Update info bar
            if self.notesPressed.isEmpty {
                self.infoBar.setSingleChord("🎹 Touch a key to play")
            } else if self.notesPressed.count == 1 {
                self.infoBar.setSingleChord("🎵 \(self.notesPressed[0])")
            } else {
                let chord = self.notesPressed.joined(separator: " + ")
                self.infoBar.setSingleChord("🎵 \(chord)")
            }
        }
    }

    // MARK: - Instrument Action
    @objc private func instrumentChanged(_ sender: UISegmentedControl) {
        let instruments = AudioEngineManager.InstrumentType.allCases
        guard sender.selectedSegmentIndex < instruments.count else { return }
        let selected = instruments[sender.selectedSegmentIndex]
        AudioEngineManager.shared.switchInstrument(to: selected)
        infoBar.setSingleChord("🎹 \(selected.displayName) loaded")
    }

    // MARK: - Tempo Action
    @objc private func tempoChanged(_ sender: UISlider) {
        tempoMultiplier = sender.value
    }
}
