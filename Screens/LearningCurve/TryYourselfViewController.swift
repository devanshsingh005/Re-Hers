import UIKit
import Foundation

class TryYourselfViewController: UIViewController {

    private let noteName: String
    private let pitchDetector = PitchDetector()
    
    private var isListening = false
    private var attemptCount = 0
    var onSessionCompleted: ((Int) -> Void)?

    private let cardView    = UIView()
    private let statusLabel = UILabel()
    private let micButton   = UIButton(type: .system)
    private let doneButton  = UIButton(type: .system)
    private let attemptCounterLabel = UILabel()
    private var pulseViews: [UIView] = []

    init(noteName: String) {
        self.noteName = noteName
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle   = .crossDissolve
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        pitchDetector.delegate = self
        setupUI()
    }

    private func setupUI() {
        cardView.backgroundColor = ComponentColors.LearningCurve.popupBackground
        cardView.layer.cornerRadius = 32
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        let dragIndicator = UIView()
        dragIndicator.backgroundColor = UIColor.systemGray4
        dragIndicator.layer.cornerRadius = 2.5
        dragIndicator.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(dragIndicator)

        let titleLabel = UILabel()
        titleLabel.text = "Try It Yourself"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        let descLabel = UILabel()
        descLabel.text = "Sing or play the \(noteName) note.\nWe'll use your microphone to detect the pitch."
        descLabel.font = .systemFont(ofSize: 15)
        descLabel.textColor = .systemGray
        descLabel.numberOfLines = 0
        descLabel.textAlignment = .center
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(descLabel)

        attemptCounterLabel.text = "Ready when you are"
        attemptCounterLabel.font = .systemFont(ofSize: 13, weight: .medium)
        attemptCounterLabel.textColor = .systemGray2
        attemptCounterLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(attemptCounterLabel)

        // Pulsing rings background
        for _ in 0..<3 {
            let ring = UIView()
            ring.layer.borderWidth = 1.5
            ring.layer.borderColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0).cgColor
            ring.layer.cornerRadius = 60
            ring.translatesAutoresizingMaskIntoConstraints = false
            cardView.addSubview(ring)
            pulseViews.append(ring)
            
            NSLayoutConstraint.activate([
                ring.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
                ring.centerYAnchor.constraint(equalTo: cardView.centerYAnchor, constant: 40),
                ring.widthAnchor.constraint(equalToConstant: 120),
                ring.heightAnchor.constraint(equalToConstant: 120)
            ])
        }

        let micCfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        micButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: micCfg), for: .normal)
        micButton.tintColor = .white
        micButton.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        micButton.layer.cornerRadius = 45
        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.addTarget(self, action: #selector(toggleListening), for: .touchUpInside)
        
        // Shadow for mic button
        micButton.layer.shadowColor   = ComponentColors.HomeScreen.actionButtonFill.cgColor
        micButton.layer.shadowOpacity = 0.4
        micButton.layer.shadowRadius  = 12
        micButton.layer.shadowOffset  = CGSize(width: 0, height: 6)
        cardView.addSubview(micButton)

        statusLabel.text = "Tap the mic to start"
        statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        statusLabel.textColor = .systemGray
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(statusLabel)

        doneButton.setTitle("Done Practicing ✓", for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        doneButton.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.1)
        doneButton.setTitleColor(ComponentColors.HomeScreen.actionButtonFill, for: .normal)
        doneButton.layer.cornerRadius = 24
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.alpha = 0 // Hidden until first attempt
        doneButton.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)
        cardView.addSubview(doneButton)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 480),

            dragIndicator.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            dragIndicator.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            dragIndicator.widthAnchor.constraint(equalToConstant: 36),
            dragIndicator.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: dragIndicator.bottomAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            descLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            attemptCounterLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 12),
            attemptCounterLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            micButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            micButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor, constant: 40),
            micButton.widthAnchor.constraint(equalToConstant: 90),
            micButton.heightAnchor.constraint(equalToConstant: 90),

            statusLabel.topAnchor.constraint(equalTo: micButton.bottomAnchor, constant: 40),
            statusLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            doneButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 14),
            doneButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            doneButton.heightAnchor.constraint(equalToConstant: 48),
            doneButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -28),
        ])
    }

    // MARK: - Actions

    @objc private func toggleListening() {
        isListening.toggle()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if isListening {
            pitchDetector.startListening()
            attemptCount += 1
            let starsHint = attemptCount == 1 ? "⭐⭐⭐" : attemptCount == 2 ? "⭐⭐" : "⭐"
            attemptCounterLabel.text = "Attempts: \(attemptCount)  •  \(starsHint)"
            UIView.transition(with: attemptCounterLabel, duration: 0.2, options: .transitionCrossDissolve, animations: nil)

            let waveCfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
            micButton.setImage(UIImage(systemName: "waveform", withConfiguration: waveCfg), for: .normal)
            statusLabel.text = "Listening... 🎤"; statusLabel.textColor = ComponentColors.HomeScreen.actionButtonFill
            startPulseAnimation()
            UIView.animate(withDuration: 0.3) { self.micButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1) }

        } else {
            pitchDetector.stopListening()
            let micCfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
            micButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: micCfg), for: .normal)
            statusLabel.text = "Good! Tap mic again to retry, or tap Done ✓"
            statusLabel.textColor = .systemGray
            stopPulseAnimation()
            UIView.animate(withDuration: 0.3) { self.micButton.transform = .identity }

            if doneButton.alpha == 0 {
                UIView.animate(withDuration: 0.35, delay: 0.1,
                               usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
                    self.doneButton.alpha = 1
                }
            }
        }
    }

    @objc private func didTapDone() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIView.animate(withDuration: 0.1, animations: {
            self.doneButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) { self.doneButton.transform = .identity }
        }
        let finalCount = max(1, attemptCount)
        dismiss(animated: true) { [weak self] in
            self?.onSessionCompleted?(finalCount)
        }
    }

    private func startPulseAnimation() {
        for (i, ring) in pulseViews.enumerated() {
            UIView.animate(withDuration: 1.0, delay: Double(i) * 0.15,
                           options: [.repeat, .autoreverse, .allowUserInteraction]) {
                ring.layer.borderColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(
                    CGFloat(0.25 - Double(i) * 0.08)).cgColor
                ring.transform = CGAffineTransform(scaleX: 1.1 + CGFloat(i) * 0.05,
                                                   y: 1.1 + CGFloat(i) * 0.05)
            }
        }
    }

    private func stopPulseAnimation() {
        for ring in pulseViews {
            ring.layer.removeAllAnimations()
            UIView.animate(withDuration: 0.4) {
                ring.layer.borderColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0).cgColor
                ring.transform = .identity
            }
        }
    }
}

// MARK: - PitchDetectorDelegate

extension TryYourselfViewController: PitchDetectorDelegate {
    func pitchDetectorDidDetect(notes: [String], frequency: Float, amplitude: CGFloat) {
        guard isListening, let topNoteWithOctave = notes.first else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isListening else { return }
            
            // Strip trailing octave digit(s): "C4" → "C", "F#5" → "F#", "A#4" → "A#"
            var detectedNote = topNoteWithOctave
            while let last = detectedNote.last, last.isNumber {
                detectedNote = String(detectedNote.dropLast())
            }
            
            // Resolve target note letter using centralized MusicHelper
            let targetNote = MusicHelper.getNoteLetter(from: self.noteName)
            
            // Match: detected note must equal target (ignoring case)
            let isMatch = detectedNote.uppercased() == targetNote.uppercased()
            
            let resultStr = isMatch ? "Perfect! 🎯" : "Keep trying! 🎵"
            self.statusLabel.text = "Heard: \(topNoteWithOctave) - \(resultStr)"
            self.statusLabel.textColor = isMatch ? ComponentColors.LessonScreen.correctAnswer : ComponentColors.HomeScreen.actionButtonFill
        }
    }
}
