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
        case scan(scanId: Int64)
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
    private var cachedPDFPath: String?
    private var cachedJobId: UUID?
    private var sourceContext: SheetSourceContext = .unknown
    private var loadedDiscoverSong: Song?
    private var trackedPracticeSessionStartedAt: Date?

    // Polling (only used when result_url is genuinely not yet available)
    private var pollTask: Task<Void, Never>?
    private let maxPollAttempts = 20
    private let pollIntervalSeconds: UInt64 = 3

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
    private let loadingIndicator  = UIActivityIndicatorView(style: .medium)
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
        pollTask?.cancel()
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

        loadingIndicator.color = ComponentColors.SongDetailScreen.primaryActionFill
        loadingIndicator.hidesWhenStopped = true

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
                               pageLabel, pdfView, loadingIndicator, errorLabel, buttonStack]
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

            loadingIndicator.centerXAnchor.constraint(equalTo: pdfView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: pdfView.centerYAnchor),

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
        let shouldEnableActions = GuestSessionManager.shared.isGuest() || hasJSON
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
            loadingIndicator.startAnimating()
            Task {
                await loadSelectedSegmentFromCurrentSource(isOriginal: isOriginal)
            }
        }
    }

    // MARK: - Data Fetch

    /// Main entry point. Reads scan row → job row, then:
    ///   1. If result_url is already set → fetch labeled PDF directly from Supabase CDN (instant).
    ///   2. If not → poll until the backend sets it, then fetch from Supabase CDN.
    /// Output JSON is also fetched from the backend API concurrently (unchanged).
    private func loadSheetData() {
        pdfView.isHidden = true
        errorLabel.isHidden = true
        loadingIndicator.startAnimating()

        if let scanId = passedSheetScanId {
            sourceContext = .scan(scanId: scanId)
            loadedDiscoverSong = nil
            loadSheetDataFromScan(scanId)
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

    private func loadSheetDataFromScan(_ scanId: Int64) {
        Task {
            do {
                // ── Step 1: read scan row to get job_id ──────────────────────────
                struct ScanRow: Codable {
                    let jsonData: AnyCodable?
                    enum CodingKeys: String, CodingKey { case jsonData = "json_data" }
                }
                let scans: [ScanRow] = try await supabase.from("scans").select("json_data")
                    .eq("id", value: Int(scanId)).limit(1).execute().value

                guard let dict = scans.first?.jsonData?.value as? [String: Any],
                      let jobId = (dict["job_id"] as? String).flatMap(UUID.init) else {
                    debugLog("[SongDetail] ❌ Could not extract job_id from scan \(scanId)")
                    await MainActor.run { self.showError() }
                    return
                }

                debugLog("[SongDetail] ✓ jobId=\(jobId.uuidString)")

                // ── Step 2: read job row to get pdf_path + result_url ────────────
                struct JobRow: Decodable {
                    let pdfPath: String
                    let resultUrl: String?
                    enum CodingKeys: String, CodingKey {
                        case pdfPath = "pdf_path"; case resultUrl = "result_url"
                    }
                }
                let jobs: [JobRow] = try await supabase.from("jobs").select("pdf_path, result_url")
                    .eq("id", value: jobId).limit(1).execute().value

                guard let job = jobs.first else {
                    debugLog("[SongDetail] ❌ No job row found for jobId=\(jobId.uuidString)")
                    await MainActor.run { self.showError() }
                    return
                }

                debugLog("[SongDetail] job.result_url=\(job.resultUrl ?? "nil")")

                await MainActor.run {
                    self.cachedPDFPath = job.pdfPath
                    self.cachedJobId   = jobId
                }

                // ── Step 3: fetch labeled PDF + output JSON concurrently ─────────
                // fetchLabeledPDFWithPolling goes direct to Supabase CDN via
                // a signed URL — no Azure hop. It only polls when result_url is nil.
                async let pdfTask: Void  = fetchLabeledPDFWithPolling(
                    resultUrl: job.resultUrl, jobId: jobId)
                async let jsonTask: Void = fetchOutputJSON(jobId: jobId, pdfPath: job.pdfPath)
                _ = await (pdfTask, jsonTask)

            } catch {
                debugLog("[SongDetail] ❌ loadSheetData error: \(error)")
                await MainActor.run { self.showError() }
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
        case .scan:
            if isOriginal {
                await fetchOriginalPDF()
            } else {
                await fetchLabeledPDFWithPolling(resultUrl: nil, jobId: cachedJobId)
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

    // MARK: - Output JSON (Azure backend — unchanged)
    private func fetchOutputJSON(jobId: UUID, pdfPath: String) async {
        _ = pdfPath
        guard let token = try? await SupabaseManager.shared.accessToken(),
              let url = ReHersAPI.url(path: "/sheets/\(jobId.uuidString)") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await ReHersPinnedSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            debugLog("[SongDetail] fetchOutputJSON status=\(status)")
            guard status == 200 else { return }
            guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  isValidScoreJSON(parsed) else {
                debugLog("[SongDetail] fetchOutputJSON — not valid score JSON")
                return
            }
            await MainActor.run { self.sheetMusicJSON = parsed }
        } catch {
            debugLog("[SongDetail] fetchOutputJSON error: \(error)")
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

    // MARK: - Labeled PDF: fast path + poll fallback

    /// Entry point for labeled PDF.
    ///
    /// Fast path (result_url already set):
    ///   iOS → Supabase Storage CDN  (~1–2 s)
    ///
    /// Slow path (result_url nil — job still processing):
    ///   Poll jobs table until result_url appears, then take the fast path.
    ///   Never touches the Azure backend for the PDF bytes.
    private func fetchLabeledPDFWithPolling(resultUrl: String?, jobId: UUID?) async {
        guard let jId = jobId ?? cachedJobId else {
            debugLog("[SongDetail] ❌ no jobId for labeled PDF fetch")
            await MainActor.run { showError() }
            return
        }

        // ── Fast path: result_url is already available ───────────────────────────
        if let url = resultUrl, !url.isEmpty {
            debugLog("[SongDetail] result_url ready — going direct to Supabase CDN: \(url)")
            await fetchLabeledPDFFromStoragePath(url, jobId: jId)
            return
        }

        // ── Slow path: poll jobs table until result_url is populated ─────────────
        debugLog("[SongDetail] result_url nil — polling jobId=\(jId.uuidString)")

        pollTask = Task {
            struct JobPollRow: Decodable {
                let resultUrl: String?
                let status: String?
                enum CodingKeys: String, CodingKey {
                    case resultUrl = "result_url"; case status
                }
            }

            for attempt in 1...maxPollAttempts {
                if Task.isCancelled { debugLog("[SongDetail] poll cancelled"); return }

                do {
                    let rows: [JobPollRow] = try await supabase
                        .from("jobs").select("result_url, status")
                        .eq("id", value: jId).limit(1).execute().value

                    let status = rows.first?.status ?? "unknown"
                    let url    = rows.first?.resultUrl
                    debugLog("[SongDetail] poll \(attempt)/\(maxPollAttempts) status=\(status) url=\(url ?? "nil")")

                    if status == "failed" {
                        await MainActor.run { self.showError() }
                        return
                    }
                    // result_url is now populated → take fast path immediately
                    if let resolvedURL = url, !resolvedURL.isEmpty {
                        await fetchLabeledPDFFromStoragePath(resolvedURL, jobId: jId)
                        return
                    }
                } catch {
                    debugLog("[SongDetail] poll \(attempt) error: \(error)")
                }

                if attempt < maxPollAttempts {
                    try? await Task.sleep(nanoseconds: pollIntervalSeconds * 1_000_000_000)
                }
            }

            debugLog("[SongDetail] ❌ polling exhausted")
            await MainActor.run { self.showError() }
        }

        await pollTask?.value
    }

    /// Converts the raw result_url stored in the jobs table into a short-lived
    /// Supabase signed URL and downloads the PDF **directly from Supabase CDN**.
    ///
    /// The result_url stored by the backend is either:
    ///   • A bare storage path:  "uid/job-id/labeled.pdf"
    ///   • A full storage URL:   "https://<project>.supabase.co/storage/v1/object/public/labeled_pdfs/uid/job-id/labeled.pdf"
    ///
    /// We strip the bucket prefix in the full-URL case so we always pass a bare
    /// path to createSignedURL, which then hands us a fresh CDN-signed URL.
    ///
    ///   Before: iOS → Azure backend → Supabase Storage → Azure → iOS  (~8–12 s)
    ///   After:  iOS → Supabase Storage CDN                             (~1–2 s)
    private func fetchLabeledPDFFromStoragePath(_ rawURL: String, jobId: UUID) async {
        let bucketName = "pdf_uploads"
        let storagePath: String

        if let parsed = URL(string: rawURL), parsed.scheme != nil {
            // Full URL — strip known Supabase storage prefixes to get the bare path
            let prefixes = [
                "/object/public/\(bucketName)/",
                "/object/sign/\(bucketName)/",
                "/object/\(bucketName)/"
            ]
            if let prefix = prefixes.first(where: { rawURL.contains($0) }),
               let range = rawURL.range(of: prefix) {
                let raw = String(rawURL[range.upperBound...])
                // Strip any query string that may already be on an existing signed URL
                storagePath = raw.components(separatedBy: "?").first ?? raw
                debugLog("[SongDetail] extracted storage path: \(storagePath)")
            } else {
                // Unrecognised URL format — try fetching as-is (still hits Supabase CDN)
                debugLog("[SongDetail] ⚠️ unrecognised URL format, fetching as-is: \(rawURL)")
                await fetchAndCache(urlString: rawURL, isOriginal: false)
                return
            }
        } else {
            // Bare path (e.g. "uid/job-id/labeled.pdf")
            storagePath = rawURL
            debugLog("[SongDetail] bare storage path: \(storagePath)")
        }

        do {
            // Generate a 1-hour signed URL — this hits the Supabase CDN directly,
            // with no Azure backend involved at all.
            let signedURL = try await supabase.storage
                .from(bucketName)
                .createSignedURL(path: storagePath, expiresIn: 3600)
            debugLog("[SongDetail] ✓ signed URL ready — fetching from Supabase CDN")
            await fetchAndCache(urlString: signedURL.absoluteString, isOriginal: false)
        } catch {
            debugLog("[SongDetail] ❌ createSignedURL failed path=\(storagePath): \(error)")
            await MainActor.run { self.showError() }
        }
    }

    // MARK: - Original PDF (Supabase CDN — unchanged)
    private func fetchOriginalPDF() async {
        guard let path = cachedPDFPath else {
            debugLog("[SongDetail] ❌ fetchOriginalPDF — no cachedPDFPath")
            await MainActor.run { showError() }
            return
        }
        do {
            let signedURL = try await supabase.storage
                .from("pdf_uploads")
                .createSignedURL(path: path, expiresIn: 3600)
            await fetchAndCache(urlString: signedURL.absoluteString, isOriginal: true)
        } catch {
            debugLog("[SongDetail] ❌ fetchOriginalPDF createSignedURL failed: \(error)")
            await MainActor.run { showError() }
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
        guard let jsonSource = song.discoverJSONSource else {
            debugLog("[SongDetail] ℹ️ No JSON source for discover song \(song.id)")
            return
        }

        do {
            let data = try await fetchRemoteData(from: jsonSource.rawValue, fallbackBucket: jsonSource.fallbackBucket)
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  isValidScoreJSON(parsed) else {
                debugLog("[SongDetail] discover JSON invalid for song \(song.id)")
                return
            }
            await MainActor.run {
                self.sheetMusicJSON = parsed
            }
        } catch {
            debugLog("[SongDetail] ❌ discover JSON fetch error: \(error)")
        }
    }

    // MARK: - Generic fetch + cache

    /// Downloads a PDF from `urlString` and caches it.
    ///
    /// For Supabase signed URLs the Bearer token and pinned session are NOT needed
    /// (the signed URL itself is the credential). Only our own Azure backend URLs
    /// require the Bearer header + certificate pinning.
    private func fetchAndCache(urlString: String, isOriginal: Bool) async {
        guard let url = URL(string: urlString) else {
            debugLog("[SongDetail] ❌ invalid URL: \(urlString)")
            await MainActor.run { showError() }
            return
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 30

        // Only add Bearer + pinned session for our own Azure backend URLs.
        // Supabase signed URLs are self-credentialed — adding a Bearer header
        // would actually cause a 400 on some CDN edge nodes.
        let isBackendURL = urlString.hasPrefix(ReHersAPI.baseURLString)
        if isBackendURL, let token = try? await SupabaseManager.shared.accessToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let session: URLSession = isBackendURL ? ReHersPinnedSession.shared : URLSession.shared

        do {
            let (data, resp) = try await session.data(for: req)
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? -1
            debugLog("[SongDetail] fetchAndCache isOriginal=\(isOriginal) status=\(statusCode) bytes=\(data.count)")

            guard (200...299).contains(statusCode) else {
                debugLog("[SongDetail] ❌ non-2xx: \(statusCode)")
                await MainActor.run { self.showError() }
                return
            }
            guard let doc = PDFDocument(data: data), doc.pageCount > 0 else {
                debugLog("[SongDetail] ❌ not a valid PDF (bytes=\(data.count))")
                await MainActor.run { self.showError() }
                return
            }
            await MainActor.run {
                if isOriginal { self.originalPDF = doc } else { self.labeledPDF = doc }
                if isOriginal == (self.segmentControl.selectedSegmentIndex == 0) {
                    self.showPDF(doc)
                }
            }
        } catch {
            debugLog("[SongDetail] ❌ fetchAndCache error: \(error)")
            await MainActor.run { self.showError() }
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
        loadingIndicator.stopAnimating()
        errorLabel.isHidden = true
    }

    private func showError() {
        loadingIndicator.stopAnimating()
        pdfView.isHidden = true
        errorLabel.isHidden = false
    }

    @objc private func didTapPDF() {
        guard let doc = segmentControl.selectedSegmentIndex == 0 ? originalPDF : labeledPDF else { return }
        let vc = MaximizeUploadPageViewController()
        vc.pdfDocument = doc
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
}

// MARK: - AnyCodable
private struct AnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if      let v = try? c.decode(Bool.self)                 { value = v }
        else if let v = try? c.decode(Int.self)                  { value = v }
        else if let v = try? c.decode(Double.self)               { value = v }
        else if let v = try? c.decode(String.self)               { value = v }
        else if let v = try? c.decode([AnyCodable].self)         { value = v.map(\.value) }
        else if let v = try? c.decode([String: AnyCodable].self) { value = v.mapValues(\.value) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Cannot decode") }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let v as Bool:          try c.encode(v)
        case let v as Int:           try c.encode(v)
        case let v as Double:        try c.encode(v)
        case let v as String:        try c.encode(v)
        case let v as [Any]:         try c.encode(v.map { AnyCodable($0) })
        case let v as [String: Any]: try c.encode(v.mapValues { AnyCodable($0) })
        default: throw EncodingError.invalidValue(value, .init(codingPath: c.codingPath, debugDescription: "Cannot encode"))
        }
    }
}
