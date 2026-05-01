//
//  UploadQuizPopup.swift
//  Re-Hearse_v1
//  Screens/MainUploadScreen/
//

import UIKit

// MARK: - Quiz Question Model
struct MusicQuizQuestion {
    let question: String
    let drawingType: StaffDrawingType
    let answers: [String]
    let correctIndex: Int
}

// MARK: - Staff Drawing Types
enum StaffDrawingType {
    case noteOnLine(line: Int, noteName: String)
    case noteInSpace(space: Int, noteName: String)
    case noteWithDuration(duration: NoteDuration, beats: String)
    case restSymbol(duration: NoteDuration)
    case timeSignature(top: Int, bottom: Int)
    case dynamicSymbol(symbol: String)
    case clef(type: ClefType)
}

enum NoteDuration { case whole, half, quarter, eighth }
enum ClefType { case treble, bass }

// MARK: - Static Question Bank
private let questionBank: [MusicQuizQuestion] = [
    MusicQuizQuestion(
        question: "What note is this?",
        drawingType: .noteOnLine(line: 1, noteName: "E"),
        answers: ["E", "F", "G"], correctIndex: 0
    ),
    MusicQuizQuestion(
        question: "What note is this?",
        drawingType: .noteInSpace(space: 1, noteName: "F"),
        answers: ["D", "E", "F"], correctIndex: 2
    ),
    MusicQuizQuestion(
        question: "What note is this?",
        drawingType: .noteOnLine(line: 3, noteName: "B"),
        answers: ["A", "B", "C"], correctIndex: 1
    ),
    MusicQuizQuestion(
        question: "What note is this?",
        drawingType: .noteInSpace(space: 3, noteName: "C"),
        answers: ["C", "D", "E"], correctIndex: 0
    ),
    MusicQuizQuestion(
        question: "How many beats does this note get?",
        drawingType: .noteWithDuration(duration: .whole, beats: "4"),
        answers: ["2", "3", "4"], correctIndex: 2
    ),
    MusicQuizQuestion(
        question: "How many beats does this note get?",
        drawingType: .noteWithDuration(duration: .half, beats: "2"),
        answers: ["1", "2", "4"], correctIndex: 1
    ),
    MusicQuizQuestion(
        question: "How many beats does this note get?",
        drawingType: .noteWithDuration(duration: .quarter, beats: "1"),
        answers: ["1", "2", "3"], correctIndex: 0
    ),
    MusicQuizQuestion(
        question: "What does this symbol mean?",
        drawingType: .restSymbol(duration: .quarter),
        answers: ["Play loud", "Silence", "Repeat"], correctIndex: 1
    ),
    MusicQuizQuestion(
        question: "What time signature is this?",
        drawingType: .timeSignature(top: 4, bottom: 4),
        answers: ["3/4", "2/4", "4/4"], correctIndex: 2
    ),
    MusicQuizQuestion(
        question: "What clef is this?",
        drawingType: .clef(type: .treble),
        answers: ["Bass clef", "Alto clef", "Treble clef"], correctIndex: 2
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

    private var questions: [MusicQuizQuestion] = []
    private var currentIndex = 0
    private var isAnswered = false

    // MARK: - UI
    private let dimView         = UIView()
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

    deinit { autoCloseTimer?.invalidate() }

    // MARK: - Public API
    func notifyUploadComplete() {
        uploadFinished = true
        DispatchQueue.main.async { self.showUploadDone() }
    }

    func updateProgress(_ value: Float) {
        DispatchQueue.main.async {
            let clamped = max(0, min(1, value))
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
        progressPctLabel.text = "18%"
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

        // Set initial 18% fill after first layout
        DispatchQueue.main.async {
            let trackWidth = self.progressTrack.bounds.width
            self.progressFillWidth.constant = trackWidth * 0.18
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
        questionLabel.numberOfLines = 0
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

        let closeDoneBtn = UIButton(type: .system)
        closeDoneBtn.setTitle("Done", for: .normal)
        closeDoneBtn.setTitleColor(.white, for: .normal)
        closeDoneBtn.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        closeDoneBtn.layer.cornerRadius = 24
        closeDoneBtn.contentEdgeInsets = UIEdgeInsets(top: 12, left: 40, bottom: 12, right: 40)
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
        staffView.setNeedsDisplay()

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
class StaffDrawingView: UIView {

    var drawingType: StaffDrawingType = .noteOnLine(line: 1, noteName: "E")

    private let notationColor = SemanticColors.Text.musicNotation
    private let staffColor    = SemanticColors.Border.default

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)

        let w = rect.width, h = rect.height

        // Staff lines — vertically centred with comfortable padding
        let staffTop:    CGFloat = h * 0.18
        let staffBottom: CGFloat = h * 0.78
        let lineSpacing: CGFloat = (staffBottom - staffTop) / 4.0

        ctx.setStrokeColor(staffColor.cgColor)
        ctx.setLineWidth(1.2)
        for i in 0..<5 {
            let y = staffBottom - CGFloat(i) * lineSpacing
            ctx.move(to: CGPoint(x: w * 0.06, y: y))
            ctx.addLine(to: CGPoint(x: w * 0.94, y: y))
            ctx.strokePath()
        }

        switch drawingType {
        case .noteOnLine(let line, _):
            let y = staffBottom - CGFloat(line - 1) * lineSpacing
            drawFilledNote(ctx: ctx, noteY: y, lineSpacing: lineSpacing,
                           staffBottom: staffBottom, centerX: w * 0.55)

        case .noteInSpace(let space, _):
            let y = staffBottom - (CGFloat(space) - 0.5) * lineSpacing
            drawFilledNote(ctx: ctx, noteY: y, lineSpacing: lineSpacing,
                           staffBottom: staffBottom, centerX: w * 0.55)

        case .noteWithDuration(let dur, _):
            drawDurationNote(ctx: ctx, duration: dur,
                             centerX: w * 0.55,
                             centerY: staffBottom - 2 * lineSpacing,
                             lineSpacing: lineSpacing)

        case .restSymbol(let dur):
            drawRest(ctx: ctx, duration: dur, rect: rect,
                     staffBottom: staffBottom, lineSpacing: lineSpacing)

        case .timeSignature(let top, let bottom):
            drawTimeSignature(ctx: ctx, top: top, bottom: bottom,
                              staffBottom: staffBottom, lineSpacing: lineSpacing, rect: rect)

        case .dynamicSymbol(let symbol):
            drawDynamic(ctx: ctx, symbol: symbol, rect: rect)

        case .clef(let type):
            drawClef(ctx: ctx, type: type, staffBottom: staffBottom,
                     lineSpacing: lineSpacing, rect: rect)
        }
    }

    // MARK: Note helpers
    private func drawFilledNote(ctx: CGContext, noteY: CGFloat, lineSpacing: CGFloat,
                                staffBottom: CGFloat, centerX: CGFloat) {
        let rx = lineSpacing * 0.58, ry = lineSpacing * 0.42

        ctx.saveGState()
        ctx.translateBy(x: centerX, y: noteY)
        ctx.rotate(by: -0.28)
        ctx.setFillColor(notationColor.cgColor)
        ctx.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
        ctx.restoreGState()

        ctx.setStrokeColor(notationColor.cgColor)
        ctx.setLineWidth(1.8)
        ctx.move(to: CGPoint(x: centerX + rx * 0.85, y: noteY))
        ctx.addLine(to: CGPoint(x: centerX + rx * 0.85, y: noteY - lineSpacing * 2.8))
        ctx.strokePath()

        if noteY > staffBottom + 2 {
            ctx.setStrokeColor(staffColor.cgColor)
            ctx.setLineWidth(1.2)
            ctx.move(to: CGPoint(x: centerX - rx * 1.6, y: staffBottom))
            ctx.addLine(to: CGPoint(x: centerX + rx * 1.6, y: staffBottom))
            ctx.strokePath()
        }
    }

    private func drawDurationNote(ctx: CGContext, duration: NoteDuration,
                                  centerX: CGFloat, centerY: CGFloat, lineSpacing: CGFloat) {
        let rx = lineSpacing * 0.58, ry = lineSpacing * 0.42

        ctx.saveGState()
        ctx.translateBy(x: centerX, y: centerY)
        ctx.rotate(by: -0.28)
        let r = CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)

        switch duration {
        case .whole:
            ctx.setStrokeColor(notationColor.cgColor)
            ctx.setFillColor(UIColor.clear.cgColor)
            ctx.setLineWidth(2.0)
            ctx.strokeEllipse(in: r)
            ctx.restoreGState()

        case .half:
            ctx.setStrokeColor(notationColor.cgColor)
            ctx.setFillColor(UIColor.clear.cgColor)
            ctx.setLineWidth(2.0)
            ctx.strokeEllipse(in: r)
            ctx.restoreGState()
            ctx.setStrokeColor(notationColor.cgColor)
            ctx.setLineWidth(1.8)
            ctx.move(to: CGPoint(x: centerX + rx * 0.85, y: centerY))
            ctx.addLine(to: CGPoint(x: centerX + rx * 0.85, y: centerY - lineSpacing * 2.8))
            ctx.strokePath()

        case .quarter:
            ctx.setFillColor(notationColor.cgColor)
            ctx.fillEllipse(in: r)
            ctx.restoreGState()
            ctx.setStrokeColor(notationColor.cgColor)
            ctx.setLineWidth(1.8)
            ctx.move(to: CGPoint(x: centerX + rx * 0.85, y: centerY))
            ctx.addLine(to: CGPoint(x: centerX + rx * 0.85, y: centerY - lineSpacing * 2.8))
            ctx.strokePath()

        case .eighth:
            ctx.setFillColor(notationColor.cgColor)
            ctx.fillEllipse(in: r)
            ctx.restoreGState()
            let stemTopY = centerY - lineSpacing * 2.8
            ctx.setStrokeColor(notationColor.cgColor)
            ctx.setLineWidth(1.8)
            ctx.move(to: CGPoint(x: centerX + rx * 0.85, y: centerY))
            ctx.addLine(to: CGPoint(x: centerX + rx * 0.85, y: stemTopY))
            ctx.strokePath()
            let flag = UIBezierPath()
            flag.move(to: CGPoint(x: centerX + rx * 0.85, y: stemTopY))
            flag.addCurve(
                to: CGPoint(x: centerX + rx * 0.85 + lineSpacing * 0.8, y: stemTopY + lineSpacing),
                controlPoint1: CGPoint(x: centerX + rx * 0.85 + lineSpacing, y: stemTopY),
                controlPoint2: CGPoint(x: centerX + rx * 0.85 + lineSpacing * 1.2, y: stemTopY + lineSpacing * 0.5))
            flag.stroke()
        }
    }

    private func drawRest(ctx: CGContext, duration: NoteDuration, rect: CGRect,
                          staffBottom: CGFloat, lineSpacing: CGFloat) {
        let cx = rect.width * 0.55
        let midY = staffBottom - 2 * lineSpacing

        ctx.setFillColor(notationColor.cgColor)
        ctx.setStrokeColor(notationColor.cgColor)

        switch duration {
        case .whole:
            ctx.fill(CGRect(x: cx - lineSpacing * 0.8, y: staffBottom - 3 * lineSpacing,
                            width: lineSpacing * 1.6, height: lineSpacing * 0.55))
        case .half:
            ctx.fill(CGRect(x: cx - lineSpacing * 0.8, y: midY - lineSpacing * 0.55,
                            width: lineSpacing * 1.6, height: lineSpacing * 0.55))
        case .quarter:
            ctx.setLineWidth(2.0)
            ctx.setLineCap(.round)
            let pts: [CGPoint] = [
                CGPoint(x: cx - lineSpacing * 0.2, y: midY - lineSpacing * 1.2),
                CGPoint(x: cx + lineSpacing * 0.4, y: midY - lineSpacing * 0.5),
                CGPoint(x: cx - lineSpacing * 0.3, y: midY),
                CGPoint(x: cx + lineSpacing * 0.5, y: midY + lineSpacing * 0.5),
                CGPoint(x: cx - lineSpacing * 0.1, y: midY + lineSpacing * 1.2),
            ]
            ctx.move(to: pts[0])
            pts.dropFirst().forEach { ctx.addLine(to: $0) }
            ctx.strokePath()
        case .eighth:
            ctx.setLineWidth(1.8)
            ctx.strokeEllipse(in: CGRect(x: cx - lineSpacing * 0.3, y: midY - lineSpacing * 0.3,
                                         width: lineSpacing * 0.6, height: lineSpacing * 0.6))
            ctx.move(to: CGPoint(x: cx + lineSpacing * 0.3, y: midY))
            ctx.addLine(to: CGPoint(x: cx + lineSpacing * 0.6, y: midY - lineSpacing * 1.2))
            ctx.strokePath()
        }
    }

    private func drawTimeSignature(ctx: CGContext, top: Int, bottom: Int,
                                   staffBottom: CGFloat, lineSpacing: CGFloat, rect: CGRect) {
        let cx = rect.width * 0.50
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: lineSpacing * 1.5),
            .foregroundColor: notationColor,
        ]
        let topStr = "\(top)" as NSString
        let botStr = "\(bottom)" as NSString
        let sz = topStr.size(withAttributes: attrs)
        topStr.draw(at: CGPoint(x: cx - sz.width / 2, y: staffBottom - 4 * lineSpacing), withAttributes: attrs)
        botStr.draw(at: CGPoint(x: cx - sz.width / 2, y: staffBottom - 2 * lineSpacing), withAttributes: attrs)
    }

    private func drawDynamic(ctx: CGContext, symbol: String, rect: CGRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 36),
            .foregroundColor: notationColor,
        ]
        let str = symbol as NSString
        let sz = str.size(withAttributes: attrs)
        str.draw(at: CGPoint(x: rect.width / 2 - sz.width / 2,
                             y: rect.height / 2 - sz.height / 2), withAttributes: attrs)
    }

    private func drawClef(ctx: CGContext, type: ClefType, staffBottom: CGFloat,
                          lineSpacing: CGFloat, rect: CGRect) {
        let cx = rect.width * 0.50

        switch type {
        case .treble:
            ctx.setStrokeColor(notationColor.cgColor)
            ctx.setLineWidth(2.2)
            ctx.setLineCap(.round)

            let baseY  = staffBottom
            let topY   = baseY - 4 * lineSpacing - lineSpacing * 0.8
            let circleY = baseY - lineSpacing
            let circleR: CGFloat = lineSpacing * 0.85

            ctx.move(to: CGPoint(x: cx, y: baseY + lineSpacing * 0.6))
            ctx.addLine(to: CGPoint(x: cx, y: topY))
            ctx.strokePath()

            ctx.setLineWidth(2.0)
            ctx.strokeEllipse(in: CGRect(x: cx - circleR, y: circleY - circleR,
                                         width: circleR * 2, height: circleR * 2))

            let curl = UIBezierPath()
            curl.move(to: CGPoint(x: cx, y: baseY + lineSpacing * 0.6))
            curl.addCurve(
                to: CGPoint(x: cx - lineSpacing * 0.7, y: baseY + lineSpacing * 0.2),
                controlPoint1: CGPoint(x: cx + lineSpacing * 0.5, y: baseY + lineSpacing),
                controlPoint2: CGPoint(x: cx - lineSpacing * 0.5, y: baseY + lineSpacing * 0.8))
            ctx.setLineWidth(2.2)
            curl.stroke()

        case .bass:
            ctx.setFillColor(notationColor.cgColor)
            ctx.setStrokeColor(notationColor.cgColor)
            ctx.setLineWidth(2.0)

            let startY = staffBottom - 3 * lineSpacing
            let bassCurve = UIBezierPath()
            bassCurve.move(to: CGPoint(x: cx, y: startY))
            bassCurve.addCurve(
                to: CGPoint(x: cx - lineSpacing * 0.4, y: startY + lineSpacing * 2),
                controlPoint1: CGPoint(x: cx + lineSpacing * 1.2, y: startY + lineSpacing * 0.4),
                controlPoint2: CGPoint(x: cx + lineSpacing * 0.8, y: startY + lineSpacing * 1.8))
            bassCurve.stroke()

            let dotR: CGFloat = 4
            ctx.fillEllipse(in: CGRect(x: cx + lineSpacing * 0.9, y: startY - dotR,
                                       width: dotR * 2, height: dotR * 2))
            ctx.fillEllipse(in: CGRect(x: cx + lineSpacing * 0.9, y: startY + lineSpacing * 0.7 - dotR,
                                       width: dotR * 2, height: dotR * 2))
        }
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