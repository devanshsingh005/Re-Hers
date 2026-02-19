import UIKit

final class PlayAlongViewController: UIViewController {

    // MARK: - Core UI
    private let pianoKeyboard = AnimatedPianoKeyboardView()
    private let infoBar = RealTimeChordDisplayView()

    // MARK: - Progress Bar
    private let progressContainer = UIView()
    private let progressTrack = UIView()
    private let progressFill = UIView()

    // MARK: - Tempo UI
    private let tempoContainer = UIView()
    private let tempoLabel = UILabel()
    private let tempoSlider = UISlider()

    // MARK: - Navigation
    private let navBar = TopNavBar.make(title: "Play Along")

    // MARK: - State
    private var tempoMultiplier: Float = 1.0 {
        didSet {
            tempoLabel.text = String(format: "Tempo %.2fx", tempoMultiplier)
        }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupNavBar()
        setupConstraints()
        setupKeyboardCallbacks()

        pianoKeyboard.mode = .playAlong
        AudioEngineManager.shared.startEngine(loadSoundFont: "Wurlitzer210.sf2")

        infoBar.setSingleChord("🎹 Play Along Ready")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as? MainTabBarController)?.tabBar.isHidden = false
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .white
        navigationController?.navigationBar.isHidden = true

        view.addSubview(navBar)
        view.addSubview(infoBar)
        view.addSubview(pianoKeyboard)
        view.addSubview(progressContainer)

        navBar.translatesAutoresizingMaskIntoConstraints = false
        infoBar.translatesAutoresizingMaskIntoConstraints = false
        pianoKeyboard.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.translatesAutoresizingMaskIntoConstraints = false

        setupProgressBarUI()
        setupTempoUI()
    }

    // MARK: - Navbar
    private func setupNavBar() {
        navBar.isBackButtonVisible = true
        navBar.isProfileVisible = true
        navBar.isChordIconVisible = false
        navBar.isWelcomeTextHidden = true
        navBar.isStreakVisible = false
        navBar.backgroundColor = .white

        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
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
            infoBar.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 10),
            infoBar.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            infoBar.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            infoBar.heightAnchor.constraint(equalToConstant: 80),

            // Keyboard
            pianoKeyboard.topAnchor.constraint(equalTo: infoBar.bottomAnchor, constant: 8),
            pianoKeyboard.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            pianoKeyboard.trailingAnchor.constraint(equalTo: safe.trailingAnchor),

            // Progress bar
            progressContainer.topAnchor.constraint(equalTo: pianoKeyboard.bottomAnchor, constant: 12),
            progressContainer.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            progressContainer.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            progressContainer.heightAnchor.constraint(equalToConstant: 18),
            progressContainer.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor, constant: -8)
        ])

        // Keyboard height rules
        let keyboardHeight = pianoKeyboard.heightAnchor.constraint(
            equalTo: safe.heightAnchor,
            multiplier: 0.42
        )
        keyboardHeight.priority = .defaultHigh

        let keyboardMaxHeight = pianoKeyboard.heightAnchor.constraint(
            lessThanOrEqualToConstant: 260
        )

        NSLayoutConstraint.activate([keyboardHeight, keyboardMaxHeight])
    }

    // MARK: - Progress Bar UI
    private func setupProgressBarUI() {
        progressContainer.backgroundColor = UIColor(white: 0.9, alpha: 1)
        progressContainer.layer.cornerRadius = 9
        progressContainer.clipsToBounds = true

        progressTrack.backgroundColor = UIColor(white: 0.85, alpha: 1)
        progressFill.backgroundColor = .systemGreen

        progressContainer.addSubview(progressTrack)
        progressContainer.addSubview(progressFill)

        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressFill.translatesAutoresizingMaskIntoConstraints = false

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

    // MARK: - Tempo UI
    private func setupTempoUI() {
        tempoContainer.translatesAutoresizingMaskIntoConstraints = false
        infoBar.addSubview(tempoContainer)

        NSLayoutConstraint.activate([
            tempoContainer.trailingAnchor.constraint(equalTo: infoBar.trailingAnchor, constant: -12),
            tempoContainer.centerYAnchor.constraint(equalTo: infoBar.centerYAnchor),
            tempoContainer.widthAnchor.constraint(equalToConstant: 160),
            tempoContainer.heightAnchor.constraint(equalToConstant: 80)
        ])

        tempoLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        tempoLabel.textColor = .white
        tempoLabel.textAlignment = .right
        tempoLabel.text = "Tempo 1.00x"
        tempoLabel.translatesAutoresizingMaskIntoConstraints = false

        tempoSlider.minimumValue = 0.5
        tempoSlider.maximumValue = 1.5
        tempoSlider.value = 1.0
        tempoSlider.minimumTrackTintColor = .systemBlue
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
                self.infoBar.setSingleChord("🎹 \(note)")
            }
        }
    }

    // MARK: - Tempo Action
    @objc private func tempoChanged(_ sender: UISlider) {
        tempoMultiplier = sender.value
        // (Tempo scaling will be applied when scoring / backing track is added)
    }

    // MARK: - Orientation
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .landscapeRight
    }
}
