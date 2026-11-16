import UIKit
import AVFoundation
internal import PostgREST
import Auth
import Supabase

// MARK: - Variant Chip Button

class VariantChipButton: UIButton {

    private(set) var isDone: Bool = false
    private weak var noteLabel: UILabel?

    init(label: String, isSelected: Bool) {
        super.init(frame: .zero)
        setupChip(label: label, isSelected: isSelected)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupChip(label: String, isSelected: Bool) {
        backgroundColor = isSelected ? ComponentColors.HomeScreen.actionButtonFill : UIColor.systemGray6
        layer.cornerRadius = 20
        layer.shadowColor = isSelected ? ComponentColors.HomeScreen.actionButtonFill.cgColor : UIColor.clear.cgColor
        layer.shadowOpacity = 0.3; layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical; stack.alignment = .center
        stack.spacing = 2; stack.isUserInteractionEnabled = false

        let noteLabel = UILabel()
        noteLabel.text = label
        noteLabel.font = .systemFont(ofSize: 18, weight: .bold)
        noteLabel.textColor = isSelected ? ComponentColors.PrimaryButton.text : ComponentColors.LessonScreen.labelSecondary
        self.noteLabel = noteLabel

        stack.addArrangedSubview(noteLabel)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
            heightAnchor.constraint(equalToConstant: 70),
        ])
    }

    func updateLabel(_ label: String) {
        noteLabel?.text = label
    }

    /// Marks this chip done with an animated green tick badge
    func markDone() {
        guard !isDone else { return }
        isDone = true

        let tick = UILabel()
        tick.text = "✓"; tick.font = .systemFont(ofSize: 11, weight: .heavy)
        tick.textColor = .white; tick.translatesAutoresizingMaskIntoConstraints = false

        let badge = UIView()
        badge.backgroundColor = ComponentColors.LessonScreen.correctAnswer
        badge.layer.cornerRadius = 9; badge.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(tick); addSubview(badge)

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            badge.widthAnchor.constraint(equalToConstant: 18),
            badge.heightAnchor.constraint(equalToConstant: 18),
            tick.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            tick.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        ])

        badge.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.35, delay: 0,
                       usingSpringWithDamping: 0.55, initialSpringVelocity: 0.8) {
            badge.transform = .identity
        }
        
        // Update styling immediately
        backgroundColor = UIColor.systemGray6
        layer.shadowColor = UIColor.clear.cgColor
        layer.shadowOpacity = 0
        if let stack = subviews.first(where: { $0 is UIStackView }) as? UIStackView {
            for sub in stack.arrangedSubviews {
                if let lbl = sub as? UILabel {
                    lbl.textColor = (lbl.font.pointSize > 12
                                     ? ComponentColors.LessonScreen.labelSecondary
                                     : ComponentColors.LessonScreen.labelSecondary.withAlphaComponent(0.7))
                }
            }
        }
    }
}

// MARK: - Lesson Detail View Controller (L2)

class LessonDetailViewController: UIViewController {

    private let lesson: MusicLesson
    /// 1-based chapter number — passed in from L1 so we can write it to Supabase
    private let chapterIndex: Int
    private var selectedVariantIndex: Int = 0
    private var chipButtons: [VariantChipButton] = []

    // One entry per variant — true once the user taps Done on the mic sheet
    private var variantsDone: Set<Int> = []

    // Score accumulates based on how many attempts each variant took
    // 1st attempt = 3 pts, 2nd = 2 pts, 3rd+ = 1 pt
    private var scorePoints: Int = 0
    private var completionShown = false

    // ── Real-time tracking ────────────────────────────────────────────────
    /// Wall-clock time when the user opened this lesson screen
    private var lessonStartedAt: Date = Date()

    /// Seconds elapsed from open → completion popup (set once on completion)
    private var sessionDurationSeconds: Int = 0
    // ─────────────────────────────────────────────────────────────────────

    // Computed progress 0.0 – 1.0
    private var lessonProgress: Float {
        guard lesson.variants.count > 0 else { return 0 }
        return Float(variantsDone.count) / Float(lesson.variants.count)
    }

    // Called back to L1 with star count when done
    var onLessonCompleted: ((Int) -> Void)?

    // UI references
    private var staffView: LessonStaffView!
    /// What each variant shows, plays and asks for (nil for ear-training rounds).
    private lazy var items: [PracticeItem?] = lesson.variants.map { PracticeMusic.item(for: $0, in: lesson) }
    private lazy var earRounds: [PracticeMusic.EarRound] = lesson.variants.enumerated()
        .map { PracticeMusic.earRound(for: $0.element, index: $0.offset) }
    private var noteNameLabel: UILabel!
    private var englishLabel: UILabel!
    private var englishPrefixLabel: UILabel!
    private var variantsScrollView: UIScrollView!
    private var chipsStack: UIStackView!
    private var tryBtn: UIButton!
    private var progressCountLabel: UILabel!
    /// One segment per part; filled when that part is done.
    private var progressSegments: [UIView] = []
    private var earTrainingOptionButtons: [UIButton] = []
    private var earTrainingAttempts: [Int: Int] = [:]
    private var hasAudioPlaybackSession = false

    // Scrolling + Nav Setup
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let navBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let navShadowLayer = UIView()

    private var isEarTrainingLesson: Bool {
        chapterIndex == 10
    }
    init(lesson: MusicLesson, chapterIndex: Int) {
        self.lesson = lesson
        self.chapterIndex = chapterIndex
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.HomeScreen.background
        scrollView.delegate = self
        setupNavBar()
        navigationItem.titleView?.alpha = 0
        syncNavBarAlpha()
        setupScrollView()
        setupNavBackground()
        setupUI()
        loadCompletedVariantsFromSupabase()
        
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
                self.navShadowLayer.backgroundColor = UIColor.black.withAlphaComponent(0.15)
            }
        }
    }
    
    private func setupNavBar() {
        _ = NavigationBarHelper.configureInlineNavigationBar(
            for: self,
            title: "Lesson",
            subtitle: lesson.title,
            backAction: #selector(didTapBack)
        )
        
        navigationItem.rightBarButtonItems = nil
    }

    private func setupNavBackground() {
        NavigationBarHelper.updateNavigationBackgroundAppearance(
            navBackgroundView,
            shadowView: navShadowLayer,
            traitCollection: traitCollection
        )
        NavigationBarHelper.installNavigationBackground(
            navBackgroundView,
            shadowView: navShadowLayer,
            in: view
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        acquireAudioPlaybackSessionIfNeeded()
        navigationItem.titleView?.alpha = 0
        syncNavBarAlpha()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AudioEngineManager.shared.stopAllNotes()
        releaseAudioPlaybackSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncNavBarAlpha()
        lessonStartedAt = Date()
    }

    deinit {
        releaseAudioPlaybackSession()
    }

    private func acquireAudioPlaybackSessionIfNeeded() {
        guard !hasAudioPlaybackSession else { return }
        AudioEngineManager.shared.acquirePlaybackSession()
        hasAudioPlaybackSession = true
    }

    private func releaseAudioPlaybackSession() {
        guard hasAudioPlaybackSession else { return }
        AudioEngineManager.shared.releasePlaybackSession()
        hasAudioPlaybackSession = false
    }

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 96),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func item(at index: Int) -> PracticeItem? {
        items.indices.contains(index) ? items[index] : nil
    }

    private func lessonCardBorderWidth() -> CGFloat {
        traitCollection.userInterfaceStyle == .light ? 0 : 1.0
    }

    // MARK: - UI Setup

    private func setupUI() {
        // ── Header: lesson name, parts done, and one bar segment per part ──
        let lessonNameLabel = UILabel()
        lessonNameLabel.translatesAutoresizingMaskIntoConstraints = false
        lessonNameLabel.text = "Lesson \(chapterIndex) · \(lesson.title)"
        lessonNameLabel.font = .preferredFont(forTextStyle: .headline)
        lessonNameLabel.adjustsFontForContentSizeCategory = true
        lessonNameLabel.textColor = ComponentColors.LessonScreen.labelPrimary
        lessonNameLabel.numberOfLines = 2

        progressCountLabel = UILabel()
        progressCountLabel.translatesAutoresizingMaskIntoConstraints = false
        progressCountLabel.font = UIFont.preferredFont(forTextStyle: .footnote).withWeight(.semibold)
        progressCountLabel.adjustsFontForContentSizeCategory = true
        progressCountLabel.textColor = BrandColors.brand
        progressCountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        progressCountLabel.setContentHuggingPriority(.required, for: .horizontal)

        let progressBar = UIStackView()
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.axis = .horizontal
        progressBar.spacing = 4
        progressBar.distribution = .fillEqually
        progressBar.isAccessibilityElement = true
        progressBar.accessibilityLabel = "Lesson progress"
        for _ in lesson.variants {
            let segment = UIView()
            segment.layer.cornerRadius = 3
            segment.backgroundColor = BrandColors.brand.withAlphaComponent(0.18)
            progressBar.addArrangedSubview(segment)
            progressSegments.append(segment)
        }
        refreshProgress(animated: false)

        // ── Staff card ──
        let staffCardView = UIView()
        staffCardView.translatesAutoresizingMaskIntoConstraints = false
        staffCardView.backgroundColor = ComponentColors.LessonScreen.cardFill
        staffCardView.layer.cornerRadius = 24
        staffCardView.layer.shadowColor = UIColor.black.cgColor
        staffCardView.layer.shadowOpacity = 0.08
        staffCardView.layer.shadowRadius = 16
        staffCardView.layer.shadowOffset = CGSize(width: 0, height: 6)

        staffView = LessonStaffView(steps: item(at: 0)?.steps ?? [])
        staffView.translatesAutoresizingMaskIntoConstraints = false
        staffView.backgroundColor = .clear; staffView.layer.shadowOpacity = 0
        staffCardView.addSubview(staffView)
        if isEarTrainingLesson {
            let earCard = makeEarTrainingCard()
            earCard.translatesAutoresizingMaskIntoConstraints = false
            staffCardView.addSubview(earCard)
            NSLayoutConstraint.activate([
                earCard.topAnchor.constraint(equalTo: staffCardView.topAnchor),
                earCard.leadingAnchor.constraint(equalTo: staffCardView.leadingAnchor),
                earCard.trailingAnchor.constraint(equalTo: staffCardView.trailingAnchor),
                earCard.bottomAnchor.constraint(equalTo: staffCardView.bottomAnchor),
            ])
            staffView.isHidden = true
        }

        // ── Note name ──
        noteNameLabel = UILabel()
        noteNameLabel.translatesAutoresizingMaskIntoConstraints = false
        noteNameLabel.text = isEarTrainingLesson ? nil : item(at: 0)?.title
        noteNameLabel.font = isEarTrainingLesson
            ? .systemFont(ofSize: 24, weight: .semibold)
            : .systemFont(ofSize: 42, weight: .heavy)
        noteNameLabel.textColor = ComponentColors.LessonScreen.labelPrimary; noteNameLabel.textAlignment = .center
        noteNameLabel.adjustsFontSizeToFitWidth = true
        noteNameLabel.minimumScaleFactor = 0.5
        noteNameLabel.numberOfLines = 2
        noteNameLabel.lineBreakMode = .byWordWrapping
        noteNameLabel.layer.shadowColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(isEarTrainingLesson ? 0.12 : 0.3).cgColor
        noteNameLabel.layer.shadowRadius = isEarTrainingLesson ? 4 : 10
        noteNameLabel.layer.shadowOpacity = isEarTrainingLesson ? 0.12 : 0.3
        noteNameLabel.layer.shadowOffset = CGSize(width: 0, height: isEarTrainingLesson ? 2 : 4)
        noteNameLabel.isHidden = isEarTrainingLesson

        // ── English note row ──
        let engRow = UIView()
        engRow.translatesAutoresizingMaskIntoConstraints = false
        englishPrefixLabel = UILabel()
        englishPrefixLabel.translatesAutoresizingMaskIntoConstraints = false
        englishPrefixLabel.font = .systemFont(ofSize: 14, weight: .medium)
        englishPrefixLabel.textColor = ComponentColors.LessonScreen.labelSecondary
        engRow.addSubview(englishPrefixLabel)
        englishLabel = UILabel()
        englishLabel.translatesAutoresizingMaskIntoConstraints = false
        updateEnglishLabel(with: 0)
        engRow.addSubview(englishLabel)
        engRow.isHidden = isEarTrainingLesson

        // ── Variants section ──
        let variantsHeaderLabel = UILabel()
        variantsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        variantsHeaderLabel.text = isEarTrainingLesson
            ? "Which chord came after the home chord?"
            : "Pick a part, listen to it, then play it with Try Yourself"
        variantsHeaderLabel.font = .systemFont(ofSize: 12, weight: .medium)
        variantsHeaderLabel.textColor = ComponentColors.LessonScreen.labelSecondary.withAlphaComponent(0.7)

        let optionsGrid = makeEarTrainingOptionsGrid()
        optionsGrid.translatesAutoresizingMaskIntoConstraints = false
        optionsGrid.isHidden = !isEarTrainingLesson

        variantsScrollView = UIScrollView()
        variantsScrollView.translatesAutoresizingMaskIntoConstraints = false
        variantsScrollView.showsHorizontalScrollIndicator = false
        variantsScrollView.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)

        chipsStack = UIStackView()
        chipsStack.translatesAutoresizingMaskIntoConstraints = false
        chipsStack.axis = .horizontal; chipsStack.spacing = 10; chipsStack.alignment = .center
        variantsScrollView.addSubview(chipsStack)

        for (i, variant) in lesson.variants.enumerated() {
            let chipLabel = isEarTrainingLesson ? variant : (item(at: i)?.chipLabel ?? variant)
            let chip = VariantChipButton(label: chipLabel, isSelected: i == 0)
            chip.tag = i
            chip.addTarget(self, action: #selector(selectVariant(_:)), for: .touchUpInside)
            chipsStack.addArrangedSubview(chip)
            chipButtons.append(chip)
        }

        // ── Try Yourself button ──
        tryBtn = UIButton(type: .system)
        tryBtn.translatesAutoresizingMaskIntoConstraints = false
        tryBtn.setTitle("  Try Yourself", for: .normal)
        tryBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        let waveCfg = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        tryBtn.setImage(UIImage(systemName: "waveform", withConfiguration: waveCfg), for: .normal)
        tryBtn.tintColor = .white; tryBtn.setTitleColor(.white, for: .normal)
        tryBtn.backgroundColor = ComponentColors.HomeScreen.actionButtonFill; tryBtn.layer.cornerRadius = 26
        tryBtn.layer.shadowColor = ComponentColors.HomeScreen.actionButtonFill.cgColor
        tryBtn.layer.shadowOpacity = 0.35; tryBtn.layer.shadowRadius = 12
        tryBtn.layer.shadowOffset = CGSize(width: 0, height: 6)
        tryBtn.addTarget(self, action: #selector(didTapTryYourself), for: .touchUpInside)
        tryBtn.isHidden = isEarTrainingLesson

        // ── Concept card (description + family overview) ──
        let conceptCard = makeInfoCard()
        let conceptHeader = makeCardHeader("About this lesson", icon: "text.book.closed")
        let descLabel = UILabel()
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.text = summarizedLessonDescription(from: lesson.description)
        descLabel.font = .systemFont(ofSize: 14)
        descLabel.textColor = .label
        descLabel.numberOfLines = 0
        descLabel.lineBreakMode = .byWordWrapping
        conceptCard.addSubview(conceptHeader)
        conceptCard.addSubview(descLabel)
        var conceptConstraints: [NSLayoutConstraint] = [
            conceptHeader.topAnchor.constraint(equalTo: conceptCard.topAnchor, constant: 14),
            conceptHeader.leadingAnchor.constraint(equalTo: conceptCard.leadingAnchor, constant: 14),
            conceptHeader.trailingAnchor.constraint(equalTo: conceptCard.trailingAnchor, constant: -14),
            descLabel.topAnchor.constraint(equalTo: conceptHeader.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: conceptCard.leadingAnchor, constant: 14),
            descLabel.trailingAnchor.constraint(equalTo: conceptCard.trailingAnchor, constant: -14),
        ]
        if !lesson.familyOverview.isEmpty {
            let overviewLabel = UILabel()
            overviewLabel.translatesAutoresizingMaskIntoConstraints = false
            overviewLabel.text = lesson.familyOverview
            overviewLabel.font = .systemFont(ofSize: 13)
            overviewLabel.textColor = .secondaryLabel
            overviewLabel.numberOfLines = 0
            conceptCard.addSubview(overviewLabel)
            conceptConstraints += [
                overviewLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 8),
                overviewLabel.leadingAnchor.constraint(equalTo: conceptCard.leadingAnchor, constant: 14),
                overviewLabel.trailingAnchor.constraint(equalTo: conceptCard.trailingAnchor, constant: -14),
                overviewLabel.bottomAnchor.constraint(equalTo: conceptCard.bottomAnchor, constant: -14),
            ]
        } else {
            conceptConstraints.append(descLabel.bottomAnchor.constraint(equalTo: conceptCard.bottomAnchor, constant: -14))
        }
        NSLayoutConstraint.activate(conceptConstraints)

        // ── Chord details card ──
        var infoCards: [UIView] = [conceptCard]

        if !lesson.chordDetails.isEmpty && chapterIndex != 9 {
            let chordsCard = makeInfoCard()
            let chordsHeader = makeCardHeader("Chord details", icon: "music.note.list")
            chordsCard.addSubview(chordsHeader)
            var lastAnchor = chordsHeader.bottomAnchor
            var chordConstraints: [NSLayoutConstraint] = [
                chordsHeader.topAnchor.constraint(equalTo: chordsCard.topAnchor, constant: 14),
                chordsHeader.leadingAnchor.constraint(equalTo: chordsCard.leadingAnchor, constant: 14),
                chordsHeader.trailingAnchor.constraint(equalTo: chordsCard.trailingAnchor, constant: -14),
            ]
            for (i, detail) in lesson.chordDetails.enumerated() {
                let row = makeChordRow(detail: detail, index: i)
                chordsCard.addSubview(row)
                chordConstraints += [
                    row.topAnchor.constraint(equalTo: lastAnchor, constant: i == 0 ? 10 : 2),
                    row.leadingAnchor.constraint(equalTo: chordsCard.leadingAnchor, constant: 10),
                    row.trailingAnchor.constraint(equalTo: chordsCard.trailingAnchor, constant: -10),
                ]
                lastAnchor = row.bottomAnchor
            }
            chordConstraints.append(lastAnchor.constraint(equalTo: chordsCard.bottomAnchor, constant: -14))
            NSLayoutConstraint.activate(chordConstraints)
            infoCards.append(chordsCard)
        }

        if !lesson.progressions.isEmpty {
            let progsCard = makeInfoCard()
            let progsHeader = makeCardHeader("Common progressions", icon: "arrow.triangle.2.circlepath")
            progsCard.addSubview(progsHeader)
            var lastProgAnchor = progsHeader.bottomAnchor
            var progConstraints: [NSLayoutConstraint] = [
                progsHeader.topAnchor.constraint(equalTo: progsCard.topAnchor, constant: 14),
                progsHeader.leadingAnchor.constraint(equalTo: progsCard.leadingAnchor, constant: 14),
                progsHeader.trailingAnchor.constraint(equalTo: progsCard.trailingAnchor, constant: -14),
            ]
            for (i, prog) in lesson.progressions.enumerated() {
                let row = makeProgressionRow(prog: prog, index: i)
                progsCard.addSubview(row)
                progConstraints += [
                    row.topAnchor.constraint(equalTo: lastProgAnchor, constant: i == 0 ? 10 : 6),
                    row.leadingAnchor.constraint(equalTo: progsCard.leadingAnchor, constant: 10),
                    row.trailingAnchor.constraint(equalTo: progsCard.trailingAnchor, constant: -10),
                ]
                lastProgAnchor = row.bottomAnchor
            }
            progConstraints.append(lastProgAnchor.constraint(equalTo: progsCard.bottomAnchor, constant: -14))
            NSLayoutConstraint.activate(progConstraints)
            infoCards.append(progsCard)
        }

        if !lesson.listeningGuide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let listenCard = makeInfoCard()
            let listenHeader = makeCardHeader("Listening guide", icon: "ear")
            let listenLabel = UILabel()
            listenLabel.translatesAutoresizingMaskIntoConstraints = false
            listenLabel.text = lesson.listeningGuide
            listenLabel.font = .systemFont(ofSize: 14)
            listenLabel.textColor = .label
            listenLabel.numberOfLines = 0
            listenCard.addSubview(listenHeader)
            listenCard.addSubview(listenLabel)
            NSLayoutConstraint.activate([
                listenHeader.topAnchor.constraint(equalTo: listenCard.topAnchor, constant: 14),
                listenHeader.leadingAnchor.constraint(equalTo: listenCard.leadingAnchor, constant: 14),
                listenHeader.trailingAnchor.constraint(equalTo: listenCard.trailingAnchor, constant: -14),
                listenLabel.topAnchor.constraint(equalTo: listenHeader.bottomAnchor, constant: 8),
                listenLabel.leadingAnchor.constraint(equalTo: listenCard.leadingAnchor, constant: 14),
                listenLabel.trailingAnchor.constraint(equalTo: listenCard.trailingAnchor, constant: -14),
                listenLabel.bottomAnchor.constraint(equalTo: listenCard.bottomAnchor, constant: -14),
            ])
            infoCards.append(listenCard)
        }

        if !lesson.practiceTasks.isEmpty {
            let tasksCard = makeInfoCard()
            let tasksHeader = makeCardHeader("Practice tasks", icon: "checkmark.circle")
            tasksCard.addSubview(tasksHeader)
            var lastTaskAnchor = tasksHeader.bottomAnchor
            var taskConstraints: [NSLayoutConstraint] = [
                tasksHeader.topAnchor.constraint(equalTo: tasksCard.topAnchor, constant: 14),
                tasksHeader.leadingAnchor.constraint(equalTo: tasksCard.leadingAnchor, constant: 14),
                tasksHeader.trailingAnchor.constraint(equalTo: tasksCard.trailingAnchor, constant: -14),
            ]
            for (i, task) in lesson.practiceTasks.enumerated() {
                let taskRow = makeTaskRow(number: i + 1, text: task)
                tasksCard.addSubview(taskRow)
                taskConstraints += [
                    taskRow.topAnchor.constraint(equalTo: lastTaskAnchor, constant: i == 0 ? 10 : 6),
                    taskRow.leadingAnchor.constraint(equalTo: tasksCard.leadingAnchor, constant: 10),
                    taskRow.trailingAnchor.constraint(equalTo: tasksCard.trailingAnchor, constant: -10),
                ]
                lastTaskAnchor = taskRow.bottomAnchor
            }
            taskConstraints.append(lastTaskAnchor.constraint(equalTo: tasksCard.bottomAnchor, constant: -14))
            NSLayoutConstraint.activate(taskConstraints)
            infoCards.append(tasksCard)
        }

        [lessonNameLabel, progressCountLabel, progressBar, staffCardView, noteNameLabel,
         engRow, variantsHeaderLabel, optionsGrid, variantsScrollView, tryBtn].forEach { contentView.addSubview($0) }
        infoCards.forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            lessonNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            lessonNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            lessonNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: progressCountLabel.leadingAnchor, constant: -12),
            progressCountLabel.firstBaselineAnchor.constraint(equalTo: lessonNameLabel.firstBaselineAnchor),
            progressCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            progressBar.topAnchor.constraint(equalTo: lessonNameLabel.bottomAnchor, constant: 10),
            progressBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            progressBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            progressBar.heightAnchor.constraint(equalToConstant: 6),

            staffCardView.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 18),
            staffCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            staffCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            staffCardView.heightAnchor.constraint(equalToConstant: 195),
            staffView.topAnchor.constraint(equalTo: staffCardView.topAnchor),
            staffView.leadingAnchor.constraint(equalTo: staffCardView.leadingAnchor),
            staffView.trailingAnchor.constraint(equalTo: staffCardView.trailingAnchor),
            staffView.bottomAnchor.constraint(equalTo: staffCardView.bottomAnchor),

            noteNameLabel.topAnchor.constraint(equalTo: staffCardView.bottomAnchor, constant: isEarTrainingLesson ? 0 : 8),
            noteNameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            engRow.topAnchor.constraint(equalTo: noteNameLabel.bottomAnchor, constant: isEarTrainingLesson ? 0 : 4),
            engRow.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            englishPrefixLabel.leadingAnchor.constraint(equalTo: engRow.leadingAnchor),
            englishPrefixLabel.centerYAnchor.constraint(equalTo: engRow.centerYAnchor),
            englishPrefixLabel.topAnchor.constraint(equalTo: engRow.topAnchor),
            englishPrefixLabel.bottomAnchor.constraint(equalTo: engRow.bottomAnchor),
            englishLabel.leadingAnchor.constraint(equalTo: englishPrefixLabel.trailingAnchor),
            englishLabel.centerYAnchor.constraint(equalTo: engRow.centerYAnchor),
            englishLabel.trailingAnchor.constraint(equalTo: engRow.trailingAnchor),

            variantsHeaderLabel.topAnchor.constraint(equalTo: isEarTrainingLesson ? staffCardView.bottomAnchor : engRow.bottomAnchor, constant: isEarTrainingLesson ? 18 : 18),
            variantsHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            optionsGrid.topAnchor.constraint(equalTo: variantsHeaderLabel.bottomAnchor, constant: 12),
            optionsGrid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            optionsGrid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            variantsScrollView.topAnchor.constraint(equalTo: isEarTrainingLesson ? optionsGrid.bottomAnchor : variantsHeaderLabel.bottomAnchor, constant: isEarTrainingLesson ? 18 : 10),
            variantsScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            variantsScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            variantsScrollView.heightAnchor.constraint(equalToConstant: 90),
            chipsStack.topAnchor.constraint(equalTo: variantsScrollView.topAnchor),
            chipsStack.leadingAnchor.constraint(equalTo: variantsScrollView.leadingAnchor),
            chipsStack.trailingAnchor.constraint(equalTo: variantsScrollView.trailingAnchor),
            chipsStack.bottomAnchor.constraint(equalTo: variantsScrollView.bottomAnchor),
            chipsStack.heightAnchor.constraint(equalTo: variantsScrollView.heightAnchor),

            tryBtn.topAnchor.constraint(equalTo: variantsScrollView.bottomAnchor, constant: 24),
            tryBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            tryBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            tryBtn.heightAnchor.constraint(equalToConstant: 52),

            // ── Rich content cards below Try Yourself ──
        ])

        var previousCard: UIView?
        let bottomAnchorView: UIView = isEarTrainingLesson ? variantsScrollView : tryBtn
        for card in infoCards {
            NSLayoutConstraint.activate([
                card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                card.topAnchor.constraint(equalTo: (previousCard ?? bottomAnchorView).bottomAnchor, constant: previousCard == nil ? 28 : 14),
            ])
            previousCard = card
        }

        if let lastCard = previousCard {
            lastCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -36).isActive = true
        } else {
            bottomAnchorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -36).isActive = true
        }
        
    }

    // MARK: - Card builder helpers

    private func makeInfoCard() -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = ComponentColors.SongCard.background
        v.layer.cornerRadius = 18
        v.layer.borderWidth = lessonCardBorderWidth()
        v.layer.borderColor = ComponentColors.LessonScreen.cardBorder.cgColor
        v.layer.masksToBounds = true
        return v
    }

    private func makeCardHeader(_ title: String, icon: String) -> UIView {
        let row = UIStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal; row.spacing = 7; row.alignment = .center

        let img = UIImageView(image: UIImage(systemName: icon))
        img.tintColor = ComponentColors.HomeScreen.actionButtonFill; img.contentMode = .scaleAspectFit
        img.translatesAutoresizingMaskIntoConstraints = false
        img.widthAnchor.constraint(equalToConstant: 16).isActive = true
        img.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let lbl = UILabel()
        lbl.text = title; lbl.font = .systemFont(ofSize: 13, weight: .bold)
        lbl.textColor = ComponentColors.LessonScreen.labelPrimary

        row.addArrangedSubview(img)
        row.addArrangedSubview(lbl)
        return row
    }

    private func makeEarTrainingCard() -> UIView {
        let card = UIView()
        card.backgroundColor = ComponentColors.LessonScreen.cardFill
        card.layer.cornerRadius = 24
        card.layer.borderWidth = lessonCardBorderWidth()
        card.layer.borderColor = ComponentColors.LessonScreen.cardBorder.cgColor

        let playButton = UIButton(type: .system)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        playButton.tintColor = .white
        playButton.layer.cornerRadius = 48
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        playButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
        playButton.addTarget(self, action: #selector(didTapEarTrainingPlay), for: .touchUpInside)
        let helperLabel = UILabel()
        helperLabel.translatesAutoresizingMaskIntoConstraints = false
        helperLabel.text = "Home chord, then a mystery chord"
        helperLabel.adjustsFontSizeToFitWidth = true
        helperLabel.minimumScaleFactor = 0.8
        helperLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        helperLabel.textColor = ComponentColors.LessonScreen.labelSecondary
        helperLabel.textAlignment = .center

        card.addSubview(playButton)
        card.addSubview(helperLabel)

        NSLayoutConstraint.activate([
            playButton.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: -14),
            playButton.widthAnchor.constraint(equalToConstant: 96),
            playButton.heightAnchor.constraint(equalToConstant: 96),

            helperLabel.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 18),
            helperLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            helperLabel.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: 20),
            helperLabel.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -20),
        ])

        return card
    }

    private func makeEarTrainingOptionsGrid() -> UIStackView {
        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 12
        rows.alignment = .fill
        rows.distribution = .fillEqually

        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.spacing = 12
        topRow.distribution = .fillEqually

        let bottomRow = UIStackView()
        bottomRow.axis = .horizontal
        bottomRow.spacing = 12
        bottomRow.distribution = .fillEqually

        for index in 0..<PracticeMusic.earOptions.count {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.tag = index
            button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
            button.layer.cornerRadius = 18
            button.layer.borderWidth = 1
            button.addTarget(self, action: #selector(didTapEarTrainingOption(_:)), for: .touchUpInside)
            button.heightAnchor.constraint(equalToConstant: 72).isActive = true
            styleEarTrainingOption(button, state: .idle)
            earTrainingOptionButtons.append(button)
            if index < 2 {
                topRow.addArrangedSubview(button)
            } else {
                bottomRow.addArrangedSubview(button)
            }
        }

        rows.addArrangedSubview(topRow)
        rows.addArrangedSubview(bottomRow)
        refreshEarTrainingOptions()
        return rows
    }

    private enum EarTrainingOptionState {
        case idle
        case correct
        case incorrect
    }

    private func styleEarTrainingOption(_ button: UIButton, state: EarTrainingOptionState) {
        switch state {
        case .idle:
            button.backgroundColor = ComponentColors.LessonScreen.cardFill
            button.layer.borderColor = ComponentColors.LessonScreen.cardBorder.cgColor
            button.setTitleColor(ComponentColors.LessonScreen.labelPrimary, for: .normal)
        case .correct:
            button.backgroundColor = ComponentColors.LessonScreen.correctAnswer.withAlphaComponent(0.18)
            button.layer.borderColor = ComponentColors.LessonScreen.correctAnswer.cgColor
            button.setTitleColor(ComponentColors.LessonScreen.correctAnswer, for: .normal)
        case .incorrect:
            button.backgroundColor = ComponentColors.LessonScreen.incorrectAnswer.withAlphaComponent(0.12)
            button.layer.borderColor = ComponentColors.LessonScreen.incorrectAnswer.cgColor
            button.setTitleColor(ComponentColors.LessonScreen.incorrectAnswer, for: .normal)
        }
    }

    private func refreshEarTrainingOptions() {
        guard isEarTrainingLesson else { return }
        for (button, numeral) in zip(earTrainingOptionButtons, PracticeMusic.earOptions) {
            button.setTitle("\(numeral) · \(PracticeMusic.earOptionHints[numeral] ?? "")", for: .normal)
            styleEarTrainingOption(button, state: .idle)
        }
    }

    private func summarizedLessonDescription(from text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmedText.split(whereSeparator: \.isWhitespace)
        let sentences = trimmedText
            .split(whereSeparator: { [".", "!", "?"].contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard sentences.count > 3 || words.count > 60 else {
            return trimmedText
        }

        let summarySentenceCount = min(sentences.count, 3)
        let summary = sentences.prefix(summarySentenceCount).joined(separator: ". ")
        let summaryWords = summary.split(whereSeparator: \.isWhitespace)

        if summaryWords.count <= 60 {
            return summary.hasSuffix(".") ? summary : summary + "."
        }

        let fallbackSummary = sentences.prefix(min(sentences.count, 2)).joined(separator: ". ")
        return fallbackSummary.hasSuffix(".") ? fallbackSummary : fallbackSummary + "."
    }

    private func makeChordRow(detail: ChordDetail, index: Int) -> UIView {
        let bg = UIView()
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.backgroundColor = index % 2 == 0
            ? ComponentColors.LessonScreen.background
            : ComponentColors.LessonScreen.cardFill
        bg.layer.cornerRadius = 12
        bg.layer.borderWidth = lessonCardBorderWidth()
        bg.layer.borderColor = ComponentColors.LessonScreen.cardBorder.cgColor

        // Name pill
        let namePill = UIView()
        namePill.translatesAutoresizingMaskIntoConstraints = false
        namePill.backgroundColor = detail.type == "major" ? ComponentColors.HomeScreen.actionButtonFill
            : detail.type == "minor" ? ComponentColors.HomeScreen.actionButtonFill
            : ComponentColors.SongCard.metadataText
        namePill.layer.cornerRadius = 10

        let nameL = UILabel()
        nameL.translatesAutoresizingMaskIntoConstraints = false
        nameL.text = detail.name
        nameL.font = .systemFont(ofSize: 11, weight: .bold)
        nameL.textColor = ComponentColors.PrimaryButton.text
        nameL.numberOfLines = 1
        namePill.addSubview(nameL)

        // Notes label
        let notesL = UILabel()
        notesL.translatesAutoresizingMaskIntoConstraints = false
        notesL.text = detail.notes.joined(separator: " – ")
        notesL.font = .systemFont(ofSize: 12, weight: .semibold)
        notesL.textColor = ComponentColors.LessonScreen.labelPrimary

        // Emotion label
        let emotionL = UILabel()
        emotionL.translatesAutoresizingMaskIntoConstraints = false
        emotionL.text = detail.emotion
        emotionL.font = .systemFont(ofSize: 11)
        emotionL.textColor = ComponentColors.LessonScreen.labelSecondary
        emotionL.numberOfLines = 2

        bg.addSubview(namePill); bg.addSubview(nameL); bg.addSubview(notesL); bg.addSubview(emotionL)
        NSLayoutConstraint.activate([
            namePill.topAnchor.constraint(equalTo: bg.topAnchor, constant: 10),
            namePill.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),

            nameL.topAnchor.constraint(equalTo: namePill.topAnchor, constant: 4),
            nameL.bottomAnchor.constraint(equalTo: namePill.bottomAnchor, constant: -4),
            nameL.leadingAnchor.constraint(equalTo: namePill.leadingAnchor, constant: 8),
            nameL.trailingAnchor.constraint(equalTo: namePill.trailingAnchor, constant: -8),

            notesL.topAnchor.constraint(equalTo: namePill.bottomAnchor, constant: 5),
            notesL.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            notesL.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -10),

            emotionL.topAnchor.constraint(equalTo: notesL.bottomAnchor, constant: 3),
            emotionL.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            emotionL.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -10),
            emotionL.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -10),
        ])
        return bg
    }

    private func makeProgressionRow(prog: ProgressionExample, index: Int) -> UIView {
        let bg = UIView()
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.backgroundColor = index % 2 == 0
            ? ComponentColors.LessonScreen.background
            : ComponentColors.LessonScreen.cardFill
        bg.layer.cornerRadius = 12
        bg.layer.borderWidth = lessonCardBorderWidth()
        bg.layer.borderColor = ComponentColors.LessonScreen.cardBorder.cgColor

        let numeralL = UILabel()
        numeralL.translatesAutoresizingMaskIntoConstraints = false
        numeralL.text = prog.numerals
        numeralL.font = .systemFont(ofSize: 11, weight: .bold)
        numeralL.textColor = ComponentColors.LessonScreen.brandAccent

        let chordsL = UILabel()
        chordsL.translatesAutoresizingMaskIntoConstraints = false
        chordsL.text = prog.chords
        chordsL.font = .systemFont(ofSize: 13, weight: .semibold)
        chordsL.textColor = ComponentColors.LessonScreen.labelPrimary

        let feelL = UILabel()
        feelL.translatesAutoresizingMaskIntoConstraints = false
        feelL.text = prog.feel
        feelL.font = .systemFont(ofSize: 11)
        feelL.textColor = ComponentColors.LessonScreen.labelSecondary
        feelL.numberOfLines = 2

        bg.addSubview(numeralL); bg.addSubview(chordsL); bg.addSubview(feelL)
        NSLayoutConstraint.activate([
            numeralL.topAnchor.constraint(equalTo: bg.topAnchor, constant: 10),
            numeralL.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            numeralL.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -10),

            chordsL.topAnchor.constraint(equalTo: numeralL.bottomAnchor, constant: 3),
            chordsL.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            chordsL.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -10),

            feelL.topAnchor.constraint(equalTo: chordsL.bottomAnchor, constant: 3),
            feelL.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            feelL.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -10),
            feelL.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -10),
        ])
        return bg
    }

    private func makeTaskRow(number: Int, text: String) -> UIView {
        let bg = UIView()
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.backgroundColor = number % 2 == 0
            ? ComponentColors.LessonScreen.cardFill
            : ComponentColors.LessonScreen.background
        bg.layer.cornerRadius = 12
        bg.layer.borderWidth = lessonCardBorderWidth()
        bg.layer.borderColor = ComponentColors.LessonScreen.cardBorder.cgColor

        let numCircle = UIView()
        numCircle.translatesAutoresizingMaskIntoConstraints = false
        numCircle.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        numCircle.layer.cornerRadius = 12

        let numL = UILabel()
        numL.translatesAutoresizingMaskIntoConstraints = false
        numL.text = "\(number)"
        numL.font = .systemFont(ofSize: 11, weight: .bold)
        numL.textColor = .white; numL.textAlignment = .center
        numCircle.addSubview(numL)

        let taskL = UILabel()
        taskL.translatesAutoresizingMaskIntoConstraints = false
        taskL.text = text
        taskL.font = .systemFont(ofSize: 13)
        taskL.textColor = ComponentColors.LessonScreen.labelPrimary
        taskL.numberOfLines = 0

        bg.addSubview(numCircle); bg.addSubview(numL); bg.addSubview(taskL)
        NSLayoutConstraint.activate([
            numCircle.topAnchor.constraint(equalTo: bg.topAnchor, constant: 10),
            numCircle.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            numCircle.widthAnchor.constraint(equalToConstant: 24),
            numCircle.heightAnchor.constraint(equalToConstant: 24),

            numL.centerXAnchor.constraint(equalTo: numCircle.centerXAnchor),
            numL.centerYAnchor.constraint(equalTo: numCircle.centerYAnchor),

            taskL.topAnchor.constraint(equalTo: bg.topAnchor, constant: 10),
            taskL.leadingAnchor.constraint(equalTo: numCircle.trailingAnchor, constant: 10),
            taskL.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -10),
            taskL.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -10),
        ])
        return bg
    }

    // MARK: - Progress Logic

    /// Records a completed mic session for a variant. `attempts` = number of mic taps.
    private func recordVariantPracticed(variantIndex: Int, attempts: Int) {
        guard variantIndex < lesson.variants.count else { return }

        // Award score only the first time this variant is completed
        if !variantsDone.contains(variantIndex) {
            let pts = attempts == 1 ? 3 : attempts == 2 ? 2 : 1
            scorePoints += pts
            variantsDone.insert(variantIndex)
            chipButtons[variantIndex].markDone()
            refreshProgress(animated: true)

            // ── Persist part completion to Supabase ───────────────────────
            Task {
                await SupabaseProgressManager.recordPartCompleted(
                    chapterIndex: chapterIndex,
                    partIndex:    variantIndex,
                    attempts:     attempts,
                    scorePoints:  scorePoints
                )
            }
            // ─────────────────────────────────────────────────────────────
        }

        // Show completion popup once all variants done
        if lessonProgress >= 1.0 && !completionShown {
            completionShown = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.showCompletionPopup()
            }
        }
    }

    /// "3 of 7 parts" and the filled segments.
    private func refreshProgress(animated: Bool) {
        let done = variantsDone.count, total = lesson.variants.count
        progressCountLabel?.text = done == total ? "Complete" : "\(done) of \(total) parts"
        let update = {
            for (i, segment) in self.progressSegments.enumerated() {
                segment.backgroundColor = self.variantsDone.contains(i)
                    ? BrandColors.brand
                    : BrandColors.brand.withAlphaComponent(0.18)
            }
        }
        animated ? UIView.animate(withDuration: 0.3, animations: update) : update()
        progressSegments.first?.superview?.accessibilityValue = "\(done) of \(total) parts done"
    }

    // MARK: - Stars Calculation

    private func computeStars() -> Int {
        // Max possible = every variant done on first try = variants * 3
        let maxScore = lesson.variants.count * 3
        guard maxScore > 0 else { return 1 }
        let ratio = Float(scorePoints) / Float(maxScore)
        if ratio >= 0.80 { return 3 }   // ≥80% → 3 stars
        if ratio >= 0.50 { return 2 }   // ≥50% → 2 stars
        return 1                          // < 50% → 1 star
    }

    // MARK: - Completion Popup

    private func showCompletionPopup() {
        let stars = computeStars()

        // ── Capture session duration and persist to Supabase ─────────────
        sessionDurationSeconds = Int(Date().timeIntervalSince(lessonStartedAt))
        let saveTask = Task {
            await SupabaseProgressManager.recordLessonCompleted(
                chapterIndex:    chapterIndex,
                stars:           stars,
                durationSeconds: sessionDurationSeconds,
                scorePoints:     scorePoints
            )
        }
        // ─────────────────────────────────────────────────────────────────

        let popup = LessonCompletionPopupView(stars: stars, lessonTitle: lesson.title)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.alpha = 0
        popup.transform = CGAffineTransform(scaleX: 0.80, y: 0.80)

        let dim = UIView(frame: view.bounds)
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.50)
        dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dim.alpha = 0
        view.addSubview(dim)
        view.addSubview(popup)

        NSLayoutConstraint.activate([
            popup.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            popup.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            popup.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            popup.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
        ])

        UIView.animate(withDuration: 0.5, delay: 0,
                       usingSpringWithDamping: 0.62, initialSpringVelocity: 0.5) {
            popup.alpha = 1; popup.transform = .identity; dim.alpha = 1
        }

        popup.onContinue = { [weak self] in
            Task {
                await saveTask.value
                await MainActor.run {
                    UIView.animate(withDuration: 0.25, animations: {
                        popup.alpha = 0
                        popup.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                        dim.alpha = 0
                    }) { _ in
                        popup.removeFromSuperview(); dim.removeFromSuperview()
                        self?.onLessonCompleted?(stars)
                        // back to the map, where the next chapter is now unlocked
                        self?.dismiss(animated: true)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func didTapBack() {
        // If they back out mid-lesson (not via the completion popup Continue button),
        // still fire onLessonCompleted only if 100% was reached — so L1 always syncs.
        if lessonProgress >= 1.0 {
            let stars = computeStars()
            if sessionDurationSeconds == 0 {
                sessionDurationSeconds = Int(Date().timeIntervalSince(lessonStartedAt))
            }
            onLessonCompleted?(stars)
        }
        dismiss(animated: true)
        navigationController?.popViewController(animated: true)
    }

    @objc private func selectVariant(_ sender: UIButton) {
        let idx = sender.tag
        selectedVariantIndex = idx
        let variant = lesson.variants[idx]

        // Rebuild staff
        if !isEarTrainingLesson, let card = staffView.superview {
            staffView.stop()
            staffView.removeFromSuperview()
            staffView = LessonStaffView(steps: item(at: idx)?.steps ?? [])
            staffView.translatesAutoresizingMaskIntoConstraints = false
            staffView.backgroundColor = .clear; staffView.layer.shadowOpacity = 0
            card.addSubview(staffView)
            NSLayoutConstraint.activate([
                staffView.topAnchor.constraint(equalTo: card.topAnchor),
                staffView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                staffView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                staffView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            ])
        }

        if !isEarTrainingLesson {
            UIView.transition(with: noteNameLabel, duration: 0.25, options: .transitionCrossDissolve) {
                self.noteNameLabel.text = self.item(at: idx)?.title ?? variant
            }
            UIView.transition(with: englishLabel, duration: 0.25, options: .transitionCrossDissolve) {
                self.updateEnglishLabel(with: idx)
            }
        }
        if isEarTrainingLesson {
            refreshEarTrainingOptions()
        }

        for (i, btn) in chipButtons.enumerated() {
            let isSel = i == idx
            let useOrange = isSel && !btn.isDone
            UIView.animate(withDuration: 0.2) {
                btn.backgroundColor = useOrange ? ComponentColors.HomeScreen.actionButtonFill : UIColor.systemGray6
                btn.layer.shadowColor = useOrange ? ComponentColors.HomeScreen.actionButtonFill.cgColor : UIColor.clear.cgColor
                btn.layer.shadowOpacity = useOrange ? 0.3 : 0
                if let stack = btn.subviews.first(where: { $0 is UIStackView }) as? UIStackView {
                    for sub in stack.arrangedSubviews {
                        if let lbl = sub as? UILabel {
                            lbl.textColor = useOrange
                                ? (lbl.font.pointSize > 12
                                   ? ComponentColors.PrimaryButton.text
                                   : ComponentColors.PrimaryButton.text.withAlphaComponent(0.88))
                                : (lbl.font.pointSize > 12
                                   ? ComponentColors.LessonScreen.labelSecondary
                                   : ComponentColors.LessonScreen.labelSecondary.withAlphaComponent(0.7))
                        }
                    }
                }
            }
        }
    }

    /// "Notes: D · F · A", "Solfège: Do", "In C major: I–IV–V".
    private func updateEnglishLabel(with index: Int) {
        englishPrefixLabel?.text = item(at: index)?.detailPrefix
        englishLabel.text = item(at: index)?.detail
        englishLabel.font = .systemFont(ofSize: 14, weight: .bold)
        englishLabel.textColor = ComponentColors.LessonScreen.labelPrimary
    }

    @objc private func didTapTryYourself() {
        guard !isEarTrainingLesson else { return }
        let variantIdx = selectedVariantIndex
        guard let practiceItem = item(at: variantIdx) else { return }
        staffView.stop()

        let sheet = TryYourselfViewController(item: practiceItem)
        sheet.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *), let sp = sheet.sheetPresentationController {
            // the sheet's content (instructions, mic, status) needs more than half the screen
            sp.detents = [.large()]
            sp.prefersGrabberVisible = true
            sp.preferredCornerRadius = 30
        }

        // When user taps "Done Practicing" in the sheet, record it
        sheet.onSessionCompleted = { [weak self] attempts in
            self?.recordVariantPracticed(variantIndex: variantIdx, attempts: attempts)
        }

        present(sheet, animated: true)
    }

    private var earPlaybackItems: [DispatchWorkItem] = []

    /// The key's home chord, a pause, then the mystery chord.
    @objc private func didTapEarTrainingPlay() {
        guard isEarTrainingLesson, earRounds.indices.contains(selectedVariantIndex) else { return }
        let round = earRounds[selectedVariantIndex]
        earPlaybackItems.forEach { $0.cancel() }
        earPlaybackItems = []
        AudioEngineManager.shared.startEngine()
        AudioEngineManager.shared.stopAllNotes()

        func chord(_ c: PracticeChord, at time: Double) {
            let on = DispatchWorkItem {
                AudioEngineManager.shared.stopAllNotes()
                c.notes.forEach { AudioEngineManager.shared.startNote(midi: UInt8($0.midi), velocity: 100) }
            }
            earPlaybackItems.append(on)
            DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: on)
        }
        chord(round.reference, at: 0)
        chord(round.mystery, at: 1.3)
        let off = DispatchWorkItem { AudioEngineManager.shared.stopAllNotes() }
        earPlaybackItems.append(off)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6, execute: off)
    }

    @objc private func didTapEarTrainingOption(_ sender: UIButton) {
        guard isEarTrainingLesson, earRounds.indices.contains(selectedVariantIndex),
              PracticeMusic.earOptions.indices.contains(sender.tag) else { return }

        let variantIdx = selectedVariantIndex
        let answer = earRounds[variantIdx].answer
        let attempts = (earTrainingAttempts[variantIdx] ?? 0) + 1
        earTrainingAttempts[variantIdx] = attempts

        let isCorrect = PracticeMusic.earOptions[sender.tag] == answer
        for button in earTrainingOptionButtons {
            if PracticeMusic.earOptions[button.tag] == answer, isCorrect {
                styleEarTrainingOption(button, state: .correct)
            } else if button == sender && !isCorrect {
                styleEarTrainingOption(button, state: .incorrect)
            } else {
                styleEarTrainingOption(button, state: .idle)
            }
        }
        if isCorrect {
            recordVariantPracticed(variantIndex: variantIdx, attempts: attempts)
        }
    }

    // MARK: - Supabase Parts Synchronization
    
    private struct PartCompletedEvent: Decodable {
        let part_index: Int
    }
    
    private func loadCompletedVariantsFromSupabase() {
        Task {
            let done = await SupabaseProgressManager.completedPartIndexes(for: chapterIndex)
            for idx in done where idx < lesson.variants.count {
                variantsDone.insert(idx)
                chipButtons[idx].markDone()
            }
            refreshProgress(animated: true)
        }
    }

    // MARK: - Practice Variant Handlers
}

// MARK: - Lesson Completion Popup View

class LessonCompletionPopupView: UIView {

    var onContinue: (() -> Void)?

    init(stars: Int, lessonTitle: String) {
        super.init(frame: .zero)
        build(stars: stars, lessonTitle: lessonTitle)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build(stars: Int, lessonTitle: String) {
        backgroundColor = .white
        layer.cornerRadius = 28
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.20; layer.shadowRadius = 28
        layer.shadowOffset = CGSize(width: 0, height: 10)

        // Top accent bar
        let bar = UIView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.backgroundColor = ComponentColors.HomeScreen.actionButtonFill; bar.layer.cornerRadius = 4
        addSubview(bar)

        // Icon circle
        let iconCircle = UIView()
        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.10)
        iconCircle.layer.cornerRadius = 40
        addSubview(iconCircle)

        let iconLabel = UILabel()
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.text = stars == 3 ? "🏆" : stars == 2 ? "🎯" : "🎵"
        iconLabel.font = .systemFont(ofSize: 44); iconLabel.textAlignment = .center
        iconCircle.addSubview(iconLabel)

        // Stars row — filled ⭐ for earned, hollow ☆ for remaining
        let starsRow = UIStackView()
        starsRow.translatesAutoresizingMaskIntoConstraints = false
        starsRow.axis = .horizontal; starsRow.spacing = 8; starsRow.alignment = .center
        for i in 0..<3 {
            let lbl = UILabel()
            lbl.font = .systemFont(ofSize: 32)
            if i < stars {
                lbl.text = "⭐"
            } else {
                lbl.text = "☆"
                lbl.textColor = .systemGray4
            }
            // Animate each star popping in with stagger
            lbl.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            lbl.alpha = 0
            starsRow.addArrangedSubview(lbl)
            UIView.animate(withDuration: 0.45, delay: 0.35 + Double(i) * 0.13,
                           usingSpringWithDamping: 0.45, initialSpringVelocity: 0.8) {
                lbl.transform = .identity; lbl.alpha = 1
            }
        }
        addSubview(starsRow)

        // Title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let titles = ["Keep Practising!", "Well Done! 👏", "Lesson Complete! 🎉"]
        titleLabel.text = titles[min(stars - 1, 2)]
        titleLabel.font = .systemFont(ofSize: 22, weight: .heavy)
        titleLabel.textColor = .label; titleLabel.textAlignment = .center
        addSubview(titleLabel)

        // Description
        let descLabel = UILabel()
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        let descs = [
            "You earned \(stars) star — practice makes perfect!",
            "You earned \(stars) stars — great effort!",
            "You earned \(stars) stars — perfect run!"
        ]
        descLabel.text = descs[min(stars - 1, 2)]
        descLabel.font = .systemFont(ofSize: 13); descLabel.textColor = .systemGray
        descLabel.textAlignment = .center; descLabel.numberOfLines = 2
        addSubview(descLabel)

        // "Next lesson unlocked" pill
        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.10)
        pill.layer.cornerRadius = 16
        addSubview(pill)

        let pillLabel = UILabel()
        pillLabel.translatesAutoresizingMaskIntoConstraints = false
        pillLabel.text = "🔓  Next lesson is now unlocked!"
        pillLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        pillLabel.textColor = ComponentColors.HomeScreen.actionButtonFill; pillLabel.textAlignment = .center
        pill.addSubview(pillLabel)

        // Continue button
        let contBtn = UIButton(type: .system)
        contBtn.translatesAutoresizingMaskIntoConstraints = false
        contBtn.setTitle("Continue  →", for: .normal)
        contBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        contBtn.setTitleColor(.white, for: .normal)
        contBtn.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        contBtn.layer.cornerRadius = 26
        contBtn.layer.shadowColor = ComponentColors.HomeScreen.actionButtonFill.cgColor
        contBtn.layer.shadowOpacity = 0.35; contBtn.layer.shadowRadius = 12
        contBtn.layer.shadowOffset = CGSize(width: 0, height: 5)
        contBtn.addTarget(self, action: #selector(tappedContinue), for: .touchUpInside)
        addSubview(contBtn)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            bar.centerXAnchor.constraint(equalTo: centerXAnchor),
            bar.widthAnchor.constraint(equalToConstant: 48),
            bar.heightAnchor.constraint(equalToConstant: 5),

            iconCircle.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 18),
            iconCircle.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 80),
            iconCircle.heightAnchor.constraint(equalToConstant: 80),
            iconLabel.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),

            starsRow.topAnchor.constraint(equalTo: iconCircle.bottomAnchor, constant: 14),
            starsRow.centerXAnchor.constraint(equalTo: centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: starsRow.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            descLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            descLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            pill.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 16),
            pill.centerXAnchor.constraint(equalTo: centerXAnchor),
            pillLabel.topAnchor.constraint(equalTo: pill.topAnchor, constant: 10),
            pillLabel.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -10),
            pillLabel.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 18),
            pillLabel.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -18),

            contBtn.topAnchor.constraint(equalTo: pill.bottomAnchor, constant: 20),
            contBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            contBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            contBtn.heightAnchor.constraint(equalToConstant: 52),
            contBtn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -26),
        ])
    }

    @objc private func tappedContinue() { onContinue?() }
}

// MARK: - Try Yourself Sheet

class TryYourselfViewController: UIViewController {

    // MARK: - Properties

    private let item: PracticeItem
    /// Which step (chord of a progression) is being listened for.
    private var stepIndex = 0
    private var targetStep: PracticeStep { item.steps[min(stepIndex, item.steps.count - 1)] }
    private var targetHintLabel: UILabel!

    private var isListening = false
    private var pulseViews: [UIView] = []
    private var micButton: UIButton!
    private var statusLabel: UILabel!
    private var detectedNoteLabel: UILabel!
    private var attemptCount: Int = 0
    private var attemptCounterLabel: UILabel!
    private var doneButton: UIButton!
    private var instructionLabel: UILabel!
    private var lastDetectedRoot: String?
    private var stableRootFrameCount = 0
    private let minimumDetectionAmplitude: CGFloat = 0.3
    private let minimumMatchFrequency: Float = 70

    // Real pitch detection
    private let pitchDetector = PitchDetector()
    /// How many consecutive correct-note callbacks to require before marking done
    private var correctStreak = 0
    private let streakRequired = 5   // ~1 second at typical callback rate
    private var alreadyMarkedCorrect = false

    /// Delivers the number of mic taps (attempts) the user made — used to compute stars
    var onSessionCompleted: ((Int) -> Void)?

    init(item: PracticeItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        pitchDetector.delegate = self
        setupUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pitchDetector.stopListening()
    }

    // MARK: - UI Setup

    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Try Yourself"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = ComponentColors.LessonScreen.labelPrimary
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)

        // Note pill showing what note to sing — auto-sizes to fit the text
        let notePill = UIView()
        notePill.translatesAutoresizingMaskIntoConstraints = false
        notePill.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.1)
        notePill.layer.cornerRadius = 25
        let noteLabel = UILabel()
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        noteLabel.text = item.title
        noteLabel.font = .systemFont(ofSize: 28, weight: .bold)
        noteLabel.textColor = ComponentColors.HomeScreen.actionButtonFill
        noteLabel.textAlignment = .center
        noteLabel.adjustsFontSizeToFitWidth = true
        noteLabel.minimumScaleFactor = 0.5
        notePill.addSubview(noteLabel)
        NSLayoutConstraint.activate([
            noteLabel.centerXAnchor.constraint(equalTo: notePill.centerXAnchor),
            noteLabel.centerYAnchor.constraint(equalTo: notePill.centerYAnchor),
            noteLabel.leadingAnchor.constraint(equalTo: notePill.leadingAnchor, constant: 24),
            noteLabel.trailingAnchor.constraint(equalTo: notePill.trailingAnchor, constant: -24),
        ])

        // Target hint
        targetHintLabel = UILabel()
        targetHintLabel.translatesAutoresizingMaskIntoConstraints = false
        targetHintLabel.numberOfLines = 0
        updateTargetHint()
        targetHintLabel.font = .systemFont(ofSize: 12, weight: .medium)
        targetHintLabel.textColor = .systemGray2
        targetHintLabel.textAlignment = .center

        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = item.instruction
        subLabel.font = .systemFont(ofSize: 15)
        subLabel.textColor = .systemGray; subLabel.textAlignment = .center
        subLabel.numberOfLines = 0

        instructionLabel = UILabel()
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.text = "Tap the microphone, then play on your piano."
        instructionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        instructionLabel.textColor = ComponentColors.LessonScreen.labelSecondary
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0

        // Real-time detected note badge
        detectedNoteLabel = UILabel()
        detectedNoteLabel.translatesAutoresizingMaskIntoConstraints = false
        detectedNoteLabel.text = "—"
        detectedNoteLabel.font = .systemFont(ofSize: 36, weight: .heavy)
        detectedNoteLabel.textColor = ComponentColors.HomeScreen.actionButtonFill
        detectedNoteLabel.textAlignment = .center
        detectedNoteLabel.alpha = 0

        // Attempt counter
        attemptCounterLabel = UILabel()
        attemptCounterLabel.translatesAutoresizingMaskIntoConstraints = false
        attemptCounterLabel.text = "Attempts: 0  •  1st attempt = ⭐⭐⭐"
        attemptCounterLabel.font = .systemFont(ofSize: 11, weight: .medium)
        attemptCounterLabel.textColor = .systemGray; attemptCounterLabel.textAlignment = .center

        // Rings + mic
        let ringContainer = UIView()
        ringContainer.translatesAutoresizingMaskIntoConstraints = false
        for i in 0..<3 {
            let ring = UIView()
            ring.layer.cornerRadius = CGFloat(50 + i * 20)
            ring.layer.borderColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0).cgColor
            ring.layer.borderWidth = 2.5
            ring.translatesAutoresizingMaskIntoConstraints = false
            ringContainer.addSubview(ring); pulseViews.append(ring)
            let sz = CGFloat(100 + i * 40)
            NSLayoutConstraint.activate([
                ring.centerXAnchor.constraint(equalTo: ringContainer.centerXAnchor),
                ring.centerYAnchor.constraint(equalTo: ringContainer.centerYAnchor),
                ring.widthAnchor.constraint(equalToConstant: sz),
                ring.heightAnchor.constraint(equalToConstant: sz),
            ])
        }

        micButton = UIButton(type: .system)
        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        micButton.layer.cornerRadius = 42
        micButton.layer.shadowColor = ComponentColors.HomeScreen.actionButtonFill.cgColor
        micButton.layer.shadowOpacity = 0.4; micButton.layer.shadowRadius = 20
        micButton.layer.shadowOffset = CGSize(width: 0, height: 8)
        let micConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        micButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: micConfig), for: .normal)
        micButton.tintColor = .white
        micButton.addTarget(self, action: #selector(toggleListening), for: .touchUpInside)
        ringContainer.addSubview(micButton)
        NSLayoutConstraint.activate([
            micButton.centerXAnchor.constraint(equalTo: ringContainer.centerXAnchor),
            micButton.centerYAnchor.constraint(equalTo: ringContainer.centerYAnchor),
            micButton.widthAnchor.constraint(equalToConstant: 84),
            micButton.heightAnchor.constraint(equalToConstant: 84),
        ])

        let grad = CAGradientLayer()
        grad.colors = [ComponentColors.HomeScreen.actionButtonFill.cgColor, UIColor.orange.cgColor]
        grad.startPoint = CGPoint(x: 0, y: 0); grad.endPoint = CGPoint(x: 1, y: 1)
        grad.frame = CGRect(x: 0, y: 0, width: 84, height: 84); grad.cornerRadius = 42
        micButton.layer.insertSublayer(grad, at: 0)
        micButton.bringSubviewToFront(micButton.imageView ?? UIView())

        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Tap the microphone to start listening"
        statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        statusLabel.textColor = .systemGray; statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2

        // Green "Done Practicing" button
        doneButton = UIButton(type: .system)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.setTitle("✓  Done Practicing", for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        doneButton.setTitleColor(.white, for: .normal)
        let green = ComponentColors.LessonScreen.correctAnswer
        doneButton.backgroundColor = green
        doneButton.layer.cornerRadius = 24
        doneButton.layer.shadowColor = green.cgColor
        doneButton.layer.shadowOpacity = 0.35; doneButton.layer.shadowRadius = 10
        doneButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        doneButton.alpha = 0
        doneButton.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)

        [titleLabel, closeButton, notePill, targetHintLabel, subLabel, instructionLabel,
         detectedNoteLabel, attemptCounterLabel,
         ringContainer, statusLabel, doneButton].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),

            notePill.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            notePill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            notePill.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            notePill.widthAnchor.constraint(lessThanOrEqualToConstant: 220),
            notePill.heightAnchor.constraint(equalToConstant: 50),
            noteLabel.centerXAnchor.constraint(equalTo: notePill.centerXAnchor),
            noteLabel.centerYAnchor.constraint(equalTo: notePill.centerYAnchor),

            targetHintLabel.topAnchor.constraint(equalTo: notePill.bottomAnchor, constant: 4),
            targetHintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subLabel.topAnchor.constraint(equalTo: targetHintLabel.bottomAnchor, constant: 6),
            subLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            subLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            instructionLabel.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 8),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

            detectedNoteLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 4),
            detectedNoteLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            attemptCounterLabel.topAnchor.constraint(equalTo: detectedNoteLabel.bottomAnchor, constant: 4),
            attemptCounterLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            ringContainer.topAnchor.constraint(equalTo: attemptCounterLabel.bottomAnchor, constant: 12),
            ringContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ringContainer.widthAnchor.constraint(equalToConstant: 220),
            ringContainer.heightAnchor.constraint(equalToConstant: 220),

            statusLabel.topAnchor.constraint(equalTo: ringContainer.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            doneButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            doneButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            doneButton.heightAnchor.constraint(equalToConstant: 48),
            doneButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    // MARK: - Actions

    @objc private func didTapClose() {
        pitchDetector.stopListening()
        dismiss(animated: true)
    }

    @objc private func toggleListening() {
        if isListening {
            stopListeningAndReset()
            return
        }

        beginListeningFlow()
    }

    private func beginListeningFlow() {
        switch pitchDetector.recordPermissionStatus() {
        case .granted:
            startListeningSession()
        case .undetermined:
            presentMicrophoneRationale()
        case .denied:
            showMicrophonePermissionNeededState()
            presentMicrophoneSettingsAlert()
        @unknown default:
            showMicrophonePermissionNeededState()
            presentMicrophoneSettingsAlert()
        }
    }

    private func startListeningSession() {
        guard !isListening else { return }
        guard pitchDetector.startListening() else {
            showMicrophoneUnavailableState()
            presentMicrophoneUnavailableAlert()
            return
        }

        isListening = true
        attemptCount += 1
        correctStreak = 0
        stableRootFrameCount = 0
        lastDetectedRoot = nil
        stepIndex = 0
        updateTargetHint()
        let starsHint = attemptCount == 1 ? "⭐⭐⭐" : attemptCount == 2 ? "⭐⭐" : "⭐"
        attemptCounterLabel.text = "Attempts: \(attemptCount)  •  \(starsHint)"
        UIView.transition(with: attemptCounterLabel, duration: 0.2, options: .transitionCrossDissolve, animations: nil)

        let activeMicConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        micButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: activeMicConfig), for: .normal)
        statusLabel.text = "Listening… play \(targetStep.label)"
        statusLabel.textColor = ComponentColors.HomeScreen.actionButtonFill
        instructionLabel.text = "Hold it steady for a moment. Quiet rooms work best."
        UIView.animate(withDuration: 0.25) {
            self.detectedNoteLabel.alpha = 1
            self.micButton.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }
        startPulseAnimation()
    }

    private func presentMicrophoneRationale() {
        guard presentedViewController == nil else { return }

        let alert = UIAlertController(
            title: "Use Microphone for Try Yourself",
            message: "Re-Hearse only uses the microphone while this exercise is active so it can detect the note you play or sing.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { [weak self] _ in
            self?.showMicrophonePermissionNeededState()
        })
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
            self?.pitchDetector.requestMicrophonePermission { granted in
                guard let self else { return }
                if granted {
                    self.startListeningSession()
                } else {
                    self.showMicrophonePermissionNeededState()
                    self.presentMicrophoneSettingsAlert()
                }
            }
        })
        present(alert, animated: true)
    }

    private func presentMicrophoneSettingsAlert() {
        guard presentedViewController == nil else { return }

        let alert = UIAlertController(
            title: "Microphone Access Needed",
            message: "Turn on microphone access in Settings so this lesson can hear the note you play or sing.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsURL)
        })
        present(alert, animated: true)
    }

    private func presentMicrophoneUnavailableAlert() {
        guard presentedViewController == nil else { return }

        let message = pitchDetector.lastStartFailure?.errorDescription
            ?? "Re-Hearse could not start microphone capture right now. Please try again."

        let alert = UIAlertController(
            title: "Microphone Unavailable",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showMicrophonePermissionNeededState() {
        pitchDetector.stopListening()
        isListening = false
        correctStreak = 0
        stableRootFrameCount = 0
        lastDetectedRoot = nil
        let micConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        micButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: micConfig), for: .normal)
        statusLabel.text = "Microphone access needed"
        statusLabel.textColor = .systemRed
        instructionLabel.text = "Allow microphone access in Settings, then tap capture audio again."
        stopPulseAnimation()
        UIView.animate(withDuration: 0.3) {
            self.micButton.transform = .identity
        }
    }

    private func showMicrophoneUnavailableState() {
        pitchDetector.stopListening()
        isListening = false
        correctStreak = 0
        stableRootFrameCount = 0
        lastDetectedRoot = nil
        let micConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        micButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: micConfig), for: .normal)
        statusLabel.text = "Microphone unavailable"
        statusLabel.textColor = .systemRed
        instructionLabel.text = "Please check your microphone setup and try again."
        stopPulseAnimation()
        UIView.animate(withDuration: 0.3) {
            self.micButton.transform = .identity
        }
    }

    private func stopListeningAndReset() {
        pitchDetector.stopListening()
        isListening = false
        correctStreak = 0
        stableRootFrameCount = 0
        lastDetectedRoot = nil
        let micConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        micButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: micConfig), for: .normal)
        statusLabel.text = "Stopped. Tap the microphone to try again."
        statusLabel.textColor = .systemGray
        instructionLabel.text = "Tap the microphone, then play on your piano."
        stopPulseAnimation()
        UIView.animate(withDuration: 0.3) { self.micButton.transform = .identity }
    }

    @objc private func didTapDone() {
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

    /// "Listening for: D · F · A", or "Chord 2 of 4: G · B · D" in a progression.
    private func updateTargetHint() {
        let notes = targetStep.pitches.map(\.display).joined(separator: " · ")
        let prefix = item.steps.count > 1
            ? "Chord \(stepIndex + 1) of \(item.steps.count) — \(targetStep.label): "
            : (targetStep.pitches.count > 1 ? "Listening for: " : "Listening for ")
        targetHintLabel?.text = prefix + notes
    }

    // MARK: - Correct Match Animation

    private func flashCorrect() {
        guard !alreadyMarkedCorrect else { return }
        alreadyMarkedCorrect = true
        stopPulseAnimation()

        // Flash mic button green
        UIView.animate(withDuration: 0.25) {
            self.micButton.backgroundColor = ComponentColors.LessonScreen.correctAnswer
            self.micButton.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
        }

        let successConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        micButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: successConfig), for: .normal)

        statusLabel.text = "🎉 Nailed it! Tap Done ✓"
        statusLabel.textColor = ComponentColors.LessonScreen.correctAnswer
        instructionLabel.text = item.steps.count > 1 ? "You played every chord in order." : "You played \(item.title)."

        // Animate rings green
        for (i, ring) in pulseViews.enumerated() {
            UIView.animate(withDuration: 0.4, delay: Double(i) * 0.08) {
                ring.layer.borderColor = ComponentColors.LessonScreen.correctAnswer.withAlphaComponent(0.4 - Double(i) * 0.1).cgColor
                ring.transform = CGAffineTransform(scaleX: 1.15 + CGFloat(i) * 0.05, y: 1.15 + CGFloat(i) * 0.05)
            }
        }

        // Reveal Done button immediately
        UIView.animate(withDuration: 0.35, delay: 0.2, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.doneButton.alpha = 1
        }

        // Auto-dismiss after brief celebration — user doesn't need to tap anything
        statusLabel.text = "🎉 Nailed it! Marking done…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.didTapDone()
        }
    }

    // MARK: - Animations

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
    public func pitchDetectorDidDetect(notes: [String], frequency: Float, amplitude: CGFloat) {
        guard isListening, !alreadyMarkedCorrect else { return }
        guard amplitude >= minimumDetectionAmplitude, frequency >= minimumMatchFrequency else {
            correctStreak = 0
            stableRootFrameCount = 0
            lastDetectedRoot = nil
            return
        }
        let heardMidi = notes.compactMap { AudioEngineManager.shared.midiNumber(from: $0) }.map(Int.init)
        guard !heardMidi.isEmpty else { return }
        let heard = Set(heardMidi.map { $0 % 12 })
        let target = targetStep.pitchClasses

        detectedNoteLabel.text = notes.prefix(3).joined(separator: " ")
        // every note of the target sounding (any octave)
        let allHeard = target.isSubset(of: heard)
        let someHeard = !target.isDisjoint(with: heard)
        let key = heard.sorted().map(String.init).joined(separator: ",")
        if key == lastDetectedRoot { stableRootFrameCount += 1 } else { lastDetectedRoot = key; stableRootFrameCount = 1 }
        let isMatch = allHeard && stableRootFrameCount >= 2

        let color: UIColor = isMatch ? ComponentColors.LessonScreen.correctAnswer : (someHeard ? .systemOrange : .systemRed)
        detectedNoteLabel.textColor = color
        let scale = 1.0 + amplitude * 0.18
        UIView.animate(withDuration: 0.1) {
            for (i, ring) in self.pulseViews.enumerated() {
                let s = scale + CGFloat(i) * 0.03
                ring.transform = CGAffineTransform(scaleX: s, y: s)
                ring.layer.borderColor = color.withAlphaComponent(amplitude * 0.5).cgColor
            }
        }

        guard isMatch else {
            correctStreak = 0
            let missing = targetStep.pitches.filter { !heard.contains($0.pitchClass) }.map(\.display)
            statusLabel.text = someHeard && !missing.isEmpty
                ? "Almost — also play \(missing.joined(separator: ", "))"
                : "Heard \(notes.first ?? "") — play \(targetStep.label)"
            statusLabel.textColor = someHeard ? .systemOrange : .systemRed
            return
        }

        correctStreak += 1
        let filled = String(repeating: "●", count: min(correctStreak, streakRequired))
        let empty = String(repeating: "○", count: max(0, streakRequired - correctStreak))
        statusLabel.text = "✅ \(targetStep.label) — hold it!  \(filled)\(empty)"
        statusLabel.textColor = ComponentColors.LessonScreen.correctAnswer
        guard correctStreak >= streakRequired else { return }

        if stepIndex < item.steps.count - 1 {
            // next chord of the progression
            stepIndex += 1
            correctStreak = 0
            stableRootFrameCount = 0
            lastDetectedRoot = nil
            updateTargetHint()
            statusLabel.text = "Great — now play \(targetStep.label)"
        } else {
            flashCorrect()
        }
    }
}

// MARK: - UIScrollViewDelegate

extension LessonDetailViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === self.scrollView {
            syncNavBarAlpha()
        }
    }
    
    private func syncNavBarAlpha() {
        NavigationBarHelper.syncNavigationBarAlpha(
            scrollView: scrollView,
            navigationItem: navigationItem,
            navBackgroundView: navBackgroundView
        )
        
        // Fixed: only largeProfileButton scrolls away, no small one in navbar
    }
}
