//
//  HomeViewController.swift
//  Re-Hearse_v1
//
//  Home: scan or upload a sheet, your playlists and your recent uploads (Home and Upload used
//  to be separate tabs). The upload pipeline — scanner, pickers, quiz popup and on-device
//  conversion — lives here too.
//

import UIKit
import AVFoundation
import PhotosUI
import VisionKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Supabase
import Auth
internal import PostgREST

class HomeViewController: UIViewController {

    // MARK: - Constants
    private enum Constants {
        static let horizontalPadding: CGFloat = 20
        static let sectionSpacing:    CGFloat = 32
        static let recentUploadsShown = 3
        static let playlistTileSize:  CGFloat = DeviceLayout.isPad ? 200 : 140
        static let pdfPageSize = CGSize(width: 612, height: 792)
        static let maxUploadSizeBytes = 10 * 1024 * 1024
    }

    // MARK: - State
    private let defaultUploadTitleBase = "Untitled Sheet"

    /// Unique filename per upload, e.g. "SheetMusic_2026-03-08_064025.pdf".
    /// Stored internally for the file payload so uploads always remain unique.
    private func generateTimestampFilename() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return "SheetMusic_\(f.string(from: Date())).pdf"
    }

    /// The picked file's name, used as the upload's title (scans and photos have none).
    private var pickedTitleBase: String?

    private func generateUniqueUploadTitle() -> String {
        LocalSheetLibrary.shared.uniqueTitle(base: pickedTitleBase ?? defaultUploadTitleBase)
    }
    private var currentFileName  = ""
    private var currentFileType  = ""
    private var activeQuizPopup: UploadQuizPopup?
    private weak var activeDocumentPicker: UIDocumentPickerViewController?
    private weak var activeDocumentScanner: VNDocumentCameraViewController?
    private weak var activePhotoPicker: PHPickerViewController?
    private var profileFetchTask: Task<Void, Never>?
    private var playlistFetchTask: Task<Void, Never>?
    private var renameTask: Task<Void, Never>?
    private var uploadTask: Task<Void, Never>?
    private var currentUploadSource = "unknown"
    private var latestRecentUploads: [LocalSheetLibrary.Upload] = []

    // MARK: - UI
    private let scrollView   = UIScrollView()
    private let contentStack = UIStackView()
    /// "Home" and the greeting with the bell beside them, the same header as the other tabs.
    private let header = TabRootHeaderView(title: "Home", subtitle: "Welcome back",
                                           accessory: NotificationBellButton(),
                                           inset: DeviceLayout.isPad ? 40 : 20)
    private let navBackgroundView = UIVisualEffectView(effect: nil)
    private let navShadowLayer = UIView()
    private var inlineSubtitleLabel: UILabel?
    private let playlistTilesStack = UIStackView()
    private let recentUploadsStack = UIStackView()

    // Wide layout (iPad): two columns. Left: the scan card, Scan to Play, Upload and the
    // last-played sheet; right: playlists above recent uploads. Narrow (iPhone): one column.
    private let heroColumn = UIStackView()
    private lazy var heroWrapper = padded(heroColumn)
    private var playlistSection = UIView()
    private var recentSection = UIView()
    private let rightColumn = UIStackView()
    private let mainRow = UIStackView()
    private let homeMiniPlayer = MiniPlayerView()
    private lazy var homeMiniPlayerCard = makeHomeMiniPlayerCard()
    private var wideConstraints: [NSLayoutConstraint] = []

    /// The theme's card surface, as on the other screens.
    static let cardColor = ComponentColors.HomeScreen.cardBackground

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.HomeScreen.background
        setupNavigationBar()
        setupScrollView()
        setupNavBackground()
        buildScanSection()
        buildPlaylistSection()
        buildRecentUploadsSection()
        applyWidthLayout()
        registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (self: Self, _) in
            self.applyWidthLayout()
        }
        loadRecentUploads()
        loadPlaylists()
        loadGreeting()

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleProfileUpdate),
                           name: NavigationBarHelper.profileDidUpdateNotification, object: nil)
        center.addObserver(self, selector: #selector(handleLibraryChange),
                           name: LocalSheetLibrary.didChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(handleAuthStatusChanged),
                           name: SupabaseManager.authStatusChangedNotification, object: nil)

        // Sheets are converted on this device: finish any conversion the app was closed during,
        // and load the recognition models now so the first upload doesn't wait for them.
        LocalSheetLibrary.shared.resumeInterruptedConversions()
        UploadCloudSync.shared.start()
        Task.detached(priority: .utility) { await OnDeviceSheetConverter.shared.prepare() }
    }

    @objc private func handleLibraryChange(_ note: Notification) {
        // progress ticks don't change the list; status, title and membership do
        guard let id = note.userInfo?["id"] as? UUID else {
            loadRecentUploads()
            return
        }
        let current = LocalSheetLibrary.shared.upload(id: id)
        let shown = latestRecentUploads.first { $0.id == id }
        if current?.status != shown?.status || current?.title != shown?.title || (current == nil) != (shown == nil) {
            loadRecentUploads()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        cancelPendingTasks()
        clearUploadState()
        releaseTransientPickers()
    }

    @objc private func handleProfileUpdate() {
        loadGreeting()
    }

    @objc private func handleAuthStatusChanged() {
        loadGreeting()
        loadPlaylists()
        loadRecentUploads()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncNavBarAlpha()
        loadRecentUploads()
        loadPlaylists()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncNavBarAlpha()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // Content runs under the bars; leave room to scroll past the tab bar and mini player.
        scrollView.contentInset.bottom = view.safeAreaInsets.bottom + 16
        scrollView.verticalScrollIndicatorInsets.bottom = view.safeAreaInsets.bottom
    }

    func startUploadFlow() {
        guard !presentSheetUploadGuestGateIfNeeded() else { return }
        presentVisionKitScanner()
    }

    /// Stops a new upload before anything is picked when the account already has 10.
    private func presentUploadLimitIfNeeded() -> Bool {
        guard LocalSheetLibrary.shared.isAtUploadLimit else { return false }
        presentAlert(title: "Upload Limit Reached",
                     message: LocalSheetLibrary.LibraryError.limitReached.errorDescription ?? "")
        return true
    }

    @discardableResult
    private func presentSheetUploadGuestGateIfNeeded() -> Bool {
        guard GuestFeatureAccessPolicy.shouldGateSheetUploadActions(
            forGuest: GuestSessionManager.shared.isGuest()
        ) else { return presentUploadLimitIfNeeded() }
        guard let presenter = guestGatePresenter(), presenter.presentedViewController == nil else { return true }

        let gateModal = GuestFeatureGateModal(
            featureName: "sheet music upload",
            onSignUp: { [weak self] in
                self?.scheduleAuthPresentation(mode: .signUp)
            },
            onLogIn: { [weak self] in
                self?.scheduleAuthPresentation(mode: .logIn)
            }
        )

        gateModal.presentationController?.delegate = self
        presenter.present(gateModal, animated: true)
        return true
    }

    private func scheduleAuthPresentation(mode: AuthViewController.AuthMode) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let presenter = self.guestGatePresenter(), presenter.presentedViewController == nil else { return }

            let authViewController = AuthViewController(initialMode: mode)
            let authNavigationController = UINavigationController(rootViewController: authViewController)
            authNavigationController.modalPresentationStyle = .fullScreen
            presenter.present(authNavigationController, animated: true)
        }
    }

    private func guestGatePresenter() -> UIViewController? {
        if let navigationController = mainTabBarController?.selectedNav
            ?? tabBarController?.selectedViewController as? UINavigationController {
            return navigationController.visibleViewController ?? navigationController.topViewController ?? navigationController
        }

        return tabBarController?.selectedViewController ?? tabBarController
    }

    // MARK: - Navigation bar

    private func setupNavigationBar() {
        inlineSubtitleLabel = NavigationBarHelper.configureInlineNavigationBar(
            for: self, title: "Home", subtitle: "Welcome back"
        )
        navigationItem.titleView?.alpha = 0
        navigationItem.rightBarButtonItems = nil
    }

    private func setupNavBackground() {
        NavigationBarHelper.updateNavigationBackgroundAppearance(
            navBackgroundView, shadowView: navShadowLayer, traitCollection: traitCollection
        )
        NavigationBarHelper.installNavigationBackground(navBackgroundView, shadowView: navShadowLayer, in: view)
    }

    /// Fades the small title and bar background in once the header has scrolled away.
    private func syncNavBarAlpha() {
        NavigationBarHelper.syncNavigationBarAlpha(
            scrollView: scrollView, navigationItem: navigationItem, navBackgroundView: navBackgroundView
        )
    }

    /// "Welcome back, Alex" under the title.
    private func loadGreeting() {
        profileFetchTask?.cancel()
        if GuestSessionManager.shared.isGuest() {
            setGreeting(name: GuestSessionManager.shared.guestDisplayName())
            return
        }
        guard let user = SupabaseManager.shared.client.auth.currentUser else {
            setGreeting(name: nil)
            return
        }
        profileFetchTask = Task { [weak self] in
            let profile: UserProfile? = try? await SupabaseManager.shared.client
                .from("profiles").select("id, full_name, username").eq("id", value: user.id).single().execute().value
            guard let self, !Task.isCancelled else { return }
            let fullName = profile?.full_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let firstName = fullName.split(separator: " ").first.map(String.init)
            self.setGreeting(name: firstName ?? profile?.username)
        }
    }

    /// True the first time this account (or guest) sees Home, so it says "Welcome", not "Welcome back".
    private lazy var isFirstHomeVisit: Bool = {
        let owner = SupabaseManager.shared.client.auth.currentUser?.id.uuidString.lowercased() ?? "guest"
        let key = "home.visited.\(owner)"
        // Anyone with uploads or a last-played sheet has been here before this marker existed.
        let returning = UserDefaults.standard.bool(forKey: key)
            || !LocalSheetLibrary.shared.uploads().isEmpty
            || LastPlayedStore.shared.current != nil
        UserDefaults.standard.set(true, forKey: key)
        return !returning
    }()

    private func setGreeting(name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let opening = isFirstHomeVisit ? "Welcome" : "Welcome back"
        let text = trimmed.isEmpty ? opening : "\(opening), \(trimmed)"
        header.subtitleLabel.text = text
        inlineSubtitleLabel?.text = text
    }

    // MARK: - Scroll + Content Stack

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        view.addSubview(scrollView)
        // The navigation bar collapses its large title, and on iOS 26 the tab bar minimizes,
        // as this scrolls.
        setContentScrollView(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = Constants.sectionSpacing
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor,
                                              constant: TabRootHeaderView.topOffset),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
        ])

        contentStack.addArrangedSubview(header)
        contentStack.setCustomSpacing(12, after: header)
    }

    /// Wraps a view in the screen's side margins.
    private func padded(_ content: UIView) -> UIView {
        let wrapper = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: wrapper.topAnchor),
            content.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: Constants.horizontalPadding),
            content.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -Constants.horizontalPadding),
        ])
        return wrapper
    }

    private func sectionHeader(_ title: String, seeMore: @escaping () -> Void) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = UIFont.preferredFont(forTextStyle: .title3).withWeight(.bold)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.accessibilityTraits = .header

        var config = UIButton.Configuration.plain()
        config.title = "See more"
        config.image = UIImage(systemName: "chevron.forward")
        config.imagePlacement = .trailing
        config.imagePadding = 4
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .caption1, scale: .small)
            .applying(UIImage.SymbolConfiguration(weight: .semibold))
        config.baseForegroundColor = BrandColors.brand
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 0)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = UIFont.preferredFont(forTextStyle: .subheadline)
            return attrs
        }
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in seeMore() })
        button.accessibilityLabel = "See more \(title)"
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [label, button])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        return padded(row)
    }

    // MARK: - Scan section

    private func buildScanSection() {
        let card = ScanCardView()
        card.addAction(UIAction { [weak self] _ in self?.scanTapped() }, for: .touchUpInside)

        var scanConfig: UIButton.Configuration
        if #available(iOS 26.0, *) {
            scanConfig = .prominentGlass()
        } else {
            scanConfig = .filled()
            scanConfig.cornerStyle = .capsule
            scanConfig.baseBackgroundColor = BrandColors.brand
        }
        scanConfig.title = "Scan to Play"
        scanConfig.image = UIImage(systemName: "camera")
        scanConfig.imagePadding = 8
        scanConfig.baseForegroundColor = .black
        scanConfig.buttonSize = .large
        scanConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = UIFont.preferredFont(forTextStyle: .headline)
            return attrs
        }
        let scanButton = UIButton(configuration: scanConfig, primaryAction: UIAction { [weak self] _ in
            self?.scanTapped()
        })
        scanButton.tintColor = BrandColors.brand
        scanButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true

        var uploadConfig = UIButton.Configuration.plain()
        uploadConfig.title = "Upload Music Sheet"
        uploadConfig.image = UIImage(systemName: "icloud.and.arrow.up")
        uploadConfig.imagePadding = 8
        uploadConfig.baseForegroundColor = BrandColors.brand
        uploadConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.semibold)
            return attrs
        }
        let uploadButton = UIButton(configuration: uploadConfig)
        uploadButton.showsMenuAsPrimaryAction = true
        uploadButton.menu = UIMenu(children: [
            UIAction(title: "Choose from Files", image: UIImage(systemName: "folder")) { [weak self] _ in
                self?.uploadFileTapped()
            },
            UIAction(title: "Choose from Photos", image: UIImage(systemName: "photo.on.rectangle")) { [weak self] _ in
                self?.uploadPhotoTapped()
            },
        ])

        heroColumn.axis = .vertical
        heroColumn.spacing = 16
        heroColumn.addArrangedSubview(card)
        heroColumn.addArrangedSubview(scanButton)
        heroColumn.addArrangedSubview(uploadButton)
        heroColumn.setCustomSpacing(8, after: scanButton)

        rightColumn.axis = .vertical
        rightColumn.spacing = Constants.sectionSpacing
        mainRow.axis = .horizontal
        mainRow.alignment = .top
        // 20 pt more at the screen's edges: 40 pt there and between the columns, as in the design
        mainRow.isLayoutMarginsRelativeArrangement = true
        mainRow.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)

        // wide: a tall card (about 45% of the screen) and a left column a little under half
        let cardHeight = card.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.45)
        cardHeight.priority = .required - 1
        wideConstraints = [
            cardHeight,
            heroWrapper.widthAnchor.constraint(equalTo: mainRow.widthAnchor, multiplier: 0.47),
        ]
    }

    /// Two columns on a wide screen, one on a narrow one (iPhone, or a narrow iPad window).
    private func applyWidthLayout() {
        let wide = traitCollection.horizontalSizeClass == .regular
        [heroWrapper, playlistSection, recentSection, mainRow, rightColumn, homeMiniPlayerCard].forEach {
            $0.removeFromSuperview()
        }
        NSLayoutConstraint.deactivate(wideConstraints)
        if wide {
            heroColumn.addArrangedSubview(homeMiniPlayerCard)
            heroColumn.setCustomSpacing(24, after: heroColumn.arrangedSubviews[heroColumn.arrangedSubviews.count - 2])
            rightColumn.addArrangedSubview(playlistSection)
            rightColumn.addArrangedSubview(recentSection)
            mainRow.addArrangedSubview(heroWrapper)
            mainRow.addArrangedSubview(rightColumn)
            contentStack.addArrangedSubview(mainRow)
            NSLayoutConstraint.activate(wideConstraints)
        } else {
            contentStack.addArrangedSubview(heroWrapper)
            contentStack.addArrangedSubview(playlistSection)
            contentStack.addArrangedSubview(recentSection)
        }
        refreshHomeMiniPlayer()
    }

    // MARK: - Last played (wide layout)

    /// The last-played sheet as a card under the scan buttons; on iPad Home it takes the place
    /// of the tab bar's mini player.
    private func makeHomeMiniPlayerCard() -> UIView {
        let card = UIView()
        card.backgroundColor = Self.cardColor
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        homeMiniPlayer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(homeMiniPlayer)
        NSLayoutConstraint.activate([
            homeMiniPlayer.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            homeMiniPlayer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4),
            homeMiniPlayer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            homeMiniPlayer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            card.heightAnchor.constraint(equalToConstant: 68),
        ])
        homeMiniPlayer.onOpen = { [weak self] in self?.mainTabBarController?.openLastPlayed(resume: false) }
        homeMiniPlayer.onResume = { [weak self] in self?.mainTabBarController?.openLastPlayed(resume: true) }
        NotificationCenter.default.addObserver(self, selector: #selector(refreshHomeMiniPlayer),
                                               name: LastPlayedStore.didChangeNotification, object: nil)
        return card
    }

    @objc private func refreshHomeMiniPlayer() {
        let item = LastPlayedStore.shared.current
        if let item { homeMiniPlayer.configure(with: item) }
        homeMiniPlayerCard.isHidden = item == nil
    }

    @objc private func scanTapped() {
        guard !presentSheetUploadGuestGateIfNeeded() else { return }
        presentVisionKitScanner()
    }

    @objc private func uploadFileTapped() {
        guard !presentSheetUploadGuestGateIfNeeded() else { return }
        openFileManager()
    }

    private func uploadPhotoTapped() {
        guard !presentSheetUploadGuestGateIfNeeded() else { return }
        presentPhotoLibraryPicker()
    }

    // MARK: - Playlist section

    private func buildPlaylistSection() {
        let header = sectionHeader("Your Playlist") { [weak self] in
            PlaylistsManager.shared.prewarmPlaylistCacheIfNeeded()
            self?.navigationController?.pushViewController(PlaylistViewController(), animated: true)
        }

        let tiles = UIScrollView()
        tiles.showsHorizontalScrollIndicator = false
        tiles.alwaysBounceHorizontal = true
        tiles.contentInset = UIEdgeInsets(top: 0, left: Constants.horizontalPadding, bottom: 0,
                                          right: Constants.horizontalPadding)
        tiles.translatesAutoresizingMaskIntoConstraints = false
        playlistTilesStack.axis = .horizontal
        playlistTilesStack.spacing = 12
        playlistTilesStack.alignment = .top
        playlistTilesStack.translatesAutoresizingMaskIntoConstraints = false
        tiles.addSubview(playlistTilesStack)
        NSLayoutConstraint.activate([
            playlistTilesStack.topAnchor.constraint(equalTo: tiles.contentLayoutGuide.topAnchor),
            playlistTilesStack.bottomAnchor.constraint(equalTo: tiles.contentLayoutGuide.bottomAnchor),
            playlistTilesStack.leadingAnchor.constraint(equalTo: tiles.contentLayoutGuide.leadingAnchor),
            playlistTilesStack.trailingAnchor.constraint(equalTo: tiles.contentLayoutGuide.trailingAnchor),
            playlistTilesStack.heightAnchor.constraint(equalTo: tiles.frameLayoutGuide.heightAnchor),
        ])

        let section = UIStackView(arrangedSubviews: [header, tiles])
        section.axis = .vertical
        section.spacing = 10
        playlistSection = section
        showPlaylistPlaceholders()

        // Tiles plus their caption; resized for the caption's Dynamic Type size.
        let captionHeight = UIFont.preferredFont(forTextStyle: .footnote).lineHeight + 8
        tiles.heightAnchor.constraint(equalToConstant: Constants.playlistTileSize + captionHeight).isActive = true
    }

    /// Shimmering tiles until the first fetch answers, so a signed-in user's row doesn't flash
    /// "New Playlist" first. Guests have no playlists to wait for.
    private func showPlaylistPlaceholders() {
        guard !GuestSessionManager.shared.isGuest() else {
            showPlaylists([])
            return
        }
        playlistTilesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for _ in 0..<3 {
            let tile = SkeletonBox(height: Constants.playlistTileSize, cornerRadius: 14)
            tile.widthAnchor.constraint(equalToConstant: Constants.playlistTileSize).isActive = true
            tile.isAccessibilityElement = false
            playlistTilesStack.addArrangedSubview(tile)
            DispatchQueue.main.async { tile.startShimmering() }
        }
    }

    private func loadPlaylists() {
        playlistFetchTask?.cancel()
        playlistFetchTask = Task { [weak self] in
            let playlists = try? await PlaylistService.shared.fetchPlaylists()
            guard let self, !Task.isCancelled else { return }
            self.showPlaylists(playlists ?? [])
        }
    }

    private func showPlaylists(_ playlists: [Playlist]) {
        playlistTilesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if playlists.isEmpty {
            playlistTilesStack.addArrangedSubview(makeNewPlaylistTile())
            return
        }
        for playlist in playlists {
            playlistTilesStack.addArrangedSubview(makePlaylistTile(playlist))
        }
    }

    private func makePlaylistTile(_ playlist: Playlist) -> UIView {
        let tile = PlaylistTileView(title: playlist.name, playlistId: playlist.id,
                                    coverUrl: playlist.coverImageURL, size: Constants.playlistTileSize)
        tile.addAction(UIAction { [weak self] _ in
            let vc = PlaylistDetailViewController()
            vc.passedTitle    = playlist.name
            vc.passedArtist   = playlist.description ?? "Custom Playlist"
            vc.playlistId     = playlist.id
            vc.passedCoverUrl = playlist.coverImageURL
            self?.navigationController?.pushViewController(vc, animated: true)
        }, for: .touchUpInside)
        return tile
    }

    private func makeNewPlaylistTile() -> UIView {
        let tile = PlaylistTileView(title: "New Playlist", colors: [.tertiarySystemFill, .tertiarySystemFill],
                                    symbolName: "plus", size: Constants.playlistTileSize)
        tile.addAction(UIAction { [weak self] _ in
            PlaylistsManager.shared.prewarmPlaylistCacheIfNeeded()
            self?.navigationController?.pushViewController(PlaylistViewController(), animated: true)
        }, for: .touchUpInside)
        return tile
    }

    // MARK: - Recent Uploads Section

    private func buildRecentUploadsSection() {
        let header = sectionHeader("Recent Uploads") { [weak self] in self?.seeMoreTapped() }
        recentUploadsStack.axis = .vertical
        recentUploadsStack.spacing = 10
        let section = UIStackView(arrangedSubviews: [header, padded(recentUploadsStack)])
        section.axis = .vertical
        section.spacing = 10
        recentSection = section
    }

    // MARK: - Load & Display Recent Uploads
    private func loadRecentUploads() {
        let uploads = Array(LocalSheetLibrary.shared.uploads().prefix(Constants.recentUploadsShown))
        latestRecentUploads = uploads
        displayRecentUploads(uploads)
    }

    private func displayRecentUploads(_ uploads: [LocalSheetLibrary.Upload]) {
        recentUploadsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if uploads.isEmpty {
            recentUploadsStack.addArrangedSubview(makeEmptyUploadsView())
            return
        }
        for upload in uploads {
            recentUploadsStack.addArrangedSubview(makeUploadRow(upload))
        }
    }

    /// "Mar 31, 2026 · 44 KB", or the conversion state while it isn't finished.
    private func uploadMeta(_ upload: LocalSheetLibrary.Upload) -> String {
        switch upload.status {
        case .processing: return "Converting on device…"
        case .failed:     return "Conversion failed"
        case .completed:
            var parts = [relativeDate(upload.uploadedAt), formatBytes(upload.fileSizeBytes)]
            if upload.cloud == .notBackedUp { parts.append("Not backed up") }
            return parts.joined(separator: " · ")
        }
    }

    private func makeEmptyUploadsView() -> UIView {
        let container = UIView()
        container.backgroundColor = Self.cardColor
        container.layer.cornerRadius = 14
        container.layer.cornerCurve = .continuous

        let title = UILabel()
        title.text = "No uploads yet"
        title.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.semibold)
        title.adjustsFontForContentSizeCategory = true
        title.textColor = .label
        let body = UILabel()
        body.text = "Scan or upload a page of sheet music and it shows up here."
        body.font = .preferredFont(forTextStyle: .footnote)
        body.adjustsFontForContentSizeCategory = true
        body.textColor = .secondaryLabel
        body.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [title, body])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center
        body.textAlignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        ])
        return container
    }

    private func makeUploadRow(_ upload: LocalSheetLibrary.Upload) -> UIView {
        let row = UploadRowView()
        row.configure(title: upload.title, meta: uploadMeta(upload), failed: upload.status == .failed)
        row.moreButton.menu = UIMenu(children: [
            UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { [weak self, weak row] _ in
                self?.showRenameAlert(for: upload.scanId, currentTitle: row?.titleLabel.text ?? upload.title,
                                      titleLabel: row?.titleLabel)
            },
            UIAction(title: "Delete Upload", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self, weak row] _ in
                self?.confirmDeleteScan(id: upload.scanId, title: row?.titleLabel.text ?? upload.title)
            },
        ])

        // ── Tap: open the result screen; while the sheet is still converting it shows the
        //   progress and fills in by itself. A failed conversion can be retried. ──
        row.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            guard let current = LocalSheetLibrary.shared.upload(id: upload.id) else {
                self.loadRecentUploads()
                return
            }
            if current.status == .failed {
                self.presentFailedUploadAlert(current)
                return
            }
            let vc   = UploadPageNextViewController()
            vc.jobId = current.id
            debugLog("[RowTap] upload=\(current.id.uuidString.lowercased()) status=\(current.status.rawValue)")
            self.navigationController?.pushViewController(vc, animated: true)
        }, for: .touchUpInside)
        return row
    }

    private func presentFailedUploadAlert(_ upload: LocalSheetLibrary.Upload) {
        let alert = UIAlertController(
            title: "Conversion Failed",
            message: upload.errorMessage ?? "We couldn't convert this sheet music. The file may be unclear, unsupported, or incomplete.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
            LocalSheetLibrary.shared.retry(id: upload.id)
            let vc   = UploadPageNextViewController()
            vc.jobId = upload.id
            self?.navigationController?.pushViewController(vc, animated: true)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Row Options

    private func showRenameAlert(for scanId: Int64, currentTitle: String, titleLabel: UILabel?) {
        let alert = UIAlertController(title: "Rename File", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text                  = currentTitle
            tf.placeholder           = "Enter new name"
            tf.clearButtonMode       = .whileEditing
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self else { return }
            let name = InputValidator.limit(
                InputValidator.trimOnSubmit(alert.textFields?.first?.text ?? ""),
                maxLength: InputValidator.nameMaxLength
            )
            guard InputValidator.validateRequired(name, message: "File name is required.") == nil else {
                self.presentAlert(title: "Error", message: "File name is required.")
                return
            }
            titleLabel?.text = name
            self.renameTask?.cancel()
            self.renameTask = Task { [weak self] in
                guard let self else { return }
                await self.renameScan(id: scanId, newTitle: name)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func renameScan(id scanId: Int64, newTitle: String) async {
        let sanitizedTitle = InputValidator.limit(
            InputValidator.trimOnSubmit(newTitle),
            maxLength: InputValidator.nameMaxLength
        )
        guard InputValidator.validateRequired(sanitizedTitle, message: "File name is required.") == nil else {
            await MainActor.run {
                self.presentAlert(title: "Error", message: "File name is required.")
            }
            return
        }

        do {
            try LocalSheetLibrary.shared.rename(scanId: scanId, to: sanitizedTitle)
            debugLog("[Rename] upload \(scanId) → \(sanitizedTitle)")
        } catch {
            debugLog("[Rename] failed: \(error)")
            let message = AppUserFacingError.message(
                for: "rename that upload",
                error: error,
                fallback: "We couldn't rename that file right now. Please try again."
            )
            await MainActor.run {
                self.loadRecentUploads()
                self.presentAlert(title: AppUserFacingError.title(for: error), message: message)
            }
        }
    }

    private func confirmDeleteScan(id scanId: Int64, title: String) {
        let alert = UIAlertController(
            title: "Delete Upload?",
            message: "This will remove \"\(title)\" from your uploads list.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteScanTask(id: scanId)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func deleteScanTask(id scanId: Int64) {
        Task { [weak self] in
            guard let self else { return }
            await self.deleteScan(id: scanId)
        }
    }

    private func deleteScan(id scanId: Int64) async {
        do {
            try LocalSheetLibrary.shared.delete(scanId: scanId)
            loadRecentUploads()
        } catch {
            debugLog("[Delete] failed: \(error)")
            let message = AppUserFacingError.message(
                for: "delete that upload",
                error: error,
                fallback: "We couldn't delete this upload. Please try again."
            )
            await MainActor.run {
                let alert = UIAlertController(
                    title: AppUserFacingError.title(for: error),
                    message: message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    // MARK: - Formatting
    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        return kb < 1024 ? String(format: "%.0f KB", kb)
                         : String(format: "%.1f MB", kb / 1024.0)
    }

    private func relativeDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        return DateFormatter.shortDate.string(from: date)
    }

    // MARK: - Upload Pipeline
    /// Saves the PDF on this device and starts converting it there (OemerKit: Core ML + the
    /// oemer engine); nothing is uploaded. The result screen shows progress until it's done.
    private func saveUploadToDatabase(imageData: Data, fileName: String,
                                       fileType: String, popup: UploadQuizPopup) async throws {
        debugLog("[Upload] size=\(imageData.count) bytes, converting on device")

        let friendlyTitle = generateUniqueUploadTitle()
        let upload = try LocalSheetLibrary.shared.add(pdfData: imageData, title: friendlyTitle,
                                                       originalFilename: fileName)

        AnalyticsManager.logUploadCompleted(
            source: currentUploadSource,
            fileType: fileType,
            fileSizeBytes: imageData.count
        )
        loadRecentUploads()
        clearUploadState()
        let vc       = UploadPageNextViewController()
        vc.jobId     = upload.id
        vc.onDataReady = {
            popup.notifyUploadComplete()
        }
        popup.track(uploadId: upload.id)
        debugLog("[Navigate] upload=\(upload.id.uuidString)")
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Document Scanner (VisionKit)
    private func presentVisionKitScanner() {
        guard VNDocumentCameraViewController.isSupported else {
            presentAlert(title: "Scanner Unavailable",
                         message: "Document scanning is not supported on this device.")
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showDocumentScanner()
        case .notDetermined:
            presentScannerCameraAccessRationale()
        case .denied, .restricted:
            presentSettingsRedirectAlert(
                title: "Camera Access Needed",
                message: "Allow camera access in Settings to scan sheet music pages for upload."
            )
        @unknown default:
            presentSettingsRedirectAlert(
                title: "Camera Access Needed",
                message: "Allow camera access in Settings to scan sheet music pages for upload."
            )
        }
    }

    private func showDocumentScanner() {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = self
        activeDocumentScanner = scanner
        present(scanner, animated: true)
    }

    private func presentScannerCameraAccessRationale() {
        let alert = UIAlertController(
            title: "Use Camera to Scan Sheet Music",
            message: "Re-Hearse uses the camera only when you choose Scan so you can capture sheet music pages for upload and analysis.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    granted ? self.showDocumentScanner() : self.presentSettingsRedirectAlert(
                        title: "Camera Access Needed",
                        message: "Allow camera access in Settings to scan sheet music pages for upload."
                    )
                }
            }
        })
        present(alert, animated: true)
    }

    private func dismissDocumentScanner(_ scanner: VNDocumentCameraViewController,
                                        completion: (() -> Void)? = nil) {
        scanner.delegate = nil
        activeDocumentScanner = nil
        guard scanner.presentingViewController != nil else {
            completion?()
            return
        }
        scanner.dismiss(animated: true, completion: completion)
    }

    private func presentPhotoLibraryPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        activePhotoPicker = picker
        present(picker, animated: true)
    }

    private func presentSettingsRedirectAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsURL)
        })
        present(alert, animated: true)
    }

    private func createPDF(from images: [UIImage]) -> Data? {
        guard !images.isEmpty else { return nil }
        let pdf = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdf, CGRect(origin: .zero, size: Constants.pdfPageSize), nil)
        for (index, image) in images.enumerated() {
            autoreleasepool {
                // Normalize orientation — VisionKit images can arrive rotated
                let normalized = image.normalized()
                UIGraphicsBeginPDFPageWithInfo(
                    CGRect(origin: .zero, size: Constants.pdfPageSize), nil)
                // Scale to fit the page, no 1.0 cap — scanner images are always high-res
                let scale = min(Constants.pdfPageSize.width  / normalized.size.width,
                                Constants.pdfPageSize.height / normalized.size.height)
                let w = normalized.size.width  * scale
                let h = normalized.size.height * scale
                let rect = CGRect(x: (Constants.pdfPageSize.width  - w) / 2,
                                  y: (Constants.pdfPageSize.height - h) / 2,
                                  width: w, height: h)
                normalized.draw(in: rect)
                // Page number
                let txt = "\(index + 1)"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.gray
                ]
                let sz = txt.size(withAttributes: attrs)
                txt.draw(in: CGRect(x: (Constants.pdfPageSize.width - sz.width) / 2,
                                    y: 10, width: sz.width, height: sz.height),
                         withAttributes: attrs)
            }
        }
        // ⚠️ MUST call EndPDFContext BEFORE reading pdf data.
        // Swift evaluates `return pdf as Data` (copies NSMutableData → Data)
        // BEFORE a `defer` fires, so the PDF trailer would never be written.
        UIGraphicsEndPDFContext()

        guard pdf.length > 4 else { return nil }
        return pdf as Data
    }

    // MARK: - Quiz Popup
    private func showQuizPopup() -> UploadQuizPopup {
        let popup = UploadQuizPopup()
        popup.delegate = self
        
        // iPad: a centred card sized to the quiz rather than a sheet across the whole screen
        popup.modalPresentationStyle = DeviceLayout.isPad ? .formSheet : .pageSheet
        if DeviceLayout.isPad {
            popup.preferredContentSize = CGSize(width: 520, height: 600)
        }
        if !DeviceLayout.isPad, let sheet = popup.sheetPresentationController {
            // Custom detent at ~65% of screen height for a "bigger" feel than medium
            let customDetent = UISheetPresentationController.Detent.custom { context in
                context.maximumDetentValue * 0.65
            }
            sheet.detents = [customDetent, .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 32
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        
        activeQuizPopup = popup
        present(popup, animated: true)
        return popup
    }

    // MARK: - Error Presentation
    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    private func handleUploadError(_ error: Error, popup: UploadQuizPopup) {
        AnalyticsManager.logUploadFailed(
            source: currentUploadSource,
            reason: error.localizedDescription
        )
        clearUploadState()
        activeQuizPopup = nil
        let libraryError = error as? LocalSheetLibrary.LibraryError
        let title = libraryError == .limitReached ? "Upload Limit Reached"
            : libraryError == .fileTooLarge ? "Upload Too Large"
            : AppUserFacingError.title(for: error)
        let message = libraryError?.errorDescription ?? AppUserFacingError.message(
            for: "finish this upload",
            error: error,
            fallback: "We couldn't save this sheet on your device. Please check your free storage and try again."
        )
        popup.dismiss(animated: true) { [weak self] in
            self?.presentAlert(title: title, message: message)
        }
    }

    private func validateUploadSize(_ data: Data, title: String = "Upload Too Large") -> Bool {
        guard data.count <= Constants.maxUploadSizeBytes else {
            presentAlert(title: title, message: "Files must be under 10 MB.")
            return false
        }
        return true
    }

    private func clearUploadState() {
        pickedTitleBase = nil
        currentFileName = ""
        currentFileType = ""
        currentUploadSource = "unknown"
    }

    private func cancelPendingTasks() {
        profileFetchTask?.cancel()
        renameTask?.cancel()
        uploadTask?.cancel()
    }

    private func releaseTransientPickers() {
        activeDocumentPicker?.delegate  = nil
        activePhotoPicker?.delegate     = nil
        activeDocumentScanner?.delegate = nil
        activeDocumentPicker   = nil
        activePhotoPicker      = nil
        activeDocumentScanner  = nil
    }

    private func dismissDocumentPicker(_ controller: UIDocumentPickerViewController,
                                       completion: (() -> Void)? = nil) {
        activeDocumentPicker = nil
        controller.delegate = nil
        guard controller.presentingViewController != nil else {
            completion?()
            return
        }
        controller.dismiss(animated: true, completion: completion)
    }

    private func dismissPhotoPicker(_ picker: PHPickerViewController,
                                    completion: (() -> Void)? = nil) {
        activePhotoPicker = nil
        picker.delegate = nil
        guard picker.presentingViewController != nil else {
            completion?()
            return
        }
        picker.dismiss(animated: true, completion: completion)
    }

    private func beginUpload(with image: UIImage) {
        switch validateAndPrepareImage(image) {
        case .failure(let error):
            presentAlert(title: "Scan Failed", message: error.userMessage)
            return
        case .success(let preparedImage):
            guard let pdfData = createPDF(from: [preparedImage]) else {
                presentAlert(title: "Scan Failed", message: "Could not prepare the captured image for upload.")
                return
            }
            guard validateUploadSize(pdfData) else { return }

            currentFileName = generateTimestampFilename()
            currentFileType = "application/pdf"
            currentUploadSource = "image_capture"

            let popup = showQuizPopup()
            AnalyticsManager.logUploadStarted(source: currentUploadSource, fileType: currentFileType)
            uploadTask?.cancel()
            uploadTask = Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.saveUploadToDatabase(imageData: pdfData,
                                                        fileName: self.currentFileName,
                                                        fileType: self.currentFileType,
                                                        popup: popup)
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run { self.handleUploadError(error, popup: popup) }
                }
            }
        }
    }

    private func validateAndPrepareImage(_ image: UIImage) -> Result<UIImage, ImageValidationError> {
        guard let sourceData = image.normalizedImageData(jpegQuality: 1.0) else {
            return .failure(.processingFailed)
        }

        switch ImageValidator.validateAndPrepareImageData(sourceData, typeIdentifier: nil) {
        case .success(let prepared):
            guard let preparedImage = UIImage(data: prepared.data) else {
                return .failure(.processingFailed)
            }
            return .success(preparedImage)
        case .failure(let error):
            return .failure(error)
        }
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate
extension HomeViewController: VNDocumentCameraViewControllerDelegate {

    func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                      didFinishWith scan: VNDocumentCameraScan) {
        dismissDocumentScanner(controller) { [weak self] in
            guard let self else { return }
            // Collect all scanned pages — VisionKit already removes shadows
            // and corrects perspective. We then apply Apple's built-in
            // CIPhotoEffectNoir filter for a pure B&W scanned-document look.
            var pages: [UIImage] = []
            for index in 0 ..< scan.pageCount {
                autoreleasepool {
                    let raw = scan.imageOfPage(at: index)
                    let styled = raw.applyDocumentStyle()
                    if case let .success(preparedPage) = self.validateAndPrepareImage(styled) {
                        pages.append(preparedPage)
                    }
                }
            }
            guard !pages.isEmpty else {
                self.presentAlert(title: "Scan Empty",
                                  message: "No pages were captured. Please try again.")
                return
            }
            // Convert pages → PDF, then run the standard upload pipeline
            guard let pdfData = self.createPDF(from: pages) else {
                self.presentAlert(title: "Scan Failed",
                                  message: "Could not create a PDF from the scanned pages.")
                return
            }
            self.currentFileName   = self.generateTimestampFilename()
            self.currentFileType   = "application/pdf"
            self.currentUploadSource = "document_scanner"
            let popup = self.showQuizPopup()
            AnalyticsManager.logUploadStarted(source: self.currentUploadSource, fileType: self.currentFileType)
            self.uploadTask?.cancel()
            self.uploadTask = Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.saveUploadToDatabase(imageData: pdfData,
                                                        fileName: self.currentFileName,
                                                        fileType: self.currentFileType,
                                                        popup: popup)
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run { self.handleUploadError(error, popup: popup) }
                }
            }
        }
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        dismissDocumentScanner(controller)
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                      didFailWithError error: Error) {
        dismissDocumentScanner(controller) { [weak self] in
            self?.presentAlert(title: "Scan Failed", message: "We couldn't scan that document. Please try again.")
        }
    }
}

// MARK: - UIDocumentPickerDelegate + Upload Delegates
extension HomeViewController: UIDocumentPickerDelegate, UploadQuizPopupDelegate,
                        PHPickerViewControllerDelegate {

    func uploadQuizPopupDidClose(_ popup: UploadQuizPopup) { activeQuizPopup = nil }

    func openFileManager() {
        // Restrict to PDF only at the picker level
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf], asCopy: true)
        picker.delegate                = self
        picker.allowsMultipleSelection = false
        activeDocumentPicker = picker
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileURL = urls.first else { return }
        dismissDocumentPicker(controller) { [weak self] in
            guard let self else { return }

            let validatedFile: ValidatedFile
            switch FileValidator.validateDocument(at: fileURL) {
            case .success(let file):
                validatedFile = file
            case .failure(let error):
                self.presentAlert(
                    title: "Invalid File",
                    message: error.userMessage
                )
                return
            }

            do {
                guard validatedFile.sizeInBytes <= Int64(Constants.maxUploadSizeBytes) else {
                    self.presentAlert(title: "Upload Too Large", message: "Files must be under 10 MB.")
                    return
                }

                let data = try Data(contentsOf: validatedFile.url)
                guard self.validateUploadSize(data) else { return }

                // ── Layer 2: magic-byte check (%PDF) ─────────────────────────
                let pdfMagic: [UInt8] = [0x25, 0x50, 0x44, 0x46]   // %PDF
                guard data.count > 4,
                      data.prefix(4).elementsEqual(pdfMagic) else {
                    self.presentAlert(
                        title: "Invalid File",
                        message: "The selected file does not appear to be a valid PDF."
                    )
                    return
                }

                self.currentFileName   = validatedFile.url.lastPathComponent
                self.currentFileType   = "application/pdf"
                self.currentUploadSource = "document_picker"
                let name = validatedFile.url.deletingPathExtension().lastPathComponent
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                self.pickedTitleBase = name.isEmpty ? nil : String(name.prefix(60))
                let popup = self.showQuizPopup()
                AnalyticsManager.logUploadStarted(source: self.currentUploadSource, fileType: self.currentFileType)
                self.uploadTask?.cancel()
                self.uploadTask = Task { [weak self] in
                    guard let self else { return }
                    do {
                        try await self.saveUploadToDatabase(imageData: data,
                                                            fileName: self.currentFileName,
                                                            fileType: self.currentFileType,
                                                            popup: popup)
                    } catch {
                        guard !Task.isCancelled else { return }
                        await MainActor.run { self.handleUploadError(error, popup: popup) }
                    }
                }
            } catch {
                self.presentAlert(title: "Error", message: "We couldn't read that file. Please try another PDF.")
            }
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        dismissDocumentPicker(controller)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismissPhotoPicker(picker) { [weak self] in
            guard let self else { return }
            guard let result = results.first else { return }
            let itemProvider = result.itemProvider
            let typeIdentifier = ImageValidator.preferredSupportedTypeIdentifier(from: itemProvider.registeredTypeIdentifiers)
            guard let typeIdentifier else {
                self.presentAlert(title: "Import Failed", message: "The selected item is not a supported image.")
                return
            }

            itemProvider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] data, _ in
                guard let self else { return }
                guard let data else {
                    DispatchQueue.main.async {
                        self.presentAlert(title: "Import Failed", message: "We couldn't import that image. Please try another one.")
                    }
                    return
                }

                switch ImageValidator.validateAndPrepareImageData(data, typeIdentifier: typeIdentifier) {
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.presentAlert(title: "Import Failed", message: error.userMessage)
                    }
                case .success(let prepared):
                    guard let image = UIImage(data: prepared.data) else {
                        DispatchQueue.main.async {
                            self.presentAlert(title: "Import Failed", message: "We couldn't prepare that image. Please try another one.")
                        }
                        return
                    }

                    DispatchQueue.main.async {
                        self.currentUploadSource = "photo_picker"
                        self.beginUpload(with: image)
                    }
                }
            }
        }
    }

    @objc private func seeMoreTapped() {
        navigationController?.pushViewController(AllUploadsViewController(), animated: true)
    }
}

// MARK: - UIColor Hex
extension UIColor {
    convenience init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(red:   CGFloat((rgb & 0xFF0000) >> 16) / 255,
                  green: CGFloat((rgb & 0x00FF00) >>  8) / 255,
                  blue:  CGFloat( rgb & 0x0000FF)         / 255, alpha: 1)
    }
}

// MARK: - UIImage Orientation Normalization + Document Style
private extension UIImage {

    /// Converts a VisionKit scanned page to a pure B&W document image.
    /// Pipeline (all Apple-native Core Image, no custom processing):
    ///   1. CIPhotoEffectNoir  — desaturates + applies film-noir contrast curve
    ///   2. CIColorControls    — boosts contrast further so stave lines are crisp black
    /// The shared CIContext is GPU-backed and reused across pages to avoid
    /// re-allocating the Metal pipeline on every call (memory-safe).
    func applyDocumentStyle() -> UIImage {
        guard let ciInput = CIImage(image: self) else { return self }

        // Step 1 — B&W via Apple's built-in Noir filter
        let noir = CIFilter.photoEffectNoir()
        noir.inputImage = ciInput
        guard let noirOutput = noir.outputImage else { return self }

        // Step 2 — Boost contrast so music notation lines are razor-sharp
        let controls = CIFilter.colorControls()
        controls.inputImage  = noirOutput
        controls.saturation  = 0.0   // ensure fully desaturated
        controls.contrast    = 1.4   // crisp stave lines
        controls.brightness  = 0.05  // lift shadows slightly so paper stays white
        guard let finalCI = controls.outputImage else { return self }

        // Render using a shared GPU-backed context (no memory leak — static let)
        let cgResult = UIImage.ciContext.createCGImage(finalCI, from: finalCI.extent)
        guard let cgResult else { return self }

        let rendered = UIGraphicsImageRenderer(size: size).image { _ in
            UIImage(cgImage: cgResult, scale: scale, orientation: imageOrientation)
                .draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered
    }

    /// Shared Metal-backed CIContext. Creating one per page would re-allocate
    /// the GPU pipeline on every call — a significant memory/perf leak.
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
}

// MARK: - DateFormatter Convenience
private extension DateFormatter {
    static let shortDate: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
    }()
}

extension HomeViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // No additional state to reset for the guest upload gate.
    }
}

extension HomeViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        syncNavBarAlpha()
    }
}

extension HomeViewController: IPadContentWidth {
    /// Two columns across the screen, as in the iPad design.
    var iPadContentWidth: CGFloat { 1400 }
}
