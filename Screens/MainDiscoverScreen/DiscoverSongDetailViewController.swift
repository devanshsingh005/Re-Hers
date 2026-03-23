//
//  DiscoverSongDetailViewController.swift
//  Re-Hearse
//
//  Redesigned to match UploadPageNextViewController and PlaylistSongDetailViewController.
//

import UIKit
import PDFKit

class DiscoverSongDetailViewController: UIViewController {

    // MARK: - Passed Data
    var song: Song?
    var passedImage: UIImage?

    // MARK: - Private State
    private var loadedPDFDocument: PDFDocument?
    private var sheetMusicJSON: [String: Any]?

    private let projectID  = "djqgmowfjxsnjdffdohw"
    private var publicBase: String {
        "https://\(projectID).supabase.co/storage/v1/object/public"
    }

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
        loadSheetData()

        // Record this song as recently played
        if let songId = song?.id {
            Task {
                do {
                    try await RecentPlayService.shared.recordPlay(songId: songId)
                } catch {
                    print("[DiscoverDetail] ❌ Failed to record play: \(error)")
                }
            }
        }
    }

    // MARK: - Apply Passed Data

    private func applyPassedData() {
        let img = passedImage ?? UIImage(named: "trackimage_1")
        albumArtBackgroundView.image = img
        albumArtCardView.image       = img
        songTitleLabel.text = song?.title ?? "Unknown Song"
        artistLabel.text    = song?.composer ?? "Unknown Artist"
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

            pdfView.topAnchor.constraint(equalTo: pageLabel.bottomAnchor, constant: 10),
            pdfView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor),
            pdfView.heightAnchor.constraint(equalToConstant: 380),
            pdfView.bottomAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: -10),

            pdfLoadingIndicator.centerXAnchor.constraint(equalTo: pdfView.centerXAnchor),
            pdfLoadingIndicator.centerYAnchor.constraint(equalTo: pdfView.centerYAnchor),

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

    // MARK: - Fetch Data

    private func loadSheetData() {
        guard let sheetId = song?.sheetFileId else {
            print("[DiscoverDetail] ❌ No sheetFileId")
            self.showPDFError()
            return
        }

        pdfLoadingIndicator.startAnimating()
        pdfView.isHidden       = true
        pdfErrorLabel.isHidden = true

        Task {
            // 1. Fetch PDF (labeled or original)
            let pdfURLStrings = [
                "\(publicBase)/sheet_data/discover/\(sheetId.uuidString)/labeled.pdf",
                "\(publicBase)/sheet_data/discover/\(sheetId.uuidString).pdf",
                "\(publicBase)/pdf_uploads/\(sheetId.uuidString)/labeled.pdf",
                "\(publicBase)/pdf_uploads/\(sheetId.uuidString).pdf"
            ]

            var pdfFound = false
            for urlString in pdfURLStrings {
                guard let url = URL(string: urlString) else { continue }
                print("[DiscoverDetail][PDF] trying: \(url)")
                if let (data, resp) = try? await URLSession.shared.data(from: url),
                   (200...299).contains((resp as? HTTPURLResponse)?.statusCode ?? 0),
                   let doc = PDFDocument(data: data), doc.pageCount > 0 {
                    await MainActor.run {
                        self.renderPDF(doc)
                        pdfFound = true
                    }
                    break
                }
            }

            if !pdfFound {
                await MainActor.run { self.showPDFError() }
            }

            // 2. Fetch output.json for Animation (run in parallel but sequentially for simplicity)
            let jsonURLStrings = [
                "\(publicBase)/sheet_data/discover/\(sheetId.uuidString)/output.json",
                "\(publicBase)/pdf_uploads/\(sheetId.uuidString)/output.json"
            ]

            for urlString in jsonURLStrings {
                guard let url = URL(string: urlString) else { continue }
                print("[DiscoverDetail][JSON] trying: \(url)")
                if let (data, resp) = try? await URLSession.shared.data(from: url),
                   (200...299).contains((resp as? HTTPURLResponse)?.statusCode ?? 0),
                   let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("[DiscoverDetail][JSON] ✅ keys=\(parsed.keys.sorted())")
                    await MainActor.run { self.sheetMusicJSON = parsed }
                    break
                }
            }
        }
    }

    private func renderPDF(_ doc: PDFDocument) {
        loadedPDFDocument = doc
        pdfView.document  = doc
        pdfView.isHidden  = false
        pdfView.layoutIfNeeded()
        if let p = doc.page(at: 0) { pdfView.go(to: p) }
        pdfLoadingIndicator.stopAnimating()
    }

    @objc private func didTapPDFView() {
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
