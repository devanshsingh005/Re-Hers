import UIKit
@preconcurrency import Supabase
@preconcurrency import Auth
@preconcurrency import PostgREST

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
        guard !lesson.variants.isEmpty else { return 0 }
        return Float(variantsDone.count) / Float(lesson.variants.count)
    }

    // Called back to L1 with star count when done
    var onLessonCompleted: ((Int) -> Void)?

    // UI references
    private var staffView: MusicStaffView!
    private var noteNameLabel: UILabel!
    private var englishLabel: UILabel!
    private var variantsScrollView: UIScrollView!
    private var chipsStack: UIStackView!
    private var tryBtn: UIButton!
    private var progressFillConstraint: NSLayoutConstraint!
    private var progressPercentLabel: UILabel!
    private var progressRowLabel: UILabel!
    private var dotsStack: UIStackView!
    private var scrollView: UIScrollView!
    private var contentView: UIView!

    init(lesson: MusicLesson, chapterIndex: Int) {
        self.lesson = lesson
        self.chapterIndex = chapterIndex
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.HomeScreen.background
        setupUI()
        loadCompletedVariantsFromSupabase()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Start the clock the moment the lesson is fully on screen
        lessonStartedAt = Date()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Standard Detail Navigation Bar Setup
        navigationController?.navigationBar.isHidden = false
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        title = "Basics"

        navigationItem.leftBarButtonItem = NavigationBarHelper.createCustomBackButton(target: self, action: #selector(didTapBack))

        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // ── Lesson Title & Progress ──
        progressRowLabel = UILabel()
        progressRowLabel.translatesAutoresizingMaskIntoConstraints = false
        refreshProgressRowLabel()

        let progressBGView = UIView()
        progressBGView.translatesAutoresizingMaskIntoConstraints = false
        progressBGView.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.18)
        progressBGView.layer.cornerRadius = 4

        let progressFill = UIView()
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        progressFill.layer.cornerRadius = 4
        progressBGView.addSubview(progressFill)

        let lessonNameLabel = UILabel()
        lessonNameLabel.translatesAutoresizingMaskIntoConstraints = false
        lessonNameLabel.text = "Lesson \(chapterIndex): \(lesson.title)"
        lessonNameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        lessonNameLabel.textColor = ComponentColors.HomeScreen.actionButtonFill

        progressPercentLabel = UILabel()
        progressPercentLabel.translatesAutoresizingMaskIntoConstraints = false
        progressPercentLabel.text = "0% complete"
        progressPercentLabel.font = .systemFont(ofSize: 13)
        progressPercentLabel.textColor = .systemGray

        // ── Variant dots row ──
        let dotsLabel = UILabel()
        dotsLabel.translatesAutoresizingMaskIntoConstraints = false
        dotsLabel.text = "Variants:"
        dotsLabel.font = .systemFont(ofSize: 11, weight: .medium)
        dotsLabel.textColor = .systemGray

        dotsStack = UIStackView()
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        dotsStack.axis = .horizontal; dotsStack.spacing = 6; dotsStack.alignment = .center

        for _ in 0..<lesson.variants.count {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.layer.cornerRadius = 5
            dot.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.2)
            dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 10).isActive = true
            dotsStack.addArrangedSubview(dot)
        }

        let dotsRow = UIStackView(arrangedSubviews: [dotsLabel, dotsStack])
        dotsRow.translatesAutoresizingMaskIntoConstraints = false
        dotsRow.axis = .horizontal; dotsRow.spacing = 8; dotsRow.alignment = .center

        // ── Staff card ──
        let staffCardView = UIView()
        staffCardView.translatesAutoresizingMaskIntoConstraints = false
        staffCardView.backgroundColor = .white
        staffCardView.layer.cornerRadius = 24
        staffCardView.layer.shadowColor = UIColor.black.cgColor
        staffCardView.layer.shadowOpacity = 0.08
        staffCardView.layer.shadowRadius = 16
        staffCardView.layer.shadowOffset = CGSize(width: 0, height: 6)

        staffView = MusicStaffView(noteName: MusicHelper.getNoteLetter(from: lesson.variants[0]))
        staffView.translatesAutoresizingMaskIntoConstraints = false
        staffView.backgroundColor = .clear; staffView.layer.shadowOpacity = 0
        staffCardView.addSubview(staffView)

        // ── Note name ──
        noteNameLabel = UILabel()
        noteNameLabel.translatesAutoresizingMaskIntoConstraints = false
        noteNameLabel.text = lesson.variants[0]
        noteNameLabel.font = .systemFont(ofSize: 80, weight: .heavy)
        noteNameLabel.textColor = ComponentColors.HomeScreen.actionButtonFill; noteNameLabel.textAlignment = .center
        noteNameLabel.layer.shadowColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.3).cgColor
        noteNameLabel.layer.shadowRadius = 10; noteNameLabel.layer.shadowOpacity = 0.3
        noteNameLabel.layer.shadowOffset = CGSize(width: 0, height: 4)

        // ── English note row ──
        let engRow = UIView()
        engRow.translatesAutoresizingMaskIntoConstraints = false
        let engPrefix = UILabel()
        engPrefix.translatesAutoresizingMaskIntoConstraints = false
        engPrefix.text = "English Note: "
        engPrefix.font = .systemFont(ofSize: 14, weight: .medium); engPrefix.textColor = .systemGray
        engRow.addSubview(engPrefix)
        englishLabel = UILabel()
        englishLabel.translatesAutoresizingMaskIntoConstraints = false
        updateEnglishLabel(with: lesson.variants[0])
        engRow.addSubview(englishLabel)

        // ── Variants section ──
        let variantsHeaderLabel = UILabel()
        variantsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        variantsHeaderLabel.text = "Tap a variant chip, then practice with the mic ↓"
        variantsHeaderLabel.font = .systemFont(ofSize: 12, weight: .medium)
        variantsHeaderLabel.textColor = .systemGray

        variantsScrollView = UIScrollView()
        variantsScrollView.translatesAutoresizingMaskIntoConstraints = false
        variantsScrollView.showsHorizontalScrollIndicator = false
        variantsScrollView.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)

        chipsStack = UIStackView()
        chipsStack.translatesAutoresizingMaskIntoConstraints = false
        chipsStack.axis = .horizontal; chipsStack.spacing = 10; chipsStack.alignment = .center
        variantsScrollView.addSubview(chipsStack)

        for (i, variant) in lesson.variants.enumerated() {
            let sub = i == 0 ? lesson.noteEnglish : variant
            let chip = VariantChipButton(label: variant, sublabel: sub, isSelected: i == 0)
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

        // Concepts, Chords, Progressions cards...
        let conceptCard = makeInfoCard()
        let conceptHeader = makeCardHeader("About this lesson", icon: "text.book.closed")
        let descLabel = UILabel()
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.text = lesson.description
        descLabel.font = .systemFont(ofSize: 14); descLabel.textColor = ComponentColors.SongCard.titleText
        descLabel.numberOfLines = 0
        conceptCard.addSubview(conceptHeader); conceptCard.addSubview(descLabel)
        
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
            overviewLabel.font = .systemFont(ofSize: 13); overviewLabel.textColor = ComponentColors.SongCard.metadataText
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

        let chordsCard = makeChordsCard()
        let progsCard = makeProgressionsCard()
        let listenCard = makeListenCard()
        let tasksCard = makeTasksCard()

        // ── Layout additions ──
        [progressRowLabel, progressBGView, lessonNameLabel, progressPercentLabel, dotsRow, staffCardView, noteNameLabel, 
         engRow, variantsHeaderLabel, variantsScrollView, tryBtn, conceptCard, chordsCard, progsCard, listenCard, tasksCard].forEach { contentView.addSubview($0) }

        progressFillConstraint = progressFill.widthAnchor.constraint(equalToConstant: 0)
        progressFillConstraint.isActive = true

        NSLayoutConstraint.activate([
            progressRowLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            progressRowLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            progressBGView.topAnchor.constraint(equalTo: progressRowLabel.bottomAnchor, constant: 5),
            progressBGView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            progressBGView.widthAnchor.constraint(equalToConstant: 130),
            progressBGView.heightAnchor.constraint(equalToConstant: 7),

            progressFill.leadingAnchor.constraint(equalTo: progressBGView.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressBGView.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBGView.bottomAnchor),

            lessonNameLabel.topAnchor.constraint(equalTo: progressBGView.bottomAnchor, constant: 10),
            lessonNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            progressPercentLabel.centerYAnchor.constraint(equalTo: lessonNameLabel.centerYAnchor),
            progressPercentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            dotsRow.topAnchor.constraint(equalTo: lessonNameLabel.bottomAnchor, constant: 8),
            dotsRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            staffCardView.topAnchor.constraint(equalTo: dotsRow.bottomAnchor, constant: 14),
            staffCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            staffCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            staffCardView.heightAnchor.constraint(equalToConstant: 195),
            staffView.topAnchor.constraint(equalTo: staffCardView.topAnchor),
            staffView.leadingAnchor.constraint(equalTo: staffCardView.leadingAnchor),
            staffView.trailingAnchor.constraint(equalTo: staffCardView.trailingAnchor),
            staffView.bottomAnchor.constraint(equalTo: staffCardView.bottomAnchor),

            noteNameLabel.topAnchor.constraint(equalTo: staffCardView.bottomAnchor, constant: 8),
            noteNameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            engRow.topAnchor.constraint(equalTo: noteNameLabel.bottomAnchor, constant: 4),
            engRow.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            engPrefix.leadingAnchor.constraint(equalTo: engRow.leadingAnchor),
            engPrefix.centerYAnchor.constraint(equalTo: engRow.centerYAnchor),
            engPrefix.topAnchor.constraint(equalTo: engRow.topAnchor),
            engPrefix.bottomAnchor.constraint(equalTo: engRow.bottomAnchor),
            englishLabel.leadingAnchor.constraint(equalTo: engPrefix.trailingAnchor),
            englishLabel.centerYAnchor.constraint(equalTo: engRow.centerYAnchor),
            englishLabel.trailingAnchor.constraint(equalTo: engRow.trailingAnchor),

            variantsHeaderLabel.topAnchor.constraint(equalTo: engRow.bottomAnchor, constant: 18),
            variantsHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            variantsScrollView.topAnchor.constraint(equalTo: variantsHeaderLabel.bottomAnchor, constant: 10),
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

            conceptCard.topAnchor.constraint(equalTo: tryBtn.bottomAnchor, constant: 28),
            conceptCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            conceptCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            chordsCard.topAnchor.constraint(equalTo: conceptCard.bottomAnchor, constant: 14),
            chordsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            chordsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            progsCard.topAnchor.constraint(equalTo: chordsCard.bottomAnchor, constant: 14),
            progsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            progsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            listenCard.topAnchor.constraint(equalTo: progsCard.bottomAnchor, constant: 14),
            listenCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            listenCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            tasksCard.topAnchor.constraint(equalTo: listenCard.bottomAnchor, constant: 14),
            tasksCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tasksCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tasksCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -36),
        ])
        chipsStack.widthAnchor.constraint(equalToConstant: CGFloat(lesson.variants.count) * 82).isActive = true
    }

    // MARK: - Card Builders

    private func makeChordsCard() -> UIView {
        let v = makeInfoCard()
        let h = makeCardHeader("Chord details", icon: "music.note.list")
        v.addSubview(h)
        var last = h.bottomAnchor
        var cons: [NSLayoutConstraint] = [
            h.topAnchor.constraint(equalTo: v.topAnchor, constant: 14),
            h.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 14),
            h.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -14),
        ]
        for (i, det) in lesson.chordDetails.enumerated() {
            let row = makeChordRow(detail: det, index: i)
            v.addSubview(row)
            cons += [
                row.topAnchor.constraint(equalTo: last, constant: i == 0 ? 10 : 2),
                row.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 10),
                row.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -10),
            ]
            last = row.bottomAnchor
        }
        cons.append(last.constraint(equalTo: v.bottomAnchor, constant: -14))
        NSLayoutConstraint.activate(cons)
        return v
    }

    private func makeProgressionsCard() -> UIView {
        let v = makeInfoCard()
        let h = makeCardHeader("Common progressions", icon: "arrow.triangle.2.circlepath")
        v.addSubview(h)
        var last = h.bottomAnchor
        var cons: [NSLayoutConstraint] = [
            h.topAnchor.constraint(equalTo: v.topAnchor, constant: 14),
            h.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 14),
            h.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -14),
        ]
        for (i, prog) in lesson.progressions.enumerated() {
            let row = makeProgressionRow(prog: prog, index: i)
            v.addSubview(row)
            cons += [
                row.topAnchor.constraint(equalTo: last, constant: i == 0 ? 10 : 6),
                row.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 10),
                row.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -10),
            ]
            last = row.bottomAnchor
        }
        cons.append(last.constraint(equalTo: v.bottomAnchor, constant: -14))
        NSLayoutConstraint.activate(cons)
        return v
    }

    private func makeListenCard() -> UIView {
        let v = makeInfoCard()
        let h = makeCardHeader("Listening guide", icon: "ear")
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = lesson.listeningGuide.isEmpty ? "Listen carefully to each chord and notice the mood it creates." : lesson.listeningGuide
        l.font = .systemFont(ofSize: 14); l.textColor = ComponentColors.SongCard.titleText; l.numberOfLines = 0
        v.addSubview(h); v.addSubview(l)
        NSLayoutConstraint.activate([
            h.topAnchor.constraint(equalTo: v.topAnchor, constant: 14),
            h.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 14),
            h.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -14),
            l.topAnchor.constraint(equalTo: h.bottomAnchor, constant: 8),
            l.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 14),
            l.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -14),
            l.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -14),
        ])
        return v
    }

    private func makeTasksCard() -> UIView {
        let v = makeInfoCard()
        let h = makeCardHeader("Practice tasks", icon: "checkmark.circle")
        v.addSubview(h)
        var last = h.bottomAnchor
        var cons: [NSLayoutConstraint] = [
            h.topAnchor.constraint(equalTo: v.topAnchor, constant: 14),
            h.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 14),
            h.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -14),
        ]
        for (i, task) in lesson.practiceTasks.enumerated() {
            let row = makeTaskRow(number: i+1, text: task)
            v.addSubview(row)
            cons += [
                row.topAnchor.constraint(equalTo: last, constant: i == 0 ? 10 : 6),
                row.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 10),
                row.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -10),
            ]
            last = row.bottomAnchor
        }
        cons.append(last.constraint(equalTo: v.bottomAnchor, constant: -14))
        NSLayoutConstraint.activate(cons)
        return v
    }

    private func makeInfoCard() -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = ComponentColors.SongCard.background; v.layer.cornerRadius = 18; v.layer.masksToBounds = true
        return v
    }

    private func makeCardHeader(_ title: String, icon: String) -> UIView {
        let row = UIStackView(); row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal; row.spacing = 7; row.alignment = .center
        let img = UIImageView(image: UIImage(systemName: icon))
        img.tintColor = ComponentColors.HomeScreen.actionButtonFill; img.contentMode = .scaleAspectFit
        img.widthAnchor.constraint(equalToConstant: 16).isActive = true
        img.heightAnchor.constraint(equalToConstant: 16).isActive = true
        let lbl = UILabel(); lbl.text = title; lbl.font = .systemFont(ofSize: 13, weight: .bold); lbl.textColor = ComponentColors.HomeScreen.actionButtonFill
        row.addArrangedSubview(img); row.addArrangedSubview(lbl)
        return row
    }

    private func makeChordRow(detail: ChordDetail, index: Int) -> UIView {
        let bg = UIView(); bg.translatesAutoresizingMaskIntoConstraints = false
        bg.backgroundColor = index % 2 == 0 ? UIColor.white.withAlphaComponent(0.60) : UIColor.white.withAlphaComponent(0.30)
        bg.layer.cornerRadius = 12
        let namePill = UIView(); namePill.translatesAutoresizingMaskIntoConstraints = false
        namePill.backgroundColor = ComponentColors.HomeScreen.actionButtonFill; namePill.layer.cornerRadius = 10
        let nameL = UILabel(); nameL.translatesAutoresizingMaskIntoConstraints = false
        nameL.text = detail.name; nameL.font = .systemFont(ofSize: 11, weight: .bold); nameL.textColor = .white
        namePill.addSubview(nameL)
        let notesL = UILabel(); notesL.translatesAutoresizingMaskIntoConstraints = false
        notesL.text = detail.notes.joined(separator: " – "); notesL.font = .systemFont(ofSize: 12, weight: .semibold); notesL.textColor = ComponentColors.SongCard.titleText
        let emotionL = UILabel(); emotionL.translatesAutoresizingMaskIntoConstraints = false
        emotionL.text = detail.emotion; emotionL.font = .systemFont(ofSize: 11); emotionL.textColor = ComponentColors.SongCard.metadataText; emotionL.numberOfLines = 2
        bg.addSubview(namePill); bg.addSubview(notesL); bg.addSubview(emotionL)
        NSLayoutConstraint.activate([
            namePill.topAnchor.constraint(equalTo: bg.topAnchor, constant: 10),
            namePill.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            nameL.topAnchor.constraint(equalTo: namePill.topAnchor, constant: 4), nameL.bottomAnchor.constraint(equalTo: namePill.bottomAnchor, constant: -4),
            nameL.leadingAnchor.constraint(equalTo: namePill.leadingAnchor, constant: 8), nameL.trailingAnchor.constraint(equalTo: namePill.trailingAnchor, constant: -8),
            notesL.topAnchor.constraint(equalTo: namePill.bottomAnchor, constant: 5), notesL.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            emotionL.topAnchor.constraint(equalTo: notesL.bottomAnchor, constant: 3), emotionL.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            emotionL.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -10), emotionL.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -10),
        ])
        return bg
    }

    private func makeProgressionRow(prog: ProgressionExample, index: Int) -> UIView {
        let bg = UIView(); bg.translatesAutoresizingMaskIntoConstraints = false
        bg.backgroundColor = index % 2 == 0 ? UIColor.white.withAlphaComponent(0.60) : UIColor.white.withAlphaComponent(0.30)
        bg.layer.cornerRadius = 12
        let numL = UILabel(); numL.translatesAutoresizingMaskIntoConstraints = false
        numL.text = prog.numerals; numL.font = .systemFont(ofSize: 11, weight: .bold); numL.textColor = ComponentColors.HomeScreen.actionButtonFill
        let choL = UILabel(); choL.translatesAutoresizingMaskIntoConstraints = false
        choL.text = prog.chords; choL.font = .systemFont(ofSize: 13, weight: .semibold); choL.textColor = ComponentColors.SongCard.titleText
        let feelL = UILabel(); feelL.translatesAutoresizingMaskIntoConstraints = false
        feelL.text = prog.feel; feelL.font = .systemFont(ofSize: 11); feelL.textColor = ComponentColors.SongCard.metadataText; feelL.numberOfLines = 2
        bg.addSubview(numL); bg.addSubview(choL); bg.addSubview(feelL)
        NSLayoutConstraint.activate([
            numL.topAnchor.constraint(equalTo: bg.topAnchor, constant: 10), numL.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            choL.topAnchor.constraint(equalTo: numL.bottomAnchor, constant: 3), choL.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            feelL.topAnchor.constraint(equalTo: choL.bottomAnchor, constant: 3), feelL.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            feelL.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -10), feelL.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -10),
        ])
        return bg
    }

    private func makeTaskRow(number: Int, text: String) -> UIView {
        let bg = UIView(); bg.translatesAutoresizingMaskIntoConstraints = false
        bg.backgroundColor = UIColor.white.withAlphaComponent(number % 2 == 0 ? 0.30 : 0.60); bg.layer.cornerRadius = 12
        let circle = UIView(); circle.translatesAutoresizingMaskIntoConstraints = false
        circle.backgroundColor = ComponentColors.HomeScreen.actionButtonFill; circle.layer.cornerRadius = 12
        let numL = UILabel(); numL.translatesAutoresizingMaskIntoConstraints = false
        numL.text = "\(number)"; numL.font = .systemFont(ofSize: 11, weight: .bold); numL.textColor = .white; numL.textAlignment = .center
        circle.addSubview(numL)
        let tL = UILabel(); tL.translatesAutoresizingMaskIntoConstraints = false
        tL.text = text; tL.font = .systemFont(ofSize: 13); tL.textColor = ComponentColors.SongCard.titleText; tL.numberOfLines = 0
        bg.addSubview(circle); bg.addSubview(tL)
        NSLayoutConstraint.activate([
            circle.topAnchor.constraint(equalTo: bg.topAnchor, constant: 10), circle.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 10),
            circle.widthAnchor.constraint(equalToConstant: 24), circle.heightAnchor.constraint(equalToConstant: 24),
            numL.centerXAnchor.constraint(equalTo: circle.centerXAnchor), numL.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            tL.topAnchor.constraint(equalTo: bg.topAnchor, constant: 10), tL.leadingAnchor.constraint(equalTo: circle.trailingAnchor, constant: 10),
            tL.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -10), tL.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -10),
        ])
        return bg
    }

    // MARK: - Actions

    @objc private func didTapBack() { navigationController?.popViewController(animated: true) }

    @objc private func selectVariant(_ sender: UIButton) {
        let i = sender.tag
        guard i != selectedVariantIndex else { return }
        selectedVariantIndex = i
        
        for (idx, btn) in chipButtons.enumerated() {
            let selected = (idx == i)
            btn.backgroundColor = selected ? ComponentColors.HomeScreen.actionButtonFill : UIColor.systemGray6
            btn.layer.shadowColor = selected ? ComponentColors.HomeScreen.actionButtonFill.cgColor : UIColor.clear.cgColor
            if let stack = btn.subviews.first as? UIStackView {
                (stack.arrangedSubviews[0] as? UILabel)?.textColor = selected ? .white : .systemGray
                (stack.arrangedSubviews[1] as? UILabel)?.textColor = selected ? UIColor.white.withAlphaComponent(0.9) : .systemGray3
            }
        }
        
        staffView.removeFromSuperview()
        staffView = MusicStaffView(noteName: MusicHelper.getNoteLetter(from: lesson.variants[i]))
        staffView.translatesAutoresizingMaskIntoConstraints = false
        staffView.backgroundColor = .clear; staffView.layer.shadowOpacity = 0
        
        if let card = noteNameLabel.superview?.subviews.first(where: { $0.layer.cornerRadius == 24 }) {
            card.addSubview(staffView)
            NSLayoutConstraint.activate([
                staffView.topAnchor.constraint(equalTo: card.topAnchor),
                staffView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                staffView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                staffView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            ])
        }
        
        noteNameLabel.text = lesson.variants[i]
        updateEnglishLabel(with: lesson.variants[i])
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func updateEnglishLabel(with variant: String) {
        let eng = MusicHelper.getNoteLetter(from: variant)
        englishLabel.text = " \(eng)"
        englishLabel.font = .systemFont(ofSize: 14, weight: .bold); englishLabel.textColor = ComponentColors.HomeScreen.actionButtonFill
    }

    @objc private func didTapTryYourself() {
        let vc = TryYourselfViewController(noteName: lesson.variants[selectedVariantIndex])
        vc.onSessionCompleted = { [weak self] attempts in
            self?.recordVariantPracticed(variantIndex: self?.selectedVariantIndex ?? 0, attempts: attempts)
        }
        present(vc, animated: true)
    }

    private func recordVariantPracticed(variantIndex: Int, attempts: Int) {
        guard variantIndex < lesson.variants.count else { return }
        if !variantsDone.contains(variantIndex) {
            let pts = attempts == 1 ? 3 : attempts == 2 ? 2 : 1
            scorePoints += pts
            variantsDone.insert(variantIndex)
            chipButtons[variantIndex].markDone()
            if variantIndex < dotsStack.arrangedSubviews.count {
                dotsStack.arrangedSubviews[variantIndex].backgroundColor = ComponentColors.LessonScreen.correctAnswer
            }
            animateProgressBar()
            Task {
                await SupabaseProgressManager.recordPartCompleted(chapterIndex: chapterIndex, partIndex: variantIndex, attempts: attempts, scorePoints: scorePoints)
            }
        }
        if lessonProgress >= 1.0 && !completionShown {
            completionShown = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.showCompletionPopup() }
        }
    }

    private func animateProgressBar() {
        let pct = Int(lessonProgress * 100)
        progressPercentLabel.text = "\(pct)% complete"
        refreshProgressRowLabel()
        progressFillConstraint.constant = 130 * CGFloat(lessonProgress)
        UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.3) { self.view.layoutIfNeeded() }
    }

    private func refreshProgressRowLabel() {
        let pct = Int(lessonProgress * 100)
        let text = NSMutableAttributedString(string: "PROGRESS    ", attributes: [.font: UIFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: UIColor.systemGray])
        text.append(NSAttributedString(string: "\(pct)%", attributes: [.font: UIFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: ComponentColors.HomeScreen.actionButtonFill]))
        progressRowLabel?.attributedText = text
    }

    private func showCompletionPopup() {
        let stars = computeStars()
        sessionDurationSeconds = Int(Date().timeIntervalSince(lessonStartedAt))
        let saveTask = Task {
            await SupabaseProgressManager.recordLessonCompleted(chapterIndex: chapterIndex, stars: stars, durationSeconds: sessionDurationSeconds, scorePoints: scorePoints)
        }
        let popup = LessonCompletionPopupView(stars: stars, lessonTitle: lesson.title)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.alpha = 0; popup.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        let dim = UIView(frame: view.bounds); dim.backgroundColor = UIColor.black.withAlphaComponent(0.5); dim.alpha = 0
        view.addSubview(dim); view.addSubview(popup)
        NSLayoutConstraint.activate([
            popup.centerXAnchor.constraint(equalTo: view.centerXAnchor), popup.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            popup.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28), popup.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
        ])
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.5) { popup.alpha = 1; popup.transform = .identity; dim.alpha = 1 }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        popup.onContinue = { [weak self] in
            Task {
                await saveTask.value
                await MainActor.run {
                    UIView.animate(withDuration: 0.25, animations: { popup.alpha = 0; popup.transform = CGAffineTransform(scaleX: 0.9, y: 0.9); dim.alpha = 0 }) { _ in
                        popup.removeFromSuperview(); dim.removeFromSuperview()
                        self?.onLessonCompleted?(stars)
                    }
                }
            }
        }
    }

    private func computeStars() -> Int {
        let maxScore = lesson.variants.count * 3
        guard maxScore > 0 else { return 1 }
        let ratio = Float(scorePoints) / Float(maxScore)
        if ratio >= 0.8 { return 3 }
        if ratio >= 0.5 { return 2 }
        return 1
    }

    private func loadCompletedVariantsFromSupabase() {
        Task {
            do {
                let db = SupabaseManager.shared.client
                let userID = try await db.auth.session.user.id
                let rows: [[String: Any]] = try await db.from("lesson_events")
                    .select("part_index").eq("user_id", value: userID.uuidString).eq("chapter_index", value: chapterIndex).eq("event_type", value: "part_completed").execute().value as? [[String: Any]] ?? []
                await MainActor.run {
                    for row in rows {
                        if let idx = row["part_index"] as? Int {
                            self.variantsDone.insert(idx)
                            if idx < self.chipButtons.count {
                                self.chipButtons[idx].markDone()
                                if idx < self.dotsStack.arrangedSubviews.count {
                                    self.dotsStack.arrangedSubviews[idx].backgroundColor = ComponentColors.LessonScreen.correctAnswer
                                }
                            }
                        }
                    }
                    self.animateProgressBar()
                }
            } catch { print("Error loading progress: \(error)") }
        }
    }
}
