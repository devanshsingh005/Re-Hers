//
//  DiscoverSongDetailViewController.swift
//  Re-Hearse
//
//  Redesigned to match UploadPageNextViewController and PlaylistSongDetailViewController.
//

import UIKit
import PDFKit
import Supabase

enum DiscoverSongDetailAccessPolicy {
    static let allowsGuestPlayAlong = GuestFeatureAccessPolicy.allowsPlayAlong
    static let allowsGuestAnimation = GuestFeatureAccessPolicy.allowsAnimation
}

enum DiscoverSongDetailActionAvailability {
    static func shouldEnableActions(hasJSON: Bool) -> Bool {
        hasJSON
    }
}

class DiscoverSongDetailViewController: UIViewController {

    // MARK: - Passed Data
    var song: Song?
    var passedImage: UIImage?
    var onUserBlocked: ((UUID) -> Void)?

    // MARK: - Private State
    private var originalPDFDocument: PDFDocument?
    private var labeledPDFDocument: PDFDocument?
    private var recentPlayTask: Task<Void, Never>?
    private var sheetLoadTask: Task<Void, Never>?
    private let moderationService = DiscoverModerationService.shared
    private var sheetMusicJSON: [String: Any]? {
        didSet { updateActionButtonState() }
    }
    private var trackedPracticeSessionStartedAt: Date?

    // MARK: - Scroll Container
    private let mainScrollView = UIScrollView()
    private let contentView    = UIView()

    // MARK: - UI Elements
    private let albumArt         = UIImageView()
    private let songTitleLabel  = UILabel()
    private let artistLabel     = UILabel()
    private let sheetToggle     = UISegmentedControl(items: ["Original", "Labeled"])
    private let pageLabel       = UILabel()

    private let playAlongButton = UIButton(type: .system)
    private let animationButton = UIButton(type: .system)
    private let buttonStack     = UIStackView()

    private let sheetContainer      = UIView()
    private let pdfView             = PDFView()
    private let pdfLoadingIndicator = UIActivityIndicatorView(style: .medium)
    private let pdfErrorLabel       = UILabel()

    private let bottomSpacer = UIView()

    // MARK: - Lifecycle

    init() {
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }
    
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.SongDetailScreen.background
        navigationController?.navigationBar.isHidden = false
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            primaryAction: nil,
            menu: buildSongMenu()
        )

        setupUI()
        setupScroll()
        setupContent()
        setupConstraints()
        setupActions()
        updateActionButtonState()

        applyPassedData()
        loadSheetData()

        // Record this song as recently played
        if let song {
            recentPlayTask = Task { [weak self] in
                do {
                    try await RecentPlayService.shared.recordPlay(song: song)
                } catch {
                    debugLog("[DiscoverDetail] ❌ Failed to record play: \(error)")
                }
                self?.recentPlayTask = nil
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if originalPDFDocument == nil && labeledPDFDocument == nil && sheetLoadTask == nil {
            loadSheetData()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SupabaseProgressManager.beginTrackedPracticeSessionIfNeeded(&trackedPracticeSessionStartedAt)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        SupabaseProgressManager.endTrackedPracticeSession(
            &trackedPracticeSessionStartedAt,
            kind: .practicePage
        )
        let movedOffNavigationStack = navigationController?.topViewController.map { $0 !== self } ?? false
        if isMovingFromParent || isBeingDismissed || movedOffNavigationStack {
            cancelPendingTasks()
            releasePDFResources()
        }
    }

    deinit {
        cancelPendingTasks()
        releasePDFResources()
    }
    
    private func cancelPendingTasks() {
        sheetLoadTask?.cancel()
        sheetLoadTask = nil
        recentPlayTask?.cancel()
        recentPlayTask = nil
    }

    private func releasePDFResources() {
        originalPDFDocument = nil
        labeledPDFDocument = nil
        pdfView.document = nil
    }

    // MARK: - Apply Passed Data

    private func applyPassedData() {
        songTitleLabel.text = song?.title ?? "Unknown Song"
        artistLabel.text    = song?.composer ?? "Unknown Artist"
        albumArt.image = passedImage ?? trackImagePlaceholder(for: song?.title ?? "")

        if passedImage == nil, let coverUrl = song?.coverImageUrl, !coverUrl.isEmpty, coverUrl.hasPrefix("http") {
            ImageLoader.shared.loadImage(from: coverUrl) { [weak self] image in
                guard let image else { return }
                self?.albumArt.image = image
            }
        }
    }

    // MARK: - NavBar

    private func setupUI() {
        view.backgroundColor = ComponentColors.SongDetailScreen.background
        navigationController?.navigationBar.isHidden = false
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        title = ""
        navigationItem.leftBarButtonItem = NavigationBarHelper.createCustomBackButton(target: self, action: #selector(backAction))
    }

    private func buildSongMenu() -> UIMenu {
        let addToPlaylist = UIAction(title: "Add To Playlist", image: UIImage(systemName: "text.badge.plus")) { [weak self] _ in
            self?.presentPlaylistPicker()
        }

        var actions: [UIAction] = [addToPlaylist]

        if song != nil {
            let report = UIAction(title: "Report", image: UIImage(systemName: "flag")) { [weak self] _ in
                self?.presentReportReasons()
            }
            actions.append(report)
        }

        if song?.userId != nil {
            let block = UIAction(
                title: "Block User",
                image: UIImage(systemName: "hand.raised"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.confirmBlockUser()
            }
            actions.append(block)
        }

        return UIMenu(title: "", children: actions)
    }

    @objc private func backAction() {
        if let btn = navigationItem.leftBarButtonItem?.customView {
            NavigationBarHelper.animateButtonPress(btn) { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - Scroll View

    private func setupScroll() {
        mainScrollView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.alwaysBounceVertical = true
        view.addSubview(mainScrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            mainScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mainScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: mainScrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: mainScrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: mainScrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: mainScrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: mainScrollView.widthAnchor)
        ])
    }

    // MARK: - Content Setup

    private func setupContent() {
        albumArt.layer.cornerRadius = 24
        albumArt.contentMode = .scaleAspectFill
        albumArt.clipsToBounds = true
        albumArt.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(albumArt)

        songTitleLabel.textAlignment = .center
        songTitleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        songTitleLabel.textColor = ComponentColors.SongDetailScreen.songTitle
        songTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(songTitleLabel)

        artistLabel.textAlignment = .center
        artistLabel.font = .systemFont(ofSize: 14)
        artistLabel.textColor = ComponentColors.SongDetailScreen.artistName
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artistLabel)

        sheetToggle.selectedSegmentIndex = 0
        sheetToggle.translatesAutoresizingMaskIntoConstraints = false
        sheetToggle.addTarget(self, action: #selector(sheetToggleChanged), for: .valueChanged)
        contentView.addSubview(sheetToggle)

        pageLabel.text = "Sheet Music"
        pageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        pageLabel.textAlignment = .center
        pageLabel.textColor = .label
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pageLabel)

        playAlongButton.setTitle("Play Along", for: .normal)
        playAlongButton.setTitleColor(.white, for: .normal)
        playAlongButton.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        playAlongButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        playAlongButton.layer.cornerRadius = 20
        playAlongButton.setTitleColor(ComponentColors.SongDetailScreen.primaryActionText, for: .normal)
        playAlongButton.backgroundColor = ComponentColors.SongDetailScreen.primaryActionFill
        playAlongButton.layer.shadowOpacity = 0.15
        playAlongButton.layer.shadowRadius  = 6
        playAlongButton.layer.shadowOffset  = CGSize(width: 0, height: 3)
        playAlongButton.isEnabled = false

        animationButton.setTitle("Animation", for: .normal)
        animationButton.setTitleColor(.label, for: .normal)
        animationButton.backgroundColor = ComponentColors.SongDetailScreen.sheetMusicBackground
        animationButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        animationButton.layer.cornerRadius = 20
        animationButton.setTitleColor(ComponentColors.SongDetailScreen.secondaryActionText, for: .normal)
        animationButton.backgroundColor = ComponentColors.SongDetailScreen.secondaryActionFill
        animationButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        animationButton.isEnabled = false

        buttonStack.axis         = .horizontal
        buttonStack.spacing      = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.addArrangedSubview(playAlongButton)
        buttonStack.addArrangedSubview(animationButton)
        contentView.addSubview(buttonStack)

        sheetContainer.translatesAutoresizingMaskIntoConstraints = false
        sheetContainer.backgroundColor = ComponentColors.SongDetailScreen.sheetMusicCardFill
        sheetContainer.layer.cornerRadius = 20
        sheetContainer.layer.borderWidth  = 0.5
        sheetContainer.layer.borderColor  = UIColor.separator.cgColor
        sheetContainer.clipsToBounds = true
        contentView.addSubview(sheetContainer)

        pdfView.layer.cornerRadius  = 12
        pdfView.clipsToBounds       = true
        pdfView.autoScales          = true
        pdfView.displayMode         = .singlePage
        pdfView.displayDirection    = .vertical
        pdfView.backgroundColor     = ComponentColors.SongDetailScreen.sheetMusicBackground
        pdfView.isHidden            = true
        pdfView.isUserInteractionEnabled = true
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        let pdfTap = UITapGestureRecognizer(target: self, action: #selector(didTapPDFView))
        pdfView.addGestureRecognizer(pdfTap)
        sheetContainer.addSubview(pdfView)

        pdfLoadingIndicator.color = ComponentColors.SongDetailScreen.primaryActionFill
        pdfLoadingIndicator.hidesWhenStopped = true
        pdfLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        sheetContainer.addSubview(pdfLoadingIndicator)

        pdfErrorLabel.text = "Sheet music unavailable.\nThe file might not be uploaded yet."
        pdfErrorLabel.numberOfLines = 0
        pdfErrorLabel.textAlignment = .center
        pdfErrorLabel.font          = .systemFont(ofSize: 15)
        pdfErrorLabel.textColor = SemanticColors.Text.secondary
        pdfErrorLabel.isHidden      = true
        pdfErrorLabel.translatesAutoresizingMaskIntoConstraints = false
        sheetContainer.addSubview(pdfErrorLabel)

        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.backgroundColor = .clear
        contentView.addSubview(bottomSpacer)
    }

    // MARK: - Constraints

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            albumArt.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            albumArt.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            albumArt.widthAnchor.constraint(equalToConstant: 200),
            albumArt.heightAnchor.constraint(equalToConstant: 200),

            songTitleLabel.topAnchor.constraint(equalTo: albumArt.bottomAnchor, constant: 18),
            songTitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            songTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            songTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            artistLabel.topAnchor.constraint(equalTo: songTitleLabel.bottomAnchor, constant: 2),
            artistLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            artistLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            artistLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            sheetToggle.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 22),
            sheetToggle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sheetToggle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            pageLabel.topAnchor.constraint(equalTo: sheetToggle.bottomAnchor, constant: 16),
            pageLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            sheetContainer.topAnchor.constraint(equalTo: pageLabel.bottomAnchor, constant: 10),
            sheetContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sheetContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            sheetContainer.heightAnchor.constraint(equalToConstant: 430),

            buttonStack.topAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: 24),
            buttonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            buttonStack.heightAnchor.constraint(equalToConstant: 46),

            pdfLoadingIndicator.centerXAnchor.constraint(equalTo: sheetContainer.centerXAnchor),
            pdfLoadingIndicator.centerYAnchor.constraint(equalTo: sheetContainer.centerYAnchor),

            pdfErrorLabel.centerXAnchor.constraint(equalTo: sheetContainer.centerXAnchor),
            pdfErrorLabel.centerYAnchor.constraint(equalTo: sheetContainer.centerYAnchor),
            pdfErrorLabel.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 16),
            pdfErrorLabel.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -16),

            pdfView.topAnchor.constraint(equalTo: sheetContainer.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: sheetContainer.bottomAnchor),

            bottomSpacer.topAnchor.constraint(equalTo: buttonStack.bottomAnchor),
            bottomSpacer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomSpacer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomSpacer.heightAnchor.constraint(equalToConstant: 40),
            bottomSpacer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    // MARK: - Button Actions

    private func setupActions() {
        playAlongButton.addTarget(self, action: #selector(openPlayAlongVC),       for: .touchUpInside)
        animationButton.addTarget(self, action: #selector(didTapAnimation),       for: .touchUpInside)
    }

    private func updateActionButtonState() {
        let hasJSON = sheetMusicJSON != nil
        let shouldEnableActions = DiscoverSongDetailActionAvailability.shouldEnableActions(hasJSON: hasJSON)
        playAlongButton.isEnabled = shouldEnableActions
        animationButton.isEnabled = shouldEnableActions
        playAlongButton.alpha = shouldEnableActions ? 1.0 : 0.6
        animationButton.alpha = shouldEnableActions ? 1.0 : 0.6
    }

    @objc private func sheetToggleChanged() {
        if sheetToggle.selectedSegmentIndex == 0 {
            if let doc = originalPDFDocument {
                renderPDF(doc)
            } else {
                pdfView.isHidden = true
                pdfLoadingIndicator.startAnimating()
                pdfErrorLabel.isHidden = true
            }
        } else {
            if let doc = labeledPDFDocument {
                renderPDF(doc)
            } else {
                pdfView.isHidden = true
                pdfLoadingIndicator.startAnimating()
                pdfErrorLabel.isHidden = true
            }
        }
    }

    @objc private func openPlayAlongVC() {
        guard !presentGuestPlayAlongGateIfNeeded() else { return }

        if sheetMusicJSON == nil {
            loadSheetData()
        }

        guard let json = sheetMusicJSON,
              let data = try? JSONSerialization.data(withJSONObject: json) else {
            showConvertedJSONMissingError()
            return
        }

        let vc  = PlayAlongViewController()
        vc.sheetMusicData = data
        let nav = LandscapeNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @discardableResult
    private func presentGuestPlayAlongGateIfNeeded() -> Bool {
        guard !DiscoverSongDetailAccessPolicy.allowsGuestPlayAlong else { return false }
        guard GuestSessionManager.shared.isGuest(), presentedViewController == nil else { return false }

        let modal = GuestFeatureGateModal(
            featureName: "play along",
            onSignUp: { [weak self] in
                self?.presentGuestAuth(mode: .signUp)
            },
            onLogIn: { [weak self] in
                self?.presentGuestAuth(mode: .logIn)
            }
        )

        present(modal, animated: true)
        return true
    }

    private func presentGuestAuth(mode: AuthViewController.AuthMode) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.presentedViewController == nil else { return }

            let authVC = AuthViewController(initialMode: mode)
            let nav = UINavigationController(rootViewController: authVC)
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true)
        }
    }

    @objc private func didTapAnimation() {
        guard !presentGuestAnimationGateIfNeeded() else { return }
        guard canPresentAnimation() else { return }

        if sheetMusicJSON == nil {
            loadSheetData()
        }

        guard let json = sheetMusicJSON else {
            showConvertedJSONMissingError()
            return
        }

        guard let data = try? JSONSerialization.data(withJSONObject: json) else {
            showAnimationError("Failed to prepare sheet music data.")
            return
        }

        let vc = AnimationViewController()
        vc.sheetMusicData = data
        vc.songTitle      = song?.title ?? "Animation"
        let nav = LandscapeNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @discardableResult
    private func presentGuestAnimationGateIfNeeded() -> Bool {
        guard !DiscoverSongDetailAccessPolicy.allowsGuestAnimation else { return false }
        guard GuestSessionManager.shared.isGuest(), presentedViewController == nil else { return false }

        let modal = GuestFeatureGateModal(
            featureName: "animation",
            onSignUp: { [weak self] in
                self?.presentGuestAuth(mode: .signUp)
            },
            onLogIn: { [weak self] in
                self?.presentGuestAuth(mode: .logIn)
            }
        )

        present(modal, animated: true)
        return true
    }

    private func showAnimationError(_ msg: String) {
        let a = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    private func canPresentAnimation() -> Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            showAnimationError("Animation is currently available on iPhone only.")
            return false
        }

        return true
    }

    private func showConvertedJSONMissingError() {
        let message: String
        if let jsonPath = song?.outputJsonPath, !jsonPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            message = "The converted JSON has not loaded yet. Please wait a moment and try again."
        } else {
            message = "This song does not have a converted JSON path yet. Add `output_json_path` for this song in Supabase first."
        }
        showAnimationError(message)
    }

    // MARK: - Fetch Data
    private func loadSheetData() {
        sheetLoadTask?.cancel()
        pdfLoadingIndicator.startAnimating()
        pdfErrorLabel.isHidden = true

        sheetLoadTask = Task {
            async let originalTask: Void = self.loadOriginalPDF()
            async let labeledTask: Void = self.loadConvertedPDF()
            async let jsonTask: Void = self.loadConvertedJSON()
            _ = await (originalTask, labeledTask, jsonTask)
        }
    }

    private func signedURL(from rawValue: String, fallbackBucket: String) async throws -> URL {
        try await SupabaseManager.shared.signedAssetResolver.signedURL(
            for: rawValue,
            fallbackBucket: fallbackBucket
        )
    }

    private func fetchRemoteData(from rawValue: String, fallbackBucket: String) async throws -> Data {
        let url = try await signedURL(from: rawValue, fallbackBucket: fallbackBucket)

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(statusCode) else {
            throw AssetError.remoteFetchFailed(statusCode)
        }
        return data
    }

    private func loadOriginalPDF() async {
        let originalPath = song?.originalPdfPath
        guard let originalPath, !originalPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[DiscoverDetail] ℹ️ No original PDF path")
            return
        }

        do {
            let data = try await fetchRemoteData(from: originalPath, fallbackBucket: "pdf_uploads")
            print("[DiscoverDetail] ✅ Fetched Original PDF: \(data.count) bytes")
            guard let doc = PDFDocument(data: data), doc.pageCount > 0 else {
                print("[DiscoverDetail] ❌ Failed to create PDFDocument from data")
                return
            }
            await MainActor.run {
                self.originalPDFDocument = doc
                if self.sheetToggle.selectedSegmentIndex == 0 {
                    self.renderPDF(doc)
                }
            }
        } catch {
            print("[DiscoverDetail] ❌ Original PDF fetch error: \(error)")
        }
    }

    private func loadConvertedPDF() async {
        guard let pdfSource = song?.discoverPDFSource else {
            print("[DiscoverDetail] ℹ️ No converted PDF path")
            await MainActor.run { self.showPDFError() }
            return
        }

        do {
            let data = try await fetchRemoteData(from: pdfSource.rawValue, fallbackBucket: pdfSource.fallbackBucket)
            print("[DiscoverDetail] ✅ Fetched Converted PDF: \(data.count) bytes")
            guard let doc = PDFDocument(data: data), doc.pageCount > 0 else {
                print("[DiscoverDetail] ❌ Failed to create PDFDocument from converted data")
                await MainActor.run { self.showPDFError() }
                return
            }
            await MainActor.run {
                self.labeledPDFDocument = doc
                if self.sheetToggle.selectedSegmentIndex == 1 {
                    self.renderPDF(doc)
                }
            }
        } catch {
            print("[DiscoverDetail] ❌ PDF fetch error: \(error)")
            await MainActor.run {
                if self.sheetToggle.selectedSegmentIndex == 1 {
                    self.showPDFError()
                }
            }
        }
    }

    private func loadConvertedJSON() async {
        guard let song else {
            print("[DiscoverDetail] ℹ️ No song available for JSON fetch")
            return
        }

        let jsonSources = song.discoverJSONSources(
            prefersPublicSource: GuestSessionManager.shared.isGuest()
        )

        guard !jsonSources.isEmpty else {
            print("[DiscoverDetail] ℹ️ No JSON path")
            return
        }

        for jsonSource in jsonSources {
            do {
                let data = try await fetchRemoteData(from: jsonSource.rawValue, fallbackBucket: jsonSource.fallbackBucket)
                print("[DiscoverDetail] ✅ Fetched JSON: \(data.count) bytes from \(jsonSource.rawValue)")
                guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("[DiscoverDetail] ❌ Failed to parse JSON data from \(jsonSource.rawValue)")
                    continue
                }
                await MainActor.run { self.sheetMusicJSON = parsed }
                return
            } catch {
                print("[DiscoverDetail] ❌ JSON fetch error from \(jsonSource.rawValue): \(error)")
            }
        }
    }

    private func renderPDF(_ doc: PDFDocument) {
        pdfView.document  = doc
        pdfView.isHidden  = false
        pdfView.layoutIfNeeded()
        if let p = doc.page(at: 0) { pdfView.go(to: p) }
        pdfLoadingIndicator.stopAnimating()
        pdfErrorLabel.isHidden = true
    }

    @objc private func didTapPDFView() {
        let doc = sheetToggle.selectedSegmentIndex == 0 ? originalPDFDocument : labeledPDFDocument
        guard let doc else { return }
        let vc = MaximizeUploadPageViewController()
        vc.pdfData = doc.dataRepresentation()
        vc.pdfDocument = doc
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    private func showPDFError() {
        pdfLoadingIndicator.stopAnimating()
        pdfErrorLabel.isHidden = false
    }

    private enum AssetError: LocalizedError {
        case invalidURL
        case remoteFetchFailed(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The converted asset URL is invalid."
            case .remoteFetchFailed(let code):
                return "Failed to fetch converted asset (HTTP \(code))."
            }
        }
    }

    private func presentPlaylistPicker() {
        Task {
            do {
                let playlists = try await PlaylistsManager.shared.fetchRemotePlaylists()
                await MainActor.run {
                    guard !playlists.isEmpty else {
                        self.presentInfoAlert(title: "No Playlists", message: "Create a playlist first, then add this song from the menu.")
                        return
                    }

                    let alert = UIAlertController(title: "Add To Playlist", message: "Choose a playlist for this song.", preferredStyle: .actionSheet)
                    for playlist in playlists.prefix(8) {
                        alert.addAction(UIAlertAction(title: playlist.title, style: .default) { _ in
                            self.addCurrentSong(to: playlist.id)
                        })
                    }
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    self.present(alert, animated: true)
                }
            } catch {
                await MainActor.run {
                    self.presentInfoAlert(title: "Error", message: "Could not load playlists right now.")
                }
            }
        }
    }

    private func addCurrentSong(to playlistId: UUID) {
        guard let song else { return }
        Task {
            do {
                _ = try await PlaylistsManager.shared.addTrackToPlaylist(
                    playlistId: playlistId,
                    title: song.title,
                    artist: song.composer,
                    trackId: song.id.uuidString
                )
                await MainActor.run {
                    self.presentInfoAlert(title: "Added", message: "\"\(song.title)\" was added to the playlist.")
                }
            } catch {
                await MainActor.run {
                    self.presentInfoAlert(title: "Error", message: "Could not add this song to the playlist.")
                }
            }
        }
    }

    private func presentInfoAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func presentReportReasons() {
        guard song != nil else { return }

        let alert = UIAlertController(
            title: "Report Content",
            message: "Choose the reason for this report.",
            preferredStyle: .actionSheet
        )

        let reasons: [(title: String, value: String)] = [
            ("Offensive Content", "offensive_content"),
            ("Copyright Concern", "copyright_concern"),
            ("Spam or Misleading", "spam_or_misleading")
        ]

        for reason in reasons {
            alert.addAction(UIAlertAction(title: reason.title, style: .default) { [weak self] _ in
                self?.submitReport(reason: reason)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func submitReport(reason: (title: String, value: String)) {
        guard let song else { return }

        Task {
            do {
                try await moderationService.submitReport(contentID: song.id, reason: reason.value)
                await MainActor.run {
                    self.presentInfoAlert(
                        title: "Report Sent",
                        message: "Thanks for the report. We’ll review this content."
                    )
                }
            } catch {
                await MainActor.run {
                    self.presentInfoAlert(
                        title: "Report Failed",
                        message: "We couldn't send your report right now. Please try again."
                    )
                }
            }
        }
    }

    private func confirmBlockUser() {
        guard let userID = song?.userId else { return }

        let alert = UIAlertController(
            title: "Block User",
            message: "You won't see songs from this user in Discover anymore on this device.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Block", style: .destructive) { [weak self] _ in
            self?.onUserBlocked?(userID)
            self?.presentInfoAlert(
                title: "User Blocked",
                message: "This user's songs will now be hidden from Discover."
            )
        })
        present(alert, animated: true)
    }
}

struct DiscoverReportRequest: Encodable {
    let reporterID: UUID
    let contentID: UUID
    let contentType: String
    let reason: String

    enum CodingKeys: String, CodingKey {
        case reporterID = "reporter_id"
        case contentID = "content_id"
        case contentType = "content_type"
        case reason
    }
}

final class DiscoverModerationService {
    static let shared = DiscoverModerationService()

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func submitReport(contentID: UUID, reason: String) async throws {
        let reporterID = try await client.auth.session.user.id
        let payload = DiscoverReportRequest(
            reporterID: reporterID,
            contentID: contentID,
            contentType: "song",
            reason: reason
        )

        _ = try await client
            .from("reports")
            .insert(payload)
            .execute()
    }
}
