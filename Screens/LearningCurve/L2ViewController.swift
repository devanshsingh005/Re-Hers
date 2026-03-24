import UIKit
internal import PostgREST
import Auth
import Supabase

// MARK: - Music Staff View

class MusicStaffView: UIView {

    private let noteName: String
    private var noteLayer: CALayer?

    init(noteName: String) {
        self.noteName = noteName
        super.init(frame: .zero)
        backgroundColor = .white
        layer.cornerRadius = 24
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: 6)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        drawStaff()
        addTapToPlay()
    }

    private func drawStaff() {
        let staffTop: CGFloat = 50
        let staffLeft: CGFloat = 24
        let staffRight: CGFloat = bounds.width - 24
        let lineSpacing: CGFloat = 14
        let numLines = 5

        for i in 0..<numLines {
            let y = staffTop + CGFloat(i) * lineSpacing
            let line = CALayer()
            line.frame = CGRect(x: staffLeft, y: y, width: staffRight - staffLeft, height: 1)
            line.backgroundColor = UIColor.systemGray4.cgColor
            layer.addSublayer(line)
        }

        let clefLayer = CATextLayer()
        clefLayer.string = "𝄞"
        clefLayer.font = CTFontCreateWithName("TimesNewRomanPS-BoldMT" as CFString, 72, nil)
        clefLayer.fontSize = 72
        clefLayer.foregroundColor = UIColor.systemGray3.cgColor
        clefLayer.frame = CGRect(x: staffLeft + 2, y: staffTop - 32, width: 60, height: 85)
        clefLayer.contentsScale = UITraitCollection.current.displayScale
        layer.addSublayer(clefLayer)

        let centerY = staffTop + CGFloat(numLines - 1) / 2 * lineSpacing
        let noteOffset = noteYOffset(for: noteName)
        let noteY = centerY + noteOffset
        let noteX = bounds.width / 2 + 20

        if noteName == "C" {
            let ledger = CALayer()
            ledger.frame = CGRect(x: noteX - 18, y: noteY + 6, width: 38, height: 1.5)
            ledger.backgroundColor = UIColor.systemGray3.cgColor
            layer.addSublayer(ledger)
        }

        let stem = CALayer()
        stem.frame = CGRect(x: noteX + 8, y: noteY - 28, width: 2, height: 32)
        stem.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.cgColor
        layer.addSublayer(stem)

        let noteHead = CALayer()
        noteHead.bounds = CGRect(x: 0, y: 0, width: 22, height: 15)
        noteHead.position = CGPoint(x: noteX, y: noteY + 6)
        noteHead.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.cgColor
        noteHead.cornerRadius = 7
        noteHead.transform = CATransform3DMakeRotation(-0.25, 0, 0, 1)
        layer.addSublayer(noteHead)
        self.noteLayer = noteHead
        startPulse()
    }

    private func noteYOffset(for note: String) -> CGFloat {
        switch note {
        case "C": return 22
        case "D": return 14
        case "E": return 7
        case "F": return 0
        case "G": return -7
        case "A": return -14
        case "B": return -21
        default:  return 22
        }
    }

    private func startPulse() {
        guard let noteLayer = noteLayer else { return }
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0; pulse.toValue = 1.12
        pulse.duration = 0.65; pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        noteLayer.add(pulse, forKey: "pulse")
    }

    private func addTapToPlay() {
        let tapLabel = UILabel()
        tapLabel.text = "TAP TO PLAY"
        tapLabel.font = .systemFont(ofSize: 11, weight: .bold)
        tapLabel.textColor = ComponentColors.HomeScreen.actionButtonFill
        tapLabel.translatesAutoresizingMaskIntoConstraints = false

        let border = UIView()
        border.translatesAutoresizingMaskIntoConstraints = false
        border.layer.borderColor = ComponentColors.HomeScreen.actionButtonFill.cgColor
        border.layer.borderWidth = 1.2
        border.layer.cornerRadius = 11
        border.addSubview(tapLabel)
        addSubview(border)

        NSLayoutConstraint.activate([
            tapLabel.topAnchor.constraint(equalTo: border.topAnchor, constant: 5),
            tapLabel.bottomAnchor.constraint(equalTo: border.bottomAnchor, constant: -5),
            tapLabel.leadingAnchor.constraint(equalTo: border.leadingAnchor, constant: 12),
            tapLabel.trailingAnchor.constraint(equalTo: border.trailingAnchor, constant: -12),
            border.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            border.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    @objc private func handleTap() {
        guard let noteLayer = noteLayer else { return }
        noteLayer.removeAllAnimations()
        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [1.0, 1.3, 0.9, 1.1, 1.0]
        bounce.duration = 0.5; bounce.calculationMode = .cubic
        noteLayer.add(bounce, forKey: "bounce")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.startPulse() }
    }
}

// MARK: - Variant Chip Button

class VariantChipButton: UIButton {

    private(set) var isDone: Bool = false

    init(label: String, sublabel: String, isSelected: Bool) {
        super.init(frame: .zero)
        setupChip(label: label, sublabel: sublabel, isSelected: isSelected)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupChip(label: String, sublabel: String, isSelected: Bool) {
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
        noteLabel.textColor = isSelected ? .white : .systemGray

        let subLabel = UILabel()
        subLabel.text = sublabel
        subLabel.font = .systemFont(ofSize: 9, weight: .medium)
        subLabel.textColor = isSelected ? UIColor.white.withAlphaComponent(0.9) : .systemGray3

        stack.addArrangedSubview(noteLabel)
        stack.addArrangedSubview(subLabel)
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
                    lbl.textColor = (lbl.font.pointSize > 12 ? .systemGray : .systemGray3)
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
    private let noteMapping: [String: String] = [
        "Do": "C", "Re": "D", "Mi": "E", "Fa": "F", "Sol": "G", "La": "A", "Ti": "B",
        "Treble": "G", "Bass": "F", "Alto": "C", "Tenor": "C", "Soprano": "G", "Mezzo": "G", "Violin": "G",
        "Minor": "C", "Major": "C", "Sharp": "C#", "Dim": "C", "Aug": "C", "Flat": "Cb",
        "Diminished": "C", "Augmented": "C", "7th": "C",
        "C": "C", "D": "D", "E": "E", "F": "F", "G": "G", "A": "A", "B": "B"
    ]

    // Scrolling + Nav Setup
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let navBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let navShadowLayer = UIView()
    private let largeProfileButton = UIButton(type: .custom)
    private let largeSubtitleLabel = UILabel()
    private var inlineSubtitleLabel: UILabel?

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
        setupCustomLargeHeader()
        setupUI()
        loadCompletedVariantsFromSupabase()
        
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
                self.navShadowLayer.backgroundColor = UIColor.black.withAlphaComponent(0.15)
            }
        }
    }
    
    private func setupNavBar() {
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        let (headerStack, subTitle) = NavigationBarHelper.createInlineTitleView(title: "Lesson", subtitle: lesson.title)
        headerStack.alpha = 0
        self.inlineSubtitleLabel = subTitle
        navigationItem.titleView = headerStack

        let backBtn = NavigationBarHelper.createCustomBackButton(
            target: self, action: #selector(didTapBack)
        )
        navigationItem.leftBarButtonItem = backBtn
        
        navigationItem.rightBarButtonItems = nil
    }
    
    @objc private func didTapProfile() {
        push(UserProfileViewController())
    }
    
    private func push(_ vc: UIViewController) {
        navigationController?.pushViewController(vc, animated: true)
    }

    private func setupNavBackground() {
        navBackgroundView.alpha = 0
        navBackgroundView.isUserInteractionEnabled = false
        navBackgroundView.contentView.isUserInteractionEnabled = false
        view.addSubview(navBackgroundView)
        
        navShadowLayer.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        navShadowLayer.translatesAutoresizingMaskIntoConstraints = false
        navBackgroundView.contentView.addSubview(navShadowLayer)
        
        let window = view.window?.windowScene?.keyWindow ?? UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        let topPadding = window?.safeAreaInsets.top ?? 0
        let navHeight: CGFloat = 44 + topPadding
        
        navBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            navBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            navBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBackgroundView.heightAnchor.constraint(equalToConstant: navHeight),
            
            navShadowLayer.leadingAnchor.constraint(equalTo: navBackgroundView.leadingAnchor),
            navShadowLayer.trailingAnchor.constraint(equalTo: navBackgroundView.trailingAnchor),
            navShadowLayer.bottomAnchor.constraint(equalTo: navBackgroundView.bottomAnchor),
            navShadowLayer.heightAnchor.constraint(equalToConstant: 0.33)
        ])
        navBackgroundView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        navBackgroundView.layer.borderWidth = 0.5
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.titleView?.alpha = 0
        syncNavBarAlpha()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncNavBarAlpha()
        lessonStartedAt = Date()
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
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 90),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func setupCustomLargeHeader() {
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerContainer)
        
        let labelStack = UIStackView()
        labelStack.axis = .vertical
        labelStack.spacing = -2
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Lesson"
        titleLabel.font = .systemFont(ofSize: 34, weight: .heavy)
        titleLabel.textColor = ComponentColors.NavBar.title
        
        largeSubtitleLabel.text = lesson.title
        largeSubtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        largeSubtitleLabel.textColor = ComponentColors.NavBar.title.withAlphaComponent(0.6)
        
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(largeSubtitleLabel)
        headerContainer.addSubview(labelStack)
        
        largeProfileButton.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.12)
        largeProfileButton.layer.cornerRadius = 20
        largeProfileButton.layer.masksToBounds = true
        largeProfileButton.clipsToBounds = true
        largeProfileButton.layer.borderWidth = 1.0
        largeProfileButton.layer.borderColor = (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black).cgColor
        largeProfileButton.imageView?.contentMode = .scaleAspectFill
        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
        largeProfileButton.tintColor = .secondaryLabel
        largeProfileButton.translatesAutoresizingMaskIntoConstraints = false
        largeProfileButton.addTarget(self, action: #selector(didTapProfile), for: .touchUpInside)
        headerContainer.addSubview(largeProfileButton)
        
        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            headerContainer.heightAnchor.constraint(equalToConstant: 80),
            labelStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 20),
            labelStack.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            
            largeProfileButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -20),
            largeProfileButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            largeProfileButton.widthAnchor.constraint(equalToConstant: 40),
            largeProfileButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        NavigationBarHelper.loadProfileImage(into: largeProfileButton)
    }


    private func getNoteLetter(from variant: String) -> String {
        if let n = noteMapping[variant] { return n }
        let first = String(variant.prefix(1))
        return ["C","D","E","F","G","A","B"].contains(first) ? first : String(lesson.noteName.prefix(1))
    }

    // MARK: - UI Setup

    private func setupUI() {
        // ── Progress bar (L1 style) ──
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
        lessonNameLabel.text = "Lesson 1: \(lesson.title)"
        lessonNameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        lessonNameLabel.textColor = ComponentColors.HomeScreen.actionButtonFill

        progressPercentLabel = UILabel()
        progressPercentLabel.translatesAutoresizingMaskIntoConstraints = false
        progressPercentLabel.text = "0% complete"
        progressPercentLabel.font = .systemFont(ofSize: 13)
        progressPercentLabel.textColor = .systemGray

        // ── Variant dots row (one dot per variant, turns green when done) ──
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

        staffView = MusicStaffView(noteName: getNoteLetter(from: lesson.variants[0]))
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

        // ── Concept card (description + family overview) ──
        let conceptCard = makeInfoCard()
        let conceptHeader = makeCardHeader("About this lesson", icon: "text.book.closed")
        let descLabel = UILabel()
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.text = lesson.description
        descLabel.font = .systemFont(ofSize: 14)
        descLabel.textColor = ComponentColors.SongCard.titleText
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
            overviewLabel.textColor = ComponentColors.SongCard.metadataText
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

        // ── Progressions card ──
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

        // ── Listening guide card ──
        let listenCard = makeInfoCard()
        let listenHeader = makeCardHeader("Listening guide", icon: "ear")
        let listenLabel = UILabel()
        listenLabel.translatesAutoresizingMaskIntoConstraints = false
        listenLabel.text = lesson.listeningGuide.isEmpty ? "Listen carefully to each chord and notice the mood it creates." : lesson.listeningGuide
        listenLabel.font = .systemFont(ofSize: 14)
        listenLabel.textColor = ComponentColors.SongCard.titleText
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

        // ── Practice tasks card ──
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

        // ── Add all to contentView ──
        [progressRowLabel, progressBGView,
         lessonNameLabel, progressPercentLabel, dotsRow, staffCardView, noteNameLabel,
         engRow, variantsHeaderLabel, variantsScrollView, tryBtn,
         conceptCard, chordsCard, progsCard, listenCard, tasksCard].forEach { contentView.addSubview($0) }

        // Progress fill width — starts at 0
        progressFillConstraint = progressFill.widthAnchor.constraint(equalToConstant: 0)
        progressFillConstraint.isActive = true

        NSLayoutConstraint.activate([
            progressRowLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 96),
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

            // ── Rich content cards below Try Yourself ──
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

    // MARK: - Card builder helpers

    private func makeInfoCard() -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = ComponentColors.SongCard.background
        v.layer.cornerRadius = 18
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
        lbl.textColor = ComponentColors.HomeScreen.actionButtonFill

        row.addArrangedSubview(img)
        row.addArrangedSubview(lbl)
        return row
    }

    private func makeChordRow(detail: ChordDetail, index: Int) -> UIView {
        let bg = UIView()
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.backgroundColor = index % 2 == 0
            ? UIColor.white.withAlphaComponent(0.60)
            : UIColor.white.withAlphaComponent(0.30)
        bg.layer.cornerRadius = 12

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
        nameL.textColor = .white
        nameL.numberOfLines = 1
        namePill.addSubview(nameL)

        // Notes label
        let notesL = UILabel()
        notesL.translatesAutoresizingMaskIntoConstraints = false
        notesL.text = detail.notes.joined(separator: " – ")
        notesL.font = .systemFont(ofSize: 12, weight: .semibold)
        notesL.textColor = ComponentColors.SongCard.titleText

        // Emotion label
        let emotionL = UILabel()
        emotionL.translatesAutoresizingMaskIntoConstraints = false
        emotionL.text = detail.emotion
        emotionL.font = .systemFont(ofSize: 11)
        emotionL.textColor = ComponentColors.SongCard.metadataText
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
            ? UIColor.white.withAlphaComponent(0.60)
            : UIColor.white.withAlphaComponent(0.30)
        bg.layer.cornerRadius = 12

        let numeralL = UILabel()
        numeralL.translatesAutoresizingMaskIntoConstraints = false
        numeralL.text = prog.numerals
        numeralL.font = .systemFont(ofSize: 11, weight: .bold)
        numeralL.textColor = ComponentColors.HomeScreen.actionButtonFill

        let chordsL = UILabel()
        chordsL.translatesAutoresizingMaskIntoConstraints = false
        chordsL.text = prog.chords
        chordsL.font = .systemFont(ofSize: 13, weight: .semibold)
        chordsL.textColor = ComponentColors.SongCard.titleText

        let feelL = UILabel()
        feelL.translatesAutoresizingMaskIntoConstraints = false
        feelL.text = prog.feel
        feelL.font = .systemFont(ofSize: 11)
        feelL.textColor = ComponentColors.SongCard.metadataText
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
        bg.backgroundColor = UIColor.white.withAlphaComponent(number % 2 == 0 ? 0.30 : 0.60)
        bg.layer.cornerRadius = 12

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
        taskL.textColor = ComponentColors.SongCard.titleText
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

            // Mark chip done
            chipButtons[variantIndex].markDone()

            // Turn the corresponding dot green
            if variantIndex < dotsStack.arrangedSubviews.count {
                let dot = dotsStack.arrangedSubviews[variantIndex]
                UIView.animate(withDuration: 0.3) {
                    dot.backgroundColor = ComponentColors.LessonScreen.correctAnswer
                }
            }

            // Animate progress bar
            animateProgressBar()

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

    private func animateProgressBar() {
        let pct = Int(lessonProgress * 100)
        progressPercentLabel.text = "\(pct)% complete"
        refreshProgressRowLabel()

        // Animate fill — bar background is 130 pt wide
        progressFillConstraint.constant = 130 * CGFloat(lessonProgress)
        UIView.animate(withDuration: 0.55, delay: 0,
                       usingSpringWithDamping: 0.72, initialSpringVelocity: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    private func refreshProgressRowLabel() {
        let pct = Int(lessonProgress * 100)
        let text = NSMutableAttributedString(string: "PROGRESS    ", attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.systemGray
        ])
        text.append(NSAttributedString(string: "\(pct)%", attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: ComponentColors.HomeScreen.actionButtonFill
        ]))
        progressRowLabel?.attributedText = text
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
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

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
        if let card = staffView.superview {
            staffView.removeFromSuperview()
            staffView = MusicStaffView(noteName: getNoteLetter(from: variant))
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

        UIView.transition(with: noteNameLabel, duration: 0.25, options: .transitionCrossDissolve) {
            self.noteNameLabel.text = variant
        }
        UIView.transition(with: englishLabel, duration: 0.25, options: .transitionCrossDissolve) {
            self.updateEnglishLabel(with: variant)
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
                                ? (lbl.font.pointSize > 12 ? .white : UIColor.white.withAlphaComponent(0.9))
                                : (lbl.font.pointSize > 12 ? .systemGray : .systemGray3)
                        }
                    }
                }
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func updateEnglishLabel(with variant: String) {
        var name = lesson.noteEnglish
        if let m = noteMapping[variant] { name = m }
        else if ["C","D","E","F","G","A","B"].contains(variant) { name = variant }
        englishLabel.text = name
        englishLabel.font = .systemFont(ofSize: 14, weight: .bold)
        englishLabel.textColor = .label
    }

    @objc private func didTapTryYourself() {
        let variantIdx = selectedVariantIndex
        let variant = lesson.variants[variantIdx]

        let sheet = TryYourselfViewController(noteName: variant)
        sheet.modalPresentationStyle = .pageSheet
        if let sp = sheet.sheetPresentationController {
            sp.detents = [.medium()]
            sp.prefersGrabberVisible = true
            sp.preferredCornerRadius = 30
        }

        // When user taps "Done Practicing" in the sheet, record it
        sheet.onSessionCompleted = { [weak self] attempts in
            self?.recordVariantPracticed(variantIndex: variantIdx, attempts: attempts)
        }

        present(sheet, animated: true)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    // MARK: - Supabase Parts Synchronization
    
    private struct PartCompletedEvent: Decodable {
        let part_index: Int
    }
    
    private func loadCompletedVariantsFromSupabase() {
        Task {
            do {
                let db = SupabaseManager.shared.client
                let userID = try await db.auth.session.user.id
                
                let events: [PartCompletedEvent] = try await db
                    .from("lesson_events")
                    .select("part_index")
                    .eq("user_id", value: userID.uuidString)
                    .eq("chapter_index", value: chapterIndex)
                    .eq("event_type", value: "part_completed")
                    .execute()
                    .value
                
                await MainActor.run {
                    for event in events {
                        let idx = event.part_index
                        guard idx >= 0 && idx < self.lesson.variants.count else { continue }
                        self.variantsDone.insert(idx)
                        self.chipButtons[idx].markDone()
                        self.dotsStack.arrangedSubviews[idx].backgroundColor = .systemGreen
                    }
                    
                    self.refreshProgressRowLabel()
                    self.progressPercentLabel.text = "\(Int(self.lessonProgress * 100))% complete"
                    
                    if self.progressFillConstraint != nil {
                        self.progressFillConstraint.constant = 130 * CGFloat(self.lessonProgress)
                        UIView.animate(withDuration: 0.3) {
                            self.view.layoutIfNeeded()
                        }
                    }
                }
            } catch {
                print("[LessonDetailViewController] loadCompletedVariants error: \(error)")
            }
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

    private let noteName: String
    /// The root note letter we expect (e.g. "C", "G", "D")
    private let targetNote: String

    private var isListening = false
    private var pulseViews: [UIView] = []
    private var micButton: UIButton!
    private var statusLabel: UILabel!
    private var detectedNoteLabel: UILabel!
    private var attemptCount: Int = 0
    private var attemptCounterLabel: UILabel!
    private var doneButton: UIButton!

    // Real pitch detection
    private let pitchDetector = PitchDetector()
    /// How many consecutive correct-note callbacks to require before marking done
    private var correctStreak = 0
    private let streakRequired = 5   // ~1 second at typical callback rate
    private var alreadyMarkedCorrect = false

    /// Delivers the number of mic taps (attempts) the user made — used to compute stars
    var onSessionCompleted: ((Int) -> Void)?

    // Note name mapping — maps display names to target root notes.
    // Quality-only names (Major, Minor, etc.) map to nil → accept ANY detected note.
    private static let noteMapping: [String: String?] = [
        "Do": "C", "Re": "D", "Mi": "E", "Fa": "F", "Sol": "G", "La": "A", "Ti": "B",
        "Treble": "G", "Bass": "F", "Alto": "C", "Tenor": "C", "Soprano": "G", "Mezzo": "G", "Violin": "G",
        // Chord quality names — any note accepted ↓
        "Minor": nil, "Major": nil, "Sharp": nil, "Dim": nil, "Aug": nil, "Flat": nil,
        "Diminished": nil, "Augmented": nil, "7th": nil,
        "I–IV–V": nil, "I–V–vi–IV": nil, "ii–V–I": nil, "vi–IV–I–V": nil, "I–vi–IV–V": nil,
        // Specific root notes
        "C": "C", "D": "D", "E": "E", "F": "F", "G": "G", "A": "A", "B": "B",
        "Cm": "C", "Dm": "D", "Em": "E", "Fm": "F", "Gm": "G", "Am": "A", "Bm": "B",
        "C Family": "C", "G Family": "G", "F Family": "F", "D Family": "D", "A Family": "A",
    ]

    /// Tracks whether we need an exact octave match
    private let exactOctave: Int?   // nil = any octave
    /// If true, any detected note with sufficient amplitude is accepted (chord-quality mode)
    private let qualityOnly: Bool

    init(noteName: String) {
        self.noteName = noteName

        // ── Parse the passed-in name ────────────────────────────────
        // Could be: "F", "C5", "Major", "Do", "C Family", "Dm", etc.
        //
        // 1. Try the explicit mapping table first
        //    - nil value → quality-only mode (Major/Minor/etc.)
        //    - String value → specific root note target
        // 2. If it ends with a digit, honour that as the required octave
        // 3. Otherwise accept any octave
        // ────────────────────────────────────────────────────────────

        if let lookup = TryYourselfViewController.noteMapping[noteName] {
            if let rootNote = lookup {
                // Specific root note (C, G, Do→C, etc.)
                self.targetNote = rootNote
                self.exactOctave = nil
                self.qualityOnly = false
            } else {
                // Quality-only: Major, Minor, Dim, Aug, etc. — accept any note
                self.targetNote = ""
                self.exactOctave = nil
                self.qualityOnly = true
            }
        } else {
            // Raw string — check if it ends with a digit (e.g. "C5")
            let stripped = noteName.prefix(while: { !$0.isNumber })
            let root = String(stripped).uppercased()

            if let digitStr = noteName.last, digitStr.isNumber,
               let octave = Int(String(digitStr)) {
                self.targetNote = root
                self.exactOctave = octave
                self.qualityOnly = false
            } else {
                let letter = root.isEmpty ? String(noteName.prefix(1)).uppercased() : String(root.prefix(1))
                self.targetNote = letter
                self.exactOctave = nil
                self.qualityOnly = false
            }
        }

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
        closeButton.tintColor = .systemGray3
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)

        // Note pill showing what note to sing — auto-sizes to fit the text
        let notePill = UIView()
        notePill.translatesAutoresizingMaskIntoConstraints = false
        notePill.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.1)
        notePill.layer.cornerRadius = 25
        let noteLabel = UILabel()
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        noteLabel.text = noteName
        noteLabel.font = .systemFont(ofSize: 28, weight: .bold)
        noteLabel.textColor = ComponentColors.HomeScreen.actionButtonFill
        noteLabel.textAlignment = .center
        noteLabel.adjustsFontSizeToFitWidth = false
        notePill.addSubview(noteLabel)
        NSLayoutConstraint.activate([
            noteLabel.centerXAnchor.constraint(equalTo: notePill.centerXAnchor),
            noteLabel.centerYAnchor.constraint(equalTo: notePill.centerYAnchor),
            noteLabel.leadingAnchor.constraint(equalTo: notePill.leadingAnchor, constant: 24),
            noteLabel.trailingAnchor.constraint(equalTo: notePill.trailingAnchor, constant: -24),
        ])

        // Target hint
        let targetHintLabel = UILabel()
        targetHintLabel.translatesAutoresizingMaskIntoConstraints = false
        targetHintLabel.text = qualityOnly
            ? "Play any \(noteName) chord!"
            : "Target: \(targetNote)  (any octave)"
        targetHintLabel.font = .systemFont(ofSize: 12, weight: .medium)
        targetHintLabel.textColor = .systemGray2
        targetHintLabel.textAlignment = .center

        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Sing or play the note on your instrument"
        subLabel.font = .systemFont(ofSize: 15)
        subLabel.textColor = .systemGray; subLabel.textAlignment = .center
        subLabel.numberOfLines = 0

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
        micButton.layer.cornerRadius = 50
        micButton.layer.shadowColor = ComponentColors.HomeScreen.actionButtonFill.cgColor
        micButton.layer.shadowOpacity = 0.4; micButton.layer.shadowRadius = 20
        micButton.layer.shadowOffset = CGSize(width: 0, height: 8)
        let micCfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
        micButton.setImage(UIImage(systemName: "mic.fill", withConfiguration: micCfg), for: .normal)
        micButton.tintColor = .white
        micButton.addTarget(self, action: #selector(toggleListening), for: .touchUpInside)
        ringContainer.addSubview(micButton)
        NSLayoutConstraint.activate([
            micButton.centerXAnchor.constraint(equalTo: ringContainer.centerXAnchor),
            micButton.centerYAnchor.constraint(equalTo: ringContainer.centerYAnchor),
            micButton.widthAnchor.constraint(equalToConstant: 100),
            micButton.heightAnchor.constraint(equalToConstant: 100),
        ])

        let grad = CAGradientLayer()
        grad.colors = [ComponentColors.HomeScreen.actionButtonFill.cgColor, UIColor.orange.cgColor]
        grad.startPoint = CGPoint(x: 0, y: 0); grad.endPoint = CGPoint(x: 1, y: 1)
        grad.frame = CGRect(x: 0, y: 0, width: 100, height: 100); grad.cornerRadius = 50
        micButton.layer.insertSublayer(grad, at: 0)

        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Tap the microphone to start"
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

        [titleLabel, closeButton, notePill, targetHintLabel, subLabel,
         detectedNoteLabel, attemptCounterLabel,
         ringContainer, statusLabel, doneButton].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),

            notePill.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            notePill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            notePill.widthAnchor.constraint(equalToConstant: 110),
            notePill.heightAnchor.constraint(equalToConstant: 50),
            noteLabel.centerXAnchor.constraint(equalTo: notePill.centerXAnchor),
            noteLabel.centerYAnchor.constraint(equalTo: notePill.centerYAnchor),

            targetHintLabel.topAnchor.constraint(equalTo: notePill.bottomAnchor, constant: 4),
            targetHintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subLabel.topAnchor.constraint(equalTo: targetHintLabel.bottomAnchor, constant: 6),
            subLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            subLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            detectedNoteLabel.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 4),
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
            doneButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -28),
        ])
    }

    // MARK: - Actions

    @objc private func didTapClose() {
        pitchDetector.stopListening()
        dismiss(animated: true)
    }

    @objc private func toggleListening() {
        isListening.toggle()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if isListening {
            attemptCount += 1
            correctStreak = 0
            let starsHint = attemptCount == 1 ? "⭐⭐⭐" : attemptCount == 2 ? "⭐⭐" : "⭐"
            attemptCounterLabel.text = "Attempts: \(attemptCount)  •  \(starsHint)"
            UIView.transition(with: attemptCounterLabel, duration: 0.2, options: .transitionCrossDissolve, animations: nil)

            let waveCfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)
            micButton.setImage(UIImage(systemName: "waveform", withConfiguration: waveCfg), for: .normal)
            statusLabel.text = "Listening... 🎤 Sing the note!"
            statusLabel.textColor = ComponentColors.HomeScreen.actionButtonFill
            UIView.animate(withDuration: 0.25) {
                self.detectedNoteLabel.alpha = 1
                self.micButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }
            pitchDetector.startListening()
            startPulseAnimation()

        } else {
            stopListeningAndReset()
        }
    }

    private func stopListeningAndReset() {
        pitchDetector.stopListening()
        isListening = false
        correctStreak = 0
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

    // MARK: - Correct Match Animation

    private func flashCorrect() {
        guard !alreadyMarkedCorrect else { return }
        alreadyMarkedCorrect = true

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        stopPulseAnimation()

        // Flash mic button green
        UIView.animate(withDuration: 0.25) {
            self.micButton.backgroundColor = ComponentColors.LessonScreen.correctAnswer
            self.micButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }

        // Update icon to checkmark
        let checkCfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        micButton.setImage(UIImage(systemName: "checkmark", withConfiguration: checkCfg), for: .normal)

        statusLabel.text = "🎉 Nailed it! Tap Done ✓"
        statusLabel.textColor = ComponentColors.LessonScreen.correctAnswer

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

        // ── Parse detected note (e.g. "C4", "F#3") ──────────────────
        guard let rawNote = notes.first, rawNote != "—" else { return }

        // Root = letters up to (but not including) the octave digit
        let detectedRoot = String(rawNote.prefix(while: { !$0.isNumber && $0 != "-" }))
        // Octave = trailing digit(s)
        let detectedOctave = rawNote.last.flatMap { $0.isNumber ? Int(String($0)) : nil }

        // Display the full detected note (e.g. "F4") so the user sees exactly what is heard
        detectedNoteLabel.text = rawNote
        UIView.transition(with: detectedNoteLabel, duration: 0.12, options: .transitionCrossDissolve, animations: nil)

        // ── Smart match ──────────────────────────────────────────────
        // If qualityOnly is true, any detected note is a match (for generic chord quality lessons)
        // If exactOctave is set, require BOTH root and octave to match
        // If exactOctave is nil, only the root letter needs to match
        let rootMatch: Bool
        let octaveMatch: Bool
        
        if qualityOnly {
            rootMatch = true
            octaveMatch = true
        } else {
            rootMatch = detectedRoot.uppercased() == targetNote.uppercased()
            if let required = exactOctave {
                octaveMatch = detectedOctave == required
            } else {
                octaveMatch = true   // any octave is fine
            }
        }
        
        let isMatch = rootMatch && octaveMatch

        // ── Colour the detected-note badge ───────────────────────────
        if isMatch {
            detectedNoteLabel.textColor = ComponentColors.LessonScreen.correctAnswer
        } else if rootMatch && !octaveMatch {
            // Right note, wrong octave — amber hint
            detectedNoteLabel.textColor = .systemOrange
        } else {
            // Wrong note entirely — red
            detectedNoteLabel.textColor = .systemRed
        }

        // ── Ring animation driven by real amplitude ───────────────────
        let ringColor: UIColor = isMatch
            ? ComponentColors.LessonScreen.correctAnswer
            : (rootMatch ? .systemOrange : .systemRed)
        let scale = 1.0 + amplitude * 0.18
        UIView.animate(withDuration: 0.1) {
            for (i, ring) in self.pulseViews.enumerated() {
                let s = scale + CGFloat(i) * 0.03
                ring.transform = CGAffineTransform(scaleX: s, y: s)
                ring.layer.borderColor = ringColor.withAlphaComponent(amplitude * 0.5).cgColor
            }
        }

        // ── Streak logic & status text ───────────────────────────────
        if isMatch {
            correctStreak += 1
            let progress = min(correctStreak, streakRequired)
            let filled = String(repeating: "●", count: progress)
            let empty  = String(repeating: "○", count: streakRequired - progress)
            statusLabel.text = "✅ \(detectedRoot) — Hold it!  \(filled)\(empty)"
            statusLabel.textColor = ComponentColors.LessonScreen.correctAnswer
            if correctStreak >= streakRequired {
                flashCorrect()
            }
        } else {
            // Wrong — vibrate mic button briefly
            if correctStreak > 0 {
                let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
                shake.values = [-4, 4, -3, 3, -2, 2, 0]
                shake.duration = 0.3
                shake.timingFunction = CAMediaTimingFunction(name: .linear)
                micButton.layer.add(shake, forKey: "shake")
            }
            correctStreak = 0

            // Smart hint message
            if rootMatch, let oct = exactOctave, let det = detectedOctave {
                let dir = det < oct ? "higher 🔼" : "lower 🔽"
                statusLabel.text = "Right note, go \(dir) (need \(targetNote)\(oct))"
                statusLabel.textColor = .systemOrange
            } else {
                statusLabel.text = "Heard \(detectedRoot) — need \(targetNote)  🎵"
                statusLabel.textColor = .systemRed
            }
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
        let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let alpha = NavigationBarHelper.calculateNavBarAlpha(offset: offset)
        
        navigationItem.titleView?.alpha = alpha
        navigationItem.titleView?.isHidden = (alpha == 0)
        navBackgroundView.alpha = alpha
        
        // Fixed: only largeProfileButton scrolls away, no small one in navbar
    }
}

