//
//  DiscoverSongPreviewViewController.swift
//  Re-Hearse
//
//  Intermediate preview screen shown when a song is tapped in Discover.
//  Uses the converted PDF/JSON already stored on the `songs` table.
//

import UIKit
import PDFKit

final class DiscoverSongPreviewViewController: UIViewController {

    // MARK: - Passed Data

    var song: Song?
    var songImage: UIImage?

    // MARK: - Private State

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    private var loadedPDFData: Data?
    private var uploadPopup: UploadQuizPopup?
    private var recentPlayTask: Task<Void, Never>?
    private var pdfLoadTask: Task<Void, Never>?
    private var discoveryUploadTask: Task<Void, Never>?

    // MARK: - UI

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var cardView: UIView = {
        let v = UIView()
        v.backgroundColor = ComponentColors.SongDetailScreen.sheetMusicBackground
        v.layer.cornerRadius = 20
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.08
        v.layer.shadowRadius = 12
        v.layer.shadowOffset = CGSize(width: 0, height: 4)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var songTitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 20, weight: .bold)
        l.textAlignment = .center
        l.textColor = ComponentColors.SongDetailScreen.songTitle
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var sheetCardView: UIView = {
        let v = UIView()
        v.backgroundColor = ComponentColors.SongDetailScreen.sheetMusicBackground
        v.layer.cornerRadius = 16
        v.layer.borderWidth = 0.5
        v.layer.borderColor = UIColor.separator.cgColor
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(sheetCardTapped))
        v.addGestureRecognizer(tap)
        return v
    }()

    private lazy var pdfView: PDFView = {
        let pv = PDFView()
        pv.autoScales = true
        pv.displayMode = .singlePage
        pv.backgroundColor = ComponentColors.SongDetailScreen.sheetMusicBackground
        pv.isUserInteractionEnabled = false
        pv.translatesAutoresizingMaskIntoConstraints = false
        return pv
    }()

    private lazy var pdfSpinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private lazy var pdfErrorLabel: UILabel = {
        let l = UILabel()
        l.text = "Sheet music unavailable"
        l.font = .systemFont(ofSize: 14)
        l.textColor = SemanticColors.Text.secondary
        l.textAlignment = .center
        l.numberOfLines = 2
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var getConvertedButton: UIButton = {
        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = ComponentColors.HomeScreen.actionButtonFill
        cfg.baseForegroundColor = ComponentColors.SongDetailScreen.primaryActionText
        cfg.cornerStyle = .large
        var title = AttributedString("Open Converted")
        title.font = .systemFont(ofSize: 18, weight: .bold)
        cfg.attributedTitle = title
        let btn = UIButton(configuration: cfg)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // MARK: - Lifecycle

    init() {
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.hidesBottomBarWhenPushed = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.DiscoverScreen.background

        setupNavBar()
        setupLayout()
        applyData()
        loadPDF()

        if let songId = song?.id {
            recentPlayTask = Task { [weak self] in
                do {
                    try await RecentPlayService.shared.recordPlay(songId: songId)
                } catch {
                    print("[SongPreview] Failed to record play: \(error)")
                }
                self?.recentPlayTask = nil
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)

        if loadedPDFData == nil, previewImageView.image == nil, pdfLoadTask == nil {
            loadPDF()
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

    // MARK: - NavBar

    private func setupNavBar() {
        title = "Practice"
        navigationController?.navigationBar.isHidden = false
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = NavigationBarHelper.createCustomBackButton(target: self, action: #selector(backAction))
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

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(cardView)
        cardView.addSubview(songTitleLabel)
        cardView.addSubview(sheetCardView)
        sheetCardView.addSubview(previewImageView)
        sheetCardView.addSubview(pdfSpinner)
        sheetCardView.addSubview(pdfErrorLabel)

        contentView.addSubview(getConvertedButton)

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

            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            songTitleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            songTitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            songTitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            sheetCardView.topAnchor.constraint(equalTo: songTitleLabel.bottomAnchor, constant: 14),
            sheetCardView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            sheetCardView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            sheetCardView.heightAnchor.constraint(equalToConstant: 480),
            sheetCardView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),

            pdfView.topAnchor.constraint(equalTo: sheetCardView.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: sheetCardView.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: sheetCardView.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: sheetCardView.bottomAnchor),

            pdfSpinner.centerXAnchor.constraint(equalTo: sheetCardView.centerXAnchor),
            pdfSpinner.centerYAnchor.constraint(equalTo: sheetCardView.centerYAnchor),

            pdfErrorLabel.centerXAnchor.constraint(equalTo: sheetCardView.centerXAnchor),
            pdfErrorLabel.centerYAnchor.constraint(equalTo: sheetCardView.centerYAnchor),
            pdfErrorLabel.leadingAnchor.constraint(equalTo: sheetCardView.leadingAnchor, constant: 16),
            pdfErrorLabel.trailingAnchor.constraint(equalTo: sheetCardView.trailingAnchor, constant: -16),

            getConvertedButton.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 24),
            getConvertedButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            getConvertedButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            getConvertedButton.heightAnchor.constraint(equalToConstant: 54),
            getConvertedButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
        ])

        getConvertedButton.addTarget(self, action: #selector(getConvertedTapped), for: .touchUpInside)
        sheetCardView.isUserInteractionEnabled = true
    }

    // MARK: - Populate

    private func applyData() {
        songTitleLabel.text = song?.title ?? "Song name"
        setButtonLoading(false)
    }

    // MARK: - Remote Asset Helpers

    private func resolvedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        if trimmed.hasPrefix("/") {
            return ReHersAPI.url(path: trimmed)
        }

        return nil
    }

    private func fetchRemoteData(from rawValue: String) async throws -> Data {
        guard let url = resolvedURL(from: rawValue) else {
            throw AssetError.missingPDF
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        let isBackendURL = rawValue.hasPrefix("/") || url.absoluteString.hasPrefix(ReHersAPI.baseURLString)
        if isBackendURL, let token = try? await SupabaseManager.shared.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let session: URLSession = isBackendURL ? ReHersPinnedSession.shared : URLSession.shared
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(statusCode) else {
            throw AssetError.remoteFetchFailed(statusCode)
        }
        return data
    }

    // MARK: - PDF Loading

    private func loadPDF() {
        pdfLoadTask?.cancel()
        pdfSpinner.startAnimating()
        pdfView.isHidden = true
        pdfErrorLabel.isHidden = true

        Task {
            let sheetURL = song?.labeledPdfPath ?? song?.sheetUrl
            guard let sheetURL, !sheetURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                await MainActor.run { self.showPDFError() }
                return
            }

            do {
                let data = try await fetchRemoteData(from: sheetURL)
                if let doc = PDFDocument(data: data), doc.pageCount > 0 {
                    await MainActor.run { self.renderPDF(doc) }
                } else {
                    await MainActor.run { self.showPDFError() }
                }
            } catch {
                print("[DiscoverPreview] loadPDF error: \(error)")
                await MainActor.run { self.showPDFError() }
            }
            await MainActor.run {
                self.showPDFError()
                self.pdfLoadTask = nil
            }
        }
    }

    private func renderPDF(_ doc: PDFDocument) {
        loadedPDF = doc
        pdfView.document = doc
        pdfView.isHidden = false
        pdfSpinner.stopAnimating()
        if let p = doc.page(at: 0) {
            pdfView.go(to: p)
        }
    }

    private func showPDFError() {
        pdfSpinner.stopAnimating()
        pdfView.isHidden = true
        pdfErrorLabel.isHidden = false
    }

    // MARK: - Actions

    @objc private func sheetCardTapped() {
        NavigationBarHelper.animateButtonPress(sheetCardView) { [weak self] in
            guard let self, let doc = self.loadedPDF else { return }
            let vc = MaximizeUploadPageViewController()
            vc.pdfData = pdfData
            vc.pdfDocument = doc
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true)
        }
    }

    @objc private func getConvertedTapped() {
        NavigationBarHelper.animateButtonPress(getConvertedButton) { [weak self] in
            guard let self, let song = self.song else { return }
            let convertedPDFURL = song.labeledPdfPath ?? song.sheetUrl
            guard convertedPDFURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                self.presentErrorAlert("This song does not have a converted sheet URL yet.")
                return
            }

            await MainActor.run {
                self.discoveryUploadTask = nil
            }
        }
    }

    // MARK: - Step 1: Resolve PDF Data

    private func resolvePDFData() async throws -> Data {
        let candidates = await buildPDFCandidates()
        guard !candidates.isEmpty else { throw ConvertError.noPDFSource }

        for url in candidates {
            if let (data, resp) = try? await URLSession.shared.data(from: url),
               (200...299).contains((resp as? HTTPURLResponse)?.statusCode ?? 0),
               !data.isEmpty {
                return data
            }
        }
        throw ConvertError.pdfDownloadFailed
    }

    // MARK: - Step 2+3: Upload Pipeline (mirrors UploadScreen.saveUploadToDatabase)

    private func runUploadPipeline(pdfData: Data) async throws {
        guard let uidStr = await currentUserId(), let userId = UUID(uuidString: uidStr) else {
            throw ConvertError.invalidUser
        }
        guard let token = await authToken() else {
            throw ConvertError.missingToken
        }

        let fileName = generateFilename(for: song?.title)

        let api = try await callConversionAPI(
            imageData: pdfData, fileName: fileName, fileType: "application/pdf", token: token)

        guard let jobIdStr = api["job_id"] as? String,
              let jobId = UUID(uuidString: jobIdStr) else { throw ConvertError.badAPIResponse }

        let apiUidStr = uidStr.lowercased()
        let outputURL = "\(ReHersAPI.baseURLString)/sheets/\(jobIdStr.lowercased())"

        var jsonDict: [String: Any] = [
            "uploaded_at":       ISO8601DateFormatter().string(from: Date()),
            "title":             song?.title ?? fileName,
            "original_filename": fileName,
            "job_id":            jobIdStr,
            "user_id":           apiUidStr,
            "output_url":        outputURL,
            "file_size_bytes":   pdfData.count
        ]
        let protectedKeys: Set<String> = ["job_id", "user_id", "output_url", "title", "status"]
        for (k, v) in api where !protectedKeys.contains(k) { jsonDict[k] = v }

        let existingScans: [ScanRecord] = try await supabase.from("scans").select()
            .eq("user_id", value: userId)
            .like("json_data->>'job_id'", pattern: "%\(jobIdStr)%")
            .execute().value

        if existingScans.isEmpty {
            let ins = ScanInsert(
                userId: userId, jsonData: AnyCodable(jsonDict),
                processingId: jobIdStr, status: "pending",
                originalFilename: fileName, fileType: "application/pdf",
                processedAt: ISO8601DateFormatter().string(from: Date()))
            // Fire-and-forget insert — we don't need the returned record
            try await supabase.from("scans").insert(ins).execute()
        } else if let existing = existingScans.first {
            let upd = ScanUpdate(
                jsonData: AnyCodable(jsonDict), status: "pending",
                processedAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date()))
            try await supabase.from("scans").update(upd)
                .eq("id", value: Int(existing.id)).execute()
        }

        uploadPopup?.updateProgress(0.9)
        
        await MainActor.run {
            self.releasePDFResources()
            let vc       = UploadPageNextViewController()
            vc.jobId     = jobId
            vc.resultURL = outputURL
            vc.onDataReady = { [weak self] in
                self?.uploadPopup?.notifyUploadComplete()
            }

            let vc = DiscoverSongDetailViewController()
            vc.song = song
            vc.passedImage = self.songImage
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    // MARK: - Conversion API (identical to UploadScreen.callConversionAPI)

    private func callConversionAPI(imageData: Data, fileName: String,
                                   fileType: String, token: String) async throws -> [String: Any] {
        guard let url = ReHersAPI.url(path: "/convert") else {
            throw ConvertError.noResponse
        }
        let boundary = UUID().uuidString
        var req      = URLRequest(url: url)
        req.httpMethod          = "POST"
        req.timeoutInterval     = 60
        if #available(iOS 14.5, *) {
            req.assumesHTTP3Capable = false
        }
        req.setValue("Bearer \(token)",                            forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendStr("--\(boundary)\r\n")
        body.appendStr("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.appendStr("Content-Type: \(fileType)\r\n\r\n")
        body.append(imageData)
        body.appendStr("\r\n--\(boundary)--\r\n")
        req.httpBody = body

        let (data, response) = try await ReHersPinnedSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ConvertError.noResponse }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw ConvertError.apiError(http.statusCode, msg)
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        if let d = obj as? [String: Any]                    { return d }
        if let a = obj as? [[String: Any]], let f = a.first { return f }
        return ["api_response": obj, "status": "success"]
    }

    // MARK: - Auth Helpers (mirrors UploadScreen)

    private func currentUserId() async -> String? {
        do    { return try await SupabaseManager.shared.currentUserId() }
        catch { debugLog("[Auth] authentication failed"); return nil }
    }

    private func authToken() async -> String? {
        do    { return try await SupabaseManager.shared.accessToken() }
        catch { debugLog("[Auth] authentication failed"); return nil }
    }

    // MARK: - UI Helpers

    private func setButtonLoading(_ loading: Bool) {
        getConvertedButton.isEnabled = !loading
        var cfg = getConvertedButton.configuration ?? UIButton.Configuration.filled()
        let convertedPDFURL = song?.labeledPdfPath ?? song?.sheetUrl
        let baseTitle = (convertedPDFURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? "Open Converted"
            : "Converted Missing"
        var t = AttributedString(loading ? "Opening…" : baseTitle)
        t.font = .systemFont(ofSize: 18, weight: .bold)
        cfg.attributedTitle = t
        cfg.showsActivityIndicator = loading
        getConvertedButton.configuration = cfg
    }

    private func cancelPendingTasks() {
        recentPlayTask?.cancel()
        recentPlayTask = nil

        pdfLoadTask?.cancel()
        pdfLoadTask = nil

        discoveryUploadTask?.cancel()
        discoveryUploadTask = nil
    }

    private func releasePDFResources() {
        pdfSpinner.stopAnimating()
        previewImageView.image = nil
        previewImageView.isHidden = true
        loadedPDFData = nil
    }

    private static func renderPDFPreviewImage(from data: Data, maxDimension: CGFloat = 1024) -> UIImage? {
        autoreleasepool {
            guard let provider = CGDataProvider(data: data as CFData),
                  let document = CGPDFDocument(provider),
                  let page = document.page(at: 1) else {
                return nil
            }

            let pageRect = page.getBoxRect(.mediaBox)
            guard pageRect.width > 0, pageRect.height > 0 else { return nil }

            let scale = min(maxDimension / max(pageRect.width, pageRect.height), 2.0)
            let width = max(Int(pageRect.width * scale), 1)
            let height = max(Int(pageRect.height * scale), 1)
            let targetRect = CGRect(x: 0, y: 0, width: width, height: height)

            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return nil
            }

            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(targetRect)
            context.saveGState()
            context.concatenate(page.getDrawingTransform(.mediaBox, rect: targetRect, rotate: 0, preserveAspectRatio: true))
            context.drawPDFPage(page)
            context.restoreGState()

            guard let cgImage = context.makeImage() else { return nil }
            return UIImage(cgImage: cgImage)
        }
    }

    private func generateFilename(for title: String?) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HHmmss"
        let base = title?.replacingOccurrences(of: " ", with: "_") ?? "SheetMusic"
        return "\(base)_\(f.string(from: Date())).pdf"
    }

    private func presentErrorAlert(_ message: String) {
        let a = UIAlertController(title: "Converted Sheet Unavailable", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    private enum AssetError: LocalizedError {
        case missingPDF
        case remoteFetchFailed(Int)

        var errorDescription: String? {
            switch self {
            case .missingPDF:
                return "This song has no converted sheet URL attached."
            case .remoteFetchFailed(let code):
                return "Failed to fetch converted asset (HTTP \(code))."
            }
        }
    }
}
