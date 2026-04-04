//
//  L1ViewController.swift
//  Re-Hearse_v1
//
//  Lesson map. On viewWillAppear it fetches the user's saved progress
//  from Supabase and rebuilds the chapter list — so the UI is always
//  in sync with the database, even across app restarts or devices.
//

import UIKit
import Supabase


// MARK: - Chapter Node View

class ChapterNodeView: UIView {

    var chapter: MusicChapter
    var onTap: (() -> Void)?

    private let circleView  = UIView()
    private let iconLabel   = UILabel()
    private let titleLabel  = UILabel()
    private let starsStack  = UIStackView()
    private let badgeLabel  = UILabel()

    static let diameter: CGFloat = 72

    init(chapter: MusicChapter) {
        self.chapter = chapter
        super.init(frame: .zero)
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        let d = ChapterNodeView.diameter

        circleView.translatesAutoresizingMaskIntoConstraints = false
        circleView.layer.cornerRadius = d / 2
        circleView.layer.masksToBounds = false

        switch chapter.status {
        case .completed:
            circleView.backgroundColor     = ComponentColors.LearningCurve.nodeCompletedFill
            circleView.layer.borderColor   = ComponentColors.LearningCurve.pathCompleted.cgColor
            circleView.layer.shadowColor   = ComponentColors.HomeScreen.actionButtonFill.cgColor
            circleView.layer.shadowOpacity = 0.45
            circleView.layer.shadowRadius  = 10
            circleView.layer.shadowOffset  = CGSize(width: 0, height: 5)
            iconLabel.text      = "✓"
            iconLabel.font      = .systemFont(ofSize: 28, weight: .heavy)
            iconLabel.textColor = ComponentColors.LearningCurve.nodeIconCompleted
        case .current:
            circleView.backgroundColor   = ComponentColors.LearningCurve.nodeActiveFill
            circleView.layer.borderColor = ComponentColors.LearningCurve.pathCompleted.cgColor
            circleView.layer.borderWidth = 5
            circleView.layer.shadowColor   = ComponentColors.HomeScreen.actionButtonFill.cgColor
            circleView.layer.shadowOpacity = 0.3
            circleView.layer.shadowRadius  = 12
            circleView.layer.shadowOffset  = CGSize(width: 0, height: 5)
            iconLabel.text      = "♩"
            iconLabel.textColor = ComponentColors.LearningCurve.nodeIconActive
            iconLabel.font      = .systemFont(ofSize: 24)
        case .locked:
            circleView.backgroundColor   = ComponentColors.LearningCurve.nodeLockedFill
            circleView.layer.borderColor = ComponentColors.LearningCurve.nodeLockedBorder.cgColor
            circleView.layer.borderWidth = 2
            iconLabel.text      = "🔒"
            iconLabel.textColor = ComponentColors.LearningCurve.nodeIconLocked
            iconLabel.font      = .systemFont(ofSize: 24)
        }

        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.textAlignment = .center
        circleView.addSubview(iconLabel)

        starsStack.translatesAutoresizingMaskIntoConstraints = false
        starsStack.axis = .horizontal; starsStack.spacing = 1; starsStack.alignment = .center
        if chapter.stars > 0 {
            for _ in 0..<chapter.stars {
                let star = UILabel(); star.text = "⭐"; star.font = .systemFont(ofSize: 10)
                starsStack.addArrangedSubview(star)
            }
        }

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text          = chapter.title
        titleLabel.font          = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = chapter.status == .locked ? ComponentColors.LearningCurve.nodeIconLocked : ComponentColors.LearningCurve.headerTitle
        
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.text            = chapter.title.uppercased()
        badgeLabel.font            = .systemFont(ofSize: 11, weight: .heavy)
        badgeLabel.textColor       = ComponentColors.LearningCurve.chapterBadgeText
        badgeLabel.textAlignment   = .center
        badgeLabel.backgroundColor = ComponentColors.LearningCurve.chapterBadgeFill
        badgeLabel.layer.cornerRadius  = 11
        badgeLabel.layer.masksToBounds = true
        badgeLabel.isHidden            = (chapter.status != .current)

        addSubview(starsStack); addSubview(circleView)
        addSubview(titleLabel); addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            starsStack.bottomAnchor.constraint(equalTo: circleView.topAnchor, constant: -4),
            starsStack.centerXAnchor.constraint(equalTo: centerXAnchor),

            circleView.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            circleView.centerXAnchor.constraint(equalTo: centerXAnchor),
            circleView.widthAnchor.constraint(equalToConstant: d),
            circleView.heightAnchor.constraint(equalToConstant: d),

            iconLabel.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),

            badgeLabel.topAnchor.constraint(equalTo: circleView.bottomAnchor, constant: 6),
            badgeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            badgeLabel.heightAnchor.constraint(equalToConstant: 22),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),

            titleLabel.topAnchor.constraint(equalTo: circleView.bottomAnchor, constant: 6),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        if chapter.status == .current {
            titleLabel.isHidden = true
            badgeLabel.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap); isUserInteractionEnabled = true
    }

    @objc private func handleTap() {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0,
                           usingSpringWithDamping: 0.5, initialSpringVelocity: 5) {
                self.transform = .identity
            }
        }
        onTap?()
    }
}

// MARK: - Popup Card

class ChapterPopupCard: UIView {

    var onPrimary: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let containerView = UIView()

    init(chapter: MusicChapter) {
        super.init(frame: .zero)
        setupView(chapter: chapter)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupView(chapter: MusicChapter) {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = ComponentColors.LearningCurve.popupBackground
        containerView.layer.cornerRadius = 24
        containerView.layer.shadowColor = ComponentColors.LearningCurve.popupShadow.cgColor
        containerView.layer.shadowOpacity  = 0.14
        containerView.layer.shadowRadius   = 20
        containerView.layer.shadowOffset   = CGSize(width: 0, height: 6)
        addSubview(containerView)

        let statusView = UIView()
        statusView.translatesAutoresizingMaskIntoConstraints = false
        statusView.layer.cornerRadius   = 28
        statusView.layer.masksToBounds  = true

        let statusIcon = UILabel()
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.textAlignment = .center

        switch chapter.status {
        case .completed:
            statusView.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
            statusIcon.text = "✓"; statusIcon.font = .systemFont(ofSize: 22, weight: .heavy)
            statusIcon.textColor = .white
        case .current:
            statusView.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.12)
            statusIcon.text = "♩"; statusIcon.font = .systemFont(ofSize: 24, weight: .bold)
            statusIcon.textColor = ComponentColors.HomeScreen.actionButtonFill
        case .locked:
            statusView.backgroundColor = UIColor.systemGray5
            statusIcon.text = "🔒"; statusIcon.font = .systemFont(ofSize: 20)
        }
        statusView.addSubview(statusIcon)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text      = chapter.title
        titleLabel.font      = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text          = chapter.subtitle
        subtitleLabel.font          = .systemFont(ofSize: 13)
        subtitleLabel.textColor     = .systemGray
        subtitleLabel.numberOfLines = 2

        let dismissBtn = UIButton(type: .system)
        dismissBtn.translatesAutoresizingMaskIntoConstraints = false
        dismissBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        dismissBtn.tintColor       = .systemGray2
        dismissBtn.backgroundColor = UIColor.systemGray6
        dismissBtn.layer.cornerRadius = 15
        dismissBtn.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)

        let primaryBtn = UIButton(type: .system)
        primaryBtn.translatesAutoresizingMaskIntoConstraints = false
        primaryBtn.layer.cornerRadius   = 24
        primaryBtn.layer.masksToBounds  = true

        let status = chapter.status
        if status == .completed {
            let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            primaryBtn.setImage(UIImage(systemName: "arrow.counterclockwise", withConfiguration: cfg), for: .normal)
            primaryBtn.setTitle("  Practice Again", for: .normal)
            primaryBtn.titleLabel?.font      = .systemFont(ofSize: 16, weight: .bold)
            primaryBtn.tintColor             = ComponentColors.PrimaryButton.text
            primaryBtn.backgroundColor       = ComponentColors.LearningCurve.pathCompleted
            primaryBtn.layer.shadowColor     = ComponentColors.HomeScreen.actionButtonFill.cgColor
            primaryBtn.layer.shadowOpacity   = 0.35
            primaryBtn.layer.shadowRadius    = 8
            primaryBtn.layer.shadowOffset    = CGSize(width: 0, height: 4)
            primaryBtn.layer.masksToBounds   = false
        } else if status == .current {
            let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            primaryBtn.setImage(UIImage(systemName: "play.fill", withConfiguration: cfg), for: .normal)
            primaryBtn.setTitle("  Start Lesson", for: .normal)
            primaryBtn.titleLabel?.font      = .systemFont(ofSize: 16, weight: .bold)
            primaryBtn.tintColor             = ComponentColors.PrimaryButton.text
            primaryBtn.backgroundColor       = ComponentColors.LearningCurve.pathCompleted
            primaryBtn.layer.shadowColor     = ComponentColors.HomeScreen.actionButtonFill.cgColor
            primaryBtn.layer.shadowOpacity   = 0.35
            primaryBtn.layer.shadowRadius    = 8
            primaryBtn.layer.shadowOffset    = CGSize(width: 0, height: 4)
            primaryBtn.layer.masksToBounds   = false
        } else { // .locked
            let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            primaryBtn.setImage(UIImage(systemName: "lock.fill", withConfiguration: cfg), for: .normal)
            primaryBtn.setTitle("  Locked", for: .normal)
            primaryBtn.titleLabel?.font  = .systemFont(ofSize: 16, weight: .bold)
            primaryBtn.tintColor         = ComponentColors.LearningCurve.nodeIconLocked
            primaryBtn.backgroundColor   = ComponentColors.LearningCurve.nodeLockedFill
            primaryBtn.isEnabled         = false
        }
        primaryBtn.addTarget(self, action: #selector(didTapPrimary), for: .touchUpInside)

        containerView.addSubview(statusView); containerView.addSubview(statusIcon)
        containerView.addSubview(titleLabel); containerView.addSubview(subtitleLabel)
        containerView.addSubview(dismissBtn); containerView.addSubview(primaryBtn)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            dismissBtn.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            dismissBtn.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            dismissBtn.widthAnchor.constraint(equalToConstant: 30),
            dismissBtn.heightAnchor.constraint(equalToConstant: 30),

            statusView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            statusView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            statusView.widthAnchor.constraint(equalToConstant: 56),
            statusView.heightAnchor.constraint(equalToConstant: 56),

            statusIcon.centerXAnchor.constraint(equalTo: statusView.centerXAnchor),
            statusIcon.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: dismissBtn.leadingAnchor, constant: -8),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            subtitleLabel.leadingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: 14),
            subtitleLabel.trailingAnchor.constraint(equalTo: dismissBtn.leadingAnchor, constant: -8),

            primaryBtn.topAnchor.constraint(equalTo: statusView.bottomAnchor, constant: 16),
            primaryBtn.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            primaryBtn.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            primaryBtn.heightAnchor.constraint(equalToConstant: 48),
            primaryBtn.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -18),
        ])
    }

    @objc private func didTapPrimary() {
        UIView.animate(withDuration: 0.08, animations: {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }) { _ in
            UIView.animate(withDuration: 0.12) { self.transform = .identity }
        }
        onPrimary?()
    }
    @objc private func didTapDismiss() { onDismiss?() }
}

// MARK: - LessonMapViewController

class LessonMapViewController: UIViewController {

    private let scrollView   = UIScrollView()
    private let contentView  = UIView()
    private var popupCard:    ChapterPopupCard?
    private var popupOverlay: UIView?
    private var nodeViews:    [ChapterNodeView] = []

    // ── Single source of truth — always loaded from Supabase ─────────────
    /// Starts as all-locked; replaced on every viewWillAppear from Supabase.
    private var chapters: [MusicChapter] = allChapters.map { $0.with(status: .locked) }
    // ─────────────────────────────────────────────────────────────────────
    // Header progress refs
    private var headerProgressLabel:     UILabel?
    private var headerProgressFillWidth: NSLayoutConstraint?

    // Nav Background / Large Header state
    private let navBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let navShadowLayer = UIView()
    private let largeProfileButton = UIButton(type: .custom)
    private let largeSubtitleLabel = UILabel()

    private var progress: Float {
        let completed = chapters.filter { $0.status == .completed }.count
        return Float(completed) / Float(chapters.count)
    }
    private let nodeSize:  CGFloat = ChapterNodeView.diameter
    private let vSpacing:  CGFloat = 130

    // MARK: - Lifecycle

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
        setupHeader()
        setupPath()
        
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
                self.updateProfileButtonBorder()
            }
        }
    }

    private func setupNavBar() {
        _ = NavigationBarHelper.configureInlineNavigationBar(
            for: self,
            title: "Practice",
            subtitle: "Interactive lessons"
        )
        navigationItem.rightBarButtonItems = nil
    }
    
    @objc private func didTapProfile() {
        push(UserProfileViewController())
    }
    
    private func push(_ vc: UIViewController) {
        navigationController?.pushViewController(vc, animated: true)
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

    private func updateProfileButtonBorder() {
        largeProfileButton.layer.borderColor = (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black).cgColor
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.titleView?.alpha = 0
        syncNavBarAlpha()
        loadProgressFromSupabase()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncNavBarAlpha()
    }

    // MARK: - Supabase Progress Load

    private func loadProgressFromSupabase() {
        Task {
            if GuestSessionManager.shared.isGuest() {
                let snapshot = SupabaseProgressManager.guestProgressSnapshot()
                let starsMap = SupabaseProgressManager.guestChapterStars()

                await MainActor.run {
                    self.chapters = applyProgress(
                        currentChapter: snapshot.currentChapter,
                        chapterStars: starsMap
                    )
                    self.rebuildPath()
                }
                return
            }

            do {
                let (currentChapter, starsMap) = try await ChapterService.shared.fetchUserProgress()
                
                await MainActor.run {
                    self.chapters = applyProgress(
                        currentChapter: currentChapter,
                        chapterStars:   starsMap
                    )
                    self.rebuildPath()
                }
            } catch {
                debugLog("[LessonMapViewController] loadProgressFromSupabase error: \(error)")
                await MainActor.run {
                    self.chapters = applyProgress(currentChapter: 1)
                    self.rebuildPath()
                }
            }
        }
    }

    // MARK: - Scroll View

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints  = false
        scrollView.showsVerticalScrollIndicator               = false
        scrollView.contentInsetAdjustmentBehavior             = .never
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor), // Overlap for blur
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            // Content view starts with 90pt spacing from top
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 90),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - Header
    
    private func setupCustomLargeHeader() {
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerContainer)
        
        let labelStack = UIStackView()
        labelStack.axis = .vertical
        labelStack.spacing = -2
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Practice"
        titleLabel.font = .systemFont(ofSize: 34, weight: .heavy)
        titleLabel.textColor = ComponentColors.NavBar.title
        
        largeSubtitleLabel.text = "Interactive lessons"
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
        
        NavigationBarHelper.loadProfileImage(into: largeProfileButton)
        
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
    }

    private func setupHeader() {

        let progressLabel = UILabel()
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        headerProgressLabel = progressLabel
        refreshHeaderProgressLabel()

        let progressBG = UIView()
        progressBG.translatesAutoresizingMaskIntoConstraints = false
        progressBG.backgroundColor  = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.18)
        progressBG.layer.cornerRadius = 4

        let progressFill = UIView()
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor  = ComponentColors.HomeScreen.actionButtonFill
        progressFill.layer.cornerRadius = 4
        progressBG.addSubview(progressFill)
        contentView.addSubview(progressLabel)
        contentView.addSubview(progressBG)

        let fillWidth = progressFill.widthAnchor.constraint(equalToConstant: 130 * CGFloat(progress))
        fillWidth.isActive     = true
        headerProgressFillWidth = fillWidth

        NSLayoutConstraint.activate([
            progressLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 96),
            progressLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            progressBG.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 5),
            progressBG.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            progressBG.widthAnchor.constraint(equalToConstant: 130),
            progressBG.heightAnchor.constraint(equalToConstant: 7),

            progressFill.leadingAnchor.constraint(equalTo: progressBG.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressBG.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBG.bottomAnchor),
        ])
    }

    private func refreshHeaderProgressLabel() {
        let pText = NSMutableAttributedString(string: "PROGRESS    ", attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .black),
            .foregroundColor: ComponentColors.LearningCurve.headerSubtitle
        ])
        pText.append(NSAttributedString(string: "\(Int(progress * 100))%", attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: ComponentColors.HomeScreen.actionButtonFill
        ]))
        headerProgressLabel?.attributedText = pText
    }

    private func animateHeaderProgress(animated: Bool = true) {
        headerProgressFillWidth?.constant = 130 * CGFloat(progress)
        if animated {
            UIView.animate(withDuration: 0.55, delay: 0,
                           usingSpringWithDamping: 0.75, initialSpringVelocity: 0.3) {
                self.view.layoutIfNeeded()
            }
        } else {
            view.layoutIfNeeded()
        }
        refreshHeaderProgressLabel()
    }

    // MARK: - Path & Nodes

    private func setupPath() {
        let totalHeight  = CGFloat(chapters.count) * vSpacing + 140
        let w: CGFloat = {
            if view.bounds.width > 0 { return view.bounds.width }
            if let screen = view.window?.windowScene?.screen { return screen.bounds.width }
            return 390
        }()

        let canvas = PathCanvasView(chapters: chapters, nodeSize: nodeSize,
                                    vSpacing: vSpacing, width: w)
        canvas.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(canvas)
        NSLayoutConstraint.activate([
            canvas.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 120),
            canvas.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            canvas.heightAnchor.constraint(equalToConstant: totalHeight),
            canvas.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])

        for (i, chapter) in chapters.enumerated() {
            let node = ChapterNodeView(chapter: chapter)
            node.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(node)

            let pos            = nodePosition(index: i, width: w)
            let nodeContainerW: CGFloat = nodeSize + 40
            NSLayoutConstraint.activate([
                node.topAnchor.constraint(equalTo: contentView.topAnchor,
                                          constant: 120 + pos.y),
                node.centerXAnchor.constraint(equalTo: contentView.leadingAnchor,
                                              constant: pos.x + nodeSize / 2),
                node.widthAnchor.constraint(equalToConstant: nodeContainerW),
            ])

            let capturedChapter = chapter
            let capturedIndex   = i
            node.onTap = { [weak self] in
                self?.showPopup(for: capturedChapter, nodeIndex: capturedIndex)
            }
            nodeViews.append(node)
        }
    }

    private func nodePosition(index: Int, width: CGFloat) -> CGPoint {
        let y     = CGFloat(index) * vSpacing + 10
        let inset: CGFloat = width * 0.12
        let leftX  = inset
        let rightX = width - nodeSize - inset - 40
        let x: CGFloat
        switch index % 4 {
        case 0: x = rightX
        case 1: x = leftX
        case 2: x = rightX * 0.75 + leftX * 0.25
        case 3: x = leftX + (rightX - leftX) * 0.2
        default: x = index % 2 == 0 ? rightX : leftX
        }
        return CGPoint(x: x, y: y)
    }

    private func rebuildPath() {
        nodeViews.forEach { $0.removeFromSuperview() }
        nodeViews.removeAll()
        contentView.subviews.filter { $0 is PathCanvasView }.forEach { $0.removeFromSuperview() }
        setupPath()
        animateHeaderProgress(animated: false)
    }

    // MARK: - Popup

    private func showPopup(for chapter: MusicChapter, nodeIndex: Int) {
        dismissPopup(animated: false)

        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.08)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(dismissPopupAnimated))
        )
        view.addSubview(overlay)
        popupOverlay = overlay

        let card = ChapterPopupCard(chapter: chapter)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.alpha     = 0
        card.transform = CGAffineTransform(translationX: 0, y: 24)
        view.addSubview(card)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                         constant: -20),
        ])

        card.onDismiss = { [weak self] in self?.dismissPopupAnimated() }
        card.onPrimary = { [weak self] in
            guard let self = self else { return }
            guard chapter.status != .locked else { return }
            self.dismissPopup(animated: true)
            let vc = LessonDetailViewController(
                lesson: chapter.lesson, chapterIndex: chapter.chapterIndex)
            vc.onLessonCompleted = { [weak self] (stars: Int) in
                // After lesson completes, re-fetch from Supabase — single source of truth
                self?.loadProgressFromSupabase()
            }
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true)
        }
        popupCard = card

        UIView.animate(withDuration: 0.38, delay: 0,
                       usingSpringWithDamping: 0.72, initialSpringVelocity: 0.4) {
            card.alpha = 1; card.transform = .identity
        }
    }

    @objc private func dismissPopupAnimated() { dismissPopup(animated: true) }

    private func dismissPopup(animated: Bool) {
        guard let card = popupCard else { return }
        if animated {
            UIView.animate(withDuration: 0.22, animations: {
                card.alpha = 0
                card.transform = CGAffineTransform(translationX: 0, y: 18)
            }) { _ in card.removeFromSuperview() }
            UIView.animate(withDuration: 0.18) {
                self.popupOverlay?.alpha = 0
            } completion: { _ in
                self.popupOverlay?.removeFromSuperview()
                self.popupOverlay = nil
            }
        } else {
            card.removeFromSuperview()
            popupOverlay?.removeFromSuperview()
            popupOverlay = nil
        }
        popupCard = nil
    }

}

// MARK: - UIScrollViewDelegate

extension LessonMapViewController: UIScrollViewDelegate {
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

// MARK: - Path Canvas

class PathCanvasView: UIView {
    let chapters:    [MusicChapter]
    let nodeSize:    CGFloat
    let vSpacing:    CGFloat
    let canvasWidth: CGFloat

    private let watermarkDefs: [(CGFloat, CGFloat, Int, CGFloat)] = [
        (0.08, 0.06, 0, -15), (0.78, 0.12, 1,  10), (0.05, 0.28, 2,  -8),
        (0.72, 0.34, 0,  20), (0.10, 0.50, 1, -12), (0.75, 0.56, 2,  15),
        (0.06, 0.70, 0,  -5), (0.78, 0.76, 1,  18), (0.12, 0.88, 2, -20),
    ]

    init(chapters: [MusicChapter], nodeSize: CGFloat, vSpacing: CGFloat, width: CGFloat) {
        self.chapters = chapters; self.nodeSize = nodeSize
        self.vSpacing = vSpacing; self.canvasWidth = width
        super.init(frame: .zero); backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        drawWatermarks(ctx: ctx, rect: rect)
        ctx.setStrokeColor(ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(5); ctx.setLineDash(phase: 0, lengths: [12, 9])
        ctx.setLineCap(.round)
        for i in 0..<chapters.count - 1 {
            let from = nodeCenter(index: i); let to = nodeCenter(index: i + 1)
            let cp1  = CGPoint(x: from.x, y: from.y + vSpacing * 0.5)
            let cp2  = CGPoint(x: to.x,   y: to.y   - vSpacing * 0.5)
            ctx.move(to: from); ctx.addCurve(to: to, control1: cp1, control2: cp2)
        }
        ctx.strokePath()
    }

    private func drawWatermarks(ctx: CGContext, rect: CGRect) {
        let iconChars = ["♩", "♫", "♬"]
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32),
            .foregroundColor: ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.18)
        ]
        func drawStaffLines(at center: CGPoint, rotation: CGFloat) {
            ctx.saveGState()
            ctx.translateBy(x: center.x, y: center.y)
            ctx.rotate(by: rotation * .pi / 180)
            ctx.setStrokeColor(ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.18).cgColor)
            ctx.setLineWidth(2); ctx.setLineDash(phase: 0, lengths: [])
            let lineW: CGFloat = 28; let lineSpacing: CGFloat = 5
            let totalH = lineSpacing * 3
            for j in 0..<4 {
                let ly = -totalH / 2 + CGFloat(j) * lineSpacing
                ctx.move(to: CGPoint(x: -lineW/2, y: ly))
                ctx.addLine(to: CGPoint(x: lineW/2, y: ly))
            }
            ctx.strokePath(); ctx.restoreGState()
        }
        for def in watermarkDefs {
            let (xRatio, yRatio, iconIdx, rotation) = def
            let cx = xRatio * canvasWidth; let cy = yRatio * rect.height
            if iconIdx == 1 {
                drawStaffLines(at: CGPoint(x: cx, y: cy), rotation: rotation)
            } else {
                let char = iconChars[iconIdx % iconChars.count]
                ctx.saveGState()
                ctx.translateBy(x: cx, y: cy)
                ctx.rotate(by: rotation * .pi / 180)
                let size = (char as NSString).size(withAttributes: attrs)
                (char as NSString).draw(at: CGPoint(x: -size.width/2, y: -size.height/2),
                                        withAttributes: attrs)
                ctx.restoreGState()
            }
        }
    }

    func nodeCenter(index: Int) -> CGPoint {
        let y     = CGFloat(index) * vSpacing + 10 + nodeSize / 2
        let inset: CGFloat = canvasWidth * 0.12
        let leftX  = inset + nodeSize / 2
        let rightX = canvasWidth - nodeSize / 2 - inset - 40
        let x: CGFloat
        switch index % 4 {
        case 0: x = rightX
        case 1: x = leftX
        case 2: x = rightX * 0.75 + leftX * 0.25
        case 3: x = leftX + (rightX - leftX) * 0.2
        default: x = index % 2 == 0 ? rightX : leftX
        }
        return CGPoint(x: x, y: y)
    }
}
