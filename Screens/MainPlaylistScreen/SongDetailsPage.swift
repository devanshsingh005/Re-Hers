//
//  SongDetailsPage.swift
//  Re-Hearse_v1
//

import UIKit
import Foundation
import PDFKit
import Supabase

class PlaylistSongDetailViewController: UIViewController {

    // MARK: - Passed Data From Previous Page
    var passedImage: UIImage?
    var passedSongTitle: String?
    var passedArtist: String?
    var passedSheetScanId: Int64?

    // MARK: - Private State

    /// Cached PDFDocument — loaded once, reused by the Animation button
    private var loadedPDFDocument: PDFDocument?

    /// The parsed output.json dictionary — same as sheetMusicJSON in
    /// UploadPageNextViewController. Serialised to Data when Animation tapped.
    private var sheetMusicJSON: [String: Any]?

    // Supabase constants (match every other file in the project)
    private let projectID  = "djqgmowfjxsnjdffdohw"
    private var publicBase: String {
        "https://\(projectID).supabase.co/storage/v1/object/public"
    }
    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Scroll Container
    private let mainScrollView = UIScrollView()
    private let contentView    = UIView()

    // MARK: - UI Elements
    private let navBar = TopNavBar.make(title: "")

    private let albumArtBackgroundContainer = UIView()
    private let albumArtBackgroundView      = UIImageView()
    private let albumArtCardView            = UIImageView()

    private let bookmarkButton  = UIButton(type: .system)
    private let songTitleLabel  = UILabel()
    private let artistLabel     = UILabel()

    private let playAlongButton = UIButton(type: .system)
    private let animationButton = UIButton(type: .system)
    private let buttonStack     = UIStackView()

    private let sheetContainer      = UIView()
    private let pageLabel           = UILabel()
    private let pdfView             = PDFView()
    private let pdfLoadingIndicator = UIActivityIndicatorView(style: .medium)
    private let pdfErrorLabel       = UILabel()

    private let bottomSpacer = UIView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.SongDetailScreen.background
        navigationController?.navigationBar.isHidden = true

        setupUI()
        setupScroll()
        setupContent()
        setupConstraints()
        setupActions()

        applyPassedData()

        // Kick off both fetches in parallel — PDF for the inline view,
        // output.json for the Animation button (same as handleJobCompleted does).
        loadSheetData()
    }

    // MARK: - Apply Passed Data

    private func applyPassedData() {
        let img = passedImage ?? UIImage(named: "ride_home")
        albumArtBackgroundView.image = img
        albumArtCardView.image       = img
        songTitleLabel.text = passedSongTitle ?? "Unknown Song"
        artistLabel.text    = passedArtist    ?? "Unknown Artist"
    }

    // MARK: - NavBar

    private func setupUI() {
        view.backgroundColor = ComponentColors.SongDetailScreen.background
        navigationController?.navigationBar.isHidden = true
        setupNavBar()
    }

    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.isBackButtonVisible = true
        navBar.isChordIconVisible  = true
        navBar.isProfileVisible    = true
        navBar.isStreakVisible     = false
        navBar.isWelcomeTextHidden = true
        navBar.setTitle("")

        navBar.chordAction   = { [weak self] in self?.navigationController?.pushViewController(ChordRecognitionViewController(), animated: true) }
        navBar.profileAction = { [weak self] in self?.navigationController?.pushViewController(UserProfileViewController(), animated: true) }
        navBar.backAction    = { [weak self] in self?.navigationController?.popViewController(animated: true) }

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
    }

    // MARK: - Scroll View

    private func setupScroll() {
        mainScrollView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.alwaysBounceVertical = true
        view.addSubview(mainScrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            mainScrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
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
        albumArtBackgroundContainer.layer.cornerRadius = 24
        albumArtBackgroundContainer.clipsToBounds      = true
        albumArtBackgroundContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(albumArtBackgroundContainer)

        albumArtBackgroundView.contentMode = .scaleAspectFill
        albumArtBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        albumArtBackgroundContainer.addSubview(albumArtBackgroundView)

        albumArtCardView.layer.cornerRadius = 24
        albumArtCardView.contentMode = .scaleAspectFill
        albumArtCardView.clipsToBounds = true
        albumArtCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(albumArtCardView)

        bookmarkButton.setImage(UIImage(systemName: "bookmark"), for: .normal)
        bookmarkButton.tintColor = ComponentColors.SongCard.chevronIcon
        bookmarkButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bookmarkButton)

        songTitleLabel.textAlignment = .center
        songTitleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        songTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(songTitleLabel)

        artistLabel.textAlignment = .center
        artistLabel.font = .systemFont(ofSize: 14)
        artistLabel.textColor = ComponentColors.SongDetailScreen.artistName
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artistLabel)

        playAlongButton.setTitle("Play Along", for: .normal)
        playAlongButton.layer.cornerRadius = 12
        playAlongButton.setTitleColor(ComponentColors.SongDetailScreen.primaryActionText, for: .normal)
        playAlongButton.backgroundColor = ComponentColors.SongDetailScreen.primaryActionFill
        playAlongButton.layer.shadowOpacity = 0.15
        playAlongButton.layer.shadowRadius  = 6
        playAlongButton.layer.shadowOffset  = CGSize(width: 0, height: 3)

        animationButton.setTitle("Animation", for: .normal)
        animationButton.layer.cornerRadius = 12
        animationButton.setTitleColor(ComponentColors.SongDetailScreen.secondaryActionText, for: .normal)
        animationButton.backgroundColor = ComponentColors.SongDetailScreen.secondaryActionFill
        animationButton.layer.shadowOffset = CGSize(width: 0, height: 3)

        buttonStack.axis         = .horizontal
        buttonStack.spacing      = 26
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.addArrangedSubview(playAlongButton)
        buttonStack.addArrangedSubview(animationButton)
        contentView.addSubview(buttonStack)

        sheetContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sheetContainer)

        pageLabel.font          = .systemFont(ofSize: 16, weight: .medium)
        pageLabel.textAlignment = .center
        pageLabel.text          = "Sheet Music"
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        sheetContainer.addSubview(pageLabel)

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

        pdfErrorLabel.text = "Sheet music unavailable.\nTry opening this song from Uploads."
        pdfErrorLabel.numberOfLines = 0
        pdfErrorLabel.textAlignment = .center
        pdfErrorLabel.font          = .systemFont(ofSize: 15)
        pdfErrorLabel.textColor     = .secondaryLabel
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
            albumArtBackgroundContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            albumArtBackgroundContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            albumArtBackgroundContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            albumArtBackgroundContainer.heightAnchor.constraint(equalToConstant: 180),

            albumArtBackgroundView.topAnchor.constraint(equalTo: albumArtBackgroundContainer.topAnchor),
            albumArtBackgroundView.bottomAnchor.constraint(equalTo: albumArtBackgroundContainer.bottomAnchor),
            albumArtBackgroundView.leadingAnchor.constraint(equalTo: albumArtBackgroundContainer.leadingAnchor),
            albumArtBackgroundView.trailingAnchor.constraint(equalTo: albumArtBackgroundContainer.trailingAnchor),

            albumArtCardView.centerXAnchor.constraint(equalTo: albumArtBackgroundContainer.centerXAnchor),
            albumArtCardView.centerYAnchor.constraint(equalTo: albumArtBackgroundContainer.bottomAnchor, constant: -28),
            albumArtCardView.widthAnchor.constraint(equalToConstant: 140),
            albumArtCardView.heightAnchor.constraint(equalToConstant: 140),

            bookmarkButton.leadingAnchor.constraint(equalTo: albumArtCardView.trailingAnchor, constant: 10),
            bookmarkButton.centerYAnchor.constraint(equalTo: albumArtCardView.centerYAnchor, constant: 20),
            bookmarkButton.widthAnchor.constraint(equalToConstant: 36),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 36),

            songTitleLabel.topAnchor.constraint(equalTo: albumArtCardView.bottomAnchor, constant: 18),
            songTitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            artistLabel.topAnchor.constraint(equalTo: songTitleLabel.bottomAnchor, constant: 2),
            artistLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            buttonStack.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 28),
            buttonStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            buttonStack.widthAnchor.constraint(equalToConstant: 320),
            buttonStack.heightAnchor.constraint(equalToConstant: 46),

            sheetContainer.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 32),
            sheetContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sheetContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            sheetContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 420),

            pageLabel.topAnchor.constraint(equalTo: sheetContainer.topAnchor, constant: 10),
            pageLabel.centerXAnchor.constraint(equalTo: sheetContainer.centerXAnchor),

            pdfView.topAnchor.constraint(equalTo: pageLabel.bottomAnchor, constant: 10),
            pdfView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor),
            pdfView.heightAnchor.constraint(equalToConstant: 380),
            pdfView.bottomAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: -10),

            pdfLoadingIndicator.centerXAnchor.constraint(equalTo: pdfView.centerXAnchor),
            pdfLoadingIndicator.centerYAnchor.constraint(equalTo: pdfView.centerYAnchor),

            pdfErrorLabel.centerXAnchor.constraint(equalTo: pdfView.centerXAnchor),
            pdfErrorLabel.centerYAnchor.constraint(equalTo: pdfView.centerYAnchor),
            pdfErrorLabel.leadingAnchor.constraint(equalTo: pdfView.leadingAnchor, constant: 16),
            pdfErrorLabel.trailingAnchor.constraint(equalTo: pdfView.trailingAnchor, constant: -16),

            bottomSpacer.topAnchor.constraint(equalTo: sheetContainer.bottomAnchor),
            bottomSpacer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomSpacer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomSpacer.heightAnchor.constraint(equalToConstant: 24),
            bottomSpacer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    // MARK: - Button Actions

    private func setupActions() {
        playAlongButton.addTarget(self, action: #selector(openPlayAlongVC),       for: .touchUpInside)
        animationButton.addTarget(self, action: #selector(didTapAnimation),       for: .touchUpInside)
        bookmarkButton.addTarget(self,  action: #selector(bookmarkTapped),        for: .touchUpInside)
    }

    @objc private func openPlayAlongVC() {
        playAlongButton.backgroundColor = ComponentColors.SongDetailScreen.primaryActionFill
        playAlongButton.setTitleColor(ComponentColors.SongDetailScreen.primaryActionText, for: .normal)
        animationButton.backgroundColor = ComponentColors.SongDetailScreen.secondaryActionFill
        animationButton.setTitleColor(ComponentColors.SongDetailScreen.secondaryActionText, for: .normal)

        let vc  = PlayAlongViewController()
        let nav = LandscapeNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    // ── Animation button ──────────────────────────────────────────────────────
    // Mirrors didTapAnimation + navigateToAnimation in UploadPageNextViewController:
    //   guard sheetMusicJSON != nil → serialise to Data → set vc.sheetMusicData → present
    // The JSON is fetched from output.json during loadSheetData() below, exactly
    // the same way handleJobCompleted fetches it in UploadPageNextViewController.
    @objc private func didTapAnimation() {
        animationButton.backgroundColor = ComponentColors.SongDetailScreen.primaryActionFill
        animationButton.setTitleColor(ComponentColors.SongDetailScreen.primaryActionText, for: .normal)
        playAlongButton.backgroundColor = ComponentColors.SongDetailScreen.secondaryActionFill
        playAlongButton.setTitleColor(ComponentColors.SongDetailScreen.secondaryActionText, for: .normal)

        // sheetMusicJSON is populated by loadSheetData() → fetchOutputJSON().
        // Guard identical to UploadPageNextViewController.didTapAnimation.
        guard let json = sheetMusicJSON else {
            showAnimationError("No sheet music data available yet.\nPlease wait a moment and try again.")
            return
        }

        navigateToAnimation(withJSON: json)
    }

    /// Serialises the parsed output.json dictionary and passes it to
    /// AnimationViewController — exact copy of navigateToAnimation in
    /// UploadPageNextViewController.
    private func navigateToAnimation(withJSON json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else {
            showAnimationError("Failed to prepare sheet music data.")
            return
        }
        let vc = AnimationViewController()
        vc.sheetMusicData = data
        vc.songTitle      = passedSongTitle ?? "Animation"
        let nav = LandscapeNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func showAnimationError(_ msg: String) {
        let a = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    @objc private func bookmarkTapped() {
        let on = bookmarkButton.tintColor == UIColor.systemYellow
        bookmarkButton.tintColor = on ? ComponentColors.SongCard.chevronIcon : .systemYellow
        bookmarkButton.setImage(UIImage(systemName: on ? "bookmark" : "bookmark.fill"), for: .normal)
    }

    // MARK: - Master Fetch
    // Resolves the job once, then fires both fetches in parallel —
    // same work handleJobCompleted does in UploadPageNextViewController.

    private func loadSheetData() {
        guard let scanId = passedSheetScanId else {
            print("[SongDetail] ❌ No scanId")
            pdfErrorLabel.isHidden = false
            return
        }

        pdfLoadingIndicator.startAnimating()
        pdfView.isHidden       = true
        pdfErrorLabel.isHidden = true

        Task {
            do {
                // ── Step 1: resolve job from scans.json_data ──────────────────────
                // job_id lives INSIDE json_data (JSONB), not as a real column.
                // Cast via AnyCodable — the same pattern used everywhere else.
                struct ScanRow: Codable {
                    let jsonData: SongDetailAnyCodable?
                    enum CodingKeys: String, CodingKey { case jsonData = "json_data" }
                }

                let scanRows: [ScanRow] = try await supabase
                    .from("scans")
                    .select("json_data")
                    .eq("id", value: Int(scanId))
                    .limit(1)
                    .execute()
                    .value

                guard let jsonDict = scanRows.first?.jsonData?.value as? [String: Any],
                      let jobIdStr = jsonDict["job_id"] as? String,
                      let jobId    = UUID(uuidString: jobIdStr) else {
                    print("[SongDetail] ❌ No job_id in json_data for scanId=\(scanId)")
                    await MainActor.run { self.showPDFError() }
                    return
                }

                print("[SongDetail] ✅ job_id=\(jobId.uuidString)")

                // ── Step 2: query jobs for pdf_path + result_url ──────────────────
                // Mirrors fetchJobAndLoad in UploadPageNextViewController.
                struct JobRow: Decodable {
                    let pdfPath:   String
                    let resultUrl: String?
                    enum CodingKeys: String, CodingKey {
                        case pdfPath   = "pdf_path"
                        case resultUrl = "result_url"
                    }
                }

                let jobRows: [JobRow] = try await supabase
                    .from("jobs")
                    .select("pdf_path, result_url")
                    .eq("id", value: jobId)
                    .limit(1)
                    .execute()
                    .value

                guard let job = jobRows.first else {
                    print("[SongDetail] ❌ No jobs row for jobId=\(jobId)")
                    await MainActor.run { self.showPDFError() }
                    return
                }

                print("[SongDetail] pdf_path=\(job.pdfPath)  result_url=\(job.resultUrl ?? "nil")")

                // ── Step 3a: load labeled PDF ─────────────────────────────────────
                // Mirrors handleJobCompleted in UploadPageNextViewController.
                // result_url = "sheet_data/{userId}/{jobId}/labeled.pdf" (relative)
                let pdfURLString: String
                if let rel = job.resultUrl, !rel.isEmpty {
                    pdfURLString = rel.hasPrefix("http") ? rel : "\(publicBase)/\(rel)"
                } else {
                    let userId  = job.pdfPath.components(separatedBy: "/").first ?? ""
                    pdfURLString = "\(publicBase)/sheet_data/\(userId)/\(jobId.uuidString.lowercased())/labeled.pdf"
                }

                print("[SongDetail][PDF] fetching: \(pdfURLString)")
                if let pdfURL = URL(string: pdfURLString) {
                    var pdfReq = URLRequest(url: pdfURL)
                    pdfReq.timeoutInterval = 15
                    if let (pdfData, pdfResp) = try? await URLSession.shared.data(for: pdfReq),
                       (200...299).contains((pdfResp as? HTTPURLResponse)?.statusCode ?? 0) {
                        await MainActor.run { self.renderPDF(pdfData) }
                    } else {
                        await MainActor.run { self.showPDFError() }
                    }
                }

                // ── Step 3b: fetch output.json for Animation button ───────────────
                // Uses the exact same deriveOutputURL logic as UploadPageNextViewController:
                //   sheet_data/{userId}/{jobId}/output.json
                // Then parses it and stores in sheetMusicJSON — same as
                // parseAndDisplayJSON stores it in sheetMusicJSON there.
                let jsonURLString = deriveOutputURL(jobId: jobId, pdfPath: job.pdfPath)
                print("[SongDetail][JSON] fetching: \(jsonURLString)")

                if let jsonURL = URL(string: jsonURLString),
                   let (jsonData, _) = try? await URLSession.shared.data(from: jsonURL),
                   let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    print("[SongDetail][JSON] ✅ keys=\(parsed.keys.sorted())")
                    await MainActor.run { self.sheetMusicJSON = parsed }
                } else {
                    print("[SongDetail][JSON] ⚠️ output.json not available yet")
                }

            } catch {
                print("[SongDetail] ❌ \(error.localizedDescription)")
                await MainActor.run { self.showPDFError() }
            }
        }
    }

    // MARK: - Helpers

    /// Derives output.json URL from job_id + pdf_path.
    /// Direct copy of deriveOutputURL in UploadPageNextViewController.
    private func deriveOutputURL(jobId: UUID, pdfPath: String) -> String {
        let userId = pdfPath.components(separatedBy: "/").first ?? jobId.uuidString
        return "\(publicBase)/sheet_data/\(userId)/\(jobId.uuidString.lowercased())/output.json"
    }

    private func renderPDF(_ data: Data) {
        guard let doc = PDFDocument(data: data), doc.pageCount > 0 else {
            print("[SongDetail][PDF] ❌ Not a valid PDF")
            showPDFError(); return
        }
        print("[SongDetail][PDF] ✅ \(doc.pageCount) page(s)")
        loadedPDFDocument = doc
        pdfView.document  = doc
        pdfView.isHidden  = false
        pdfView.layoutIfNeeded()
        if let p = doc.page(at: 0) { pdfView.go(to: p) }
        pdfLoadingIndicator.stopAnimating()
    }

    @objc private func didTapPDFView() {
        // Pass the already-loaded PDFDocument directly to MaximizeUploadPageViewController.
        // No extra network call needed — same document that renderPDF() cached.
        guard let doc = loadedPDFDocument else { return }
        let vc = MaximizeUploadPageViewController()
        vc.pdfDocument = doc
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    private func showPDFError() {
        pdfLoadingIndicator.stopAnimating()
        pdfView.isHidden       = true
        pdfErrorLabel.isHidden = false
    }
}

// MARK: - SongDetailAnyCodable
// Identical to UploadScreen.AnyCodable / AllUploadsViewController.AnyCodable.
// Required to decode json_data (JSONB) so we can read arbitrary keys like "job_id".
private struct SongDetailAnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if      let b = try? c.decode(Bool.self)                           { value = b }
        else if let i = try? c.decode(Int.self)                            { value = i }
        else if let d = try? c.decode(Double.self)                         { value = d }
        else if let s = try? c.decode(String.self)                         { value = s }
        else if let a = try? c.decode([SongDetailAnyCodable].self)         { value = a.map { $0.value } }
        else if let d = try? c.decode([String: SongDetailAnyCodable].self) { value = d.mapValues { $0.value } }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Cannot decode") }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let b as Bool:          try c.encode(b)
        case let i as Int:           try c.encode(i)
        case let d as Double:        try c.encode(d)
        case let s as String:        try c.encode(s)
        case let a as [Any]:         try c.encode(a.map { SongDetailAnyCodable($0) })
        case let d as [String: Any]: try c.encode(d.mapValues { SongDetailAnyCodable($0) })
        default: throw EncodingError.invalidValue(
            value, .init(codingPath: c.codingPath, debugDescription: "Cannot encode"))
        }
    }
}

