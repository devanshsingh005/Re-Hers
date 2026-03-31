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
    private var loadedPDFData: Data?
    private var sheetMusicJSON: [String: Any]?
    private var recentPlayTask: Task<Void, Never>?
    private var sheetLoadTask: Task<Void, Never>?

    // MARK: - Scroll Container
    private let mainScrollView = UIScrollView()
    private let contentView    = UIView()

    // MARK: - UI Elements
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
    private let previewImageView    = UIImageView()
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
        navigationController?.setNavigationBarHidden(false, animated: false)

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
                    print("[DiscoverDetail] ❌ Failed to record play: \(error)")
                }
                self?.recentPlayTask = nil
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if loadedPDFData == nil, previewImageView.image == nil, sheetLoadTask == nil {
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

    // MARK: - Apply Passed Data

    private func applyPassedData() {
        let defaultImg = UIImage(named: "trackimage_1")
        let img = passedImage ?? defaultImg
        albumArtBackgroundView.image = img
        albumArtCardView.image       = img
        songTitleLabel.text = song?.title ?? "Unknown Song"
        artistLabel.text    = song?.composer ?? "Unknown Artist"
        
        if passedImage == nil, let coverUrl = song?.coverImageUrl, !coverUrl.isEmpty {
            if coverUrl.hasPrefix("http") {
                ImageLoader.shared.loadImage(from: coverUrl) { [weak self] loadedImg in
                    if let loadedImg = loadedImg {
                        self?.albumArtBackgroundView.image = loadedImg
                        self?.albumArtCardView.image = loadedImg
                    }
                }
            } else {
                let localImg = UIImage(named: coverUrl) ?? defaultImg
                albumArtBackgroundView.image = localImg
                albumArtCardView.image = localImg
            }
        }
    }

    // MARK: - NavBar

    private func setupUI() {
        view.backgroundColor = ComponentColors.SongDetailScreen.background
        setupNavBar()
    }

    private func setupNavBar() {
        _ = NavigationBarHelper.configureInlineNavigationBar(
            for: self,
            title: song?.title ?? "Song",
            subtitle: song?.composer ?? "Discover",
            backAction: #selector(handleBack)
        )
        navigationItem.rightBarButtonItems = NavigationBarHelper.createNativeRightBarButtonItems(
            target: self,
            profileAction: #selector(handleProfile),
            chordAction: #selector(handleChord)
        )
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
        albumArtBackgroundContainer.layer.cornerRadius = 24
        albumArtBackgroundContainer.clipsToBounds      = true
        albumArtBackgroundContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(albumArtBackgroundContainer)

        albumArtBackgroundView.contentMode = .scaleAspectFill
        albumArtBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        albumArtBackgroundContainer.addSubview(albumArtBackgroundView)

        // Dim overlay to make the foreground card pop
        let dimOverlay = UIView()
        dimOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        dimOverlay.translatesAutoresizingMaskIntoConstraints = false
        albumArtBackgroundContainer.addSubview(dimOverlay)

        NSLayoutConstraint.activate([
            dimOverlay.topAnchor.constraint(equalTo: albumArtBackgroundContainer.topAnchor),
            dimOverlay.bottomAnchor.constraint(equalTo: albumArtBackgroundContainer.bottomAnchor),
            dimOverlay.leadingAnchor.constraint(equalTo: albumArtBackgroundContainer.leadingAnchor),
            dimOverlay.trailingAnchor.constraint(equalTo: albumArtBackgroundContainer.trailingAnchor)
        ])

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
        songTitleLabel.textColor = ComponentColors.SongDetailScreen.songTitle
        songTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(songTitleLabel)

        artistLabel.textAlignment = .center
        artistLabel.font = .systemFont(ofSize: 14)
        artistLabel.textColor = ComponentColors.SongDetailScreen.artistName
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artistLabel)

        playAlongButton.setTitle("Play Along", for: .normal)
        playAlongButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        playAlongButton.layer.cornerRadius = 12
        playAlongButton.setTitleColor(ComponentColors.SongDetailScreen.primaryActionText, for: .normal)
        playAlongButton.backgroundColor = ComponentColors.SongDetailScreen.primaryActionFill
        playAlongButton.layer.shadowOpacity = 0.15
        playAlongButton.layer.shadowRadius  = 6
        playAlongButton.layer.shadowOffset  = CGSize(width: 0, height: 3)

        animationButton.setTitle("Animation", for: .normal)
        animationButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
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
        let previewTap = UITapGestureRecognizer(target: self, action: #selector(didTapPDFView))
        sheetContainer.addGestureRecognizer(previewTap)

        previewImageView.contentMode = .scaleAspectFit
        previewImageView.clipsToBounds = true
        previewImageView.layer.cornerRadius = 12
        previewImageView.backgroundColor = ComponentColors.SongDetailScreen.sheetMusicBackground
        previewImageView.isHidden = true
        previewImageView.isUserInteractionEnabled = false
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        sheetContainer.addSubview(previewImageView)

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
            songTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            songTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            artistLabel.topAnchor.constraint(equalTo: songTitleLabel.bottomAnchor, constant: 2),
            artistLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            artistLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            artistLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

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

            previewImageView.topAnchor.constraint(equalTo: pageLabel.bottomAnchor, constant: 10),
            previewImageView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor),
            previewImageView.heightAnchor.constraint(equalToConstant: 380),
            previewImageView.bottomAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: -10),

            pdfLoadingIndicator.centerXAnchor.constraint(equalTo: previewImageView.centerXAnchor),
            pdfLoadingIndicator.centerYAnchor.constraint(equalTo: previewImageView.centerYAnchor),

            pdfErrorLabel.centerXAnchor.constraint(equalTo: sheetContainer.centerXAnchor),
            pdfErrorLabel.centerYAnchor.constraint(equalTo: sheetContainer.centerYAnchor),
            pdfErrorLabel.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 16),
            pdfErrorLabel.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -16),

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

    @objc private func didTapAnimation() {
        animationButton.backgroundColor = ComponentColors.SongDetailScreen.primaryActionFill
        animationButton.setTitleColor(ComponentColors.SongDetailScreen.primaryActionText, for: .normal)
        playAlongButton.backgroundColor = ComponentColors.SongDetailScreen.secondaryActionFill
        playAlongButton.setTitleColor(ComponentColors.SongDetailScreen.secondaryActionText, for: .normal)

        guard let json = sheetMusicJSON else {
            showAnimationError("No sheet music data available yet.\nPlease wait a moment and try again.")
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

    @objc private func bookmarkTapped() {
        let on = bookmarkButton.tintColor == UIColor.systemYellow
        bookmarkButton.tintColor = on ? ComponentColors.SongCard.chevronIcon : .systemYellow
        bookmarkButton.setImage(UIImage(systemName: on ? "bookmark" : "bookmark.fill"), for: .normal)
    }

    @objc private func handleBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleChord() {
        navigationController?.pushViewController(ChordRecognitionViewController(), animated: true)
    }

    @objc private func handleProfile() {
        navigationController?.pushViewController(UserProfileViewController(), animated: true)
    }

    // MARK: - Fetch Data

    private func loadSheetData() {
        guard let sheetId = song?.sheetFileId else {
            print("[DiscoverDetail] ❌ No sheetFileId")
            self.showPDFError()
            return
        }

        sheetLoadTask?.cancel()
        pdfLoadingIndicator.startAnimating()
        previewImageView.image = nil
        previewImageView.isHidden = true
        pdfErrorLabel.isHidden = true

        sheetLoadTask = Task { [weak self] in
            guard let self else { return }
            // 1. Fetch PDF (labeled or original)
            let pdfPaths = [
                ("sheet_data", "discover/\(sheetId.uuidString)/labeled.pdf"),
                ("sheet_data", "discover/\(sheetId.uuidString).pdf"),
                ("pdf_uploads", "\(sheetId.uuidString)/labeled.pdf"),
                ("pdf_uploads", "\(sheetId.uuidString).pdf")
            ]

            var pdfFound = false
            for (bucket, path) in pdfPaths {
                guard !Task.isCancelled else {
                    await MainActor.run { self.sheetLoadTask = nil }
                    return
                }

                guard let url = try? await SupabaseManager.shared.client.storage
                    .from(bucket)
                    .createSignedURL(path: path, expiresIn: 3600) else { continue }
                if let (data, resp) = try? await URLSession.shared.data(from: url),
                   (200...299).contains((resp as? HTTPURLResponse)?.statusCode ?? 0),
                   let previewImage = Self.renderPDFPreviewImage(from: data) {
                    await MainActor.run {
                        self.renderPDF(data: data, previewImage: previewImage)
                        pdfFound = true
                    }
                    break
                }
            }

            if !pdfFound {
                await MainActor.run { self.showPDFError() }
            }

            // 2. Fetch output.json for Animation (run in parallel but sequentially for simplicity)
            let jsonPaths = [
                ("sheet_data", "discover/\(sheetId.uuidString)/output.json"),
                ("pdf_uploads", "\(sheetId.uuidString)/output.json")
            ]

            for (bucket, path) in jsonPaths {
                guard !Task.isCancelled else {
                    await MainActor.run { self.sheetLoadTask = nil }
                    return
                }

                guard let url = try? await SupabaseManager.shared.client.storage
                    .from(bucket)
                    .createSignedURL(path: path, expiresIn: 3600) else { continue }
                if let (data, resp) = try? await URLSession.shared.data(from: url),
                   (200...299).contains((resp as? HTTPURLResponse)?.statusCode ?? 0),
                   let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("[DiscoverDetail][JSON] ✅ keys=\(parsed.keys.sorted())")
                    await MainActor.run { self.sheetMusicJSON = parsed }
                    break
                }
            }

            await MainActor.run {
                self.sheetLoadTask = nil
            }
        }
    }

    private func renderPDF(data: Data, previewImage: UIImage) {
        loadedPDFData = data
        previewImageView.image = previewImage
        previewImageView.isHidden = false
        pdfLoadingIndicator.stopAnimating()
    }

    @objc private func didTapPDFView() {
        guard let pdfData = loadedPDFData,
              let doc = autoreleasepool(invoking: { PDFDocument(data: pdfData) }),
              doc.pageCount > 0 else { return }
        let vc = MaximizeUploadPageViewController()
        vc.pdfData = pdfData
        vc.pdfDocument = doc
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    private func showPDFError() {
        pdfLoadingIndicator.stopAnimating()
        previewImageView.image = nil
        previewImageView.isHidden = true
        pdfErrorLabel.isHidden = false
    }

    private func cancelPendingTasks() {
        recentPlayTask?.cancel()
        recentPlayTask = nil

        sheetLoadTask?.cancel()
        sheetLoadTask = nil
    }

    private func releasePDFResources() {
        pdfLoadingIndicator.stopAnimating()
        previewImageView.image = nil
        previewImageView.isHidden = true
        loadedPDFData = nil
        sheetMusicJSON = nil
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
}
