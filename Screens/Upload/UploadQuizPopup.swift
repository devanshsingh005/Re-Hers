//
//  UploadQuizPopup.swift
//  Re-Hearse_v1
//  Screens/MainUploadScreen/
//

import UIKit
import CoreText

// MARK: - Quiz Question Model
struct MusicQuizQuestion {
    let question: String
    let drawingType: StaffDrawingType
    let answers: [String]
    let correctIndex: Int
}

// MARK: - Staff Drawing Types
/// What the quiz staff shows. Positions count half staff-spaces up from the bottom line
/// (0 = bottom line, 1 = first space, -2 = first ledger line below).
enum StaffDrawingType {
    /// One quarter note on a clef'd staff, with an optional accidental.
    case note(clef: ScoreClef, position: Int, accidental: ScoreNote.Accidental? = nil)
    /// One note of the given value in 4/4, for "how many beats" questions.
    case noteValue(NoteValue)
    /// One rest of the given value in 4/4.
    case rest(NoteValue)
    case timeSignature(top: Int, bottom: Int)
    /// A treble key signature: sharps when positive, flats when negative.
    case keySignature(fifths: Int)
    /// A note with a dynamic marking (f, p, mf…) under the staff.
    case dynamic(String)
    case clef(ScoreClef)
}

// MARK: - Static Question Bank
private let questionBank: [MusicQuizQuestion] = [
    MusicQuizQuestion(
        question: "What note is this?",
        drawingType: .note(clef: .treble, position: 0),              // bottom line: E4
        answers: ["E", "F", "G"], correctIndex: 0
    ),
    MusicQuizQuestion(
        question: "What note is this?",
        drawingType: .note(clef: .treble, position: 1),              // first space: F4
        answers: ["D", "E", "F"], correctIndex: 2
    ),
    MusicQuizQuestion(
        question: "What note is this?",
        drawingType: .note(clef: .treble, position: 4),              // middle line: B4
        answers: ["A", "B", "C"], correctIndex: 1
    ),
    MusicQuizQuestion(
        question: "What note is this?",
        drawingType: .note(clef: .treble, position: 5),              // third space: C5
        answers: ["C", "D", "E"], correctIndex: 0
    ),
    MusicQuizQuestion(
        question: "What note is this?",
        drawingType: .note(clef: .treble, position: -2),             // ledger line below: middle C
        answers: ["A", "C", "E"], correctIndex: 1
    ),
    MusicQuizQuestion(
        question: "What note is this?",
        drawingType: .note(clef: .bass, position: 4),                // bass middle line: D3
        answers: ["B", "D", "F"], correctIndex: 1
    ),
    MusicQuizQuestion(
        question: "What note is this?",
        drawingType: .note(clef: .treble, position: 1, accidental: .sharp),   // F♯4
        answers: ["F", "F♯", "F♭"], correctIndex: 1
    ),
    MusicQuizQuestion(
        question: "How many beats does this note get?",
        drawingType: .noteValue(.whole),
        answers: ["2", "3", "4"], correctIndex: 2
    ),
    MusicQuizQuestion(
        question: "How many beats does this note get?",
        drawingType: .noteValue(.half),
        answers: ["1", "2", "4"], correctIndex: 1
    ),
    MusicQuizQuestion(
        question: "How many beats does this note get?",
        drawingType: .noteValue(.quarter),
        answers: ["1", "2", "3"], correctIndex: 0
    ),
    MusicQuizQuestion(
        question: "How many beats does this note get?",
        drawingType: .noteValue(.eighth),
        answers: ["½", "1", "2"], correctIndex: 0
    ),
    MusicQuizQuestion(
        question: "What does this symbol mean?",
        drawingType: .rest(.quarter),
        answers: ["Play loud", "Silence", "Repeat"], correctIndex: 1
    ),
    MusicQuizQuestion(
        question: "What rest is this?",
        drawingType: .rest(.whole),
        answers: ["Whole rest", "Half rest", "Quarter rest"], correctIndex: 0
    ),
    MusicQuizQuestion(
        question: "What time signature is this?",
        drawingType: .timeSignature(top: 4, bottom: 4),
        answers: ["3/4", "2/4", "4/4"], correctIndex: 2
    ),
    MusicQuizQuestion(
        question: "Which major key is this?",
        drawingType: .keySignature(fifths: 1),                       // one sharp (F♯)
        answers: ["C major", "G major", "F major"], correctIndex: 1
    ),
    MusicQuizQuestion(
        question: "What does this marking mean?",
        drawingType: .dynamic("f"),                                  // forte
        answers: ["Loud", "Soft", "Slowly"], correctIndex: 0
    ),
    MusicQuizQuestion(
        question: "What clef is this?",
        drawingType: .clef(.treble),
        answers: ["Bass clef", "Alto clef", "Treble clef"], correctIndex: 2
    ),
    MusicQuizQuestion(
        question: "What clef is this?",
        drawingType: .clef(.bass),
        answers: ["Bass clef", "Alto clef", "Treble clef"], correctIndex: 0
    ),
]

// MARK: - Delegate
protocol UploadQuizPopupDelegate: AnyObject {
    func uploadQuizPopupDidClose(_ popup: UploadQuizPopup)
}

// MARK: - Main Popup View Controller
class UploadQuizPopup: UIViewController {

    weak var delegate: UploadQuizPopupDelegate?

    private var uploadFinished = false
    private var autoCloseTimer: Timer?
    private var progressObserver: NSObjectProtocol?
    private var shownProgress: Float = 0.05

    private var questions: [MusicQuizQuestion] = []
    private var currentIndex = 0
    private var isAnswered = false

    // MARK: - UI
    private let cardView        = UIView()

    // Header
    private let cloudIconWrap   = UIView()
    private let cloudIcon       = UIImageView()
    private let titleLabel      = UILabel()
    private let subtitleLabel   = UILabel()
    private let progressTrack   = UIView()
    private let progressFill    = UIView()
    private let progressPctLabel = UILabel()
    private let closeBtn        = UIButton(type: .system)

    // Quiz card
    private let quizCard        = UIView()
    private let questionLabel   = UILabel()
    private let staffContainer  = UIView()
    private let staffView       = StaffDrawingView()
    private let answersStack    = UIStackView()
    private let feedbackLabel   = UILabel()

    // Page dots
    private let dotsStack       = UIStackView()

    // Upload done overlay
    private let doneOverlay     = UIView()
    private let checkCircle     = UIView()
    private let checkLayer      = CAShapeLayer()
    private let doneLabel       = UILabel()
    private let doneSubLabel    = UILabel()

    // Progress fill width constraint (for animation)
    private var progressFillWidth: NSLayoutConstraint!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        questions = Array(questionBank.shuffled().prefix(10))

        setupCard()
        setupHeader()
        setupQuizCard()
        setupDots()
        setupDoneOverlay()

        loadQuestion(at: 0)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startFloatingAnimation()
    }

    deinit {
        autoCloseTimer?.invalidate()
        if let progressObserver { NotificationCenter.default.removeObserver(progressObserver) }
    }

    // MARK: - Public API
    /// Follows the on-device conversion of this upload: the bar shows its real progress.
    func track(uploadId: UUID) {
        if let observer = progressObserver { NotificationCenter.default.removeObserver(observer) }
        progressObserver = NotificationCenter.default.addObserver(
            forName: LocalSheetLibrary.didChangeNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard (note.userInfo?["id"] as? UUID) == uploadId else { return }
            MainActor.assumeIsolated {
                guard let self, !self.uploadFinished,
                      let p = LocalSheetLibrary.shared.progress[uploadId] else { return }
                // the conversion starts at 0; keep the bar from jumping backwards from its start
                let value: Float = 0.05 + 0.9 * Float(p)
                self.updateProgress(max(self.shownProgress, value))
            }
        }
    }

    func notifyUploadComplete() {
        uploadFinished = true
        DispatchQueue.main.async { self.showUploadDone() }
    }

    func updateProgress(_ value: Float) {
        DispatchQueue.main.async {
            let clamped = max(0, min(1, value))
            self.shownProgress = clamped
            let pct = Int(clamped * 100)
            self.progressPctLabel.text = "\(pct)%"
            guard let parent = self.progressFill.superview else { return }
            self.progressFillWidth.constant = parent.bounds.width * CGFloat(clamped)
            UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
                parent.layoutIfNeeded()
            }
        }
    }

    // MARK: - Card Setup
    private func setupCard() {
        cardView.backgroundColor = SemanticColors.Background.modal
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: view.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - Header
    private func setupHeader() {
        // Close button
        closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeBtn.tintColor = .tertiaryLabel
        closeBtn.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        closeBtn.layer.cornerRadius = 14
        closeBtn.clipsToBounds = true
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(dismissButtonTapped), for: .touchUpInside)
        cardView.addSubview(closeBtn)

        // Cloud icon wrap
        cloudIconWrap.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.14)
        cloudIconWrap.layer.cornerRadius = 16
        cloudIconWrap.translatesAutoresizingMaskIntoConstraints = false

        cloudIcon.image = UIImage(systemName: "icloud.and.arrow.up")
        cloudIcon.tintColor = ComponentColors.HomeScreen.actionButtonFill
        cloudIcon.contentMode = .scaleAspectFit
        cloudIcon.translatesAutoresizingMaskIntoConstraints = false
        cloudIconWrap.addSubview(cloudIcon)
        cardView.addSubview(cloudIconWrap)

        // Title
        titleLabel.text = "Processing your Sheet"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .left
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        // Subtitle
        subtitleLabel.text = "Take a quick quiz while you wait!"
        subtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .left
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(subtitleLabel)

        // Progress track
        progressTrack.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        progressTrack.layer.cornerRadius = 4
        progressTrack.clipsToBounds = true
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(progressTrack)

        // Progress fill
        progressFill.backgroundColor = ComponentColors.QuizScreen.progressFill
        progressFill.layer.cornerRadius = 4
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)

        // Percentage label
        progressPctLabel.text = "5%"
        progressPctLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        progressPctLabel.textColor = ComponentColors.HomeScreen.actionButtonFill
        progressPctLabel.textAlignment = .right
        progressPctLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(progressPctLabel)

        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            closeBtn.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            closeBtn.widthAnchor.constraint(equalToConstant: 32),
            closeBtn.heightAnchor.constraint(equalToConstant: 32),

            cloudIconWrap.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 44),
            cloudIconWrap.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            cloudIconWrap.widthAnchor.constraint(equalToConstant: 56),
            cloudIconWrap.heightAnchor.constraint(equalToConstant: 56),

            cloudIcon.centerXAnchor.constraint(equalTo: cloudIconWrap.centerXAnchor),
            cloudIcon.centerYAnchor.constraint(equalTo: cloudIconWrap.centerYAnchor),
            cloudIcon.widthAnchor.constraint(equalToConstant: 28),
            cloudIcon.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.topAnchor.constraint(equalTo: cloudIconWrap.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: cloudIconWrap.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -12),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            // Progress row
            progressTrack.topAnchor.constraint(equalTo: cloudIconWrap.bottomAnchor, constant: 28),
            progressTrack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            progressTrack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -62),
            progressTrack.heightAnchor.constraint(equalToConstant: 6),

            progressPctLabel.centerYAnchor.constraint(equalTo: progressTrack.centerYAnchor),
            progressPctLabel.leadingAnchor.constraint(equalTo: progressTrack.trailingAnchor, constant: 10),
            progressPctLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),

            // Fill inside track — top/bottom/leading pinned; width is animated
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
        ])

        // Width constraint wired up after layout pass
        progressFillWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)
        progressFillWidth.isActive = true

        // Initial fill after first layout, until the conversion reports progress
        DispatchQueue.main.async {
            let trackWidth = self.progressTrack.bounds.width
            self.progressFillWidth.constant = trackWidth * CGFloat(self.shownProgress)
            self.progressTrack.layoutIfNeeded()
        }
    }

    // MARK: - Quiz Card
    private func setupQuizCard() {
        quizCard.backgroundColor = SemanticColors.Background.card
        quizCard.layer.cornerRadius = 20
        quizCard.applyReHearseShader(level: 1)
        quizCard.clipsToBounds = false
        quizCard.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(quizCard)

        // Question label
        questionLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        questionLabel.textColor = .label
        questionLabel.textAlignment = .center
        // One line, shrinking to fit: the sheet's height leaves no room for a second line.
        questionLabel.numberOfLines = 1
        questionLabel.adjustsFontSizeToFitWidth = true
        questionLabel.minimumScaleFactor = 0.7
        questionLabel.translatesAutoresizingMaskIntoConstraints = false
        quizCard.addSubview(questionLabel)

        // Staff container — subtle background so staff reads clearly
        staffContainer.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        staffContainer.layer.cornerRadius = 12
        staffContainer.clipsToBounds = true
        staffContainer.translatesAutoresizingMaskIntoConstraints = false
        quizCard.addSubview(staffContainer)

        // Staff drawing view inside container
        staffView.translatesAutoresizingMaskIntoConstraints = false
        staffView.backgroundColor = .clear
        staffContainer.addSubview(staffView)

        // Answers stack
        answersStack.axis = .horizontal
        answersStack.spacing = 10
        answersStack.distribution = .fillEqually
        answersStack.translatesAutoresizingMaskIntoConstraints = false
        quizCard.addSubview(answersStack)

        // Feedback label
        feedbackLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        feedbackLabel.textAlignment = .center
        feedbackLabel.textColor = .tertiaryLabel
        feedbackLabel.text = "Tap an answer to continue"
        feedbackLabel.numberOfLines = 1
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        quizCard.addSubview(feedbackLabel)

        NSLayoutConstraint.activate([
            quizCard.topAnchor.constraint(equalTo: progressTrack.bottomAnchor, constant: 24),
            quizCard.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            quizCard.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),

            questionLabel.topAnchor.constraint(equalTo: quizCard.topAnchor, constant: 20),
            questionLabel.leadingAnchor.constraint(equalTo: quizCard.leadingAnchor, constant: 16),
            questionLabel.trailingAnchor.constraint(equalTo: quizCard.trailingAnchor, constant: -16),

            staffContainer.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 18),
            staffContainer.leadingAnchor.constraint(equalTo: quizCard.leadingAnchor, constant: 14),
            staffContainer.trailingAnchor.constraint(equalTo: quizCard.trailingAnchor, constant: -14),
            staffContainer.heightAnchor.constraint(equalToConstant: 150),

            staffView.topAnchor.constraint(equalTo: staffContainer.topAnchor, constant: 6),
            staffView.bottomAnchor.constraint(equalTo: staffContainer.bottomAnchor, constant: -6),
            staffView.leadingAnchor.constraint(equalTo: staffContainer.leadingAnchor),
            staffView.trailingAnchor.constraint(equalTo: staffContainer.trailingAnchor),

            answersStack.topAnchor.constraint(equalTo: staffContainer.bottomAnchor, constant: 18),
            answersStack.leadingAnchor.constraint(equalTo: quizCard.leadingAnchor, constant: 14),
            answersStack.trailingAnchor.constraint(equalTo: quizCard.trailingAnchor, constant: -14),
            answersStack.heightAnchor.constraint(equalToConstant: 54),

            feedbackLabel.topAnchor.constraint(equalTo: answersStack.bottomAnchor, constant: 10),
            feedbackLabel.leadingAnchor.constraint(equalTo: quizCard.leadingAnchor, constant: 16),
            feedbackLabel.trailingAnchor.constraint(equalTo: quizCard.trailingAnchor, constant: -16),
            feedbackLabel.bottomAnchor.constraint(equalTo: quizCard.bottomAnchor, constant: -16),
        ])
    }

    // MARK: - Page Dots
    private func setupDots() {
        dotsStack.axis = .horizontal
        dotsStack.spacing = 5
        dotsStack.alignment = .center
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(dotsStack)

        for i in 0..<min(questions.count, 10) {
            let dot = UIView()
            dot.layer.cornerRadius = 3.5
            dot.backgroundColor = i == 0
                ? ComponentColors.HomeScreen.actionButtonFill
                : ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.22)
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: i == 0 ? 20 : 7).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 7).isActive = true
            dotsStack.addArrangedSubview(dot)
        }

        NSLayoutConstraint.activate([
            dotsStack.topAnchor.constraint(equalTo: quizCard.bottomAnchor, constant: 14),
            dotsStack.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            dotsStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    // MARK: - Done Overlay
    private func setupDoneOverlay() {
        doneOverlay.backgroundColor = ComponentColors.App.screenBackground
        doneOverlay.layer.cornerRadius = 28
        doneOverlay.clipsToBounds = true
        doneOverlay.alpha = 0
        doneOverlay.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(doneOverlay)
        NSLayoutConstraint.activate([
            doneOverlay.topAnchor.constraint(equalTo: cardView.topAnchor),
            doneOverlay.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            doneOverlay.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            doneOverlay.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
        ])

        checkCircle.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.12)
        checkCircle.layer.cornerRadius = 40
        checkCircle.translatesAutoresizingMaskIntoConstraints = false
        doneOverlay.addSubview(checkCircle)

        checkLayer.strokeColor = ComponentColors.HomeScreen.actionButtonFill.cgColor
        checkLayer.fillColor = UIColor.clear.cgColor
        checkLayer.lineWidth = 4
        checkLayer.lineCap = .round
        checkLayer.lineJoin = .round
        checkLayer.strokeEnd = 0
        checkCircle.layer.addSublayer(checkLayer)

        doneLabel.text = "Upload Complete!"
        doneLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        doneLabel.textColor = .label
        doneLabel.textAlignment = .center
        doneLabel.translatesAutoresizingMaskIntoConstraints = false
        doneOverlay.addSubview(doneLabel)

        doneSubLabel.text = "Closing in 5 seconds…"
        doneSubLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        doneSubLabel.textColor = .secondaryLabel
        doneSubLabel.textAlignment = .center
        doneSubLabel.translatesAutoresizingMaskIntoConstraints = false
        doneOverlay.addSubview(doneSubLabel)

        var doneConfig = UIButton.Configuration.filled()
        doneConfig.title = "Done"
        doneConfig.baseForegroundColor = .white
        doneConfig.baseBackgroundColor = ComponentColors.HomeScreen.actionButtonFill
        doneConfig.background.cornerRadius = 24
        doneConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 40, bottom: 12, trailing: 40)
        let closeDoneBtn = UIButton(configuration: doneConfig)
        closeDoneBtn.translatesAutoresizingMaskIntoConstraints = false
        closeDoneBtn.addTarget(self, action: #selector(dismissButtonTapped), for: .touchUpInside)
        doneOverlay.addSubview(closeDoneBtn)

        NSLayoutConstraint.activate([
            checkCircle.centerXAnchor.constraint(equalTo: doneOverlay.centerXAnchor),
            checkCircle.centerYAnchor.constraint(equalTo: doneOverlay.centerYAnchor, constant: -50),
            checkCircle.widthAnchor.constraint(equalToConstant: 80),
            checkCircle.heightAnchor.constraint(equalToConstant: 80),

            doneLabel.topAnchor.constraint(equalTo: checkCircle.bottomAnchor, constant: 20),
            doneLabel.centerXAnchor.constraint(equalTo: doneOverlay.centerXAnchor),

            doneSubLabel.topAnchor.constraint(equalTo: doneLabel.bottomAnchor, constant: 8),
            doneSubLabel.centerXAnchor.constraint(equalTo: doneOverlay.centerXAnchor),

            closeDoneBtn.topAnchor.constraint(equalTo: doneSubLabel.bottomAnchor, constant: 24),
            closeDoneBtn.centerXAnchor.constraint(equalTo: doneOverlay.centerXAnchor),
        ])
    }

    // MARK: - Load Question
    private func loadQuestion(at index: Int) {
        guard index < questions.count else { return }
        isAnswered = false
        let q = questions[index]

        questionLabel.text = q.question
        staffView.drawingType = q.drawingType

        feedbackLabel.text = "Tap an answer to continue"
        feedbackLabel.textColor = .tertiaryLabel

        answersStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, answer) in q.answers.enumerated() {
            let btn = QuizAnswerButton(type: .custom)
            btn.setTitle(answer, for: .normal)
            btn.tag = i
            btn.addTarget(self, action: #selector(answerButtonTapped(_:)), for: .touchUpInside)
            answersStack.addArrangedSubview(btn)
        }

        updateDots(activeIndex: index)
    }

    // MARK: - Handle Answer
    private func handleAnswer(selectedIndex: Int) {
        guard !isAnswered else { return }
        isAnswered = true

        let q = questions[currentIndex]
        let isCorrect = selectedIndex == q.correctIndex

        for (i, view) in answersStack.arrangedSubviews.enumerated() {
            guard let btn = view as? QuizAnswerButton else { continue }
            if i == q.correctIndex {
                btn.setCorrect()
            } else if i == selectedIndex && !isCorrect {
                btn.setWrong()
            } else {
                UIView.animate(withDuration: 0.2) { btn.alpha = 0.38 }
            }
        }

        feedbackLabel.text = isCorrect
            ? "✓  Correct!"
            : "✗  The answer was \(q.answers[q.correctIndex])"
        feedbackLabel.textColor = isCorrect
            ? SemanticColors.State.correct
            : SemanticColors.State.incorrect

        UIView.animate(withDuration: 0.1, animations: {
            self.quizCard.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { _ in
            UIView.animate(withDuration: 0.15) { self.quizCard.transform = .identity }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self = self else { return }
            self.currentIndex += 1
            if self.currentIndex < self.questions.count {
                self.animateQuizTransition { self.loadQuestion(at: self.currentIndex) }
            } else if !self.uploadFinished {
                self.currentIndex = 0
                self.questions = Array(questionBank.shuffled().prefix(10))
                self.animateQuizTransition { self.loadQuestion(at: 0) }
            }
        }
    }

    @objc private func dismissButtonTapped() { dismissPopup() }
    @objc private func answerButtonTapped(_ sender: UIButton) { handleAnswer(selectedIndex: sender.tag) }

    // MARK: - Dot Updates
    private func updateDots(activeIndex: Int) {
        for (i, dot) in dotsStack.arrangedSubviews.enumerated() {
            UIView.animate(withDuration: 0.22) {
                if i == activeIndex {
                    dot.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
                    dot.constraints.first(where: { $0.firstAttribute == .width })?.constant = 20
                } else {
                    dot.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.22)
                    dot.constraints.first(where: { $0.firstAttribute == .width })?.constant = 7
                }
                dot.superview?.layoutIfNeeded()
            }
        }
    }

    // MARK: - Upload Done
    private func showUploadDone() {
        updateProgress(1.0)
        UIView.animate(withDuration: 0.35, delay: 0.3, options: .curveEaseInOut) {
            self.doneOverlay.alpha = 1
        } completion: { _ in
            self.animateCheckmark()
            self.startAutoCloseCountdown()
        }
    }

    private func animateCheckmark() {
        let size: CGFloat = 80
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 22, y: 40))
        path.addLine(to: CGPoint(x: 34, y: 54))
        path.addLine(to: CGPoint(x: 58, y: 28))
        checkLayer.path = path.cgPath
        checkLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)

        let anim = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue = 0; anim.toValue = 1
        anim.duration = 0.5
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        checkLayer.add(anim, forKey: "checkmark")
        checkLayer.strokeEnd = 1

        UIView.animate(withDuration: 0.3, delay: 0.4,
                       usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            self.checkCircle.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) { self.checkCircle.transform = .identity }
        }
    }

    private func startAutoCloseCountdown() {
        var remaining = 5
        autoCloseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            remaining -= 1
            self.doneSubLabel.text = remaining > 0
                ? "Closing in \(remaining) second\(remaining == 1 ? "" : "s")…"
                : "Closing…"
            if remaining <= 0 { timer.invalidate(); self.dismissPopup() }
        }
    }

    // MARK: - Animations
    private func startFloatingAnimation() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
        animation.values = [0, -4, 0]
        animation.duration = 4.0
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        staffView.layer.add(animation, forKey: "floating")
    }

    private func animateQuizTransition(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.15, animations: {
            self.quizCard.alpha = 0
            self.quizCard.transform = CGAffineTransform(translationX: -20, y: 0)
        }) { _ in
            completion()
            self.quizCard.transform = CGAffineTransform(translationX: 20, y: 0)
            UIView.animate(withDuration: 0.22, delay: 0.05,
                           usingSpringWithDamping: 0.82, initialSpringVelocity: 0.3) {
                self.quizCard.alpha = 1
                self.quizCard.transform = .identity
            }
        }
    }

    private func dismissPopup() {
        autoCloseTimer?.invalidate()
        autoCloseTimer = nil
        self.delegate?.uploadQuizPopupDidClose(self)
        self.dismiss(animated: true)
    }
}

// MARK: - Staff Drawing View
/// The quiz's staff, drawn with the same glyphs as the Animation sheet and the Practice lessons
/// (`SheetGlyphs`): real clefs, note heads, stems, flags, ledger lines, rests, accidentals,
/// key and time signatures at their true staff positions.
class StaffDrawingView: UIView {

    var drawingType: StaffDrawingType = .clef(.treble) {
        didSet { drawnSize = .zero; setNeedsLayout() }
    }

    private let content = CALayer()
    private var drawnSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isUserInteractionEnabled = false
        layer.addSublayer(content)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.drawnSize = .zero
            self.setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != drawnSize, bounds.width > 0, bounds.height > 0 else { return }
        drawnSize = bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        redraw()
        CATransaction.commit()
    }

    private func redraw() {
        content.sublayers?.forEach { $0.removeFromSuperlayer() }
        content.frame = bounds

        let ink = SemanticColors.Text.musicNotation.resolvedColor(with: traitCollection)
        let scale = traitCollection.displayScale
        // Staff space: fits the staff plus a ledger note and stem in the box.
        let s = min(12, bounds.height / 11)
        var staffTop = (bounds.height - 4 * s) / 2
        if case .dynamic = drawingType { staffTop -= 1.2 * s }   // room for the marking underneath
        let bottomLine = staffTop + 4 * s
        let left: CGFloat = 18, right = bounds.width - 18
        func y(_ position: Int) -> CGFloat { bottomLine - CGFloat(position) * s / 2 }

        // Staff lines
        let staffLines = CGMutablePath()
        for i in 0..<5 {
            staffLines.addRect(CGRect(x: left, y: staffTop + CGFloat(i) * s - 0.5, width: right - left, height: 1))
        }
        addShape(staffLines, color: ink.withAlphaComponent(0.45))

        let path = CGMutablePath()
        var textLayers: [CALayer] = []

        let clefX = left + 0.4 * s
        let afterClef = clefX + 3.6 * s
        /// Draws the clef with its left edge at `x` (or centred on `centerX`) at its true size:
        /// the treble clef curls round the G line and reaches past both ends of the staff; the bass
        /// clef's dots sit either side of the F line.
        func addClef(_ clef: ScoreClef, x: CGFloat = clefX, centerX: CGFloat? = nil) {
            // Extents in staff spaces from SMuFL's gClef / fClef bounding boxes.
            let top: CGFloat, bottom: CGFloat
            if clef.isBass {
                let fLine = staffTop + s
                top = fLine - 1.03 * s
                bottom = fLine + 2.54 * s
            } else {
                let gLine = bottomLine - s
                top = gLine - 4.39 * s
                bottom = gLine + 2.63 * s
            }
            guard let glyph = Self.clefGlyph(bass: clef.isBass) else {
                textLayers.append(SheetGlyphs.clefLayer(clef, x: x, staffTop: staffTop, s: s, color: ink, scale: scale))
                return
            }
            let box = glyph.boundingBoxOfPath
            let k = (bottom - top) / box.height
            let left = centerX.map { $0 - box.width * k / 2 } ?? x
            // Font outlines are y-up: flip, scale to the extents, and move into place.
            let place = CGAffineTransform(a: k, b: 0, c: 0, d: -k, tx: left - box.minX * k, ty: bottom + box.minY * k)
            path.addPath(glyph, transform: place)
        }
        func addTime(_ top: Int, _ bottom: Int, centerX: CGFloat) {
            textLayers += SheetGlyphs.timeLayers(ScoreTimeSignature(beats: top, beatType: bottom), centerX: centerX,
                                                 staffTop: staffTop, s: s, color: ink, scale: scale)
        }
        func addNote(_ value: NoteValue, position p: Int, x: CGFloat, accidental: ScoreNote.Accidental? = nil) {
            let headWidth = SheetGlyphs.headWidth(value, s: s)
            let noteY = y(p)
            SheetGlyphs.addHead(path, center: CGPoint(x: x, y: noteY), value: value, s: s)

            // Ledger lines through and between the note and the staff
            let ledgerThickness = max(1.2, 0.1 * s)
            func ledger(_ q: Int) {
                path.addRect(CGRect(x: x - headWidth * 0.85, y: y(q) - ledgerThickness / 2,
                                    width: headWidth * 1.7, height: ledgerThickness))
            }
            if p <= -2 { stride(from: -2, through: p, by: -2).forEach(ledger) }
            if p >= 10 { stride(from: 10, through: p, by: 2).forEach(ledger) }

            if let accidental {
                SheetGlyphs.addAccidental(path, accidental, centerX: x - headWidth / 2 - 0.95 * s, centerY: noteY, s: s)
            }

            guard value.hasStem else { return }
            // Stem up (on the right) below the middle line, down (on the left) from it upwards.
            let up = p < 4
            let t = max(1.1, 0.11 * s)
            let length = 3.5 * s
            let stemX = up ? x + headWidth / 2 - t / 2 : x - headWidth / 2 + t / 2
            let tipY = up ? noteY - length : noteY + length
            path.addRect(CGRect(x: stemX - t / 2, y: min(noteY, tipY), width: t, height: length))
            if value.flagCount > 0 {
                SheetGlyphs.addFlags(path, stemX: stemX - t / 2, tipY: tipY,
                                     count: value.flagCount, up: up, s: s)
            }
        }

        let middleX = (afterClef + right) / 2

        switch drawingType {
        case .clef(let clef):
            addClef(clef, centerX: (left + right) / 2)

        case .note(let clef, let position, let accidental):
            addClef(clef)
            addNote(.quarter, position: position, x: middleX, accidental: accidental)

        case .noteValue(let value):
            addClef(.treble)
            addTime(4, 4, centerX: afterClef + 0.9 * s)
            addNote(value, position: 3, x: (afterClef + 2 * s + right) / 2)   // A4, stem up

        case .rest(let value):
            addClef(.treble)
            addTime(4, 4, centerX: afterClef + 0.9 * s)
            SheetGlyphs.addRest(path, value: value, x: (afterClef + 2 * s + right) / 2, centerY: y(4), s: s)

        case .timeSignature(let top, let bottom):
            addClef(.treble)
            addTime(top, bottom, centerX: middleX)

        case .keySignature(let fifths):
            addClef(.treble)
            let count = CGFloat(min(7, abs(fifths)))
            let width = 0.5 * s + count * 0.95 * s
            SheetGlyphs.addKeySignature(path, fifths: fifths, previous: 0, clef: .treble,
                                        x: middleX - width / 2, staffTop: staffTop, s: s)

        case .dynamic(let marking):
            addClef(.treble)
            addNote(.quarter, position: 3, x: middleX)
            let font = UIFont(name: "TimesNewRomanPS-BoldItalicMT", size: 2.6 * s)
                ?? UIFont.italicSystemFont(ofSize: 2.6 * s)
            textLayers.append(SheetGlyphs.textLayer(marking, font: font, color: ink, centerX: middleX,
                                                    centerY: bottomLine + 2.4 * s, scale: scale))
        }

        addShape(path, color: ink)
        textLayers.forEach(content.addSublayer)
    }

    /// The outline of the Unicode clef (𝄞 / 𝄢) from a font that has it (Apple Symbols, or
    /// whichever font the system falls back to).
    private static func clefGlyph(bass: Bool) -> CGPath? {
        let string = bass ? "𝄢" : "𝄞"
        let base = CTFontCreateWithName("AppleSymbols" as CFString, 100, nil)
        let font = CTFontCreateForString(base, string as CFString, CFRange(location: 0, length: string.utf16.count))
        var chars = Array(string.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        guard CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count), glyphs[0] != 0,
              let path = CTFontCreatePathForGlyph(font, glyphs[0], nil),
              !path.boundingBoxOfPath.isEmpty else { return nil }
        return path
    }

    private func addShape(_ path: CGPath, color: UIColor) {
        let shape = CAShapeLayer()
        shape.path = path
        shape.fillColor = color.cgColor
        shape.frame = content.bounds
        content.addSublayer(shape)
    }
}

// MARK: - Quiz Answer Button
class QuizAnswerButton: UIButton {
    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel?.numberOfLines = 0
        titleLabel?.textAlignment = .center
        setTitleColor(SemanticColors.Text.primary, for: .normal)

        // Visible default state — subtle fill + border
        backgroundColor = UIColor.white.withAlphaComponent(0.06)
        layer.cornerRadius = 14
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        clipsToBounds = true
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.96, y: 0.96)
                    : .identity
            }
        }
    }

    func setCorrect() {
        backgroundColor = SemanticColors.State.correctSubtle
        setTitleColor(SemanticColors.State.correct, for: .normal)
        layer.borderColor = SemanticColors.Border.success.cgColor
        transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        UIView.animate(withDuration: 0.4, delay: 0,
                       usingSpringWithDamping: 0.4, initialSpringVelocity: 0.5) {
            self.transform = .identity
        }
    }

    func setWrong() {
        backgroundColor = SemanticColors.State.incorrectSubtle
        setTitleColor(SemanticColors.State.incorrect, for: .normal)
        layer.borderColor = SemanticColors.Border.error.cgColor
        let shake = CABasicAnimation(keyPath: "position")
        shake.duration = 0.05
        shake.repeatCount = 3
        shake.autoreverses = true
        shake.fromValue = NSValue(cgPoint: CGPoint(x: center.x - 4, y: center.y))
        shake.toValue   = NSValue(cgPoint: CGPoint(x: center.x + 4, y: center.y))
        layer.add(shake, forKey: "shake")
    }
}
