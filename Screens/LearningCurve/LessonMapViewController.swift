import UIKit
@preconcurrency import Supabase
@preconcurrency import Auth
@preconcurrency import PostgREST

class LessonMapViewController: UIViewController {

    private let scrollView   = UIScrollView()
    private let contentView  = UIView()
    private var popupCard:    ChapterPopupCard?
    private var popupOverlay: UIView?
    private var nodeViews:    [ChapterNodeView] = []
    
    private let navBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let navShadowLayer = UIView()
    private let largeSubtitleLabel = UILabel()
    private var inlineSubtitleLabel: UILabel?
    private let largeProfileButton = UIButton(type: .custom)

    private var chapters: [MusicChapter] = allChapters.map { $0.with(status: .locked) }
    
    // Tracks last fetched progress to avoid redundant rebuilds
    private var lastFetchedChapterIndex: Int = -1
    private var lastFetchedStarsMap: [Int: Int] = [:]
    private var hasSuccessfullyLoadedOnce = false

    // Header progress refs
    private var headerProgressLabel:     UILabel?
    private var headerProgressFill:      UIView?
    private var headerProgressFillWidth: NSLayoutConstraint?

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
        syncNavBarAlpha()
        navigationItem.titleView?.alpha = 0
        setupScrollView()
        setupNavBackground()
        setupCustomLargeHeader()
        setupHeader()
        rebuildPath() // Ensure initial path is built before Supabase returns
        fetchProfileData()
        
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
                self.updateProfileButtonBorder()
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleProfileUpdate), name: TopNavBar.profileDidUpdateNotification, object: nil)
    }

    @objc private func handleProfileUpdate() {
        fetchProfileData()
    }

    private func setupNavBar() {
        navigationItem.title = ""
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        
        let (headerStack, subTitle) = NavigationBarHelper.createInlineTitleView(title: "Practice", subtitle: "Select a module")
        self.inlineSubtitleLabel = subTitle
        navigationItem.titleView = headerStack
        
        navigationItem.rightBarButtonItems = nil
        setupNavigationBarAppearance()
    }

    private func setupNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
    }

    private func setupNavBackground() {
        navBackgroundView.alpha = 0
        navBackgroundView.isUserInteractionEnabled = false 
        navBackgroundView.contentView.isUserInteractionEnabled = false
        view.addSubview(navBackgroundView)
        
        navShadowLayer.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        navShadowLayer.translatesAutoresizingMaskIntoConstraints = false
        navShadowLayer.isUserInteractionEnabled = false
        navBackgroundView.contentView.addSubview(navShadowLayer)
        
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        let topPadding = window?.safeAreaInsets.top ?? 0
        let navHeight: CGFloat = 44 + topPadding
        
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
        
        applyLiquidGlass(to: navBackgroundView)
    }

    private func applyLiquidGlass(to blurView: UIVisualEffectView) {
        blurView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        blurView.layer.borderWidth = 0.5
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
        largeProfileButton.clipsToBounds = true
        largeProfileButton.layer.borderWidth    = 1.0
        largeProfileButton.layer.borderColor    = (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black).cgColor
        
        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
        largeProfileButton.tintColor = .white
        largeProfileButton.imageView?.contentMode = .scaleAspectFill
        
        largeProfileButton.translatesAutoresizingMaskIntoConstraints = false
        largeProfileButton.addTarget(self, action: #selector(handleProfileTap), for: .touchUpInside)
        headerContainer.addSubview(largeProfileButton)
        
        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 90),
            headerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            headerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            headerContainer.heightAnchor.constraint(equalToConstant: 80),
            
            labelStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            labelStack.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            largeProfileButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            largeProfileButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            largeProfileButton.widthAnchor.constraint(equalToConstant: 40),
            largeProfileButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func fetchProfileData() {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else {
                await MainActor.run {
                    largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    largeProfileButton.tintColor = .secondaryLabel
                }
                return
            }
            do {
                let profile: Profile = try await SupabaseManager.shared.client
                    .from("profiles").select().eq("id", value: user.id).single().execute().value
                if let avatarUrl = profile.avatar_url, !avatarUrl.isEmpty {
                    await loadAndSetProfileImage(from: avatarUrl)
                } else {
                    await MainActor.run {
                        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                        largeProfileButton.tintColor = .secondaryLabel
                    }
                }
            } catch {
                print("Profile error: \(error)")
                await MainActor.run {
                    largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    largeProfileButton.tintColor = .secondaryLabel
                }
            }
        }
    }

    private func loadAndSetProfileImage(from urlString: String) async {
        if urlString.starts(with: "icon_") {
            await MainActor.run {
                if let img = UIImage(named: urlString) {
                    largeProfileButton.setImage(img, for: .normal)
                    largeProfileButton.tintColor = .clear
                }
            }
            return
        }
        var finalURL = urlString
        if urlString.contains("supabase.co/storage/v1/object/useprofile/") && !urlString.contains("/public/") {
            finalURL = urlString.replacingOccurrences(of: "/object/useprofile/", with: "/object/public/useprofile/")
        }
        guard let url = URL(string: finalURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 30))
            if let img = UIImage(data: data) {
                await MainActor.run {
                    self.largeProfileButton.setImage(img, for: .normal)
                    self.largeProfileButton.tintColor = .clear
                    self.largeProfileButton.imageView?.contentMode = .scaleAspectFill
                }
            } else {
                await MainActor.run {
                    self.largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    self.largeProfileButton.tintColor = .secondaryLabel
                }
            }
        } catch {
            await MainActor.run {
                self.largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                self.largeProfileButton.tintColor = .secondaryLabel
            }
        }
    }

    func syncNavBarAlpha() {
        let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let alpha = NavigationBarHelper.calculateNavBarAlpha(offset: offset)
        
        navigationItem.titleView?.alpha = alpha
        navigationItem.titleView?.isHidden = (alpha == 0)
        navBackgroundView.alpha = alpha
    }

    @objc private func handleProfileTap() {
        navigationController?.pushViewController(UserProfileViewController(), animated: true)
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationItem.titleView?.alpha = 0
    }

    private func loadProgressFromSupabase() {
        Task {
            do {
                let db = SupabaseManager.shared.client
                let userID = try await db.auth.session.user.id
                let profileData: [[String: Any]] = try await db
                    .from("profiles")
                    .select("current_chapter")
                    .eq("id", value: userID.uuidString)
                    .limit(1)
                    .execute()
                    .value as? [[String: Any]] ?? []

                guard let firstProfile = profileData.first, let currentChapter = firstProfile["current_chapter"] as? Int else { return }

                let eventsData: [[String: Any]] = try await db
                    .from("lesson_events")
                    .select("chapter_index, stars")
                    .eq("user_id", value: userID.uuidString)
                    .eq("event_type", value: "lesson_completed")
                    .execute()
                    .value as? [[String: Any]] ?? []

                var starsMap: [Int: Int] = [:]
                for row in eventsData {
                    if let cIdx = row["chapter_index"] as? Int, let stars = row["stars"] as? Int {
                        let prev = starsMap[cIdx] ?? 0
                        starsMap[cIdx] = max(prev, stars)
                    }
                }

                await MainActor.run {
                    self.applyFetchedProgress(currentMapChapter: currentChapter, starsMap: starsMap)
                }
            } catch {
                print("[LessonMapViewController] Supabase fetch error: \(error)")
            }
        }
    }

    private func applyFetchedProgress(currentMapChapter: Int, starsMap: [Int: Int]) {
        if hasSuccessfullyLoadedOnce &&
            currentMapChapter == lastFetchedChapterIndex &&
            starsMap == lastFetchedStarsMap {
            return
        }

        self.lastFetchedChapterIndex = currentMapChapter
        self.lastFetchedStarsMap      = starsMap
        self.hasSuccessfullyLoadedOnce = true
        self.chapters = applyProgress(currentChapter: currentMapChapter, chapterStars: starsMap)
        rebuildPath()
    }

    private func updateProfileButtonBorder() {
        largeProfileButton.layer.borderColor = (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black).cgColor
    }

    private func setupHeader() {
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerView)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text          = NSLocalizedString("your_progress_header", comment: "")
        label.font          = .systemFont(ofSize: 13, weight: .bold)
        label.textColor     = .systemGray
        headerView.addSubview(label)

        headerProgressLabel = UILabel()
        headerProgressLabel?.translatesAutoresizingMaskIntoConstraints = false
        headerProgressLabel?.text          = "0%"
        headerProgressLabel?.font          = .systemFont(ofSize: 13, weight: .heavy)
        headerProgressLabel?.textColor     = .label
        headerView.addSubview(headerProgressLabel!)

        let track = UIView()
        track.translatesAutoresizingMaskIntoConstraints = false
        track.backgroundColor = UIColor.systemGray5
        track.layer.cornerRadius = 4
        headerView.addSubview(track)

        headerProgressFill = UIView()
        headerProgressFill?.translatesAutoresizingMaskIntoConstraints = false
        headerProgressFill?.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        headerProgressFill?.layer.cornerRadius = 4
        track.addSubview(headerProgressFill!)

        headerProgressFillWidth = headerProgressFill?.widthAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 170),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            headerView.heightAnchor.constraint(equalToConstant: 60),

            label.topAnchor.constraint(equalTo: headerView.topAnchor),
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),

            headerProgressLabel!.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            headerProgressLabel!.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),

            track.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            track.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            track.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            track.heightAnchor.constraint(equalToConstant: 8),

            headerProgressFill!.topAnchor.constraint(equalTo: track.topAnchor),
            headerProgressFill!.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            headerProgressFill!.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            headerProgressFillWidth!
        ])
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func animateHeaderProgress() {
        let p = progress
        headerProgressLabel?.text = "\(Int(p * 100))%"
        let availableWidth = view.bounds.width - 48
        headerProgressFillWidth?.constant = availableWidth * CGFloat(p)
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.view.layoutIfNeeded()
        }
    }

    private func setupPath() {
        let totalHeight  = CGFloat(chapters.count) * vSpacing + 170
        let pathTopOffset: CGFloat = 150
        let w: CGFloat = view.bounds.width > 0 ? view.bounds.width : 390

        let canvas = PathCanvasView(chapters: chapters, nodeSize: nodeSize,
                                    vSpacing: vSpacing, width: w)
        canvas.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(canvas)
        NSLayoutConstraint.activate([
            canvas.topAnchor.constraint(equalTo: contentView.topAnchor, constant: pathTopOffset),
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
                                          constant: pathTopOffset + pos.y),
                node.centerXAnchor.constraint(equalTo: contentView.leadingAnchor,
                                              constant: pos.x + nodeSize / 2),
                node.widthAnchor.constraint(equalToConstant: nodeContainerW),
            ])

            node.onTap = { [weak self] in
                self?.showPopup(for: chapter, nodeIndex: i)
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
        animateHeaderProgress()
    }

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
            navigationController?.pushViewController(vc, animated: true)
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
            }) { _ in
                card.removeFromSuperview()
                self.popupOverlay?.removeFromSuperview()
            }
        } else {
            card.removeFromSuperview()
            self.popupOverlay?.removeFromSuperview()
        }
        popupCard = nil
        popupOverlay = nil
    }
}

extension LessonMapViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        syncNavBarAlpha()
    }
}
