//
//  DiscoverSongDetailViewController.swift
//  Re-Hearse
//
//  Redesigned to match UploadPageNextViewController and PlaylistSongDetailViewController.
//

import UIKit
import PDFKit
import Supabase

class DiscoverSongDetailViewController: UIViewController {

    // MARK: - Passed Data
    var song: Song?
    var passedImage: UIImage?

    // MARK: - Private State
    private var originalPDFDocument: PDFDocument?
    private var labeledPDFDocument: PDFDocument?
    private var sheetMusicJSON: [String: Any]? {
        didSet { updateActionButtonState() }
    }

    // MARK: - Scroll Container
    private let mainScrollView = UIScrollView()
    private let contentView    = UIView()

    // MARK: - UI Elements
    private let songTitleLabel  = UILabel()
    private let artistLabel     = UILabel()
    private let sheetToggle     = UISegmentedControl(items: ["Original", "Labeled"])

    private let playAlongButton = UIButton(type: .system)
    private let animationButton = UIButton(type: .system)
    private let buttonStack     = UIStackView()

    private let sheetContainer      = UIView()
    private let previewButton       = UIButton(type: .system)
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

        applyPassedData()
        loadSheetData()

        // Record this song as recently played
        if let songId = song?.id {
            recentPlayTask = Task { [weak self] in
                do {
                    try await RecentPlayService.shared.recordPlay(songId: songId)
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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
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
        let saveForLater = UIAction(title: "Save For Later", image: UIImage(systemName: "bookmark")) { [weak self] _ in
            self?.presentInfoAlert(title: "Saved", message: "This song was added to your saved list.")
        }
        return UIMenu(title: "", children: [addToPlaylist, saveForLater])
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
        songTitleLabel.textAlignment = .center
        songTitleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        songTitleLabel.textColor = ComponentColors.SongDetailScreen.songTitle
        songTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(songTitleLabel)

        artistLabel.textAlignment = .center
        artistLabel.font = .systemFont(ofSize: 14)
        artistLabel.textColor = ComponentColors.SongDetailScreen.artistName
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artistLabel)

        sheetToggle.selectedSegmentIndex = 1
        sheetToggle.translatesAutoresizingMaskIntoConstraints = false
        sheetToggle.addTarget(self, action: #selector(sheetToggleChanged), for: .valueChanged)
        contentView.addSubview(sheetToggle)

        playAlongButton.setTitle("Play Along", for: .normal)
        playAlongButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        playAlongButton.layer.cornerRadius = 12
        playAlongButton.setTitleColor(ComponentColors.SongDetailScreen.primaryActionText, for: .normal)
        playAlongButton.backgroundColor = ComponentColors.SongDetailScreen.primaryActionFill
        playAlongButton.layer.shadowOpacity = 0.15
        playAlongButton.layer.shadowRadius  = 6
        playAlongButton.layer.shadowOffset  = CGSize(width: 0, height: 3)
        playAlongButton.isEnabled = false

        animationButton.setTitle("Animation", for: .normal)
        animationButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        animationButton.layer.cornerRadius = 12
        animationButton.setTitleColor(ComponentColors.SongDetailScreen.secondaryActionText, for: .normal)
        animationButton.backgroundColor = ComponentColors.SongDetailScreen.secondaryActionFill
        animationButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        animationButton.isEnabled = false

        buttonStack.axis         = .horizontal
        buttonStack.spacing      = 26
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

        var previewConfig = UIButton.Configuration.filled()
        previewConfig.title = "Preview"
        previewConfig.baseForegroundColor = .white
        previewConfig.baseBackgroundColor = ComponentColors.HomeScreen.actionButtonFill
        previewConfig.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 18, bottom: 7, trailing: 18)
        previewConfig.cornerStyle = .fixed
        previewConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var output = incoming
            output.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            return output
        }
        previewButton.configuration = previewConfig
        previewButton.layer.cornerRadius = 16
        previewButton.clipsToBounds = true
        previewButton.translatesAutoresizingMaskIntoConstraints = false
        sheetContainer.addSubview(previewButton)
        pdfView.layer.cornerRadius  = 12
        pdfView.clipsToBounds       = true
        pdfView.autoScales          = true
        pdfView.displayMode         = .singlePageContinuous
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
            songTitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
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

            sheetContainer.topAnchor.constraint(equalTo: sheetToggle.bottomAnchor, constant: 20),
            sheetContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sheetContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            sheetContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 560),

            buttonStack.topAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: 24),
            buttonStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            buttonStack.widthAnchor.constraint(equalToConstant: 320),
            buttonStack.heightAnchor.constraint(equalToConstant: 46),

            previewButton.topAnchor.constraint(equalTo: sheetContainer.topAnchor, constant: 14),
            previewButton.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -16),
            previewButton.heightAnchor.constraint(equalToConstant: 32),

            pdfView.topAnchor.constraint(equalTo: previewButton.bottomAnchor, constant: 12),
            pdfView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 10),
            pdfView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -10),
            pdfView.heightAnchor.constraint(equalToConstant: 480),
            pdfView.bottomAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: -10),

            pdfLoadingIndicator.centerXAnchor.constraint(equalTo: sheetContainer.centerXAnchor),
            pdfLoadingIndicator.centerYAnchor.constraint(equalTo: sheetContainer.centerYAnchor),

            pdfErrorLabel.centerXAnchor.constraint(equalTo: sheetContainer.centerXAnchor),
            pdfErrorLabel.centerYAnchor.constraint(equalTo: sheetContainer.centerYAnchor),
            pdfErrorLabel.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 16),
            pdfErrorLabel.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -16),

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
        previewButton.addTarget(self, action: #selector(didTapPDFView), for: .touchUpInside)
    }

    private func updateActionButtonState() {
        let hasJSON = sheetMusicJSON != nil
        playAlongButton.isEnabled = hasJSON
        animationButton.isEnabled = hasJSON
        playAlongButton.alpha = hasJSON ? 1.0 : 0.6
        animationButton.alpha = hasJSON ? 1.0 : 0.6
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
        playAlongButton.backgroundColor = ComponentColors.SongDetailScreen.primaryActionFill
        playAlongButton.setTitleColor(ComponentColors.SongDetailScreen.primaryActionText, for: .normal)
        animationButton.backgroundColor = ComponentColors.SongDetailScreen.secondaryActionFill
        animationButton.setTitleColor(ComponentColors.SongDetailScreen.secondaryActionText, for: .normal)

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

    @objc private func didTapAnimation() {
        animationButton.backgroundColor = ComponentColors.SongDetailScreen.primaryActionFill
        animationButton.setTitleColor(ComponentColors.SongDetailScreen.primaryActionText, for: .normal)
        playAlongButton.backgroundColor = ComponentColors.SongDetailScreen.secondaryActionFill
        playAlongButton.setTitleColor(ComponentColors.SongDetailScreen.secondaryActionText, for: .normal)

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

    private func showAnimationError(_ msg: String) {
        let a = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
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

    private func resolvedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        if trimmed.hasPrefix("/") {
            return ReHersAPI.url(path: trimmed)
        } else {
            // Assume it's a relative backend path even without a leading slash
            return ReHersAPI.url(path: "/" + trimmed)
        }
    }

        let session: URLSession = isBackendURL ? ReHersPinnedSession.shared : URLSession.shared
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(statusCode) else {
            throw AssetError.remoteFetchFailed(statusCode)
        }
        return data
    }

    private func loadOriginalPDF() async {
        let originalURL = song?.originalPdfPath
        guard let originalURL, !originalURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        do {
            let data = try await fetchRemoteData(from: originalURL)
            guard let doc = PDFDocument(data: data), doc.pageCount > 0 else { return }
            await MainActor.run {
                self.originalPDFDocument = doc
                if self.sheetToggle.selectedSegmentIndex == 0 {
                    self.renderPDF(doc)
                }
            }
        } catch {
            print("[DiscoverDetail] Original PDF fetch error: \(error)")
        }
    }

    private func loadConvertedPDF() async {
        let sheetURL = song?.labeledPdfPath ?? song?.sheetUrl
        guard let sheetURL, !sheetURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run { self.showPDFError() }
            return
        }

        do {
            let data = try await fetchRemoteData(from: sheetURL)
            guard let doc = PDFDocument(data: data), doc.pageCount > 0 else {
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
            print("[DiscoverDetail] PDF fetch error: \(error)")
            await MainActor.run {
                if self.sheetToggle.selectedSegmentIndex == 1 {
                    self.showPDFError()
                }
            }
        }
    }

    private func loadConvertedJSON() async {
        let jsonURL = song?.outputJsonPath ?? song?.jsonUrl
        guard let jsonURL, !jsonURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        do {
            let data = try await fetchRemoteData(from: jsonURL)
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            await MainActor.run { self.sheetMusicJSON = parsed }
        } catch {
            print("[DiscoverDetail] JSON fetch error: \(error)")
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
                    artist: song.composer
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
}
