//
//  UploadScreen.swift
//  Re-Hearse_v1
//

import UIKit
import AVFoundation
import Photos
import Supabase
import Auth
internal import PostgREST
import PDFKit
import Vision
import VisionKit
import CryptoKit
import Security

class UploadScreen: UIViewController {

    // MARK: - Constants
    private enum Constants {
        static let horizontalPadding: CGFloat = 24
        static let sectionSpacing:    CGFloat = 24
        static let cornerRadius:      CGFloat = 20
        static let buttonHeight:      CGFloat = 52
        static let pdfPageSize = CGSize(width: 612, height: 792)
    }

    // MARK: - State
    private var uploadTitle: String = DateFormatter.shortDate.string(from: Date())

    /// Unique filename per upload, e.g. "SheetMusic_2026-03-08_064025.pdf".
    /// Stored in json_data so no two files can share a name.
    private func generateTimestampFilename() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return "SheetMusic_\(f.string(from: Date())).pdf"
    }
    private var currentUploadData: Data?
    private var currentFileName  = ""
    private var currentFileType  = ""
    private var activeQuizPopup: UploadQuizPopup?
    private var recentUploadsStack: UIStackView?

    // MARK: - Supabase
    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - UI
    private let scrollView  = UIScrollView()
    private let contentView = UIStackView()
    
    private let navBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let navShadowLayer = UIView()
    private let largeSubtitleLabel = UILabel()
    private var inlineSubtitleLabel: UILabel?
    private let largeProfileButton = UIButton(type: .custom)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.HomeScreen.background
        scrollView.delegate = self
        setupNavBar()
        syncNavBarAlpha()
        setupScrollView()
        setupNavBackground()
        setupCustomLargeHeader()
        setupActionCards()
        setupRecentUploadsSection()
        loadRecentUploads()
        fetchProfileData()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProfileUpdate),
            name: NavigationBarHelper.profileDidUpdateNotification,
            object: nil
        )
    }

    @objc private func handleProfileUpdate() {
        fetchProfileData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadRecentUploads()
    }

    func startUploadFlow() { presentDocumentScanner() }

    // MARK: - NavBar
    private func setupNavBar() {
        inlineSubtitleLabel = NavigationBarHelper.configureInlineNavigationBar(
            for: self,
            title: "Upload",
            subtitle: "Upload a new song"
        )
        
        navigationItem.rightBarButtonItems = nil
    }

    private func setupNavBackground() {
        NavigationBarHelper.updateNavigationBackgroundAppearance(
            navBackgroundView,
            shadowView: navShadowLayer,
            traitCollection: traitCollection
        )
        NavigationBarHelper.installNavigationBackground(
            navBackgroundView,
            shadowView: navShadowLayer,
            in: view
        )
    }

    private func setupCustomLargeHeader() {
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.insertArrangedSubview(headerContainer, at: 0)
        
        let labelStack = UIStackView()
        labelStack.axis = .vertical
        labelStack.spacing = -2
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Upload"
        titleLabel.font = .systemFont(ofSize: 34, weight: .heavy)
        titleLabel.textColor = ComponentColors.NavBar.title
        
        largeSubtitleLabel.text = "Capture or import your documents"
        largeSubtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        largeSubtitleLabel.textColor = ComponentColors.NavBar.title.withAlphaComponent(0.6)
        
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(largeSubtitleLabel)
        headerContainer.addSubview(labelStack)
        
        largeProfileButton.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.12)
        largeProfileButton.layer.cornerRadius = 20
        largeProfileButton.clipsToBounds = true
        largeProfileButton.layer.borderWidth    = 1.0
        largeProfileButton.layer.borderColor    = (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black).cgColor
        
        // Default placeholder
        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
        largeProfileButton.tintColor = .white
        largeProfileButton.imageView?.contentMode = .scaleAspectFill
        
        largeProfileButton.translatesAutoresizingMaskIntoConstraints = false
        largeProfileButton.addTarget(self, action: #selector(handleProfileTap), for: .touchUpInside)
        headerContainer.addSubview(largeProfileButton)
        
        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            headerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            headerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            headerContainer.heightAnchor.constraint(equalToConstant: 80),
            labelStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            labelStack.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            largeProfileButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            largeProfileButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            largeProfileButton.widthAnchor.constraint(equalToConstant: 40),
            largeProfileButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func fetchProfileData() {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else {
                await MainActor.run {
                    largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    largeProfileButton.tintColor = .secondaryLabel
                }
                return
            }
            do {
                let profile: Profile = try await SupabaseManager.shared.client
                    .from("profiles").select().eq("id", value: user.id).single().execute().value
                if let avatarUrl = profile.avatar_url, !avatarUrl.isEmpty {
                    await loadAndSetProfileImage(from: avatarUrl)
                } else {
                    await MainActor.run {
                        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                        largeProfileButton.tintColor = .secondaryLabel
                    }
                }
            } catch {
                print("Profile error: \(error)")
                await MainActor.run {
                    largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    largeProfileButton.tintColor = .secondaryLabel
                }
            }
        }
    }

    private func loadAndSetProfileImage(from urlString: String) async {
        if urlString.starts(with: "icon_") {
            await MainActor.run {
                if let img = UIImage(named: urlString) {
                    largeProfileButton.setImage(img, for: .normal)
                    largeProfileButton.tintColor = .clear
                }
            }
            return
        }
        guard let finalURL = await NavigationBarHelper.signedProfileURLString(from: urlString),
              let url = URL(string: finalURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 30))
            if let img = UIImage(data: data) {
                await MainActor.run {
                    self.largeProfileButton.setImage(img, for: .normal)
                    self.largeProfileButton.tintColor = .clear
                    self.largeProfileButton.imageView?.contentMode = .scaleAspectFill
                }
            } else {
                await MainActor.run {
                    self.largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    self.largeProfileButton.tintColor = .secondaryLabel
                }
            }
        } catch {
            await MainActor.run {
                self.largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                self.largeProfileButton.tintColor = .secondaryLabel
            }
        }
    }

    private func syncNavBarAlpha() {
        NavigationBarHelper.syncNavigationBarAlpha(
            scrollView: scrollView,
            navigationItem: navigationItem,
            navBackgroundView: navBackgroundView
        )
    }

    @objc private func handleProfileTap() {
        navigationController?.pushViewController(UserProfileViewController(), animated: true)
    }

    // MARK: - Scroll + Content Stack
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical        = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.addSubview(contentView)
        contentView.axis    = .vertical
        contentView.spacing = Constants.sectionSpacing
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor), // Overlap for blur
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 90), // Space for status bar offset
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor,
                                                  constant: Constants.horizontalPadding),
            contentView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor,
                                                   constant: -Constants.horizontalPadding),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor,
                                               constant: -2 * Constants.horizontalPadding)
        ])
    }

    // SetupActionCards follows...

    // MARK: - Action Cards
    private func setupActionCards() {
        let row = UIStackView(arrangedSubviews: [makeScanCard(), makeUploadCard()])
        row.axis         = .horizontal
        row.spacing      = 14
        row.distribution = .fillEqually
        row.heightAnchor.constraint(equalToConstant: 210).isActive = true
        contentView.addArrangedSubview(row)
    }

    private func makeScanCard() -> UIView {
        let card = cardButton()
        let gradient = GradientView(colors: [ComponentColors.HomeScreen.actionButtonGradientStart, ComponentColors.HomeScreen.actionButtonGradientEnd])
        gradient.isUserInteractionEnabled = false
        gradient.translatesAutoresizingMaskIntoConstraints = false
        card.insertSubview(gradient, at: 0)

        let (iconWrap, iconImg) = makeCardIcon(systemName: "doc.text.viewfinder", tint: .white,
                                               bg: UIColor.white.withAlphaComponent(0.25))
        let mainLbl = cardLabel("Scan",         size: 22, weight: .bold,    color: .white)
        let subLbl  = cardLabel("Music Sheet",  size: 11, weight: .semibold,
                                color: UIColor.white.withAlphaComponent(0.9), tracking: 1.5)
        [iconWrap, mainLbl, subLbl].forEach { card.addSubview($0) }
        NSLayoutConstraint.activate(
            gradient.pinEdges(to: card) + [
            iconWrap.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            iconWrap.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            iconWrap.widthAnchor.constraint(equalToConstant: 64),
            iconWrap.heightAnchor.constraint(equalToConstant: 64),
            iconImg.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            iconImg.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            iconImg.widthAnchor.constraint(equalToConstant: 36),
            iconImg.heightAnchor.constraint(equalToConstant: 36),
            mainLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            mainLbl.bottomAnchor.constraint(equalTo: subLbl.topAnchor, constant: -2),
            subLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            subLbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        card.addTarget(self, action: #selector(scanTapped),      for: .touchUpInside)
        attachPressAnimations(to: card)
        return card
    }

    private func makeUploadCard() -> UIView {
        let orange = BrandColors.brand
        let card   = cardButton()
        card.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.08)
        card.layer.borderColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.18).cgColor
        card.layer.borderWidth = 1.5

        let (iconWrap, iconImg) = makeCardIcon(systemName: "icloud.and.arrow.up", tint: orange,
                                               bg: orange.withAlphaComponent(0.15))
        let mainLbl = cardLabel("Upload",      size: 22, weight: .bold,    color: SemanticColors.Text.primary)
        let subLbl  = cardLabel("Music Sheet", size: 11, weight: .semibold, color: SemanticColors.Text.secondary, tracking: 1.5)
        [iconWrap, mainLbl, subLbl].forEach { card.addSubview($0) }
        NSLayoutConstraint.activate([
            iconWrap.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            iconWrap.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            iconWrap.widthAnchor.constraint(equalToConstant: 64),
            iconWrap.heightAnchor.constraint(equalToConstant: 64),
            iconImg.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            iconImg.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            iconImg.widthAnchor.constraint(equalToConstant: 36),
            iconImg.heightAnchor.constraint(equalToConstant: 36),
            mainLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            mainLbl.bottomAnchor.constraint(equalTo: subLbl.topAnchor, constant: -2),
            subLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            subLbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        card.addTarget(self, action: #selector(uploadFileTapped), for: .touchUpInside)
        attachPressAnimations(to: card)
        return card
    }

    // MARK: - Card Helpers
    private func cardButton() -> UIButton {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.layer.cornerRadius = Constants.cornerRadius
        b.clipsToBounds      = true
        return b
    }

    private func makeCardIcon(systemName: String, tint: UIColor,
                              bg: UIColor) -> (UIView, UIImageView) {
        let wrap = UIView()
        wrap.backgroundColor      = bg
        wrap.layer.cornerRadius   = 16
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.isUserInteractionEnabled = false

        let img = UIImageView(image: UIImage(systemName: systemName))
        img.tintColor    = tint
        img.contentMode  = .scaleAspectFit
        img.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(img)
        return (wrap, img)
    }

    private func cardLabel(_ text: String, size: CGFloat, weight: UIFont.Weight,
                           color: UIColor, tracking: CGFloat = 0) -> UILabel {
        let l = UILabel()
        l.text      = text
        l.font      = .systemFont(ofSize: size, weight: weight)
        l.textColor = color
        l.translatesAutoresizingMaskIntoConstraints = false
        l.isUserInteractionEnabled = false
        if tracking != 0 { l.letterSpacing(tracking) }
        return l
    }

    private func attachPressAnimations(to button: UIButton) {
        button.addTarget(self, action: #selector(cardTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(cardTouchUp(_:)),
                         for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func cardTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12) {
            sender.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }
    }
    @objc private func cardTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0,
                       usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            sender.transform = .identity
        }
    }
    @objc private func scanTapped()       { presentDocumentScanner() }
    @objc private func uploadFileTapped() { openFileManager() }

    // MARK: - Recent Uploads Section
    private func setupRecentUploadsSection() {
        let headerLabel = UILabel()
        headerLabel.text = "Recent Uploads"
        headerLabel.font = .systemFont(ofSize: 20, weight: .bold)
        headerLabel.textColor = SemanticColors.Text.primary

        let seeMoreBtn = UIButton(type: .system)
        seeMoreBtn.setTitle("See More", for: .normal)
        seeMoreBtn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        seeMoreBtn.setTitleColor(BrandColors.brand, for: .normal)
        seeMoreBtn.addTarget(self, action: #selector(seeMoreTapped), for: .touchUpInside)

        let headerRow = UIStackView(arrangedSubviews: [headerLabel, seeMoreBtn])
        headerRow.axis         = .horizontal
        headerRow.distribution = .equalSpacing
        headerRow.alignment    = .center
        contentView.addArrangedSubview(headerRow)

        let uploadsStack = UIStackView()
        uploadsStack.axis    = .vertical
        uploadsStack.spacing = 10
        recentUploadsStack   = uploadsStack
        contentView.addArrangedSubview(uploadsStack)
    }

    // MARK: - Load & Display Recent Uploads
    private func loadRecentUploads() {
        Task {
            do {
                let uploads = try await fetchRecentUploads()
                await MainActor.run { self.displayRecentUploads(uploads) }
            } catch {
                print("[Uploads] load error: \(error)")
                await MainActor.run { self.displayRecentUploads([]) }
            }
        }
    }

    private func fetchRecentUploads() async throws -> [Scan] {
        guard let uid = await currentUserId(), let userId = UUID(uuidString: uid) else { return [] }
        let response: [Scan] = try await supabase
            .from("scans").select()
            .eq("user_id", value: userId)
            .order("updated_at", ascending: false)
            .limit(5)
            .execute().value
        var seen = Set<Int64>()
        return response.filter { seen.insert($0.id).inserted }
    }

    private func displayRecentUploads(_ scans: [Scan]) {
        guard let stack = recentUploadsStack else { return }
        uploadTitle = DateFormatter.shortDate.string(from: Date())
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if scans.isEmpty { stack.addArrangedSubview(makeEmptyState()); return }
        for scan in scans {
            let title    = extractTitle(from: scan.jsonData)
                        ?? extractOriginalFilename(from: scan.jsonData)
                        ?? scan.originalFilename
                        ?? DateFormatter.shortDate.string(from: Date())
            let fileType = (scan.fileType ?? "application/pdf").contains("pdf") ? "PDF" : "FILE"
            let dateStr  = extractDate(from: scan.jsonData, fallback: scan.processedAt ?? scan.updatedAt)
            let sizeStr  = extractFileSize(from: scan.jsonData)
            let meta     = [dateStr, sizeStr].filter { !$0.isEmpty }.joined(separator: " • ")
            stack.addArrangedSubview(makeUploadRow(title: title, fileType: fileType,
                                                    meta: meta, scan: scan))
        }
    }

    private func makeEmptyState() -> UIView {
        let container = UIView()
        container.backgroundColor  = .secondarySystemBackground
        container.layer.cornerRadius = 14
        let label = UILabel()
        label.text          = "No recent uploads yet"
        label.textColor     = .tertiaryLabel
        label.font          = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 70)
        ])
        return container
    }

    private func makeUploadRow(title: String, fileType: String, meta: String, scan: Scan) -> UIView {
        // Card
        let card = UIButton(type: .custom)
        card.backgroundColor       = ComponentColors.SongCard.background
        card.layer.cornerRadius    = 16
        card.layer.shadowColor     = UIColor.black.cgColor
        card.layer.shadowOpacity   = 0.05
        card.layer.shadowRadius    = 8
        card.layer.shadowOffset    = CGSize(width: 0, height: 2)
        card.clipsToBounds         = false
        card.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconWrap = UIView()
        iconWrap.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.12)
        iconWrap.layer.cornerRadius  = 12
        iconWrap.clipsToBounds       = true
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.isUserInteractionEnabled = false
        let iconImg = UIImageView(image: UIImage(systemName: "doc.fill"))
        iconImg.tintColor   = BrandColors.brand
        iconImg.contentMode = .scaleAspectFit
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.addSubview(iconImg)

        // Text
        let titleLbl = UILabel()
        titleLbl.text          = title
        titleLbl.font          = .systemFont(ofSize: 15, weight: .semibold)
        titleLbl.textColor     = SemanticColors.Text.primary
        titleLbl.lineBreakMode = .byTruncatingTail

        let badgeLbl = UILabel()
        badgeLbl.text              = fileType
        badgeLbl.font              = .systemFont(ofSize: 11, weight: .bold)
        badgeLbl.textColor         = ComponentColors.HomeScreen.actionButtonFill
        badgeLbl.backgroundColor   = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.12)
        badgeLbl.layer.cornerRadius = 5
        badgeLbl.clipsToBounds     = true
        badgeLbl.textAlignment     = .center
        badgeLbl.translatesAutoresizingMaskIntoConstraints = false
        badgeLbl.widthAnchor.constraint(equalToConstant: 38).isActive  = true
        badgeLbl.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let dateLbl = UILabel()
        dateLbl.text      = meta
        dateLbl.font      = .systemFont(ofSize: 12)
        dateLbl.textColor = SemanticColors.Text.tertiary

        let metaRow = UIStackView(arrangedSubviews: [badgeLbl, dateLbl])
        metaRow.axis      = .horizontal
        metaRow.spacing   = 6
        metaRow.alignment = .center

        let textStack = UIStackView(arrangedSubviews: [titleLbl, metaRow])
        textStack.axis    = .vertical
        textStack.spacing = 5
        textStack.isUserInteractionEnabled = false
        textStack.translatesAutoresizingMaskIntoConstraints = false

        // More button
        let moreBtn = UIButton(type: .system)
        moreBtn.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        moreBtn.tintColor = SemanticColors.Text.tertiary
        moreBtn.translatesAutoresizingMaskIntoConstraints = false
        moreBtn.showsMenuAsPrimaryAction = true
        
        let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { [weak self, weak titleLbl] _ in
            self?.showRenameAlert(for: scan.id, currentTitle: titleLbl?.text ?? title, titleLabel: titleLbl)
        }
        moreBtn.menu = UIMenu(title: "", children: [rename])

        card.addSubview(iconWrap); card.addSubview(textStack); card.addSubview(moreBtn)
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 76),
            iconWrap.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            iconWrap.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconWrap.widthAnchor.constraint(equalToConstant: 48),
            iconWrap.heightAnchor.constraint(equalToConstant: 48),
            iconImg.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            iconImg.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            iconImg.widthAnchor.constraint(equalToConstant: 26),
            iconImg.heightAnchor.constraint(equalToConstant: 26),
            textStack.leadingAnchor.constraint(equalTo: iconWrap.trailingAnchor, constant: 13),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: moreBtn.leadingAnchor, constant: -8),
            moreBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            moreBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            moreBtn.widthAnchor.constraint(equalToConstant: 30),
            moreBtn.heightAnchor.constraint(equalToConstant: 30)
        ])

        // ── Tap: pass jobId + resultURL so the next screen can fetch both
        //   the input PDF and the output JSON without an extra DB round-trip. ──
        card.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            let jsonDict = scan.jsonData?.value as? [String: Any]

            guard let jobIdStr = jsonDict?["job_id"] as? String,
                  let jobId    = UUID(uuidString: jobIdStr) else {
                print("[RowTap] ❌ No job_id in scan \(scan.id)")
                return
            }

            let outputURL = jsonDict?["output_url"] as? String

            let vc        = UploadPageNextViewController()
            vc.jobId      = jobId
            vc.resultURL  = outputURL
            print("[RowTap] jobId=\(jobId.uuidString.lowercased())  hasResultURL=\(outputURL?.isEmpty == false)")
            self.navigationController?.pushViewController(vc, animated: true)
        }, for: .touchUpInside)

        attachPressAnimations(to: card)
        return card
    }

    // MARK: - Row Options
    private func showRowOptions(for scanId: Int64, currentTitle: String, titleLabel: UILabel?) {
        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self] _ in
            self?.showRenameAlert(for: scanId, currentTitle: currentTitle, titleLabel: titleLabel)
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = ac.popoverPresentationController {
            pop.sourceView             = view
            pop.sourceRect             = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        present(ac, animated: true)
    }

    private func showRenameAlert(for scanId: Int64, currentTitle: String, titleLabel: UILabel?) {
        let alert = UIAlertController(title: "Rename File", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text                  = currentTitle
            tf.placeholder           = "Enter new name"
            tf.clearButtonMode       = .whileEditing
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self,
                  let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return }
            titleLabel?.text = name
            Task { await self.renameScan(id: scanId, newTitle: name) }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func renameScan(id scanId: Int64, newTitle: String) async {
        do {
            let scans: [Scan] = try await supabase.from("scans").select()
                .eq("id", value: Int(scanId)).limit(1).execute().value
            guard let scan = scans.first else { return }
            var dict = (scan.jsonData?.value as? [String: Any]) ?? [:]
            dict["title"] = newTitle
            let upd = ScanUpdate(
                jsonData:    AnyCodable(dict),
                status:      scan.status ?? "completed",
                processedAt: scan.processedAt ?? ISO8601DateFormatter().string(from: Date()),
                updatedAt:   ISO8601DateFormatter().string(from: Date())
            )
            try await supabase.from("scans").update(upd).eq("id", value: Int(scanId)).execute()
            print("[Rename] scan \(scanId) → \(newTitle)")
        } catch {
            print("[Rename] failed: \(error)")
            await MainActor.run { self.loadRecentUploads() }
        }
    }

    // MARK: - JSON Helpers
    private func extractTitle(from json: AnyCodable?) -> String? {
        (json?.value as? [String: Any])?["title"] as? String
    }

    private func extractOriginalFilename(from json: AnyCodable?) -> String? {
        guard let name = (json?.value as? [String: Any])?["original_filename"] as? String else { return nil }
        // Strip .pdf extension for display
        return name.hasSuffix(".pdf") ? String(name.dropLast(4)) : name
    }

    private func extractDate(from json: AnyCodable?, fallback: String?) -> String {
        if let ua = (json?.value as? [String: Any])?["uploaded_at"] as? String {
            return formatDate(ua)
        }
        return formatDate(fallback)
    }

    private func extractFileSize(from json: AnyCodable?) -> String {
        guard let d = json?.value as? [String: Any] else { return "" }
        if let b = d["file_size_bytes"] as? Int    { return formatBytes(b) }
        if let b = d["file_size_bytes"] as? Double { return formatBytes(Int(b)) }
        if let b = d["file_size"] as? Int          { return formatBytes(b) }
        if let s = d["file_size"] as? String, let b = Int(s) { return formatBytes(b) }
        return ""
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        return kb < 1024 ? String(format: "%.0f KB", kb)
                         : String(format: "%.1f MB", kb / 1024.0)
    }

    private func formatDate(_ s: String?) -> String {
        guard let s, !s.isEmpty else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return relativeDate(d) }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return relativeDate(d) }
        return ""
    }

    private func relativeDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        return DateFormatter.shortDate.string(from: date)
    }

    // MARK: - Auth Helpers
    private func currentUserId() async -> String? {
        do    { return try await SupabaseManager.shared.currentUserId() }
        catch { print("[Auth] user ID retrieval failed"); return nil }
    }

    private func authToken() async -> String? {
        do    { return try await SupabaseManager.shared.accessToken() }
        catch { print("[Auth] auth retrieval failed"); return nil }
    }

    // MARK: - Upload Pipeline
    private func saveUploadToDatabase(imageData: Data, fileName: String,
                                       fileType: String, popup: UploadQuizPopup) async throws {
        print("[Upload] size=\(imageData.count) bytes")

        guard let uidStr = await currentUserId(), let userId = UUID(uuidString: uidStr) else {
            throw UploadError.invalidUser
        }
        guard let token = await authToken() else {
            throw UploadError.missingToken
        }

        // ── Step 1: Railway API ───────────────────────────────────────────────────
        // Railway uploads the PDF to Supabase Storage with its service key and
        // returns the job ID. We do NOT re-upload from iOS (would 403 on RLS).
        let api = try await callConversionAPI(imageData: imageData,
                                              fileName: fileName, fileType: fileType, token: token)

        guard let jobIdStr = api["job_id"] as? String,
              let jobId = UUID(uuidString: jobIdStr) else { throw UploadError.badAPIResponse }

        let apiUidStr = uidStr.lowercased()
        let pdfPath   = "\(apiUidStr)/\(jobIdStr.lowercased())/input.pdf"
        let outputURL = "\(ReHersAPI.baseURLString)/sheets/\(jobIdStr.lowercased())"

        // ── Step 3: Build json_data (protect canonical keys from API overwrite) ───
        // Generate a unique timestamp-based filename for this upload.
        let timestampFilename = generateTimestampFilename()
        uploadTitle = String(timestampFilename.dropLast(4))  // strip .pdf for display title

        var jsonDict: [String: Any] = [
            "uploaded_at":         ISO8601DateFormatter().string(from: Date()),
            "title":               uploadTitle,           // e.g. "SheetMusic_2026-03-08_064025"
            "original_filename":   timestampFilename,     // e.g. "SheetMusic_2026-03-08_064025.pdf"
            "job_id":              jobIdStr,
            "user_id":             apiUidStr,
            "output_url":          outputURL,
            "file_size_bytes":     imageData.count
        ]
        let protectedKeys: Set<String> = ["job_id", "user_id", "output_url", "title", "status"]
        for (k, v) in api where !protectedKeys.contains(k) { jsonDict[k] = v }

        // ── Step 4: Upsert scan record ────────────────────────────────────────────
        let existingScans: [Scan] = try await supabase.from("scans").select()
            .eq("user_id", value: userId)
            .like("json_data->>'job_id'", pattern: "%\(jobIdStr)%")
            .execute().value

        if existingScans.isEmpty {
            let ins = ScanInsert(userId: userId, jsonData: AnyCodable(jsonDict),
                                  processingId: jobIdStr, status: "pending",
                                  originalFilename: timestampFilename, fileType: "application/pdf",
                                  processedAt: ISO8601DateFormatter().string(from: Date()))
            let _: Scan = try await supabase.from("scans").insert(ins).select().single().execute().value
        } else if let existing = existingScans.first {
            let upd = ScanUpdate(jsonData: AnyCodable(jsonDict), status: "pending",
                                  processedAt: ISO8601DateFormatter().string(from: Date()),
                                  updatedAt: ISO8601DateFormatter().string(from: Date()))
            try await supabase.from("scans").update(upd).eq("id", value: Int(existing.id)).execute()
        }

        // ── Navigate ──────────────────────────────────────────────────────────────
        await MainActor.run {
            self.loadRecentUploads()
            let vc       = UploadPageNextViewController()
            vc.jobId     = jobId
            vc.onDataReady = {
                popup.notifyUploadComplete()
            }
            print("[Navigate] jobId=\(jobId.uuidString)")
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    // MARK: - Conversion API
    private func callConversionAPI(imageData: Data, fileName: String,
                                   fileType: String, token: String) async throws -> [String: Any] {
        guard let url = ReHersAPI.url(path: "/convert") else {
            throw UploadError.noResponse
        }
        let boundary = UUID().uuidString
        var req      = URLRequest(url: url)
        req.httpMethod  = "POST"
        req.timeoutInterval = 60
        req.assumesHTTP3Capable = false   // force HTTP/1.1 — avoids QUIC sendmsg failures
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(fileType)\r\n\r\n")
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n")
        req.httpBody = body

        let (data, response) = try await ReHersPinnedSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw UploadError.noResponse }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw UploadError.apiError(http.statusCode, msg)
        }

        let obj = try JSONSerialization.jsonObject(with: data)
        if let d = obj as? [String: Any]              { return d }
        if let a = obj as? [[String: Any]], let f = a.first { return f }
        return ["api_response": obj, "status": "success"]
    }

    // MARK: - Document Scanner
    private func presentDocumentScanner() {
        guard VNDocumentCameraViewController.isSupported else {
            presentAlert(title: "Not Supported",
                         message: "Document scanning is not available on this device.")
            return
        }
        let vc = VNDocumentCameraViewController()
        vc.delegate = self
        present(vc, animated: true)
    }

    private func createPDFFromScan(_ scan: VNDocumentCameraScan) -> Data? {
        let pdf = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdf, CGRect(origin: .zero, size: Constants.pdfPageSize), nil)
        for i in 0..<scan.pageCount {
            UIGraphicsBeginPDFPageWithInfo(CGRect(origin: .zero, size: Constants.pdfPageSize), nil)
            let img  = scan.imageOfPage(at: i)
            let s    = min(Constants.pdfPageSize.width  / img.size.width,
                           Constants.pdfPageSize.height / img.size.height, 1.0)
            let w    = img.size.width * s;  let h = img.size.height * s
            img.draw(in: CGRect(x: (Constants.pdfPageSize.width  - w) / 2,
                                y: (Constants.pdfPageSize.height - h) / 2,
                                width: w, height: h))
            let txt   = "\(i + 1)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.gray
            ]
            let sz = txt.size(withAttributes: attributes)
            txt.draw(in: CGRect(x: (Constants.pdfPageSize.width - sz.width) / 2,
                                y: 10, width: sz.width, height: sz.height), withAttributes: attributes)
        }
        UIGraphicsEndPDFContext()
        return pdf as Data
    }

    // MARK: - Quiz Popup
    private func showQuizPopup() -> UploadQuizPopup {
        let popup = UploadQuizPopup()
        popup.delegate             = self
        popup.modalPresentationStyle = .overFullScreen
        popup.modalTransitionStyle   = .crossDissolve
        activeQuizPopup            = popup
        present(popup, animated: false)
        return popup
    }

    // MARK: - Error Presentation
    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    private func handleUploadError(_ error: Error, popup: UploadQuizPopup) {
        popup.dismiss(animated: true) { [weak self] in
            self?.presentAlert(title: "Upload Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Upload Errors
    enum UploadError: LocalizedError {
        case invalidUser, missingToken, badAPIResponse, noResponse
        case apiError(Int, String)
        var errorDescription: String? {
            switch self {
            case .invalidUser:    return "Could not retrieve your user ID."
            case .missingToken:   return "Could not retrieve authentication token."
            case .badAPIResponse: return "Missing job_id in API response."
            case .noResponse:     return "No response received from the server."
            case .apiError(let code, let msg): return "Server error \(code): \(msg)"
            }
        }
    }

    // MARK: - Data Models
    struct Job: Codable, Identifiable {
        let id: UUID; let userId: UUID; let pdfPath: String
        let resultUrl: String?; let status: String
        let errorMessage: String?; let createdAt: String?; let updatedAt: String?
        enum CodingKeys: String, CodingKey {
            case id; case userId = "user_id"; case pdfPath = "pdf_path"
            case resultUrl = "result_url"; case status
            case errorMessage = "error_message"; case createdAt = "created_at"; case updatedAt = "updated_at"
        }
    }
    struct JobInsert: Encodable {
        let id: UUID; let userId: UUID; let pdfPath: String; let resultUrl: String?; let status: String
        enum CodingKeys: String, CodingKey {
            case id; case userId = "user_id"; case pdfPath = "pdf_path"
            case resultUrl = "result_url"; case status
        }
    }
    struct JobUpdate: Encodable {
        let resultUrl: String?; let status: String?; let errorMessage: String?; let updatedAt: String
        enum CodingKeys: String, CodingKey {
            case resultUrl = "result_url"; case status
            case errorMessage = "error_message"; case updatedAt = "updated_at"
        }
        init(resultUrl: String? = nil, status: String? = nil,
             errorMessage: String? = nil, updatedAt: String) {
            self.resultUrl    = resultUrl;    self.status       = status
            self.errorMessage = errorMessage; self.updatedAt    = updatedAt
        }
    }
    struct Scan: Codable, Identifiable {
        let id: Int64; let userId: UUID; let jsonData: AnyCodable?; let processingId: String?
        let status: String?; let originalFilename: String?; let fileType: String?
        let processedAt: String?; let updatedAt: String?; let errorMessage: String?
        enum CodingKeys: String, CodingKey {
            case id; case userId = "user_id"; case jsonData = "json_data"
            case processingId = "processing_id"; case status
            case originalFilename = "original_filename"; case fileType = "file_type"
            case processedAt = "processed_at"; case updatedAt = "updated_at"
            case errorMessage = "error_message"
        }
    }
    struct ScanInsert: Encodable {
        let userId: UUID; let jsonData: AnyCodable; let processingId: String; let status: String
        let originalFilename: String?; let fileType: String?; let processedAt: String?
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"; case jsonData = "json_data"
            case processingId = "processing_id"; case status
            case originalFilename = "original_filename"; case fileType = "file_type"
            case processedAt = "processed_at"
        }
    }
    struct ScanUpdate: Encodable {
        let jsonData: AnyCodable; let status: String; let processedAt: String; let updatedAt: String
        enum CodingKeys: String, CodingKey {
            case jsonData = "json_data"; case status
            case processedAt = "processed_at"; case updatedAt = "updated_at"
        }
    }
    struct AnyCodable: Codable {
        let value: Any
        init(_ value: Any) { self.value = value }
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if      let b = try? c.decode(Bool.self)                  { value = b }
            else if let i = try? c.decode(Int.self)                   { value = i }
            else if let d = try? c.decode(Double.self)                { value = d }
            else if let s = try? c.decode(String.self)                { value = s }
            else if let a = try? c.decode([AnyCodable].self)          { value = a.map { $0.value } }
            else if let d = try? c.decode([String: AnyCodable].self)  { value = d.mapValues { $0.value } }
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
}

enum ReHersAPI {
    static var baseURLString: String {
        guard let rawBaseURL = Bundle.main.object(forInfoDictionaryKey: "BACKEND_API_URL") as? String else {
            fatalError("BACKEND_API_URL not set in build configuration")
        }

        let baseURL = rawBaseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        guard !baseURL.isEmpty else {
            fatalError("BACKEND_API_URL not set in build configuration")
        }

        return baseURL
    }

    static func url(path: String) -> URL? {
        URL(string: "\(baseURLString)\(path)")
    }
}

final class ReHersPinnedSessionDelegate: NSObject, URLSessionDelegate {
    private let expectedHost = URL(string: ReHersAPI.baseURLString)?.host ?? ""
    private let pinnedPublicKeyHash = "HHrSlgBFDK8S5rQlffqsyZ/rHPP7lqg6OR8l/+k3OIo="

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard challenge.protectionSpace.host == expectedHost,
              let trust = challenge.protectionSpace.serverTrust,
              SecTrustEvaluateWithError(trust, nil),
              let certificate = SecTrustGetCertificateAtIndex(trust, 0),
              let hash = spkiHash(for: certificate) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard hash == pinnedPublicKeyHash else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    private func spkiHash(for certificate: SecCertificate) -> String? {
        guard let key = SecCertificateCopyKey(certificate),
              let keyData = SecKeyCopyExternalRepresentation(key, nil) as Data?,
              let attributes = SecKeyCopyAttributes(key) as? [String: Any],
              let keyType = attributes[kSecAttrKeyType as String] as? String else {
            return nil
        }

        let algorithmIdentifier: Data
        if keyType == (kSecAttrKeyTypeRSA as String) {
            algorithmIdentifier = Data([
                0x30, 0x0d,
                0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01,
                0x05, 0x00
            ])
        } else {
            return nil
        }

        let subjectPublicKey = derEncoded(tag: 0x03, body: Data([0x00]) + keyData)
        let spki = derEncoded(tag: 0x30, body: algorithmIdentifier + subjectPublicKey)
        return Data(SHA256.hash(data: spki)).base64EncodedString()
    }

    private func derEncoded(tag: UInt8, body: Data) -> Data {
        var data = Data([tag])
        data.append(derLength(body.count))
        data.append(body)
        return data
    }

    private func derLength(_ length: Int) -> Data {
        if length < 0x80 {
            return Data([UInt8(length)])
        }

        var value = length
        var bytes: [UInt8] = []
        while value > 0 {
            bytes.insert(UInt8(value & 0xff), at: 0)
            value >>= 8
        }

        return Data([0x80 | UInt8(bytes.count)] + bytes)
    }
}

enum ReHersPinnedSession {
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: ReHersPinnedSessionDelegate(), delegateQueue: nil)
    }()
}

// MARK: - VNDocumentCameraViewControllerDelegate
extension UploadScreen: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                       didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true)
        Task {
            guard let pdfData = self.createPDFFromScan(scan) else { return }
            self.currentUploadData = pdfData
            self.currentFileName   = generateTimestampFilename()
            self.currentFileType   = "application/pdf"
            let popup = await MainActor.run { self.showQuizPopup() }
            do {
                try await self.saveUploadToDatabase(imageData: pdfData,
                                                     fileName: self.currentFileName,
                                                     fileType: self.currentFileType,
                                                     popup: popup)
            } catch {
                await MainActor.run { self.handleUploadError(error, popup: popup) }
            }
        }
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate + UIImagePickerControllerDelegate
extension UploadScreen: UIImagePickerControllerDelegate, UINavigationControllerDelegate,
                         UIDocumentPickerDelegate, UploadQuizPopupDelegate {

    func uploadQuizPopupDidClose(_ popup: UploadQuizPopup) { activeQuizPopup = nil }

    func openFileManager() {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf, .data, .item], asCopy: true)
        picker.delegate             = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileURL = urls.first else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            currentUploadData = data
            currentFileName   = generateTimestampFilename()   // unique per upload
            currentFileType   = "application/pdf"
            let popup = showQuizPopup()
            Task {
                do {
                    try await saveUploadToDatabase(imageData: data,
                                                    fileName: currentFileName,
                                                    fileType: currentFileType, popup: popup)
                } catch {
                    await MainActor.run { self.handleUploadError(error, popup: popup) }
                }
            }
        } catch {
            presentAlert(title: "Error", message: "Failed to read file: \(error.localizedDescription)")
        }
    }

    func imagePickerController(_ picker: UIImagePickerController,
                                didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    @objc private func seeMoreTapped() {
        let vc = AllUploadsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - UIColor Hex
extension UIColor {
    convenience init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(red:   CGFloat((rgb & 0xFF0000) >> 16) / 255,
                  green: CGFloat((rgb & 0x00FF00) >>  8) / 255,
                  blue:  CGFloat( rgb & 0x0000FF)         / 255, alpha: 1)
    }
}

// MARK: - GradientView
private class GradientView: UIView {
    private let gl = CAGradientLayer()
    init(colors: [UIColor]) {
        super.init(frame: .zero)
        gl.colors     = colors.map { $0.cgColor }
        gl.startPoint = CGPoint(x: 0, y: 0)
        gl.endPoint   = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gl)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() { super.layoutSubviews(); gl.frame = bounds }
}

// MARK: - UILabel Tracking
private extension UILabel {
    func letterSpacing(_ spacing: CGFloat) {
        guard let text else { return }
        let a = NSMutableAttributedString(string: text)
        a.addAttribute(.kern, value: spacing, range: NSRange(location: 0, length: text.count))
        attributedText = a
    }
}

// MARK: - DateFormatter Convenience
private extension DateFormatter {
    static let shortDate: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
    }()
}

// MARK: - NSLayoutConstraint Helpers
private extension NSLayoutConstraint {
    static func pin(_ view: UIView, to other: UIView) -> [NSLayoutConstraint] {
        [view.topAnchor.constraint(equalTo: other.topAnchor),
         view.leadingAnchor.constraint(equalTo: other.leadingAnchor),
         view.trailingAnchor.constraint(equalTo: other.trailingAnchor),
         view.bottomAnchor.constraint(equalTo: other.bottomAnchor)]
    }
}

private extension UIView {
    func pinEdges(to other: UIView) -> [NSLayoutConstraint] {
        NSLayoutConstraint.pin(self, to: other)
    }
}

// MARK: - Data Append Helper
private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}

// MARK: - UIScrollViewDelegate
extension UploadScreen: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        syncNavBarAlpha()
    }
    @available(iOS, deprecated: 17.0)
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            largeProfileButton.layer.borderColor = (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black).cgColor
        }
    }
}
