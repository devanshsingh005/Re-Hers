//
//  UploadQuizPopup.swift
//  Re-Hearse_v1
//  Screens/MainUplaodScreen/
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
    case noteOnLine(line: Int, noteName: String)      // line 1–5 from bottom
    case noteInSpace(space: Int, noteName: String)    // space 1–4 from bottom
    case noteWithDuration(duration: NoteDuration, beats: String)
    case restSymbol(duration: NoteDuration)
    case timeSignature(top: Int, bottom: Int)
    case dynamicSymbol(symbol: String)
    case clef(type: ClefType)
}

enum NoteDuration { case whole, half, quarter, eighth }
enum ClefType { case treble, bass }

// MARK: - Static Question Bank (10 questions)
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
    
    // Upload state
    private var uploadFinished = false
    private var autoCloseTimer: Timer?
    
    // Quiz state
    private var questions: [MusicQuizQuestion] = []
    private var currentIndex = 0
    private var isAnswered = false
    
    // MARK: - UI
    private let dimView = UIView()
    private let cardView = UIView()
    
    // Header
    private let cloudIconWrap = UIView()
    private let cloudIcon = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private let closeBtn = UIButton(type: .system)
    
    // Quiz card
    private let quizCard = UIView()
    private let questionLabel = UILabel()
    private let staffView = StaffDrawingView()
    private let answersStack = UIStackView()
    
    // Page dots
    private let dotsStack = UIStackView()
    
    // Upload done overlay
    private let doneOverlay = UIView()
    private let checkCircle = UIView()
    private let checkLayer = CAShapeLayer()
    private let doneLabel = UILabel()
    private let doneSubLabel = UILabel()
    
    // MARK: - Init
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        
        questions = Array(questionBank.shuffled().prefix(10))
        
        setupDimView()
        setupCard()
        setupHeader()
        setupQuizCard()
        setupDots()
        setupDoneOverlay()
        
        loadQuestion(at: 0)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }
    
    // MARK: - Public API
    /// Call when upload completes successfully
    func notifyUploadComplete() {
        uploadFinished = true
        DispatchQueue.main.async { self.showUploadDone() }
    }
    
    /// Call to update the progress bar (0.0 – 1.0)
    func updateProgress(_ value: Float) {
        DispatchQueue.main.async {
            self.progressBar.setProgress(value, animated: true)
        }
    }
    
    // MARK: - Dim + Card Container
    private func setupDimView() {
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        dimView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupCard() {
        cardView.backgroundColor = UIColor(red: 0.96, green: 0.95, blue: 0.94, alpha: 1.0)
        cardView.layer.cornerRadius = 28
        cardView.clipsToBounds = true
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.alpha = 0
        cardView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        view.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }
    
    // MARK: - Header (cloud icon, title, progress, close)
    private func setupHeader() {
        // Close button
        closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeBtn.tintColor = .secondaryLabel
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addAction(UIAction { [weak self] _ in self?.dismissPopup() }, for: .touchUpInside)
        cardView.addSubview(closeBtn)
        
        // Cloud icon wrap (orange tinted circle)
        cloudIconWrap.backgroundColor = UIColor(hex: "#FF6B00").withAlphaComponent(0.12)
        cloudIconWrap.layer.cornerRadius = 26
        cloudIconWrap.translatesAutoresizingMaskIntoConstraints = false
        
        cloudIcon.image = UIImage(systemName: "icloud.and.arrow.up")
        cloudIcon.tintColor = UIColor(hex: "#FF6B00")
        cloudIcon.contentMode = .scaleAspectFit
        cloudIcon.translatesAutoresizingMaskIntoConstraints = false
        cloudIconWrap.addSubview(cloudIcon)
        cardView.addSubview(cloudIconWrap)
        
        // Title
        titleLabel.text = "Uploading your sheet..."
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        // Subtitle
        subtitleLabel.text = "Analyzing notes..."
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(subtitleLabel)
        
        // Progress bar
        progressBar.progressTintColor = UIColor(hex: "#EF9408")
        progressBar.trackTintColor = UIColor(hex: "#EF9408").withAlphaComponent(0.15)
        progressBar.layer.cornerRadius = 3
        progressBar.clipsToBounds = true
        progressBar.setProgress(0.15, animated: false)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(progressBar)
        
        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            closeBtn.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            closeBtn.widthAnchor.constraint(equalToConstant: 28),
            closeBtn.heightAnchor.constraint(equalToConstant: 28),
            
            cloudIconWrap.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 28),
            cloudIconWrap.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            cloudIconWrap.widthAnchor.constraint(equalToConstant: 52),
            cloudIconWrap.heightAnchor.constraint(equalToConstant: 52),
            
            cloudIcon.centerXAnchor.constraint(equalTo: cloudIconWrap.centerXAnchor),
            cloudIcon.centerYAnchor.constraint(equalTo: cloudIconWrap.centerYAnchor),
            cloudIcon.widthAnchor.constraint(equalToConstant: 26),
            cloudIcon.heightAnchor.constraint(equalToConstant: 26),
            
            titleLabel.topAnchor.constraint(equalTo: cloudIconWrap.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            
            progressBar.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            progressBar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            progressBar.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            progressBar.heightAnchor.constraint(equalToConstant: 6),
        ])
    }
    
    // MARK: - Quiz Card
    private func setupQuizCard() {
        quizCard.backgroundColor = .systemBackground
        quizCard.layer.cornerRadius = 20
        quizCard.layer.shadowColor = UIColor.black.cgColor
        quizCard.layer.shadowOpacity = 0.06
        quizCard.layer.shadowRadius = 10
        quizCard.layer.shadowOffset = CGSize(width: 0, height: 3)
        quizCard.clipsToBounds = false
        quizCard.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(quizCard)
        
        // Question label
        questionLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        questionLabel.textColor = .label
        questionLabel.textAlignment = .center
        questionLabel.translatesAutoresizingMaskIntoConstraints = false
        quizCard.addSubview(questionLabel)
        
        // Staff drawing view
        staffView.translatesAutoresizingMaskIntoConstraints = false
        staffView.backgroundColor = .clear
        quizCard.addSubview(staffView)
        
        // Answers stack
        answersStack.axis = .horizontal
        answersStack.spacing = 10
        answersStack.distribution = .fillEqually
        answersStack.translatesAutoresizingMaskIntoConstraints = false
        quizCard.addSubview(answersStack)
        
        NSLayoutConstraint.activate([
            quizCard.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 18),
            quizCard.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            quizCard.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            questionLabel.topAnchor.constraint(equalTo: quizCard.topAnchor, constant: 20),
            questionLabel.leadingAnchor.constraint(equalTo: quizCard.leadingAnchor, constant: 16),
            questionLabel.trailingAnchor.constraint(equalTo: quizCard.trailingAnchor, constant: -16),
            
            staffView.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 16),
            staffView.leadingAnchor.constraint(equalTo: quizCard.leadingAnchor, constant: 16),
            staffView.trailingAnchor.constraint(equalTo: quizCard.trailingAnchor, constant: -16),
            staffView.heightAnchor.constraint(equalToConstant: 130),
            
            answersStack.topAnchor.constraint(equalTo: staffView.bottomAnchor, constant: 18),
            answersStack.leadingAnchor.constraint(equalTo: quizCard.leadingAnchor, constant: 16),
            answersStack.trailingAnchor.constraint(equalTo: quizCard.trailingAnchor, constant: -16),
            answersStack.heightAnchor.constraint(equalToConstant: 48),
            answersStack.bottomAnchor.constraint(equalTo: quizCard.bottomAnchor, constant: -20),
        ])
    }
    
    // MARK: - Page dots
    private func setupDots() {
        dotsStack.axis = .horizontal
        dotsStack.spacing = 6
        dotsStack.alignment = .center
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(dotsStack)
        
        for i in 0..<min(questions.count, 10) {
            let dot = UIView()
            dot.layer.cornerRadius = 4
            dot.backgroundColor = i == 0
                ? UIColor(hex: "#FF6B00")
                : UIColor(hex: "#FF6B00").withAlphaComponent(0.25)
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: i == 0 ? 16 : 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            dotsStack.addArrangedSubview(dot)
        }
        
        NSLayoutConstraint.activate([
            dotsStack.topAnchor.constraint(equalTo: quizCard.bottomAnchor, constant: 16),
            dotsStack.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            dotsStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
        ])
    }
    
    // MARK: - Done Overlay
    private func setupDoneOverlay() {
        doneOverlay.backgroundColor = UIColor(red: 0.96, green: 0.95, blue: 0.94, alpha: 1.0)
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
        
        // Check circle
        checkCircle.backgroundColor = UIColor(hex: "#FF6B00").withAlphaComponent(0.12)
        checkCircle.layer.cornerRadius = 40
        checkCircle.translatesAutoresizingMaskIntoConstraints = false
        doneOverlay.addSubview(checkCircle)
        
        // Check layer (animated stroke)
        checkLayer.strokeColor = UIColor(hex: "#FF6B00").cgColor
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
        
        doneSubLabel.text = "Closing in 5 seconds..."
        doneSubLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        doneSubLabel.textColor = .secondaryLabel
        doneSubLabel.textAlignment = .center
        doneSubLabel.translatesAutoresizingMaskIntoConstraints = false
        doneOverlay.addSubview(doneSubLabel)
        
        let closeDoneBtn = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "Done"
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor(hex: "#FF6B00")
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 40, bottom: 12, trailing: 40)
        closeDoneBtn.configuration = config
        closeDoneBtn.translatesAutoresizingMaskIntoConstraints = false
        closeDoneBtn.addAction(UIAction { [weak self] _ in self?.dismissPopup() }, for: .touchUpInside)
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
        guard index < questions.count else { dismissPopup(); return }
        
        isAnswered = false
        let q = questions[index]
        questionLabel.text = q.question
        staffView.drawingType = q.drawingType
        staffView.setNeedsDisplay()
        
        // Clear old answer buttons
        answersStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for (i, answer) in q.answers.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(answer, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            btn.layer.cornerRadius = 22
            btn.clipsToBounds = true
            btn.tag = i
            
            if i == q.correctIndex {
                // Pre-mark correct answer button with orange style
                btn.setTitleColor(UIColor(hex: "#FF6B00"), for: .normal)
                btn.backgroundColor = UIColor(hex: "#FF6B00").withAlphaComponent(0.10)
                btn.layer.borderWidth = 1.5
                btn.layer.borderColor = UIColor(hex: "#FF6B00").withAlphaComponent(0.3).cgColor
            } else {
                btn.setTitleColor(.label, for: .normal)
                btn.backgroundColor = UIColor.systemGray6
                btn.layer.borderWidth = 0
            }
            
            btn.addAction(UIAction { [weak self] _ in
                self?.handleAnswer(selectedIndex: i)
            }, for: .touchUpInside)
            
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
            guard let btn = view as? UIButton else { continue }
            
            UIView.animate(withDuration: 0.2) {
                if i == q.correctIndex {
                    // Always highlight correct in green
                    btn.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
                    btn.setTitleColor(UIColor.systemGreen, for: .normal)
                    btn.layer.borderWidth = 1.5
                    btn.layer.borderColor = UIColor.systemGreen.cgColor
                } else if i == selectedIndex && !isCorrect {
                    // Highlight wrong selection in red
                    btn.backgroundColor = UIColor.systemRed.withAlphaComponent(0.12)
                    btn.setTitleColor(UIColor.systemRed, for: .normal)
                    btn.layer.borderWidth = 1.5
                    btn.layer.borderColor = UIColor.systemRed.cgColor
                }
            }
        }
        
        // Pulse the card
        UIView.animate(withDuration: 0.1, animations: {
            self.quizCard.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { _ in
            UIView.animate(withDuration: 0.15) {
                self.quizCard.transform = .identity
            }
        }
        
        // Auto-advance after 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            self.currentIndex += 1
            if self.currentIndex < self.questions.count {
                self.animateQuizTransition {
                    self.loadQuestion(at: self.currentIndex)
                }
            } else {
                // Cycled through all — restart from beginning if upload still running
                if !self.uploadFinished {
                    self.currentIndex = 0
                    self.questions = Array(questionBank.shuffled().prefix(10))
                    self.animateQuizTransition { self.loadQuestion(at: 0) }
                }
            }
        }
    }
    
    // MARK: - Dot Updates
    private func updateDots(activeIndex: Int) {
        for (i, dot) in dotsStack.arrangedSubviews.enumerated() {
            guard let dotView = dot as UIView? else { continue }
            UIView.animate(withDuration: 0.2) {
                if i == activeIndex {
                    dotView.backgroundColor = UIColor(hex: "#FF6B00")
                    dotView.constraints.forEach {
                        if $0.firstAttribute == .width { $0.constant = 16 }
                    }
                } else {
                    dotView.backgroundColor = UIColor(hex: "#FF6B00").withAlphaComponent(0.25)
                    dotView.constraints.forEach {
                        if $0.firstAttribute == .width { $0.constant = 8 }
                    }
                }
            }
        }
    }
    
    // MARK: - Upload Done
    private func showUploadDone() {
        progressBar.setProgress(1.0, animated: true)
        
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
        // Checkmark path centered in 80×80 circle
        path.move(to: CGPoint(x: 22, y: 40))
        path.addLine(to: CGPoint(x: 34, y: 54))
        path.addLine(to: CGPoint(x: 58, y: 28))
        checkLayer.path = path.cgPath
        checkLayer.frame = CGRect(x: 0, y: 0, width: size, height: size)
        
        let anim = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue = 0
        anim.toValue = 1
        anim.duration = 0.5
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        checkLayer.add(anim, forKey: "checkmark")
        checkLayer.strokeEnd = 1
        
        // Pulse the circle
        UIView.animate(withDuration: 0.3, delay: 0.4,
                       usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            self.checkCircle.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.checkCircle.transform = .identity
            }
        }
    }
    
    private func startAutoCloseCountdown() {
        var remaining = 5
        autoCloseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            remaining -= 1
            self.doneSubLabel.text = remaining > 0
                ? "Closing in \(remaining) second\(remaining == 1 ? "" : "s")..."
                : "Closing..."
            if remaining <= 0 {
                timer.invalidate()
                self.dismissPopup()
            }
        }
    }
    
    // MARK: - Animations
    private func animateIn() {
        UIView.animate(withDuration: 0.38, delay: 0,
                       usingSpringWithDamping: 0.75, initialSpringVelocity: 0.3) {
            self.cardView.alpha = 1
            self.cardView.transform = .identity
        }
    }
    
    private func animateQuizTransition(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.15, animations: {
            self.quizCard.alpha = 0
            self.quizCard.transform = CGAffineTransform(translationX: -20, y: 0)
        }) { _ in
            completion()
            self.quizCard.transform = CGAffineTransform(translationX: 20, y: 0)
            UIView.animate(withDuration: 0.2, delay: 1,
                           usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
                self.quizCard.alpha = 1
                self.quizCard.transform = .identity
            }
        }
    }
    
    private func dismissPopup() {
        autoCloseTimer?.invalidate()
        UIView.animate(withDuration: 0.25, animations: {
            self.cardView.alpha = 0
            self.cardView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            self.dimView.alpha = 0
        }) { _ in
            self.delegate?.uploadQuizPopupDidClose(self)
            self.dismiss(animated: false)
        }
    }
}

// MARK: - Staff Drawing View
class StaffDrawingView: UIView {
    
    var drawingType: StaffDrawingType = .noteOnLine(line: 1, noteName: "E")
    
    private let orangeColor = UIColor(hex: "#FF6B00")
    private let staffColor   = UIColor(red: 0.55, green: 0.55, blue: 0.6, alpha: 1.0)
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)
        
        let w = rect.width
        let h = rect.height
        
        // Draw 5 staff lines centered vertically
        let staffTop: CGFloat    = h * 0.22
        let staffBottom: CGFloat = h * 0.72
        let lineSpacing: CGFloat = (staffBottom - staffTop) / 4.0
        
        ctx.setStrokeColor(staffColor.cgColor)
        ctx.setLineWidth(1.2)
        
        for i in 0..<5 {
            let y = staffBottom - CGFloat(i) * lineSpacing
            ctx.move(to: CGPoint(x: w * 0.08, y: y))
            ctx.addLine(to: CGPoint(x: w * 0.92, y: y))
            ctx.strokePath()
        }
        
        switch drawingType {
        case .noteOnLine(let line, _):
            drawFilledNote(ctx: ctx, staffBottom: staffBottom, lineSpacing: lineSpacing,
                           yOffset: CGFloat(line - 1) * lineSpacing, centerX: w * 0.55, isOnLine: true)
            
        case .noteInSpace(let space, _):
            let y = staffBottom - (CGFloat(space) - 0.5) * lineSpacing
            drawFilledNote(ctx: ctx, staffBottom: staffBottom, lineSpacing: lineSpacing,
                           yOffset: 0, centerX: w * 0.55, overrideY: y)
            
        case .noteWithDuration(let dur, _):
            drawDurationNote(ctx: ctx, duration: dur, centerX: w * 0.55,
                             centerY: staffBottom - 2 * lineSpacing, lineSpacing: lineSpacing)
            
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
    
    // MARK: - Note helpers
    private func drawFilledNote(ctx: CGContext, staffBottom: CGFloat, lineSpacing: CGFloat,
                                yOffset: CGFloat, centerX: CGFloat, isOnLine: Bool = false,
                                overrideY: CGFloat? = nil) {
        let noteY = overrideY ?? (staffBottom - yOffset)
        let rx: CGFloat = lineSpacing * 0.58
        let ry: CGFloat = lineSpacing * 0.42
        
        // Note head (filled ellipse, slightly tilted)
        ctx.saveGState()
        ctx.translateBy(x: centerX, y: noteY)
        ctx.rotate(by: -0.3)
        let ellipseRect = CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)
        ctx.setFillColor(UIColor.label.cgColor)
        ctx.fillEllipse(in: ellipseRect)
        ctx.restoreGState()
        
        // Stem (up)
        ctx.setStrokeColor(UIColor.label.cgColor)
        ctx.setLineWidth(1.8)
        ctx.move(to: CGPoint(x: centerX + rx * 0.85, y: noteY))
        ctx.addLine(to: CGPoint(x: centerX + rx * 0.85, y: noteY - lineSpacing * 2.8))
        ctx.strokePath()
        
        // Ledger lines if note is below staff
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
        let rx: CGFloat = lineSpacing * 0.58
        let ry: CGFloat = lineSpacing * 0.42
        
        ctx.saveGState()
        ctx.translateBy(x: centerX, y: centerY)
        ctx.rotate(by: -0.3)
        let ellipseRect = CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2)
        
        switch duration {
        case .whole:
            // Open note head, no stem
            ctx.setStrokeColor(UIColor.label.cgColor)
            ctx.setFillColor(UIColor.clear.cgColor)
            ctx.setLineWidth(2.0)
            ctx.strokeEllipse(in: ellipseRect)
            ctx.restoreGState()
            
        case .half:
            // Open note head with stem
            ctx.setStrokeColor(UIColor.label.cgColor)
            ctx.setFillColor(UIColor.clear.cgColor)
            ctx.setLineWidth(2.0)
            ctx.strokeEllipse(in: ellipseRect)
            ctx.restoreGState()
            ctx.setLineWidth(1.8)
            ctx.move(to: CGPoint(x: centerX + rx * 0.85, y: centerY))
            ctx.addLine(to: CGPoint(x: centerX + rx * 0.85, y: centerY - lineSpacing * 2.8))
            ctx.strokePath()
            
        case .quarter:
            // Filled note head with stem
            ctx.setFillColor(UIColor.label.cgColor)
            ctx.fillEllipse(in: ellipseRect)
            ctx.restoreGState()
            ctx.setLineWidth(1.8)
            ctx.move(to: CGPoint(x: centerX + rx * 0.85, y: centerY))
            ctx.addLine(to: CGPoint(x: centerX + rx * 0.85, y: centerY - lineSpacing * 2.8))
            ctx.strokePath()
            
        case .eighth:
            // Filled note head, stem + flag
            ctx.setFillColor(UIColor.label.cgColor)
            ctx.fillEllipse(in: ellipseRect)
            ctx.restoreGState()
            let stemTopY = centerY - lineSpacing * 2.8
            ctx.setLineWidth(1.8)
            ctx.move(to: CGPoint(x: centerX + rx * 0.85, y: centerY))
            ctx.addLine(to: CGPoint(x: centerX + rx * 0.85, y: stemTopY))
            ctx.strokePath()
            // Flag
            let flagPath = UIBezierPath()
            flagPath.move(to: CGPoint(x: centerX + rx * 0.85, y: stemTopY))
            flagPath.addCurve(to: CGPoint(x: centerX + rx * 0.85 + lineSpacing * 0.8, y: stemTopY + lineSpacing),
                              controlPoint1: CGPoint(x: centerX + rx * 0.85 + lineSpacing, y: stemTopY),
                              controlPoint2: CGPoint(x: centerX + rx * 0.85 + lineSpacing * 1.2, y: stemTopY + lineSpacing * 0.5))
            ctx.setStrokeColor(UIColor.label.cgColor)
            ctx.setLineWidth(1.8)
            flagPath.stroke()
        }
    }
    
    // MARK: - Rest
    private func drawRest(ctx: CGContext, duration: NoteDuration, rect: CGRect,
                          staffBottom: CGFloat, lineSpacing: CGFloat) {
        let cx = rect.width * 0.55
        let midY = staffBottom - 2 * lineSpacing
        
        ctx.setFillColor(UIColor.label.cgColor)
        ctx.setStrokeColor(UIColor.label.cgColor)
        
        switch duration {
        case .whole:
            // Filled rectangle hanging from 4th line
            let restY = staffBottom - 3 * lineSpacing
            ctx.fill(CGRect(x: cx - lineSpacing * 0.8, y: restY,
                            width: lineSpacing * 1.6, height: lineSpacing * 0.55))
        case .half:
            // Filled rectangle sitting on 3rd line
            let restY = staffBottom - 2 * lineSpacing - lineSpacing * 0.55
            ctx.fill(CGRect(x: cx - lineSpacing * 0.8, y: restY,
                            width: lineSpacing * 1.6, height: lineSpacing * 0.55))
        case .quarter:
            // Zigzag rest symbol
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
            for p in pts.dropFirst() { ctx.addLine(to: p) }
            ctx.strokePath()
        case .eighth:
            // Circle + stem
            ctx.setLineWidth(1.8)
            ctx.strokeEllipse(in: CGRect(x: cx - lineSpacing * 0.3, y: midY - lineSpacing * 0.3,
                                         width: lineSpacing * 0.6, height: lineSpacing * 0.6))
            ctx.move(to: CGPoint(x: cx + lineSpacing * 0.3, y: midY))
            ctx.addLine(to: CGPoint(x: cx + lineSpacing * 0.3 + lineSpacing * 0.3, y: midY - lineSpacing * 1.2))
            ctx.strokePath()
        }
    }
    
    // MARK: - Time Signature
    private func drawTimeSignature(ctx: CGContext, top: Int, bottom: Int, staffBottom: CGFloat,
                                   lineSpacing: CGFloat, rect: CGRect) {
        let cx = rect.width * 0.50
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: lineSpacing * 1.5),
            .foregroundColor: UIColor.label
        ]
        let topStr = "\(top)" as NSString
        let botStr = "\(bottom)" as NSString
        let sz = topStr.size(withAttributes: attrs)
        topStr.draw(at: CGPoint(x: cx - sz.width / 2,
                                y: staffBottom - 4 * lineSpacing), withAttributes: attrs)
        botStr.draw(at: CGPoint(x: cx - sz.width / 2,
                                y: staffBottom - 2 * lineSpacing), withAttributes: attrs)
    }
    
    // MARK: - Dynamic
    private func drawDynamic(ctx: CGContext, symbol: String, rect: CGRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 36),
            .foregroundColor: UIColor.label
        ]
        let str = symbol as NSString
        let sz = str.size(withAttributes: attrs)
        str.draw(at: CGPoint(x: rect.width / 2 - sz.width / 2,
                             y: rect.height / 2 - sz.height / 2), withAttributes: attrs)
    }
    
    // MARK: - Treble / Bass Clef
    private func drawClef(ctx: CGContext, type: ClefType, staffBottom: CGFloat,
                          lineSpacing: CGFloat, rect: CGRect) {
        let cx = rect.width * 0.50
        
        switch type {
        case .treble:
            // Treble clef using SF Symbol fallback — drawn as stylised G path
            ctx.setStrokeColor(UIColor.label.cgColor)
            ctx.setFillColor(UIColor.label.cgColor)
            ctx.setLineWidth(2.2)
            ctx.setLineCap(.round)
            
            let baseY = staffBottom
            let top    = baseY - 4 * lineSpacing - lineSpacing * 0.8
            let circleY = baseY - lineSpacing           // G line (2nd from bottom)
            let circleR: CGFloat = lineSpacing * 0.85
            
            // Vertical spine
            ctx.move(to: CGPoint(x: cx, y: baseY + lineSpacing * 0.6))
            ctx.addLine(to: CGPoint(x: cx, y: top))
            ctx.strokePath()
            
            // Circle around G line
            ctx.setLineWidth(2.0)
            ctx.strokeEllipse(in: CGRect(x: cx - circleR, y: circleY - circleR,
                                         width: circleR * 2, height: circleR * 2))
            
            // Curl at bottom
            let curlPath = UIBezierPath()
            curlPath.move(to: CGPoint(x: cx, y: baseY + lineSpacing * 0.6))
            curlPath.addCurve(
                to: CGPoint(x: cx - lineSpacing * 0.7, y: baseY + lineSpacing * 0.2),
                controlPoint1: CGPoint(x: cx + lineSpacing * 0.5, y: baseY + lineSpacing),
                controlPoint2: CGPoint(x: cx - lineSpacing * 0.5, y: baseY + lineSpacing * 0.8))
            ctx.setLineWidth(2.2)
            curlPath.stroke()
            
        case .bass:
            // F clef — dot dot + curve
            ctx.setFillColor(UIColor.label.cgColor)
            ctx.setStrokeColor(UIColor.label.cgColor)
            ctx.setLineWidth(2.0)
            
            let startY = staffBottom - 3 * lineSpacing
            
            // Curve
            let bassCurve = UIBezierPath()
            bassCurve.move(to: CGPoint(x: cx, y: startY))
            bassCurve.addCurve(
                to: CGPoint(x: cx - lineSpacing * 0.4, y: startY + lineSpacing * 2),
                controlPoint1: CGPoint(x: cx + lineSpacing * 1.2, y: startY + lineSpacing * 0.4),
                controlPoint2: CGPoint(x: cx + lineSpacing * 0.8, y: startY + lineSpacing * 1.8))
            bassCurve.stroke()
            
            // Two dots
            let dotR: CGFloat = 4
            ctx.fillEllipse(in: CGRect(x: cx + lineSpacing * 0.9, y: startY - dotR,
                                       width: dotR * 2, height: dotR * 2))
            ctx.fillEllipse(in: CGRect(x: cx + lineSpacing * 0.9, y: startY + lineSpacing * 0.7 - dotR,
                                       width: dotR * 2, height: dotR * 2))
        }
    }
}

