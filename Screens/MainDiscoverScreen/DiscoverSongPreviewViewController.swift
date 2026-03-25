//
//  DiscoverSongPreviewViewController.swift
//  Re-Hearse
//
//  Intermediate preview screen shown when a song is tapped in Discover.
//  "Get Converted" reuses the EXACT same upload pipeline as UploadScreen
//  (callConversionAPI → scans upsert → push UploadPageNextViewController).
//

import UIKit
import PDFKit
import Supabase
import Auth
internal import PostgREST

final class DiscoverSongPreviewViewController: UIViewController, UploadQuizPopupDelegate {

    // MARK: - Passed Data

    var song: Song?
    var songImage: UIImage?

    // MARK: - Private State

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    private var loadedPDF: PDFDocument?
    private var uploadPopup: UploadQuizPopup?

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
        v.backgroundColor     = ComponentColors.SongDetailScreen.sheetMusicBackground
        v.layer.cornerRadius  = 20
        v.layer.shadowColor   = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.08
        v.layer.shadowRadius  = 12
        v.layer.shadowOffset  = CGSize(width: 0, height: 4)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var songTitleLabel: UILabel = {
        let l = UILabel()
        l.font          = .systemFont(ofSize: 20, weight: .bold)
        l.textAlignment = .center
        l.textColor     = ComponentColors.SongDetailScreen.songTitle
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var sheetCardView: UIView = {
        let v = UIView()
        v.backgroundColor    = ComponentColors.SongDetailScreen.sheetMusicBackground
        v.layer.cornerRadius = 16
        v.layer.borderWidth  = 0.5
        v.layer.borderColor  = UIColor.separator.cgColor
        v.clipsToBounds      = true
        v.translatesAutoresizingMaskIntoConstraints = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(sheetCardTapped))
        v.addGestureRecognizer(tap)
        return v
    }()

    private lazy var pdfView: PDFView = {
        let pv = PDFView()
        pv.autoScales               = true
        pv.displayMode              = .singlePage
        pv.backgroundColor          = ComponentColors.SongDetailScreen.sheetMusicBackground
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
        l.text          = "Sheet music unavailable"
        l.font          = .systemFont(ofSize: 14)
        l.textColor     = SemanticColors.Text.secondary
        l.textAlignment = .center
        l.numberOfLines = 2
        l.isHidden      = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var getConvertedButton: UIButton = {
        var cfg                 = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = ComponentColors.HomeScreen.actionButtonFill
        cfg.baseForegroundColor = ComponentColors.SongDetailScreen.primaryActionText
        cfg.cornerStyle         = .large
        var title               = AttributedString("Get Converted")
        title.font              = .systemFont(ofSize: 18, weight: .bold)
        cfg.attributedTitle     = title
        let btn                 = UIButton(configuration: cfg)
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

        // Record this song as recently played
        if let songId = song?.id {
            Task {
                do {
                    try await RecentPlayService.shared.recordPlay(songId: songId)
                } catch {
                    print("[SongPreview] ❌ Failed to record play: \(error)")
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - NavBar

    private func setupNavBar() {
        title = "Practice"
        navigationController?.navigationBar.isHidden = false
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        
        // Use custom circular back button in the nav bar for uniformity and to avoid overlapping issues
        navigationItem.leftBarButtonItem = NavigationBarHelper.createCustomBackButton(target: self, action: #selector(backAction))
    }

    @objc private func backAction() {
        // Find the button inside the custom view if possible, or just animate the view
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
        sheetCardView.addSubview(pdfView)
        sheetCardView.addSubview(pdfSpinner)
        sheetCardView.addSubview(pdfErrorLabel)

        contentView.addSubview(getConvertedButton)

        NSLayoutConstraint.activate([
            // Scroll
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Card
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            // Song title
            songTitleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            songTitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            songTitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            // Sheet music card directly below title
            sheetCardView.topAnchor.constraint(equalTo: songTitleLabel.bottomAnchor, constant: 14),
            sheetCardView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            sheetCardView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            sheetCardView.heightAnchor.constraint(equalToConstant: 480),
            sheetCardView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),

            // PDF
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

            // Get Converted button
            getConvertedButton.topAnchor.constraint(equalTo: cardView.bottomAnchor, constant: 24),
            getConvertedButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            getConvertedButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            getConvertedButton.heightAnchor.constraint(equalToConstant: 54),
            getConvertedButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
        ])

        getConvertedButton.addTarget(self, action: #selector(getConvertedTapped), for: .touchUpInside)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(sheetCardTapped))
        sheetCardView.addGestureRecognizer(tap)
        sheetCardView.isUserInteractionEnabled = true
    }

    // MARK: - Populate

    private func applyData() {
        songTitleLabel.text = song?.title ?? "Song name"
    }

    // MARK: - PDF URL Construction

    private func buildPDFCandidates() async -> [URL] {
        guard let song else { return [] }

        var candidatePaths: [String] = []

        if let sheetURL = song.sheetUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sheetURL.isEmpty {
            candidatePaths.append(sheetURL)
            if sheetURL.hasPrefix("Sheets/") {
                candidatePaths.append(String(sheetURL.dropFirst("Sheets/".count)))
            }
        }

        let titlePath = song.title.hasSuffix(".pdf") ? song.title : "\(song.title).pdf"
        candidatePaths.append(titlePath)

        var candidates: [URL] = []
        var seenPaths = Set<String>()

        for path in candidatePaths where seenPaths.insert(path).inserted {
            if let signedURL = try? await supabase.storage
                .from("Sheets")
                .createSignedURL(path: path, expiresIn: 3600) {
                candidates.append(signedURL)
            }
        }

        return candidates
    }

    // MARK: - PDF Loading (preview only)

    private func loadPDF() {
        pdfSpinner.startAnimating()
        pdfView.isHidden       = true
        pdfErrorLabel.isHidden = true

        Task {
            let candidates = await buildPDFCandidates()
            guard !candidates.isEmpty else {
                await MainActor.run { self.showPDFError() }
                return
            }

            for url in candidates {
                if let (data, resp) = try? await URLSession.shared.data(from: url),
                   (200...299).contains((resp as? HTTPURLResponse)?.statusCode ?? 0),
                   let doc = PDFDocument(data: data), doc.pageCount > 0 {
                    await MainActor.run { self.renderPDF(doc) }
                    return
                }
            }
            await MainActor.run { self.showPDFError() }
        }
    }

    private func renderPDF(_ doc: PDFDocument) {
        loadedPDF        = doc
        pdfView.document = doc
        pdfView.isHidden = false
        pdfSpinner.stopAnimating()
        if let p = doc.page(at: 0) { pdfView.go(to: p) }
    }

    private func showPDFError() {
        pdfSpinner.stopAnimating()
        pdfView.isHidden       = true
        pdfErrorLabel.isHidden = false
    }

    // MARK: - Actions

    @objc private func sheetCardTapped() {
        NavigationBarHelper.animateButtonPress(sheetCardView) { [weak self] in
            guard let self = self else { return }
            guard let doc = self.loadedPDF else { return }
            let vc = MaximizeUploadPageViewController()
            vc.pdfDocument = doc
            vc.modalPresentationStyle = .fullScreen
            self.present(vc, animated: true)
        }
    }

    // MARK: - Get Converted (reuses UploadScreen pipeline 1:1)

    @objc private func getConvertedTapped() {
        NavigationBarHelper.animateButtonPress(getConvertedButton) { [weak self] in
            guard let self = self else { return }
            // Instantiate and present the popup
            let popup = UploadQuizPopup()
            popup.delegate = self
            popup.modalPresentationStyle = .overFullScreen
            popup.modalTransitionStyle = .crossDissolve
            self.uploadPopup = popup
            
            self.present(popup, animated: true) { [weak self] in
                self?.startDiscoveryUpload()
            }
        }
    }

    private func startDiscoveryUpload() {
        Task {
            do {
                uploadPopup?.updateProgress(0.1)
                let pdfData = try await resolvePDFData()
                uploadPopup?.updateProgress(0.3)
                try await runUploadPipeline(pdfData: pdfData)
            } catch {
                await MainActor.run {
                    self.uploadPopup?.dismiss(animated: true) {
                        self.uploadPopup = nil
                        self.presentErrorAlert(error.localizedDescription)
                    }
                }
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
            let vc       = UploadPageNextViewController()
            vc.jobId     = jobId
            vc.resultURL = outputURL
            vc.onDataReady = { [weak self] in
                self?.uploadPopup?.notifyUploadComplete()
            }
            print("[Convert] → UploadPageNextVC jobId=\(jobId.uuidString)")
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
        req.assumesHTTP3Capable = false
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
        catch { print("[Auth] authentication failed"); return nil }
    }

    private func authToken() async -> String? {
        do    { return try await SupabaseManager.shared.accessToken() }
        catch { print("[Auth] authentication failed"); return nil }
    }

    // MARK: - UI Helpers

    private func setButtonLoading(_ loading: Bool) {
        getConvertedButton.isEnabled = !loading
        var cfg = getConvertedButton.configuration ?? UIButton.Configuration.filled()
        var t   = AttributedString(loading ? "Converting…" : "Get Converted")
        t.font  = .systemFont(ofSize: 18, weight: .bold)
        cfg.attributedTitle        = t
        cfg.showsActivityIndicator = loading
        getConvertedButton.configuration = cfg
    }

    private func generateFilename(for title: String?) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HHmmss"
        let base = title?.replacingOccurrences(of: " ", with: "_") ?? "SheetMusic"
        return "\(base)_\(f.string(from: Date())).pdf"
    }

    private func presentErrorAlert(_ message: String) {
        let a = UIAlertController(title: "Conversion Failed", message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    // MARK: - Error Types

    enum ConvertError: LocalizedError {
        case noPDFSource, pdfDownloadFailed
        case invalidUser, missingToken, badAPIResponse, noResponse
        case apiError(Int, String)
        var errorDescription: String? {
            switch self {
            case .noPDFSource:            return "This song has no sheet music file attached."
            case .pdfDownloadFailed:      return "Could not download the sheet music PDF."
            case .invalidUser:            return "Could not retrieve your user ID."
            case .missingToken:           return "Could not retrieve authentication token."
            case .badAPIResponse:         return "Missing job_id in API response."
            case .noResponse:             return "No response received from the server."
            case .apiError(let c, let m): return "Server error \(c): \(m)"
            }
        }
    }

    // MARK: - Private Data Models

    private struct ScanRecord: Codable, Identifiable {
        let id: Int64; let userId: UUID; let jsonData: AnyCodable?
        let processingId: String?; let status: String?
        let originalFilename: String?; let fileType: String?
        let processedAt: String?; let updatedAt: String?
        enum CodingKeys: String, CodingKey {
            case id; case userId = "user_id"; case jsonData = "json_data"
            case processingId = "processing_id"; case status
            case originalFilename = "original_filename"; case fileType = "file_type"
            case processedAt = "processed_at"; case updatedAt = "updated_at"
        }
    }

    private struct ScanInsert: Encodable {
        let userId: UUID; let jsonData: AnyCodable; let processingId: String; let status: String
        let originalFilename: String?; let fileType: String?; let processedAt: String?
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"; case jsonData = "json_data"
            case processingId = "processing_id"; case status
            case originalFilename = "original_filename"; case fileType = "file_type"
            case processedAt = "processed_at"
        }
    }

    private struct ScanUpdate: Encodable {
        let jsonData: AnyCodable; let status: String; let processedAt: String; let updatedAt: String
        enum CodingKeys: String, CodingKey {
            case jsonData = "json_data"; case status
            case processedAt = "processed_at"; case updatedAt = "updated_at"
        }
    }

    private struct AnyCodable: Codable {
        let value: Any
        init(_ value: Any) { self.value = value }
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if      let b = try? c.decode(Bool.self)                 { value = b }
            else if let i = try? c.decode(Int.self)                  { value = i }
            else if let d = try? c.decode(Double.self)               { value = d }
            else if let s = try? c.decode(String.self)               { value = s }
            else if let a = try? c.decode([AnyCodable].self)         { value = a.map { $0.value } }
            else if let d = try? c.decode([String: AnyCodable].self) { value = d.mapValues { $0.value } }
            else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Cannot decode") }
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch value {
            case let b as Bool:          try c.encode(b)
            case let i as Int:           try c.encode(i)
            case let d as Double:        try c.encode(d)
            case let s as String:        try c.encode(s)
            case let a as [Any]:         try c.encode(a.map { AnyCodable($0) })
            case let d as [String: Any]: try c.encode(d.mapValues { AnyCodable($0) })
            default: throw EncodingError.invalidValue(
                value, .init(codingPath: c.codingPath, debugDescription: "Cannot encode"))
            }
        }
    }

    // MARK: - UploadQuizPopupDelegate
    func uploadQuizPopupDidClose(_ popup: UploadQuizPopup) {
        uploadPopup = nil
    }
}

// MARK: - Data Helper

private extension Data {
    mutating func appendStr(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}
