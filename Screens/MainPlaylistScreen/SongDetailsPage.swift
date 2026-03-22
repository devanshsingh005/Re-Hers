//
//  SongDetailsPage.swift
//  Re-Hearse_v1
//

import UIKit
import PDFKit
import Supabase
import Auth
import PostgREST

class PlaylistSongDetailViewController: UIViewController {

    // MARK: - Public Input
    var passedImage: UIImage?
    var passedSongTitle: String?
    var passedArtist: String?
    var passedSheetScanId: Int64?

    // MARK: - State
    private var labeledPDF: PDFDocument?
    private var originalPDF: PDFDocument?
    private var sheetMusicJSON: [String: Any]?
    private var cachedPDFPath: String?
    private var cachedJobId: UUID?

    // MARK: - Supabase
    private let projectID = "djqgmowfjxsnjdffdohw"
    private var publicBase: String { "https://\(projectID).supabase.co/storage/v1/object/public" }
    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - UI
    private let navBar           = TopNavBar.make(title: "")
    private let scrollView       = UIScrollView()
    private let contentView      = UIView()
    private let albumArt         = UIImageView()
    private let titleLabel       = UILabel()
    private let artistLabel      = UILabel()
    private let segmentControl   = UISegmentedControl(items: ["Original", "Labeled"])
    private let pageLabel        = UILabel()
    private let pdfView          = PDFView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel       = UILabel()
    private let playAlongButton  = UIButton(type: .system)
    private let animationButton  = UIButton(type: .system)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.SongDetailScreen.background
        navigationController?.navigationBar.isHidden = true
        setupNavBar()
        setupScrollView()
        buildUI()
        loadSheetData()
    }

    // MARK: - NavBar
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.isBackButtonVisible = true
        navBar.isChordIconVisible  = true
        navBar.isProfileVisible    = true
        navBar.isStreakVisible     = false
        navBar.isWelcomeTextHidden = true
        navBar.setTitle("")
        navBar.backAction    = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        navBar.chordAction   = { [weak self] in self?.navigationController?.pushViewController(ChordRecognitionViewController(), animated: true) }
        navBar.profileAction = { [weak self] in self?.navigationController?.pushViewController(UserProfileViewController(), animated: true) }
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
        ])
    }

    // MARK: - Scroll View
    private func setupScrollView() {
        [scrollView, contentView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
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
        // Use passedImage if provided, otherwise derive a stable placeholder from the song title
        albumArt.image = passedImage
            ?? trackImagePlaceholder(for: passedSongTitle ?? "")

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

        errorLabel.text = "Sheet music unavailable.\nTry opening this song from Uploads."
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.font = .systemFont(ofSize: 15)
        errorLabel.textColor = .secondaryLabel
        errorLabel.isHidden = true

        configure(playAlongButton, title: "Play Along", isPrimary: true)
        configure(animationButton,  title: "Animation",  isPrimary: false)
        playAlongButton.addTarget(self, action: #selector(openPlayAlong),  for: .touchUpInside)
        animationButton.addTarget(self,  action: #selector(openAnimation), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [playAlongButton, animationButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 26
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
            pdfView.heightAnchor.constraint(equalToConstant: 380),

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
    }

    private func configure(_ btn: UIButton, title: String, isPrimary: Bool) {
        btn.setTitle(title, for: .normal)
        btn.layer.cornerRadius = 25
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
        let nav = LandscapeNavigationController(rootViewController: PlayAlongViewController())
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func openAnimation() {
        configure(animationButton,  title: "Animation",  isPrimary: true)
        configure(playAlongButton, title: "Play Along", isPrimary: false)
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

    private func alert(_ msg: String) {
        let a = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    // MARK: - Segment
    @objc private func segmentChanged() {
        let isOriginal = segmentControl.selectedSegmentIndex == 0
        if let doc = isOriginal ? originalPDF : labeledPDF {
            showPDF(doc)
        } else {
            pdfView.isHidden = true; errorLabel.isHidden = true
            loadingIndicator.startAnimating()
            Task { isOriginal ? await fetchOriginalPDF() : await fetchLabeledPDF(resultUrl: nil, jobId: nil) }
        }
    }

    // MARK: - Data Fetch
    private func loadSheetData() {
        guard let scanId = passedSheetScanId else { errorLabel.isHidden = false; return }
        pdfView.isHidden = true; errorLabel.isHidden = true
        loadingIndicator.startAnimating()

        Task {
            do {
                struct ScanRow: Codable {
                    let jsonData: AnyCodable?
                    enum CodingKeys: String, CodingKey { case jsonData = "json_data" }
                }
                let scans: [ScanRow] = try await supabase.from("scans").select("json_data")
                    .eq("id", value: Int(scanId)).limit(1).execute().value

                guard let dict = scans.first?.jsonData?.value as? [String: Any],
                      let jobId = (dict["job_id"] as? String).flatMap(UUID.init) else {
                    await MainActor.run { self.showError() }; return
                }

                struct JobRow: Decodable {
                    let pdfPath: String
                    let resultUrl: String?
                    enum CodingKeys: String, CodingKey {
                        case pdfPath = "pdf_path"; case resultUrl = "result_url"
                    }
                }
                let jobs: [JobRow] = try await supabase.from("jobs").select("pdf_path, result_url")
                    .eq("id", value: jobId).limit(1).execute().value

                guard let job = jobs.first else { await MainActor.run { self.showError() }; return }

                await MainActor.run { self.cachedPDFPath = job.pdfPath; self.cachedJobId = jobId }

                async let pdfTask: Void  = fetchLabeledPDF(resultUrl: job.resultUrl, jobId: jobId)
                async let jsonTask: Void = fetchOutputJSON(jobId: jobId, pdfPath: job.pdfPath)
                _ = await (pdfTask, jsonTask)

            } catch {
                await MainActor.run { self.showError() }
            }
        }
    }

    private func fetchOutputJSON(jobId: UUID, pdfPath: String) async {
        let userId = pdfPath.components(separatedBy: "/").first ?? ""
        guard let url = URL(string: "\(publicBase)/sheet_data/\(userId)/\(jobId.uuidString.lowercased())/output.json"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        await MainActor.run { self.sheetMusicJSON = parsed }
    }

    private func fetchLabeledPDF(resultUrl: String?, jobId: UUID?) async {
        guard let jId = jobId ?? cachedJobId else { await MainActor.run { showError() }; return }
        let urlStr: String
        if let rel = resultUrl, !rel.isEmpty {
            urlStr = rel.hasPrefix("http") ? rel : "\(publicBase)/\(rel)"
        } else {
            let userId = (cachedPDFPath ?? "").components(separatedBy: "/").first ?? ""
            urlStr = "\(publicBase)/sheet_data/\(userId)/\(jId.uuidString.lowercased())/labeled.pdf"
        }
        await fetchAndCache(urlString: urlStr, isOriginal: false)
    }

    private func fetchOriginalPDF() async {
        guard let path = cachedPDFPath else { await MainActor.run { showError() }; return }
        await fetchAndCache(urlString: "\(publicBase)/pdf_uploads/\(path)", isOriginal: true)
    }

    private func fetchAndCache(urlString: String, isOriginal: Bool) async {
        var req = URLRequest(url: URL(string: urlString)!)
        req.timeoutInterval = 15
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (200...299).contains((resp as? HTTPURLResponse)?.statusCode ?? 0),
              let doc = PDFDocument(data: data), doc.pageCount > 0 else {
            await MainActor.run { self.showError() }; return
        }
        await MainActor.run {
            if isOriginal { self.originalPDF = doc } else { self.labeledPDF = doc }
            if isOriginal == (self.segmentControl.selectedSegmentIndex == 0) { self.showPDF(doc) }
        }
    }

    // MARK: - PDF Display
    private func showPDF(_ doc: PDFDocument) {
        pdfView.document = doc
        pdfView.isHidden = false
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
