//
//  UploadScreen.swift
//  Re-Hearse_v1
//

import UIKit
import AVFoundation
import PhotosUI
import VisionKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Supabase
import Auth
internal import PostgREST
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
        static let maxUploadSizeBytes = 10 * 1024 * 1024
    }

    // MARK: - State
    private var uploadTitle: String = DateFormatter.shortDate.string(from: Date())
    private let defaultUploadTitleBase = "Untitled Sheet"

    /// Unique filename per upload, e.g. "SheetMusic_2026-03-08_064025.pdf".
    /// Stored internally for the file payload so uploads always remain unique.
    private func generateTimestampFilename() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return "SheetMusic_\(f.string(from: Date())).pdf"
    }

    private func generateUniqueUploadTitle(for userId: UUID) async throws -> String {
        struct ScanTitleRow: Decodable {
            let jsonData: AnyCodable?
            let originalFilename: String?

            enum CodingKeys: String, CodingKey {
                case jsonData = "json_data"
                case originalFilename = "original_filename"
            }
        }

        let scans: [ScanTitleRow] = try await supabase
            .from("scans")
            .select("json_data, original_filename")
            .eq("user_id", value: userId)
            .limit(200)
            .execute()
            .value

        let existingTitles: Set<String> = Set(scans.compactMap { scan in
            if let jsonTitle = (scan.jsonData?.value as? [String: Any])?["title"] as? String,
               !jsonTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return jsonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard let fallbackName = scan.originalFilename?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !fallbackName.isEmpty else { return nil }
            return fallbackName.hasSuffix(".pdf") ? String(fallbackName.dropLast(4)) : fallbackName
        })

        if !existingTitles.contains(defaultUploadTitleBase) {
            return defaultUploadTitleBase
        }

        var suffix = 2
        while existingTitles.contains("\(defaultUploadTitleBase) \(suffix)") {
            suffix += 1
        }
        return "\(defaultUploadTitleBase) \(suffix)"
    }
    private var currentUploadData: Data?
    private var currentFileName  = ""
    private var currentFileType  = ""
    private var activeQuizPopup: UploadQuizPopup?
    private var recentUploadsStack: UIStackView?
    private weak var activeDocumentPicker: UIDocumentPickerViewController?
    private weak var activeDocumentScanner: VNDocumentCameraViewController?
    private weak var activePhotoPicker: PHPickerViewController?
    private weak var activeCameraController: UploadCameraCaptureViewController?
    private var profileFetchTask: Task<Void, Never>?
    private var recentUploadsTask: Task<Void, Never>?
    private var renameTask: Task<Void, Never>?
    private var uploadTask: Task<Void, Never>?
    private var currentUploadSource = "unknown"
    private var latestRecentUploads: [Scan] = []
    private var recentUploadsErrorMessage: String?
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

    deinit {
        NotificationCenter.default.removeObserver(self)
        cancelPendingTasks()
        clearUploadState()
        releaseTransientPickers()
    }

    @objc private func handleProfileUpdate() {
        fetchProfileData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadRecentUploads()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isMovingFromParent || isBeingDismissed {
            NotificationCenter.default.removeObserver(self)
            cancelPendingTasks()
            clearUploadState()
            releaseTransientPickers()
        }
    }

    func startUploadFlow() {
        guard !presentSheetUploadGuestGateIfNeeded() else { return }
        presentVisionKitScanner()
    }

    @discardableResult
    private func presentSheetUploadGuestGateIfNeeded() -> Bool {
        guard GuestFeatureAccessPolicy.shouldGateSheetUploadActions(
            forGuest: GuestSessionManager.shared.isGuest()
        ) else { return false }
        guard let presenter = guestGatePresenter(), presenter.presentedViewController == nil else { return true }

        let gateModal = GuestFeatureGateModal(
            featureName: "sheet music upload",
            onSignUp: { [weak self] in
                self?.scheduleAuthPresentation(mode: .signUp)
            },
            onLogIn: { [weak self] in
                self?.scheduleAuthPresentation(mode: .logIn)
            }
        )

        gateModal.presentationController?.delegate = self
        presenter.present(gateModal, animated: true)
        return true
    }

    private func scheduleAuthPresentation(mode: AuthViewController.AuthMode) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let presenter = self.guestGatePresenter(), presenter.presentedViewController == nil else { return }

            let authViewController = AuthViewController(initialMode: mode)
            let authNavigationController = UINavigationController(rootViewController: authViewController)
            authNavigationController.modalPresentationStyle = .fullScreen
            presenter.present(authNavigationController, animated: true)
        }
    }

    private func guestGatePresenter() -> UIViewController? {
        if let navigationController = tabBarController?.selectedViewController as? UINavigationController {
            return navigationController.visibleViewController ?? navigationController.topViewController ?? navigationController
        }

        return tabBarController?.selectedViewController ?? tabBarController
    }

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
        profileFetchTask?.cancel()
        profileFetchTask = Task { [weak self] in
            guard let self else { return }
            guard let user = SupabaseManager.shared.client.auth.currentUser else {
                await MainActor.run {
                    self.largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    self.largeProfileButton.tintColor = .secondaryLabel
                }
                return
            }
            do {
                let profile: UserProfile = try await SupabaseManager.shared.client
                    .from("profiles").select().eq("id", value: user.id).single().execute().value
                if Task.isCancelled { return }
                if let avatarUrl = profile.avatar_url, !avatarUrl.isEmpty {
                    await self.loadAndSetProfileImage(from: avatarUrl)
                } else {
                    await MainActor.run {
                        self.largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                        self.largeProfileButton.tintColor = .secondaryLabel
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                debugLog("Profile error: \(error)")
                await MainActor.run {
                    self.largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    self.largeProfileButton.tintColor = .secondaryLabel
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
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 96), // Match Home so content flows behind the navbar consistently
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -56),
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
    @objc private func scanTapped() {
        guard !presentSheetUploadGuestGateIfNeeded() else { return }
        presentVisionKitScanner()
    }

    @objc private func uploadFileTapped() {
        guard !presentSheetUploadGuestGateIfNeeded() else { return }
        openFileManager()
    }

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
        recentUploadsTask?.cancel()
        recentUploadsTask = Task { [weak self] in
            guard let self else { return }
            do {
                let uploads = try await self.fetchRecentUploads()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.latestRecentUploads = uploads
                    self.recentUploadsErrorMessage = nil
                    self.displayRecentUploads(uploads)
                }
            } catch {
                guard !Task.isCancelled else { return }
                debugLog("[Uploads] load error: \(error)")
                let message = AppUserFacingError.message(
                    for: "load your recent uploads",
                    error: error,
                    fallback: "We couldn't load your recent uploads right now. Please try again."
                )
                await MainActor.run {
                    if self.latestRecentUploads.isEmpty {
                        self.recentUploadsErrorMessage = message
                        self.displayRecentUploads([])
                    } else {
                        self.recentUploadsErrorMessage = nil
                        self.displayRecentUploads(self.latestRecentUploads)
                    }
                }
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
        if scans.isEmpty {
            stack.addArrangedSubview(makeEmptyState(message: recentUploadsErrorMessage))
            return
        }
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

    private func makeEmptyState(message: String?) -> UIView {
        let container = UIView()
        container.backgroundColor  = .secondarySystemBackground
        container.layer.cornerRadius = 14
        let label = UILabel()
        label.text          = message ?? "No recent uploads yet"
        label.textColor     = .tertiaryLabel
        label.font          = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.numberOfLines = 0
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
        let delete = UIAction(
            title: "Delete Upload",
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.confirmDeleteScan(id: scan.id, title: titleLbl.text ?? title)
        }
        moreBtn.menu = UIMenu(title: "", children: [rename, delete])

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
                debugLog("[RowTap] ❌ No job_id in scan \(scan.id)")
                return
            }

            let outputURL = jsonDict?["output_url"] as? String
            Task { [weak self] in
                guard let self else { return }
                if let statusMessage = await self.jobStatusGateMessage(jobId: jobId) {
                    await MainActor.run {
                        self.presentUploadStatusAlert(title: title, message: statusMessage)
                    }
                    return
                }

                await MainActor.run {
                    let vc        = UploadPageNextViewController()
                    vc.jobId      = jobId
                    vc.resultURL  = outputURL
                    debugLog("[RowTap] jobId=\(jobId.uuidString.lowercased())  hasResultURL=\(outputURL?.isEmpty == false)")
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
        }, for: .touchUpInside)

        attachPressAnimations(to: card)
        return card
    }

    private func jobStatusGateMessage(jobId: UUID) async -> String? {
        struct JobStatusRow: Decodable {
            let status: String?
            let errorMessage: String?
            let labelStatus: String?
            let labelWarning: String?
            let resultUrl: String?
            enum CodingKeys: String, CodingKey {
                case status
                case errorMessage = "error_message"
                case labelStatus = "label_status"
                case labelWarning = "label_warning"
                case resultUrl = "result_url"
            }
        }

        do {
            let rows: [JobStatusRow] = try await supabase
                .from("jobs")
                .select("status, error_message, label_status, label_warning, result_url")
                .eq("id", value: jobId)
                .limit(1)
                .execute()
                .value

            guard let row = rows.first else { return nil }
            let status = row.status?.lowercased() ?? ""
            let labelStatus = row.labelStatus?.lowercased() ?? ""
            let hasResult = (row.resultUrl?.isEmpty == false)

            if (status == "pending" || status == "processing") && !hasResult {
                return "This sheet music is still being prepared. Please wait a little longer, then try again."
            }

            if status == "failed" {
                if let message = userFriendlyUploadStatusMessage(
                    rawMessage: row.errorMessage,
                    fallback: "We couldn't convert this sheet music. The file may be unclear, unsupported, or incomplete."
                ) {
                    return message
                }
                return "This upload could not be converted successfully. The sheet may be unclear, unsupported, or incomplete."
            }

            if labelStatus == "failed" {
                if let message = userFriendlyUploadStatusMessage(
                    rawMessage: row.labelWarning ?? row.errorMessage,
                    fallback: "We processed this file, but couldn't prepare the practice sheet for it."
                ) {
                    return message
                }
                return "We processed this file, but couldn't prepare the practice sheet for it."
            }

            if hasResult && (labelStatus.isEmpty || labelStatus == "success") {
                return nil
            }

            return nil
        } catch {
            debugLog("[UploadStatus] job lookup failed: \(error)")
            return nil
        }
    }

    private func userFriendlyUploadStatusMessage(rawMessage: String?, fallback: String) -> String? {
        let trimmed = rawMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return fallback }

        let lowercased = trimmed.lowercased()
        if lowercased.contains("note labeling pipeline failed") {
            return "We processed this file, but couldn't recognize the notes clearly enough to build a practice sheet."
        }
        if lowercased.contains("timeout") {
            return "The conversion took too long and couldn't be completed. Please try again with a clearer file."
        }
        if lowercased.contains("unsupported") {
            return "This file format or sheet layout isn't supported yet. Please try a different file."
        }

        return trimmed
    }

    private func presentUploadStatusAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: "Upload Not Ready",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Row Options
    private func showRowOptions(for scanId: Int64, currentTitle: String, titleLabel: UILabel?) {
        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self] _ in
            self?.showRenameAlert(for: scanId, currentTitle: currentTitle, titleLabel: titleLabel)
        })
        ac.addAction(UIAlertAction(title: "Delete Upload", style: .destructive) { [weak self] _ in
            self?.confirmDeleteScan(id: scanId, title: currentTitle)
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
            guard let self else { return }
            let name = InputValidator.limit(
                InputValidator.trimOnSubmit(alert.textFields?.first?.text ?? ""),
                maxLength: InputValidator.nameMaxLength
            )
            guard InputValidator.validateRequired(name, message: "File name is required.") == nil else {
                self.presentAlert(title: "Error", message: "File name is required.")
                return
            }
            titleLabel?.text = name
            self.renameTask?.cancel()
            self.renameTask = Task { [weak self] in
                guard let self else { return }
                await self.renameScan(id: scanId, newTitle: name)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func renameScan(id scanId: Int64, newTitle: String) async {
        let sanitizedTitle = InputValidator.limit(
            InputValidator.trimOnSubmit(newTitle),
            maxLength: InputValidator.nameMaxLength
        )
        guard InputValidator.validateRequired(sanitizedTitle, message: "File name is required.") == nil else {
            await MainActor.run {
                self.presentAlert(title: "Error", message: "File name is required.")
            }
            return
        }

        do {
            let scans: [Scan] = try await supabase.from("scans").select()
                .eq("id", value: Int(scanId)).limit(1).execute().value
            guard let scan = scans.first else { return }
            var dict = (scan.jsonData?.value as? [String: Any]) ?? [:]
            dict["title"] = sanitizedTitle
            let upd = ScanUpdate(
                jsonData:    AnyCodable(dict),
                status:      scan.status ?? "completed",
                processedAt: scan.processedAt ?? ISO8601DateFormatter().string(from: Date()),
                updatedAt:   ISO8601DateFormatter().string(from: Date())
            )
            try await supabase.from("scans").update(upd).eq("id", value: Int(scanId)).execute()
            debugLog("[Rename] scan \(scanId) → \(sanitizedTitle)")
        } catch {
            debugLog("[Rename] failed: \(error)")
            let message = AppUserFacingError.message(
                for: "rename that upload",
                error: error,
                fallback: "We couldn't rename that file right now. Please try again."
            )
            await MainActor.run {
                self.loadRecentUploads()
                self.presentAlert(title: AppUserFacingError.title(for: error), message: message)
            }
        }
    }

    private func confirmDeleteScan(id scanId: Int64, title: String) {
        let alert = UIAlertController(
            title: "Delete Upload?",
            message: "This will remove \"\(title)\" from your uploads list.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteScanTask(id: scanId)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func deleteScanTask(id scanId: Int64) {
        Task { [weak self] in
            guard let self else { return }
            await self.deleteScan(id: scanId)
        }
    }

    private func deleteScan(id scanId: Int64) async {
        do {
            try await supabase
                .from("scans")
                .delete()
                .eq("id", value: Int(scanId))
                .execute()
            await MainActor.run { self.loadRecentUploads() }
        } catch {
            debugLog("[Delete] failed: \(error)")
            let message = AppUserFacingError.message(
                for: "delete that upload",
                error: error,
                fallback: "We couldn't delete this upload. Please try again."
            )
            await MainActor.run {
                let alert = UIAlertController(
                    title: AppUserFacingError.title(for: error),
                    message: message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
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
        catch { debugLog("[Auth] user ID retrieval failed"); return nil }
    }

    private func authToken() async -> String? {
        do    { return try await SupabaseManager.shared.accessToken() }
        catch { debugLog("[Auth] auth retrieval failed"); return nil }
    }

    // MARK: - Upload Pipeline
    private func saveUploadToDatabase(imageData: Data, fileName: String,
                                       fileType: String, popup: UploadQuizPopup) async throws {
        debugLog("[Upload] size=\(imageData.count) bytes")

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
        let timestampFilename = generateTimestampFilename()
        let friendlyTitle = try await generateUniqueUploadTitle(for: userId)
        uploadTitle = friendlyTitle

        var jsonDict: [String: Any] = [
            "uploaded_at":         ISO8601DateFormatter().string(from: Date()),
            "title":               friendlyTitle,
            "original_filename":   timestampFilename,
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
            AnalyticsManager.logUploadCompleted(
                source: self.currentUploadSource,
                fileType: fileType,
                fileSizeBytes: imageData.count
            )
            self.loadRecentUploads()
            self.clearUploadState()
            let vc       = UploadPageNextViewController()
            vc.jobId     = jobId
            vc.onDataReady = {
                popup.notifyUploadComplete()
            }
            debugLog("[Navigate] jobId=\(jobId.uuidString)")
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
        if #available(iOS 14.5, *) {
            req.assumesHTTP3Capable = false   // force HTTP/1.1 — avoids QUIC sendmsg failures
        }
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

    // MARK: - Document Scanner (VisionKit)
    private func presentVisionKitScanner() {
        guard VNDocumentCameraViewController.isSupported else {
            presentAlert(title: "Scanner Unavailable",
                         message: "Document scanning is not supported on this device.")
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showDocumentScanner()
        case .notDetermined:
            presentScannerCameraAccessRationale()
        case .denied, .restricted:
            presentSettingsRedirectAlert(
                title: "Camera Access Needed",
                message: "Allow camera access in Settings to scan sheet music pages for upload."
            )
        @unknown default:
            presentSettingsRedirectAlert(
                title: "Camera Access Needed",
                message: "Allow camera access in Settings to scan sheet music pages for upload."
            )
        }
    }

    private func showDocumentScanner() {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = self
        activeDocumentScanner = scanner
        present(scanner, animated: true)
    }

    private func presentScannerCameraAccessRationale() {
        let alert = UIAlertController(
            title: "Use Camera to Scan Sheet Music",
            message: "Re-Hearse uses the camera only when you choose Scan so you can capture sheet music pages for upload and analysis.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    granted ? self.showDocumentScanner() : self.presentSettingsRedirectAlert(
                        title: "Camera Access Needed",
                        message: "Allow camera access in Settings to scan sheet music pages for upload."
                    )
                }
            }
        })
        present(alert, animated: true)
    }

    private func dismissDocumentScanner(_ scanner: VNDocumentCameraViewController,
                                        completion: (() -> Void)? = nil) {
        scanner.delegate = nil
        activeDocumentScanner = nil
        guard scanner.presentingViewController != nil else {
            completion?()
            return
        }
        scanner.dismiss(animated: true, completion: completion)
    }

    private func presentUploadCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showUploadCamera()
        case .notDetermined:
            presentCameraAccessRationale()
        case .denied, .restricted:
            presentSettingsRedirectAlert(
                title: "Camera Access Needed",
                message: "Allow camera access in Settings to capture sheet music pages for upload."
            )
        @unknown default:
            presentSettingsRedirectAlert(
                title: "Camera Access Needed",
                message: "Allow camera access in Settings to capture sheet music pages for upload."
            )
        }
    }

    private func presentPhotoLibraryPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        activePhotoPicker = picker
        present(picker, animated: true)
    }

    private func showUploadCamera() {
        let cameraVC = UploadCameraCaptureViewController()
        cameraVC.delegate = self
        cameraVC.modalPresentationStyle = .fullScreen
        activeCameraController = cameraVC
        present(cameraVC, animated: true)
    }

    private func presentCameraAccessRationale() {
        let alert = UIAlertController(
            title: "Capture Sheet Music",
            message: "Re-Hearse uses the camera only when you choose Camera so you can photograph sheet music pages for upload and analysis.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    granted ? self.showUploadCamera() : self.presentSettingsRedirectAlert(
                        title: "Camera Access Needed",
                        message: "Allow camera access in Settings to capture sheet music pages for upload."
                    )
                }
            }
        })
        present(alert, animated: true)
    }

    private func presentSettingsRedirectAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsURL)
        })
        present(alert, animated: true)
    }

    private func createPDF(from images: [UIImage]) -> Data? {
        guard !images.isEmpty else { return nil }
        let pdf = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdf, CGRect(origin: .zero, size: Constants.pdfPageSize), nil)
        for (index, image) in images.enumerated() {
            autoreleasepool {
                // Normalize orientation — VisionKit images can arrive rotated
                let normalized = image.normalizedOrientation()
                UIGraphicsBeginPDFPageWithInfo(
                    CGRect(origin: .zero, size: Constants.pdfPageSize), nil)
                // Scale to fit the page, no 1.0 cap — scanner images are always high-res
                let scale = min(Constants.pdfPageSize.width  / normalized.size.width,
                                Constants.pdfPageSize.height / normalized.size.height)
                let w = normalized.size.width  * scale
                let h = normalized.size.height * scale
                let rect = CGRect(x: (Constants.pdfPageSize.width  - w) / 2,
                                  y: (Constants.pdfPageSize.height - h) / 2,
                                  width: w, height: h)
                normalized.draw(in: rect)
                // Page number
                let txt = "\(index + 1)"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.gray
                ]
                let sz = txt.size(withAttributes: attrs)
                txt.draw(in: CGRect(x: (Constants.pdfPageSize.width - sz.width) / 2,
                                    y: 10, width: sz.width, height: sz.height),
                         withAttributes: attrs)
            }
        }
        // ⚠️ MUST call EndPDFContext BEFORE reading pdf data.
        // Swift evaluates `return pdf as Data` (copies NSMutableData → Data)
        // BEFORE a `defer` fires, so the PDF trailer would never be written.
        UIGraphicsEndPDFContext()

        guard pdf.length > 4 else { return nil }
        return pdf as Data
    }

    // MARK: - Quiz Popup
    private func showQuizPopup() -> UploadQuizPopup {
        let popup = UploadQuizPopup()
        popup.delegate = self
        
        if #available(iOS 16.0, *) {
            popup.modalPresentationStyle = .pageSheet
            if let sheet = popup.sheetPresentationController {
                // Custom detent at ~65% of screen height for a "bigger" feel than medium
                let customDetent = UISheetPresentationController.Detent.custom { context in
                    return context.maximumDetentValue * 0.65
                }
                sheet.detents = [customDetent, .large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 32
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
        } else if #available(iOS 15.0, *) {
            popup.modalPresentationStyle = .pageSheet
            if let sheet = popup.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 32
            }
        } else {
            popup.modalPresentationStyle = .overFullScreen
            popup.modalTransitionStyle = .coverVertical
        }
        
        activeQuizPopup = popup
        present(popup, animated: true)
        return popup
    }

    // MARK: - Error Presentation
    private func presentAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    private func handleUploadError(_ error: Error, popup: UploadQuizPopup) {
        AnalyticsManager.logUploadFailed(
            source: currentUploadSource,
            reason: error.localizedDescription
        )
        clearUploadState()
        activeQuizPopup = nil
        let title = AppUserFacingError.title(for: error)
        let message = AppUserFacingError.message(
            for: "finish this upload",
            error: error,
            fallback: "Our servers are facing an issue. Please try uploading something else."
        )
        popup.dismiss(animated: true) { [weak self] in
            self?.presentAlert(title: title, message: message)
        }
    }

    private func canStartUploadRequest() -> Bool {
        guard AppConnectivityMonitor.shared.isOnline else {
            presentAlert(
                title: "No Internet Connection",
                message: "Your internet connection appears to be offline. Please reconnect before uploading."
            )
            return false
        }
        return true
    }

    private func validateUploadSize(_ data: Data, title: String = "Upload Too Large") -> Bool {
        guard data.count <= Constants.maxUploadSizeBytes else {
            presentAlert(title: title, message: "Files must be under 10 MB.")
            return false
        }
        return true
    }

    private func clearUploadState() {
        currentUploadData = nil
        currentFileName = ""
        currentFileType = ""
        currentUploadSource = "unknown"
    }

    private func cancelPendingTasks() {
        profileFetchTask?.cancel()
        recentUploadsTask?.cancel()
        renameTask?.cancel()
        uploadTask?.cancel()
    }

    private func releaseTransientPickers() {
        activeDocumentPicker?.delegate  = nil
        activePhotoPicker?.delegate     = nil
        activeCameraController?.delegate = nil
        activeDocumentScanner?.delegate = nil
        activeDocumentPicker   = nil
        activePhotoPicker      = nil
        activeCameraController = nil
        activeDocumentScanner  = nil
    }

    private func dismissDocumentPicker(_ controller: UIDocumentPickerViewController,
                                       completion: (() -> Void)? = nil) {
        activeDocumentPicker = nil
        controller.delegate = nil
        guard controller.presentingViewController != nil else {
            completion?()
            return
        }
        controller.dismiss(animated: true, completion: completion)
    }

    private func dismissPhotoPicker(_ picker: PHPickerViewController,
                                    completion: (() -> Void)? = nil) {
        activePhotoPicker = nil
        picker.delegate = nil
        guard picker.presentingViewController != nil else {
            completion?()
            return
        }
        picker.dismiss(animated: true, completion: completion)
    }

    private func dismissUploadCamera(_ controller: UploadCameraCaptureViewController,
                                     completion: (() -> Void)? = nil) {
        activeCameraController = nil
        controller.delegate = nil
        guard controller.presentingViewController != nil else {
            completion?()
            return
        }
        controller.dismiss(animated: true, completion: completion)
    }

    private func beginUpload(with image: UIImage) {
        switch validateAndPrepareImage(image) {
        case .failure(let error):
            presentAlert(title: "Scan Failed", message: error.userMessage)
            return
        case .success(let preparedImage):
            guard let pdfData = createPDF(from: [preparedImage]) else {
                presentAlert(title: "Scan Failed", message: "Could not prepare the captured image for upload.")
                return
            }
            guard validateUploadSize(pdfData) else { return }
            guard canStartUploadRequest() else { return }

            currentUploadData = pdfData
            currentFileName = generateTimestampFilename()
            currentFileType = "application/pdf"
            currentUploadSource = "image_capture"

            let popup = showQuizPopup()
            AnalyticsManager.logUploadStarted(source: currentUploadSource, fileType: currentFileType)
            uploadTask?.cancel()
            uploadTask = Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.saveUploadToDatabase(imageData: pdfData,
                                                        fileName: self.currentFileName,
                                                        fileType: self.currentFileType,
                                                        popup: popup)
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run { self.handleUploadError(error, popup: popup) }
                }
            }
        }
    }

    private func validateAndPrepareImage(_ image: UIImage) -> Result<UIImage, ImageValidationError> {
        guard let sourceData = image.normalized().pngData() ?? image.normalized().jpegData(compressionQuality: 1.0) else {
            return .failure(.processingFailed)
        }

        switch ImageValidator.validateAndPrepareImageData(sourceData, typeIdentifier: nil) {
        case .success(let prepared):
            guard let preparedImage = UIImage(data: prepared.data) else {
                return .failure(.processingFailed)
            }
            return .success(preparedImage)
        case .failure(let error):
            return .failure(error)
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
        // NOTE: Certificate pinning is disabled for now to allow backend URL changes
        // (e.g., redeployments to a new Azure Container Apps domain) without breaking uploads.
        completionHandler(.performDefaultHandling, nil)
        return

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

protocol UploadCameraCaptureViewControllerDelegate: AnyObject {
    func uploadCameraCaptureViewController(_ controller: UploadCameraCaptureViewController,
                                           didCapture image: UIImage)
    func uploadCameraCaptureViewControllerDidCancel(_ controller: UploadCameraCaptureViewController)
}

final class UploadCameraCaptureViewController: UIViewController {
    weak var delegate: UploadCameraCaptureViewControllerDelegate?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.rehearse.upload.camera.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isSessionConfigured = false

    private let shutterButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildUI()
        configureSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSessionIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    deinit {
        stopSession()
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
    }

    private func buildUI() {
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview

        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 36
        shutterButton.layer.borderWidth = 6
        shutterButton.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        shutterButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(shutterButton)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(cancelCapture), for: .touchUpInside)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            shutterButton.widthAnchor.constraint(equalToConstant: 72),
            shutterButton.heightAnchor.constraint(equalToConstant: 72),

            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.isSessionConfigured else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            defer {
                self.session.commitConfiguration()
            }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input),
                  self.session.canAddOutput(self.photoOutput) else {
                DispatchQueue.main.async { [weak self] in
                    self?.presentAlert(message: "Camera is unavailable on this device.")
                }
                return
            }

            self.session.addInput(input)
            self.session.addOutput(self.photoOutput)
            self.photoOutput.isHighResolutionCaptureEnabled = true
            self.isSessionConfigured = true
        }
    }

    private func startSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self, self.isSessionConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    private func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    @objc private func cancelCapture() {
        delegate?.uploadCameraCaptureViewControllerDidCancel(self)
    }

    private func presentAlert(message: String) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Camera Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self else { return }
            self.delegate?.uploadCameraCaptureViewControllerDidCancel(self)
        })
        present(alert, animated: true)
    }
}

extension UploadCameraCaptureViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            debugLog("[UploadCamera] capture failed: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.presentAlert(message: "We couldn't capture that photo. Please try again.")
            }
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            autoreleasepool {
                guard let data = photo.fileDataRepresentation(),
                      let image = UIImage(data: data) else {
                    DispatchQueue.main.async { [weak self] in
                        self?.presentAlert(message: "Could not decode captured photo.")
                    }
                    return
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.delegate?.uploadCameraCaptureViewController(self, didCapture: image)
                }
            }
        }
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate
extension UploadScreen: VNDocumentCameraViewControllerDelegate {

    func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                      didFinishWith scan: VNDocumentCameraScan) {
        dismissDocumentScanner(controller) { [weak self] in
            guard let self else { return }
            // Collect all scanned pages — VisionKit already removes shadows
            // and corrects perspective. We then apply Apple's built-in
            // CIPhotoEffectNoir filter for a pure B&W scanned-document look.
            var pages: [UIImage] = []
            for index in 0 ..< scan.pageCount {
                autoreleasepool {
                    let raw = scan.imageOfPage(at: index)
                    let styled = raw.applyDocumentStyle()
                    if case let .success(preparedPage) = self.validateAndPrepareImage(styled) {
                        pages.append(preparedPage)
                    }
                }
            }
            guard !pages.isEmpty else {
                self.presentAlert(title: "Scan Empty",
                                  message: "No pages were captured. Please try again.")
                return
            }
            // Convert pages → PDF, then run the standard upload pipeline
            guard let pdfData = self.createPDF(from: pages) else {
                self.presentAlert(title: "Scan Failed",
                                  message: "Could not create a PDF from the scanned pages.")
                return
            }
            guard self.canStartUploadRequest() else { return }
            self.currentUploadData = pdfData
            self.currentFileName   = self.generateTimestampFilename()
            self.currentFileType   = "application/pdf"
            self.currentUploadSource = "document_scanner"
            let popup = self.showQuizPopup()
            AnalyticsManager.logUploadStarted(source: self.currentUploadSource, fileType: self.currentFileType)
            self.uploadTask?.cancel()
            self.uploadTask = Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.saveUploadToDatabase(imageData: pdfData,
                                                        fileName: self.currentFileName,
                                                        fileType: self.currentFileType,
                                                        popup: popup)
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run { self.handleUploadError(error, popup: popup) }
                }
            }
        }
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        dismissDocumentScanner(controller)
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                      didFailWithError error: Error) {
        dismissDocumentScanner(controller) { [weak self] in
            self?.presentAlert(title: "Scan Failed", message: "We couldn't scan that document. Please try again.")
        }
    }
}

// MARK: - UIDocumentPickerDelegate + Upload Delegates
extension UploadScreen: UIDocumentPickerDelegate, UploadQuizPopupDelegate,
                        PHPickerViewControllerDelegate, UploadCameraCaptureViewControllerDelegate {

    func uploadQuizPopupDidClose(_ popup: UploadQuizPopup) { activeQuizPopup = nil }

    func openFileManager() {
        // Restrict to PDF only at the picker level
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf], asCopy: true)
        picker.delegate                = self
        picker.allowsMultipleSelection = false
        activeDocumentPicker = picker
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileURL = urls.first else { return }
        dismissDocumentPicker(controller) { [weak self] in
            guard let self else { return }

            let validatedFile: ValidatedFile
            switch FileValidator.validateDocument(at: fileURL) {
            case .success(let file):
                validatedFile = file
            case .failure(let error):
                self.presentAlert(
                    title: "Invalid File",
                    message: error.userMessage
                )
                return
            }

            do {
                guard validatedFile.sizeInBytes <= Int64(Constants.maxUploadSizeBytes) else {
                    self.presentAlert(title: "Upload Too Large", message: "Files must be under 10 MB.")
                    return
                }

                let data = try Data(contentsOf: validatedFile.url)
                guard self.validateUploadSize(data) else { return }

                // ── Layer 2: magic-byte check (%PDF) ─────────────────────────
                let pdfMagic: [UInt8] = [0x25, 0x50, 0x44, 0x46]   // %PDF
                guard data.count > 4,
                      data.prefix(4).elementsEqual(pdfMagic) else {
                    self.presentAlert(
                        title: "Invalid File",
                        message: "The selected file does not appear to be a valid PDF."
                    )
                    return
                }

                self.currentUploadData = data
                self.currentFileName   = self.generateTimestampFilename()
                self.currentFileType   = "application/pdf"
                self.currentUploadSource = "document_picker"
                guard self.canStartUploadRequest() else { return }
                let popup = self.showQuizPopup()
                AnalyticsManager.logUploadStarted(source: self.currentUploadSource, fileType: self.currentFileType)
                self.uploadTask?.cancel()
                self.uploadTask = Task { [weak self] in
                    guard let self else { return }
                    do {
                        try await self.saveUploadToDatabase(imageData: data,
                                                            fileName: self.currentFileName,
                                                            fileType: self.currentFileType,
                                                            popup: popup)
                    } catch {
                        guard !Task.isCancelled else { return }
                        await MainActor.run { self.handleUploadError(error, popup: popup) }
                    }
                }
            } catch {
                self.presentAlert(title: "Error", message: "We couldn't read that file. Please try another PDF.")
            }
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        dismissDocumentPicker(controller)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismissPhotoPicker(picker) { [weak self] in
            guard let self else { return }
            guard let result = results.first else { return }
            let itemProvider = result.itemProvider
            let typeIdentifier = ImageValidator.preferredSupportedTypeIdentifier(from: itemProvider.registeredTypeIdentifiers)
            guard let typeIdentifier else {
                self.presentAlert(title: "Import Failed", message: "The selected item is not a supported image.")
                return
            }

            itemProvider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] data, _ in
                guard let self else { return }
                guard let data else {
                    DispatchQueue.main.async {
                        self.presentAlert(title: "Import Failed", message: "We couldn't import that image. Please try another one.")
                    }
                    return
                }

                switch ImageValidator.validateAndPrepareImageData(data, typeIdentifier: typeIdentifier) {
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.presentAlert(title: "Import Failed", message: error.userMessage)
                    }
                case .success(let prepared):
                    guard let image = UIImage(data: prepared.data) else {
                        DispatchQueue.main.async {
                            self.presentAlert(title: "Import Failed", message: "We couldn't prepare that image. Please try another one.")
                        }
                        return
                    }

                    DispatchQueue.main.async {
                        self.currentUploadSource = "photo_picker"
                        self.beginUpload(with: image)
                    }
                }
            }
        }
    }

    func uploadCameraCaptureViewController(_ controller: UploadCameraCaptureViewController,
                                           didCapture image: UIImage) {
        dismissUploadCamera(controller) { [weak self] in
            self?.currentUploadSource = "camera_capture"
            self?.beginUpload(with: image)
        }
    }

    func uploadCameraCaptureViewControllerDidCancel(_ controller: UploadCameraCaptureViewController) {
        dismissUploadCamera(controller)
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

// MARK: - UIImage Orientation Normalization + Document Style
private extension UIImage {
    /// Redraws the image into a new context so imageOrientation == .up.
    /// VisionKit scan pages often carry non-up orientations; drawing them
    /// directly into the PDF context without normalization produces rotated pages.
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up, let cgImage else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Converts a VisionKit scanned page to a pure B&W document image.
    /// Pipeline (all Apple-native Core Image, no custom processing):
    ///   1. CIPhotoEffectNoir  — desaturates + applies film-noir contrast curve
    ///   2. CIColorControls    — boosts contrast further so stave lines are crisp black
    /// The shared CIContext is GPU-backed and reused across pages to avoid
    /// re-allocating the Metal pipeline on every call (memory-safe).
    func applyDocumentStyle() -> UIImage {
        guard let ciInput = CIImage(image: self) else { return self }

        // Step 1 — B&W via Apple's built-in Noir filter
        let noir = CIFilter.photoEffectNoir()
        noir.inputImage = ciInput
        guard let noirOutput = noir.outputImage else { return self }

        // Step 2 — Boost contrast so music notation lines are razor-sharp
        let controls = CIFilter.colorControls()
        controls.inputImage  = noirOutput
        controls.saturation  = 0.0   // ensure fully desaturated
        controls.contrast    = 1.4   // crisp stave lines
        controls.brightness  = 0.05  // lift shadows slightly so paper stays white
        guard let finalCI = controls.outputImage else { return self }

        // Render using a shared GPU-backed context (no memory leak — static let)
        let cgResult = UIImage.ciContext.createCGImage(finalCI, from: finalCI.extent)
        guard let cgResult else { return self }

        let rendered = UIGraphicsImageRenderer(size: size).image { _ in
            UIImage(cgImage: cgResult, scale: scale, orientation: imageOrientation)
                .draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered
    }

    /// Shared Metal-backed CIContext. Creating one per page would re-allocate
    /// the GPU pipeline on every call — a significant memory/perf leak.
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
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

extension UploadScreen: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // No additional state to reset for the guest upload gate.
    }
}
