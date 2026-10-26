//
//  SongDetailsPage.swift
//  Re-Hearse_v1
//

import UIKit
import PDFKit
import Supabase
import Auth
internal import PostgREST

class PlaylistSongDetailViewController: UIViewController {
    private enum SheetSourceContext {
        case unknown
        case localUpload(UUID)
        case discoverSongId(UUID)
        case discoverSongMetadata(title: String, artist: String)
    }

    // MARK: - Public Input
    var passedImage: UIImage?
    var passedSongTitle: String?
    var passedArtist: String?
    var passedTrackId: String?
    var passedSheetScanId: Int64?

    // MARK: - State
    private var labeledPDF: PDFDocument?
    private var originalPDF: PDFDocument?
    private var sheetMusicJSON: [String: Any]? {
        didSet { updateActionButtonState() }
    }
    private var sourceContext: SheetSourceContext = .unknown
    private var loadedDiscoverSong: Song?
    private var trackedPracticeSessionStartedAt: Date?

    // MARK: - Supabase
    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - UI
    private let scrollView        = UIScrollView()
    private let contentView       = UIView()
    private let albumArt          = UIImageView()
    private let titleLabel        = UILabel()
    private let artistLabel       = UILabel()
    private let segmentControl    = UISegmentedControl(items: ["Original", "Labeled"])
    private let pageLabel         = UILabel()
    private let pdfView           = PDFView()
    private let pdfSkeleton       = PDFSkeletonView()
    private let errorLabel        = UILabel()
    private let playAlongButton   = UIButton(type: .system)
    private let animationButton   = UIButton(type: .system)
    private var pdfHeightConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.SongDetailScreen.background

        title = ""
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = .white
        let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        navigationController?.navigationBar.titleTextAttributes = textAttributes

        setupScrollView()
        buildUI()

        debugLog("[SongDetail] viewDidLoad — passedSheetScanId=\(String(describing: passedSheetScanId)) trackId=\(passedTrackId ?? "nil")")
        loadSheetData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
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
    }

    // MARK: - Scroll View
    private func setupScrollView() {
        [scrollView, contentView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
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
    }

    // MARK: - Build UI
    private func buildUI() {
        albumArt.layer.cornerRadius = 24
        albumArt.contentMode = .scaleAspectFill
        albumArt.clipsToBounds = true
        albumArt.image = passedImage ?? trackImagePlaceholder(for: passedSongTitle ?? "")

        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.text = passedSongTitle ?? "Unknown Song"

        artistLabel.textAlignment = .center
        artistLabel.font = .systemFont(ofSize: 14)
        artistLabel.textColor = ComponentColors.SongDetailScreen.artistName
        artistLabel.text = passedArtist ?? "Unknown Artist"

        segmentControl.selectedSegmentIndex = 1
        segmentControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        pageLabel.text = "Sheet Music"
        pageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        pageLabel.textAlignment = .center

        pdfView.layer.cornerRadius = 12
        pdfView.clipsToBounds = true
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = ComponentColors.SongDetailScreen.sheetMusicBackground
        pdfView.isHidden = true
        pdfView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapPDF)))

        pdfSkeleton.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.text = "Sheet music is still processing.\nPlease wait a moment and try again."
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.font = .systemFont(ofSize: 15)
        errorLabel.textColor = .secondaryLabel
        errorLabel.isHidden = true

        configure(playAlongButton, title: "Play Along", isPrimary: true)
        configure(animationButton,  title: "Animation",  isPrimary: false)
        playAlongButton.isEnabled = false
        animationButton.isEnabled = false
        playAlongButton.alpha = 0.6
        animationButton.alpha = 0.6
        playAlongButton.addTarget(self, action: #selector(openPlayAlong),  for: .touchUpInside)
        animationButton.addTarget(self,  action: #selector(openAnimation), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [playAlongButton, animationButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually

        let views: [UIView] = [albumArt, titleLabel, artistLabel, segmentControl,
                               pageLabel, pdfView, pdfSkeleton, errorLabel, buttonStack]
        views.forEach { $0.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview($0) }

        let cx = contentView.centerXAnchor
        NSLayoutConstraint.activate([
            albumArt.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            albumArt.centerXAnchor.constraint(equalTo: cx),
            albumArt.widthAnchor.constraint(equalToConstant: 200),
            albumArt.heightAnchor.constraint(equalToConstant: 200),

            titleLabel.topAnchor.constraint(equalTo: albumArt.bottomAnchor, constant: 18),
            titleLabel.centerXAnchor.constraint(equalTo: cx),

            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            artistLabel.centerXAnchor.constraint(equalTo: cx),

            segmentControl.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 24),
            segmentControl.centerXAnchor.constraint(equalTo: cx),
            segmentControl.widthAnchor.constraint(equalToConstant: 320),

            pageLabel.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 16),
            pageLabel.centerXAnchor.constraint(equalTo: cx),

            pdfView.topAnchor.constraint(equalTo: pageLabel.bottomAnchor, constant: 10),
            pdfView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            pdfView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            pdfSkeleton.topAnchor.constraint(equalTo: pdfView.topAnchor),
            pdfSkeleton.leadingAnchor.constraint(equalTo: pdfView.leadingAnchor),
            pdfSkeleton.trailingAnchor.constraint(equalTo: pdfView.trailingAnchor),
            pdfSkeleton.bottomAnchor.constraint(equalTo: pdfView.bottomAnchor),

            errorLabel.centerXAnchor.constraint(equalTo: pdfView.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: pdfView.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: pdfView.leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(equalTo: pdfView.trailingAnchor, constant: -16),

            buttonStack.topAnchor.constraint(equalTo: pdfView.bottomAnchor, constant: 24),
            buttonStack.leadingAnchor.constraint(equalTo: pdfView.leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: pdfView.trailingAnchor),
            buttonStack.heightAnchor.constraint(equalToConstant: 46),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
        ])

        // Dynamic height — recalculated from real page bounds in showPDF()
        let h = pdfView.heightAnchor.constraint(equalToConstant: 480)
        h.isActive = true
        pdfHeightConstraint = h
    }

    private func configure(_ btn: UIButton, title: String, isPrimary: Bool) {
        btn.setTitle(title, for: .normal)
        btn.layer.cornerRadius = 23
        btn.layer.shadowOffset = CGSize(width: 0, height: 3)
        btn.backgroundColor = isPrimary
            ? ComponentColors.SongDetailScreen.primaryActionFill
            : ComponentColors.SongDetailScreen.secondaryActionFill
        btn.setTitleColor(isPrimary
            ? ComponentColors.SongDetailScreen.primaryActionText
            : ComponentColors.SongDetailScreen.secondaryActionText, for: .normal)
        if isPrimary { btn.layer.shadowOpacity = 0.15; btn.layer.shadowRadius = 6 }
    }

    // MARK: - Actions
    @objc private func openPlayAlong() {
        configure(playAlongButton, title: "Play Along", isPrimary: true)
        configure(animationButton,  title: "Animation",  isPrimary: false)

        guard !presentGuestPlayAlongGateIfNeeded() else { return }

        if sheetMusicJSON == nil {
            loadSheetData()
        }

        guard let json = sheetMusicJSON,
              let data = try? JSONSerialization.data(withJSONObject: json) else {
            alert(sheetMusicJSON == nil
                ? "Sheet music is still loading.\nPlease wait a moment and try again."
                : "Failed to prepare sheet music data.")
            return
        }

        let vc = PlayAlongViewController()
        vc.sheetMusicData = data
    
        let nav = LandscapeNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @discardableResult
    private func presentGuestPlayAlongGateIfNeeded() -> Bool {
        guard !GuestFeatureAccessPolicy.allowsPlayAlong else { return false }
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

    @objc private func openAnimation() {
        configure(animationButton,  title: "Animation",  isPrimary: true)
        configure(playAlongButton, title: "Play Along", isPrimary: false)
        guard !presentGuestAnimationGateIfNeeded() else { return }
        guard canPresentAnimation() else { return }

        if sheetMusicJSON == nil {
            loadSheetData()
        }

        guard let json = sheetMusicJSON,
              let data = try? JSONSerialization.data(withJSONObject: json) else {
            alert(sheetMusicJSON == nil
                ? "No sheet music data available yet.\nPlease wait a moment and try again."
                : "Failed to prepare sheet music data.")
            return
        }
        let vc = AnimationViewController()
        vc.sheetMusicData = data
        vc.songTitle = passedSongTitle ?? "Animation"
        let nav = LandscapeNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @discardableResult
    private func presentGuestAnimationGateIfNeeded() -> Bool {
        guard !GuestFeatureAccessPolicy.allowsAnimation else { return false }
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

    private func alert(_ msg: String) {
        let a = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    private func canPresentAnimation() -> Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            alert("Animation is currently available on iPhone only.")
            return false
        }

        return true
    }

    private func updateActionButtonState() {
        let hasJSON = sheetMusicJSON != nil
        let shouldEnableActions = hasJSON
        playAlongButton.isEnabled = shouldEnableActions
        animationButton.isEnabled = shouldEnableActions
        playAlongButton.alpha = shouldEnableActions ? 1.0 : 0.6
        animationButton.alpha = shouldEnableActions ? 1.0 : 0.6
    }

    // MARK: - Segment
    @objc private func segmentChanged() {
        let isOriginal = segmentControl.selectedSegmentIndex == 0
        if let doc = isOriginal ? originalPDF : labeledPDF {
            showPDF(doc)
        } else {
            pdfView.isHidden = true; errorLabel.isHidden = true
            pdfSkeleton.show(in: view)
            Task {
                await loadSelectedSegmentFromCurrentSource(isOriginal: isOriginal)
            }
        }
    }

    // MARK: - Data Fetch

    /// Main entry point. The user's own uploads are stored and converted on this device;
    /// Discover songs come from Supabase.
    private func loadSheetData() {
        pdfView.isHidden = true
        errorLabel.isHidden = true
        pdfSkeleton.show(in: view)

        if let trackId = passedTrackId, let uploadId = LocalSheetLibrary.uploadId(fromPlaylistTrackId: trackId) {
            sourceContext = .localUpload(uploadId)
            loadedDiscoverSong = nil
            loadSheetDataFromLocalUpload(uploadId)
            return
        }

        if let scanId = passedSheetScanId {
            // playlist items from before uploads moved onto the device point at a server-side scan
            loadedDiscoverSong = nil
            if let upload = LocalSheetLibrary.shared.upload(scanId: scanId) {
                sourceContext = .localUpload(upload.id)
                loadSheetDataFromLocalUpload(upload.id)
            } else {
                showError(message: "This upload isn't on this device.\nUpload the sheet again to practise it here.")
            }
            return
        }

        if let trackId = passedTrackId, let songId = UUID(uuidString: trackId) {
            sourceContext = .discoverSongId(songId)
            loadSheetDataFromSong(songId: songId)
            return
        }

        if let songTitle = passedSongTitle, let artist = passedArtist {
            sourceContext = .discoverSongMetadata(title: songTitle, artist: artist)
            loadSheetDataFromSongMetadata(title: songTitle, artist: artist)
            return
        }

        sourceContext = .unknown
        debugLog("[SongDetail] ❌ neither scanId nor discover song identity available")
        showError()
    }

    private func loadSheetDataFromLocalUpload(_ id: UUID) {
        Task {
            let library = LocalSheetLibrary.shared
            guard let upload = await library.waitForConversion(id: id) else {
                showError(message: "This upload is no longer on this device.")
                return
            }
            guard upload.status == .completed else {
                showError(message: upload.errorMessage ?? "This sheet couldn't be converted.")
                return
            }
            originalPDF = library.inputPDF(id: id).flatMap { PDFDocument(data: $0) }
            labeledPDF = library.labeledPDF(id: id).flatMap { PDFDocument(data: $0) }
            if let json = library.scoreJSON(id: id), isValidScoreJSON(json) { sheetMusicJSON = json }
            if let doc = segmentControl.selectedSegmentIndex == 0 ? originalPDF : labeledPDF {
                showPDF(doc)
            } else {
                showError()
            }
        }
    }

    private func loadSheetDataFromSong(songId: UUID) {
        Task {
            do {
                if let song = try await fetchDiscoverSong(songId: songId) {
                    await loadDiscoverSongAssets(song)
                    return
                }

                debugLog("[SongDetail] ℹ️ no discover song found for trackId=\(songId.uuidString), falling back to title/artist")

                if let song = try await fetchDiscoverSongFromMetadata() {
                    if let title = passedSongTitle, let artist = passedArtist {
                        await MainActor.run {
                            self.sourceContext = .discoverSongMetadata(title: title, artist: artist)
                        }
                    }
                    await loadDiscoverSongAssets(song)
                    return
                }

                debugLog("[SongDetail] ❌ no discover song found for trackId or metadata fallback")
                await MainActor.run { self.showError() }
            } catch {
                debugLog("[SongDetail] ❌ load discover song sheet data error: \(error)")
                await MainActor.run { self.showError() }
            }
        }
    }

    private func loadSheetDataFromSongMetadata(title: String, artist: String) {
        Task {
            do {
                guard let song = try await fetchDiscoverSong(title: title, artist: artist) else {
                    debugLog("[SongDetail] ❌ no discover song found for title=\(title) artist=\(artist)")
                    await MainActor.run { self.showError() }
                    return
                }

                await loadDiscoverSongAssets(song)
            } catch {
                debugLog("[SongDetail] ❌ discover song metadata lookup failed: \(error)")
                await MainActor.run { self.showError() }
            }
        }
    }

    private func fetchDiscoverSong(songId: UUID) async throws -> Song? {
        let songs: [Song] = try await supabase
            .from("songs")
            .select()
            .eq("id", value: songId.uuidString)
            .limit(1)
            .execute()
            .value

        return songs.first
    }

    private func fetchDiscoverSong(title: String, artist: String) async throws -> Song? {
        let songs: [Song] = try await supabase
            .from("songs")
            .select()
            .eq("title", value: title)
            .eq("composer", value: artist)
            .limit(1)
            .execute()
            .value

        return songs.first
    }

    private func fetchDiscoverSongFromMetadata() async throws -> Song? {
        guard let title = passedSongTitle, let artist = passedArtist else {
            return nil
        }

        return try await fetchDiscoverSong(title: title, artist: artist)
    }

    private func loadDiscoverSongAssets(_ song: Song) async {
        await MainActor.run {
            self.loadedDiscoverSong = song
        }

        async let originalTask: Void = fetchOriginalPDFFromSong(song)
        async let labeledTask: Void = fetchLabeledPDFFromSong(song)
        async let jsonTask: Void = fetchOutputJSONFromSong(song)
        _ = await (originalTask, labeledTask, jsonTask)
    }

    private func loadSelectedSegmentFromCurrentSource(isOriginal: Bool) async {
        switch sourceContext {
        case .localUpload(let id):
            let library = LocalSheetLibrary.shared
            if let doc = (isOriginal ? library.inputPDF(id: id) : library.labeledPDF(id: id)).flatMap({ PDFDocument(data: $0) }) {
                if isOriginal { originalPDF = doc } else { labeledPDF = doc }
                showPDF(doc)
            } else {
                showError()
            }

        case .discoverSongId(let songId):
            var resolvedSong = loadedDiscoverSong
            if resolvedSong == nil {
                resolvedSong = try? await fetchDiscoverSong(songId: songId)
            }

            if let song = resolvedSong {
                await MainActor.run { self.loadedDiscoverSong = song }
                if isOriginal {
                    await fetchOriginalPDFFromSong(song)
                } else {
                    await fetchLabeledPDFFromSong(song)
                }
            } else if let fallbackSong = try? await fetchDiscoverSongFromMetadata() {
                await MainActor.run {
                    self.loadedDiscoverSong = fallbackSong
                    if let title = self.passedSongTitle, let artist = self.passedArtist {
                        self.sourceContext = .discoverSongMetadata(title: title, artist: artist)
                    }
                }
                if isOriginal {
                    await fetchOriginalPDFFromSong(fallbackSong)
                } else {
                    await fetchLabeledPDFFromSong(fallbackSong)
                }
            } else {
                await MainActor.run { self.showError() }
            }

        case .discoverSongMetadata(let title, let artist):
            var resolvedSong = loadedDiscoverSong
            if resolvedSong == nil {
                resolvedSong = try? await fetchDiscoverSong(title: title, artist: artist)
            }

            if let song = resolvedSong {
                await MainActor.run { self.loadedDiscoverSong = song }
                if isOriginal {
                    await fetchOriginalPDFFromSong(song)
                } else {
                    await fetchLabeledPDFFromSong(song)
                }
            } else {
                await MainActor.run { self.showError() }
            }

        case .unknown:
            await MainActor.run { self.showError() }
        }
    }

    private func isValidScoreJSON(_ json: [String: Any]) -> Bool {
        if json["score-partwise"] != nil { return true }
        if json["measure"] != nil { return true }
        func findMeasure(in dict: [String: Any]) -> Bool {
            if dict["measure"] != nil { return true }
            for value in dict.values {
                if let sub = value as? [String: Any], findMeasure(in: sub) { return true }
                else if let arr = value as? [[String: Any]] {
                    for item in arr { if findMeasure(in: item) { return true } }
                }
            }
            return false
        }
        return findMeasure(in: json)
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
            throw NSError(
                domain: "PlaylistSongDetail",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Remote asset fetch failed with status \(statusCode)"]
            )
        }
        return data
    }

    private func fetchOriginalPDFFromSong(_ song: Song) async {
        guard let originalPath = song.originalPdfPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !originalPath.isEmpty else {
            debugLog("[SongDetail] ℹ️ No original PDF path for discover song \(song.id)")
            return
        }

        do {
            let data = try await fetchRemoteData(from: originalPath, fallbackBucket: "pdf_uploads")
            guard let doc = PDFDocument(data: data), doc.pageCount > 0 else {
                await MainActor.run { self.showError() }
                return
            }
            await MainActor.run {
                self.originalPDF = doc
                if self.segmentControl.selectedSegmentIndex == 0 {
                    self.showPDF(doc)
                }
            }
        } catch {
            debugLog("[SongDetail] ❌ discover original PDF fetch error: \(error)")
            await MainActor.run {
                if self.segmentControl.selectedSegmentIndex == 0 {
                    self.showError()
                }
            }
        }
    }

    private func fetchLabeledPDFFromSong(_ song: Song) async {
        guard let pdfSource = song.discoverPDFSource else {
            debugLog("[SongDetail] ℹ️ No labeled PDF source for discover song \(song.id)")
            await MainActor.run {
                if self.segmentControl.selectedSegmentIndex == 1 {
                    self.showError()
                }
            }
            return
        }

        do {
            let data = try await fetchRemoteData(from: pdfSource.rawValue, fallbackBucket: pdfSource.fallbackBucket)
            guard let doc = PDFDocument(data: data), doc.pageCount > 0 else {
                await MainActor.run { self.showError() }
                return
            }
            await MainActor.run {
                self.labeledPDF = doc
                if self.segmentControl.selectedSegmentIndex == 1 {
                    self.showPDF(doc)
                }
            }
        } catch {
            debugLog("[SongDetail] ❌ discover labeled PDF fetch error: \(error)")
            await MainActor.run {
                if self.segmentControl.selectedSegmentIndex == 1 {
                    self.showError()
                }
            }
        }
    }

    private func fetchOutputJSONFromSong(_ song: Song) async {
        let jsonSources = song.discoverJSONSources(
            prefersPublicSource: GuestSessionManager.shared.isGuest()
        )

        guard !jsonSources.isEmpty else {
            debugLog("[SongDetail] ℹ️ No JSON source for discover song \(song.id)")
            return
        }

        for jsonSource in jsonSources {
            do {
                let data = try await fetchRemoteData(from: jsonSource.rawValue, fallbackBucket: jsonSource.fallbackBucket)
                guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      isValidScoreJSON(parsed) else {
                    debugLog("[SongDetail] discover JSON invalid for song \(song.id) from \(jsonSource.rawValue)")
                    continue
                }
                await MainActor.run {
                    self.sheetMusicJSON = parsed
                }
                return
            } catch {
                debugLog("[SongDetail] ❌ discover JSON fetch error from \(jsonSource.rawValue): \(error)")
            }
        }
    }

    // MARK: - PDF Display
    private func showPDF(_ doc: PDFDocument) {
        pdfView.document = doc
        pdfView.isHidden = false

        if let page = doc.page(at: 0) {
            let pageRect  = page.bounds(for: pdfView.displayBox)
            let pageRatio = pageRect.height / pageRect.width
            let viewWidth = view.bounds.width - 32
            let newHeight = max(300, viewWidth * pageRatio)
            pdfHeightConstraint?.constant = newHeight
            UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
        }

        pdfView.layoutIfNeeded()
        if let p = doc.page(at: 0) { pdfView.go(to: p) }
        pdfSkeleton.hide()
        errorLabel.isHidden = true
    }

    private func showError() {
        pdfSkeleton.hide()
        pdfView.isHidden = true
        errorLabel.isHidden = false
    }

    private func showError(message: String) {
        errorLabel.text = message
        showError()
    }

    @objc private func didTapPDF() {
        guard let doc = segmentControl.selectedSegmentIndex == 0 ? originalPDF : labeledPDF else { return }
        let vc = MaximizeUploadPageViewController()
        vc.pdfDocument = doc
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
}
