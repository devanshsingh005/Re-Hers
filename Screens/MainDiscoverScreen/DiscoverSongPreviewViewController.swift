//
//  DiscoverSongPreviewViewController.swift
//  Re-Hearse
//
//  Intermediate preview screen shown when a song is tapped in Discover.
//  Uses the converted PDF/JSON already stored on the `songs` table.
//

import UIKit
import PDFKit
import Supabase

final class DiscoverSongPreviewViewController: UIViewController {

    // MARK: - Passed Data

    var song: Song?
    var songImage: UIImage?

    // MARK: - Private State

    private var loadedPDF: PDFDocument?
    private var pdfLoadTask: Task<Void, Never>?

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)

        if loadedPDF == nil && pdfLoadTask == nil {
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
        sheetCardView.addSubview(pdfView)
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
            sheetCardView.heightAnchor.constraint(equalToConstant: 580),
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
        } else {
            return ReHersAPI.url(path: "/" + trimmed)
        }
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

        pdfLoadTask = Task {
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
            vc.pdfData = doc.dataRepresentation()
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

            let vc = DiscoverSongDetailViewController()
            vc.song = song
            vc.passedImage = self.songImage
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }


    private func cancelPendingTasks() {
        pdfLoadTask?.cancel()
        pdfLoadTask = nil
    }

    private func releasePDFResources() {
        pdfSpinner.stopAnimating()
        pdfView.document = nil
        loadedPDF = nil
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
