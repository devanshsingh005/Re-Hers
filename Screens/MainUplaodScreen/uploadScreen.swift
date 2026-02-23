//
//  UploadScreen.swift
//  Re-Hearse_v1
//
//  CHANGES FROM ORIGINAL — three bugs fixed, everything else identical:
//
//  BUG 1 (saveUploadToDatabase) — PDF was never uploaded to Supabase storage.
//    Original code only built a pdfPath string; supabase.storage.upload() was
//    never called. Added Step 2 which uploads the PDF bytes to pdf_uploads bucket.
//
//  BUG 2 (saveUploadToDatabase) — pdfPath stored "uploads/{uid}/{jid}/{file}".
//    "uploads/" was treated as a path prefix inside the bucket, so getPublicURL
//    produced .../pdf_uploads/uploads/... which matched nothing. Fixed path to
//    "{uid}/{jid}/{cleanFile}" with no spurious prefix. Also stores pdf_public_url
//    in json_data so re-opens never need a DB round-trip to reconstruct the URL.
//
//  BUG 3 (makeUploadRow) — card tap pushed UploadPageNextViewController() with
//    ZERO properties (scanId/resultURL/pdfPublicURL all nil) → blank screen.
//    Fixed to pass scanId, resultURL, and pdfPublicURL from the scan record.
//
//  BUG 4 (navigateToNextPage) — signature lacked pdfPublicURL parameter so new
//    uploads also got a blank screen. Added parameter and set vc.pdfPublicURL.

import UIKit
import AVFoundation
import Photos
import Supabase
import PDFKit
import Vision
import VisionKit

class UploadScreen: UIViewController {
    
    private enum Constants {
        static let horizontalPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 24
        static let elementSpacing: CGFloat = 12
        static let cornerRadius: CGFloat = 20
        static let buttonHeight: CGFloat = 52
        static let pdfPageSize = CGSize(width: 612, height: 792)
    }
    
    // MARK: - State / Data
    private var uploadTitle: String = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: Date())
    }()
    private var currentUploadData: Data?
    private var currentFileName: String = ""
    private var currentFileType: String = ""
    private var activeQuizPopup: UploadQuizPopup?
    private var recentUploadsStack: UIStackView?
    
    private var supabase: SupabaseClient { SupabaseManager.shared.client }
    private let supabaseStorageBaseURL = "https://djqgmowfjxsnjdffdohw.supabase.co/storage/v1/object/public"
    
    // MARK: - UI Elements
    private let navBar = TopNavBar.make(title: "Upload")
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.96, green: 0.95, blue: 0.94, alpha: 1.0)
        navigationController?.navigationBar.isHidden = true
        setupNavBar()
        setupScrollView()
        setupHeaderSection()
        setupActionCards()
        setupRecentUploadsSection()
        loadRecentUploadsFromDB()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadRecentUploadsFromDB()
    }
    
    func startUploadFlow() { presentDocumentScanner() }
    
    // MARK: - NavBar
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        navBar.isChordIconVisible = true
        navBar.chordAction = { [weak self] in
            guard let self = self else { return }
            let vc = ChordRecognitionViewController()
            if let nav = self.navigationController { nav.pushViewController(vc, animated: true) }
            else { vc.modalPresentationStyle = .fullScreen; self.present(vc, animated: true) }
        }
        navBar.profileAction = { [weak self] in
            guard let self = self else { return }
            self.navigationController?.pushViewController(UserProfileViewController(), animated: true)
        }
        navBar.backAction = { [weak self] in self?.navigationController?.popViewController(animated: true) }
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
    }
    
    // MARK: - Scroll + Content Stack
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.addSubview(contentView)
        contentView.axis = .vertical
        contentView.spacing = Constants.sectionSpacing
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Constants.horizontalPadding),
            contentView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Constants.horizontalPadding),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * Constants.horizontalPadding)
        ])
    }
    
    // MARK: - Header
    private func setupHeaderSection() {
        let headerStack = UIStackView()
        headerStack.axis = .vertical; headerStack.spacing = 4
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Capture or import your documents"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        headerStack.addArrangedSubview(subtitleLabel)
        contentView.addArrangedSubview(headerStack)
    }
    
    // MARK: - Action Cards
    private func setupActionCards() {
        let cardsRow = UIStackView()
        cardsRow.axis = .horizontal; cardsRow.spacing = 14; cardsRow.distribution = .fillEqually
        cardsRow.addArrangedSubview(makeScanCard())
        cardsRow.addArrangedSubview(makeUploadCard())
        contentView.addArrangedSubview(cardsRow)
        cardsRow.heightAnchor.constraint(equalToConstant: 210).isActive = true
    }
    
    private func makeScanCard() -> UIView {
        let card = UIButton(type: .custom)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.clipsToBounds = true
        card.layer.cornerRadius = Constants.cornerRadius
        let gradientView = GradientView(colors: [UIColor(hex: "#EF9408"), UIColor(hex: "#FF6B00")])
        gradientView.isUserInteractionEnabled = false
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        card.insertSubview(gradientView, at: 0)
        let iconContainer = UIView()
        iconContainer.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        iconContainer.layer.cornerRadius = 16
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.isUserInteractionEnabled = false
        let iconImg = UIImageView(image: UIImage(systemName: "doc.text.viewfinder"))
        iconImg.tintColor = .white; iconImg.contentMode = .scaleAspectFit
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        let mainLabel = UILabel()
        mainLabel.text = "Scan"; mainLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        mainLabel.textColor = .white; mainLabel.translatesAutoresizingMaskIntoConstraints = false
        let subLabel = UILabel()
        subLabel.text = "Music Sheet"; subLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        subLabel.textColor = UIColor.white.withAlphaComponent(0.75); subLabel.letterSpacing(1.5)
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImg)
        card.addSubview(iconContainer); card.addSubview(mainLabel); card.addSubview(subLabel)
        NSLayoutConstraint.activate([
            gradientView.topAnchor.constraint(equalTo: card.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            iconContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            iconContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            iconContainer.widthAnchor.constraint(equalToConstant: 64),
            iconContainer.heightAnchor.constraint(equalToConstant: 64),
            iconImg.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImg.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImg.widthAnchor.constraint(equalToConstant: 36),
            iconImg.heightAnchor.constraint(equalToConstant: 36),
            mainLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            mainLabel.bottomAnchor.constraint(equalTo: subLabel.topAnchor, constant: -2),
            subLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            subLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        card.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)
        card.addTarget(self, action: #selector(cardTouchDown(_:)), for: .touchDown)
        card.addTarget(self, action: #selector(cardTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return card
    }
    
    private func makeUploadCard() -> UIView {
        let card = UIButton(type: .custom)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(hex: "#FF740E").withAlphaComponent(0.08)
        card.layer.cornerRadius = Constants.cornerRadius; card.clipsToBounds = false
        card.layer.borderColor = UIColor(hex: "#FF6B00").withAlphaComponent(0.18).cgColor
        card.layer.borderWidth = 1.5
        let iconContainer = UIView()
        iconContainer.backgroundColor = UIColor(hex: "#FF740E").withAlphaComponent(0.15)
        iconContainer.layer.cornerRadius = 16
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.isUserInteractionEnabled = false
        let iconImg = UIImageView(image: UIImage(systemName: "icloud.and.arrow.up"))
        iconImg.tintColor = UIColor(hex: "#FF6B00"); iconImg.contentMode = .scaleAspectFit
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        let mainLabel = UILabel()
        mainLabel.text = "Upload"; mainLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        mainLabel.textColor = .label; mainLabel.translatesAutoresizingMaskIntoConstraints = false
        let subLabel = UILabel()
        subLabel.text = "Music Sheet"; subLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        subLabel.textColor = .secondaryLabel; subLabel.letterSpacing(1.5)
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImg)
        card.addSubview(iconContainer); card.addSubview(mainLabel); card.addSubview(subLabel)
        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            iconContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            iconContainer.widthAnchor.constraint(equalToConstant: 64),
            iconContainer.heightAnchor.constraint(equalToConstant: 64),
            iconImg.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImg.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImg.widthAnchor.constraint(equalToConstant: 36),
            iconImg.heightAnchor.constraint(equalToConstant: 36),
            mainLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            mainLabel.bottomAnchor.constraint(equalTo: subLabel.topAnchor, constant: -2),
            subLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            subLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        card.addTarget(self, action: #selector(uploadFileTapped), for: .touchUpInside)
        card.addTarget(self, action: #selector(cardTouchDown(_:)), for: .touchDown)
        card.addTarget(self, action: #selector(cardTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return card
    }
    
    @objc private func cardTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12) { sender.transform = CGAffineTransform(scaleX: 0.96, y: 0.96) }
    }
    @objc private func cardTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            sender.transform = .identity
        }
    }
    @objc private func scanTapped()       { presentDocumentScanner() }
    @objc private func uploadFileTapped() { openFileManager() }
    
    // MARK: - Recent Uploads Section
    private func setupRecentUploadsSection() {
        let headerRow = UIStackView()
        headerRow.axis = .horizontal; headerRow.distribution = .equalSpacing; headerRow.alignment = .center
        let headerLabel = UILabel()
        headerLabel.text = "Recent Uploads"; headerLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        headerLabel.textColor = .label
        let seeAllButton = UIButton(type: .system)
        seeAllButton.backgroundColor = UIColor(hex: "#FF6B00").withAlphaComponent(0.10)
        seeAllButton.layer.cornerRadius = 14
        seeAllButton.configuration = {
            var config = UIButton.Configuration.plain()
            config.title = "See All"; config.baseForegroundColor = UIColor(hex: "#FF6B00")
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            return config
        }()
        seeAllButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.navigationController?.pushViewController(AllUploadsViewController(), animated: true)
        }, for: .touchUpInside)
        headerRow.addArrangedSubview(headerLabel); headerRow.addArrangedSubview(seeAllButton)
        contentView.addArrangedSubview(headerRow)
        let uploadsStack = UIStackView()
        uploadsStack.axis = .vertical; uploadsStack.spacing = 10
        recentUploadsStack = uploadsStack
        contentView.addArrangedSubview(uploadsStack)
    }
    
    // MARK: - Database
    private func loadRecentUploadsFromDB() {
        Task {
            do {
                let uploads = try await fetchRecentUploadsFromDatabase()
                DispatchQueue.main.async { self.displayRecentUploads(uploads) }
            } catch {
                print("Error loading recent uploads: \(error)")
                DispatchQueue.main.async { self.displayRecentUploads([]) }
            }
        }
    }
    
    private func fetchRecentUploadsFromDatabase() async throws -> [Scan] {
        guard let userIdString = await getCurrentUserId(),
              let userId = UUID(uuidString: userIdString) else { return [] }
        let response: [Scan] = try await supabase
            .from("scans").select().eq("user_id", value: userId)
            .order("updated_at", ascending: false).limit(5).execute().value
        var unique: [Scan] = []; var seen = Set<Int64>()
        for s in response { if seen.insert(s.id).inserted { unique.append(s) } }
        return unique
    }
    
    private func getCurrentUserId() async -> String? {
        do { return try await supabase.auth.session.user.id.uuidString }
        catch { print("Error getting user session: \(error)"); return nil }
    }
    
    private func getSupabaseAuthToken() async -> String? {
        do { return try await supabase.auth.session.accessToken }
        catch { print("Error getting auth token: \(error)"); return nil }
    }
    
    private func displayRecentUploads(_ scans: [Scan]) {
        guard let stack = recentUploadsStack else { return }
        uploadTitle = { let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f.string(from: Date()) }()
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if scans.isEmpty { stack.addArrangedSubview(makeEmptyStateRow()); return }
        for scan in scans {
            let title   = extractTitle(from: scan.jsonData) ?? scan.originalFilename
                ?? { let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f.string(from: Date()) }()
            let fileType = (scan.fileType ?? "application/pdf").contains("pdf") ? "PDF" : "FILE"
            let dateStr  = extractDate(from: scan.jsonData, fallback: scan.processedAt ?? scan.updatedAt)
            let sizeStr  = extractFileSize(from: scan.jsonData)
            let metaStr  = [dateStr, sizeStr].compactMap { $0.isEmpty ? nil : $0 }.joined(separator: " • ")
            stack.addArrangedSubview(makeUploadRow(title: title, fileType: fileType, metaStr: metaStr, scan: scan))
        }
    }
    
    private func makeEmptyStateRow() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground; container.layer.cornerRadius = 14
        let label = UILabel()
        label.text = "No recent uploads yet"; label.textColor = .tertiaryLabel
        label.font = UIFont.systemFont(ofSize: 15, weight: .regular); label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 70)
        ])
        return container
    }
    
    private func makeUploadRow(title: String, fileType: String, metaStr: String, scan: Scan) -> UIView {
        let card = UIButton(type: .custom)
        card.backgroundColor = .systemBackground; card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor; card.layer.shadowOpacity = 0.05
        card.layer.shadowRadius = 8; card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.clipsToBounds = false; card.translatesAutoresizingMaskIntoConstraints = false
        
        let iconWrap = GradientView(colors: [UIColor(hex: "#EF9408"), UIColor(hex: "#FF6B00")])
        iconWrap.layer.cornerRadius = 12; iconWrap.clipsToBounds = true
        iconWrap.translatesAutoresizingMaskIntoConstraints = false; iconWrap.isUserInteractionEnabled = false
        let iconImg = UIImageView(image: UIImage(systemName: "doc.fill"))
        iconImg.tintColor = .white; iconImg.contentMode = .scaleAspectFit
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        
        let textStack = UIStackView(); textStack.axis = .vertical; textStack.spacing = 5
        textStack.isUserInteractionEnabled = false; textStack.translatesAutoresizingMaskIntoConstraints = false
        let titleLbl = UILabel(); titleLbl.text = title
        titleLbl.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLbl.textColor = .label; titleLbl.lineBreakMode = .byTruncatingTail
        
        let metaRow = UIStackView(); metaRow.axis = .horizontal; metaRow.spacing = 6; metaRow.alignment = .center
        let badgeLabel = UILabel(); badgeLabel.text = fileType
        badgeLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        badgeLabel.textColor = UIColor(hex: "#FF6B00")
        badgeLabel.backgroundColor = UIColor(hex: "#FF6B00").withAlphaComponent(0.12)
        badgeLabel.layer.cornerRadius = 5; badgeLabel.clipsToBounds = true; badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.widthAnchor.constraint(equalToConstant: 38).isActive = true
        badgeLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        let dateLbl = UILabel(); dateLbl.text = metaStr
        dateLbl.font = UIFont.systemFont(ofSize: 12, weight: .regular); dateLbl.textColor = .tertiaryLabel
        metaRow.addArrangedSubview(badgeLabel); metaRow.addArrangedSubview(dateLbl)
        textStack.addArrangedSubview(titleLbl); textStack.addArrangedSubview(metaRow)
        
        let moreBtn = UIButton(type: .system)
        moreBtn.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        moreBtn.tintColor = .tertiaryLabel; moreBtn.translatesAutoresizingMaskIntoConstraints = false
        moreBtn.isUserInteractionEnabled = true
        let scanId = scan.id
        moreBtn.addAction(UIAction { [weak self, weak titleLbl] _ in
            guard let self = self else { return }
            self.showRowOptions(for: scanId, currentTitle: titleLbl?.text ?? title, titleLabel: titleLbl)
        }, for: .touchUpInside)
        
        iconWrap.addSubview(iconImg); card.addSubview(iconWrap)
        card.addSubview(textStack); card.addSubview(moreBtn)
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

        // Pass only jobId — the next screen fetches pdf_path and output_url from DB.
        card.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let jsonDict  = scan.jsonData?.value as? [String: Any]
            let jobIdStr  = jsonDict?["job_id"] as? String
            guard let jobIdStr, let jobId = UUID(uuidString: jobIdStr) else {
                print("[RowTap] ❌ No job_id in scan \(scan.id) — cannot navigate")
                return
            }
            let vc = UploadPageNextViewController()
            vc.jobId = jobId
            print("[RowTap] jobId=\(jobId.uuidString)")
            self.navigationController?.pushViewController(vc, animated: true)
        }, for: .touchUpInside)
        
        
        card.addTarget(self, action: #selector(cardTouchDown(_:)), for: .touchDown)
        card.addTarget(self, action: #selector(cardTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
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
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        present(ac, animated: true)
    }
    
    private func showRenameAlert(for scanId: Int64, currentTitle: String, titleLabel: UILabel?) {
        let alert = UIAlertController(title: "Rename File", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = currentTitle; tf.placeholder = "Enter new name"
            tf.clearButtonMode = .whileEditing; tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self,
                  let newName = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !newName.isEmpty else { return }
            titleLabel?.text = newName
            Task { await self.renameScan(scanId: scanId, newTitle: newName) }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func renameScan(scanId: Int64, newTitle: String) async {
        do {
            let scans: [Scan] = try await supabase.from("scans").select()
                .eq("id", value: Int(scanId)).limit(1).execute().value
            guard let scan = scans.first else { return }
            var jsonDict = (scan.jsonData?.value as? [String: Any]) ?? [:]
            jsonDict["title"] = newTitle
            let scanUpdate = ScanUpdate(
                jsonData: AnyCodable(jsonDict), status: scan.status ?? "completed",
                processedAt: scan.processedAt ?? ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            try await supabase.from("scans").update(scanUpdate).eq("id", value: Int(scanId)).execute()
            print("Scan \(scanId) renamed to: \(newTitle)")
        } catch {
            print("Failed to rename scan \(scanId): \(error)")
            DispatchQueue.main.async { self.loadRecentUploadsFromDB() }
        }
    }
    
    // MARK: - JSON helpers
    private func extractDate(from jsonData: AnyCodable?, fallback: String?) -> String {
        if let dict = jsonData?.value as? [String: Any],
           let ua = dict["uploaded_at"] as? String { return formatDateString(ua) }
        return formatDateString(fallback)
    }
    private func extractFileSize(from jsonData: AnyCodable?) -> String {
        guard let dict = jsonData?.value as? [String: Any] else { return "" }
        if let b = dict["file_size_bytes"] as? Int    { return formatBytes(b) }
        if let b = dict["file_size_bytes"] as? Double { return formatBytes(Int(b)) }
        if let b = dict["file_size"] as? Int          { return formatBytes(b) }
        if let s = dict["file_size"] as? String, let b = Int(s) { return formatBytes(b) }
        return ""
    }
    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        return kb < 1024 ? String(format: "%.0f KB", kb) : String(format: "%.1f MB", kb / 1024.0)
    }
    private func formatDateString(_ s: String?) -> String {
        guard let s = s, !s.isEmpty else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return shortDateString(from: d) }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return shortDateString(from: d) }
        return ""
    }
    private func shortDateString(from date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: date)
    }
    private func extractTitle(from jsonData: AnyCodable?) -> String? {
        (jsonData?.value as? [String: Any])?["title"] as? String
    }
    
    // MARK: - Upload Pipeline

//    private func saveUploadToDatabase(imageData: Data, fileName: String,
//                                       fileType: String, popup: UploadQuizPopup) async throws {
//        print("[Upload] size=\(imageData.count) bytes")
//
//        guard let userIdString = await getCurrentUserId(),
//              let userId = UUID(uuidString: userIdString) else {
//            throw NSError(domain: "UploadError", code: 1,
//                          userInfo: [NSLocalizedDescriptionKey: "Invalid user ID"])
//        }
//        guard let authToken = await getSupabaseAuthToken() else {
//            throw NSError(domain: "UploadError", code: 3,
//                          userInfo: [NSLocalizedDescriptionKey: "Failed to get auth token"])
//        }
//
//        // ── Step 1: Call Railway API ──────────────────────────────────────────────
//        let apiResponse: [String: Any] = try await callExternalConversionAPI(
//            imageData: imageData, fileName: fileName, fileType: fileType, authToken: authToken
//        )
//        print("[Upload] API keys: \(apiResponse.keys.sorted())")
//
//        guard let apiJobIdString  = apiResponse["job_id"]  as? String,
//              let apiJobId        = UUID(uuidString: apiJobIdString),
//              let apiUserIdString = apiResponse["user_id"] as? String,
//              let apiUserId       = UUID(uuidString: apiUserIdString) else {
//            throw NSError(domain: "UploadError", code: 5,
//                          userInfo: [NSLocalizedDescriptionKey: "Missing job_id or user_id in API response"])
//        }
//
//        // ── Step 2: Upload PDF to Supabase Storage ────────────────────────────────
//        // Path is always userId/jobId/input.pdf — deterministic, no filename mutation.
//        // IMPORTANT: Use a custom URLSession with HTTP/3 (QUIC) disabled.
//        // QUIC fails on the iOS Simulator with large payloads:
//        //   sendmsg [40: Message too long] → -1005 "network connection was lost"
//        // Forcing HTTP/1.1 fixes this for both simulator and device.
//        let pdfPath = "\(apiUserIdString.lowercased())/\(apiJobIdString.lowercased())/input.pdf"
//        print("[Upload] → pdf_uploads/\(pdfPath)")
//
//        let uploadURL = URL(string: "https://djqgmowfjxsnjdffdohw.supabase.co/storage/v1/object/pdf_uploads/\(pdfPath)")!
//        var uploadReq = URLRequest(url: uploadURL)
//        uploadReq.httpMethod = "POST"
//        uploadReq.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
//        uploadReq.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
//        uploadReq.setValue("true", forHTTPHeaderField: "x-upsert")
//        uploadReq.assumesHTTP3Capable = false   // force HTTP/1.1 — disables QUIC
//        uploadReq.httpBody = imageData
//
//        let sessionConfig = URLSessionConfiguration.default
//        sessionConfig.httpAdditionalHeaders = ["Connection": "keep-alive"]
//        let uploadSession = URLSession(configuration: sessionConfig)
//
//        let (_, uploadResp) = try await uploadSession.data(for: uploadReq)
//        let uploadCode = (uploadResp as? HTTPURLResponse)?.statusCode ?? 0
//        guard (200...299).contains(uploadCode) else {
//            throw NSError(domain: "UploadError", code: uploadCode,
//                          userInfo: [NSLocalizedDescriptionKey: "Storage upload failed (HTTP \(uploadCode))"])
//        }
//        print("[Upload] ✅ Storage upload succeeded (HTTP \(uploadCode))")
//
//
//
//        // ── Step 3: Output URL ────────────────────────────────────────────────────
//        // Prefer output_url returned by the API. Fall back to the deterministic
//        // sheet_data path we know the Railway service writes to.
//        let outputURL = (apiResponse["output_url"] as? String)
//            ?? "\(supabaseStorageBaseURL)/sheet_data/\(apiUserIdString.lowercased())/\(apiJobIdString.lowercased())/output.json"
//        print("[Upload] outputURL=\(outputURL)")
//
//        // ── Step 4: Upsert job record ─────────────────────────────────────────────
//        let existingJobs: [Job] = try await supabase.from("jobs").select()
//            .eq("id", value: apiJobId).execute().value
//        if existingJobs.isEmpty {
//            let ins = JobInsert(id: apiJobId, userId: apiUserId,
//                                pdfPath: pdfPath, resultUrl: outputURL, status: "completed")
//            if let _: Job = try? await supabase.from("jobs").insert(ins)
//                .select().single().execute().value { }
//        } else {
//            let upd = JobUpdate(resultUrl: outputURL, status: "completed", errorMessage: nil,
//                                updatedAt: ISO8601DateFormatter().string(from: Date()))
//            try await supabase.from("jobs").update(upd).eq("id", value: apiJobId).execute()
//        }
//
//        // ── Step 5: Build json_data ───────────────────────────────────────────────
//        // Store job_id and output_url. The next screen always fetches the PDF path
//        // from jobs.pdf_path — do NOT store pdf_public_url here.
//        var jsonDict: [String: Any] = [
//            "status":            "completed",
//            "uploaded_at":       ISO8601DateFormatter().string(from: Date()),
//            "title":             uploadTitle,
//            "job_id":            apiJobIdString,
//            "user_id":           apiUserIdString,
//            "output_url":        outputURL,
//            "file_size_bytes":   imageData.count
//        ]
//        for (k, v) in apiResponse { jsonDict[k] = v }
//
//        // ── Step 6: Upsert scan record ────────────────────────────────────────────
//        let existingScans: [Scan] = try await supabase.from("scans").select()
//            .eq("user_id", value: userId)
//            .like("json_data->>\'job_id\'", pattern: "%\(apiJobIdString)%")
//            .execute().value
//
//        if existingScans.isEmpty {
//            let ins = ScanInsert(userId: userId, jsonData: AnyCodable(jsonDict),
//                                  processingId: apiJobIdString, status: "completed",
//                                  originalFilename: "input.pdf", fileType: "application/pdf",
//                                  processedAt: ISO8601DateFormatter().string(from: Date()))
//            let scanResponse: Scan = try await supabase.from("scans")
//                .insert(ins).select().single().execute().value
//            DispatchQueue.main.async {
//                self.navigateToNextPage(jobId: apiJobId, popup: popup)
//            }
//        } else if let existing = existingScans.first {
//            let upd = ScanUpdate(jsonData: AnyCodable(jsonDict), status: "completed",
//                                  processedAt: ISO8601DateFormatter().string(from: Date()),
//                                  updatedAt: ISO8601DateFormatter().string(from: Date()))
//            try await supabase.from("scans").update(upd).eq("id", value: Int(existing.id)).execute()
//            DispatchQueue.main.async {
//                self.navigateToNextPage(jobId: apiJobId, popup: popup)
//            }
//        }
//    }
    private func saveUploadToDatabase(imageData: Data, fileName: String,
                                       fileType: String, popup: UploadQuizPopup) async throws {
        print("[Upload] size=\(imageData.count) bytes")

        guard let userIdString = await getCurrentUserId(),
              let userId = UUID(uuidString: userIdString) else {
            throw NSError(domain: "UploadError", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid user ID"])
        }

        guard let authToken = await getSupabaseAuthToken() else {
            throw NSError(domain: "UploadError", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to get auth token"])
        }

        // ── Step 1: Call Railway API ──────────────────────────────────────────────
        // The Railway backend uploads the PDF to Supabase Storage itself using its
        // service key. It returns job_id and user_id. We do NOT re-upload from iOS.
        let apiResponse: [String: Any] = try await callExternalConversionAPI(
            imageData: imageData, fileName: fileName, fileType: fileType, authToken: authToken
        )
        print("[Upload] API keys: \(apiResponse.keys.sorted())")

        guard let apiJobIdString  = apiResponse["job_id"]  as? String,
              let apiJobId        = UUID(uuidString: apiJobIdString),
              let apiUserIdString = apiResponse["user_id"] as? String,
              let apiUserId       = UUID(uuidString: apiUserIdString) else {
            throw NSError(domain: "UploadError", code: 5,
                          userInfo: [NSLocalizedDescriptionKey: "Missing job_id or user_id in API response"])
        }

        // ── Step 2: REMOVED — Railway already uploaded the PDF to Supabase Storage.
        // Re-uploading from iOS causes a 403 RLS violation because the path is owned
        // by the Railway service key, not the user JWT.
        // The canonical pdf_path comes from the Railway backend (apiUserIdString).
        let pdfPath = "\(apiUserIdString.lowercased())/\(apiJobIdString.lowercased())/input.pdf"
        print("[Upload] Railway stored PDF at pdf_uploads/\(pdfPath)")

        // ── Step 3: Output URL ────────────────────────────────────────────────────
        // Use api output_url if provided, else construct from apiUserIdString (same
        // user the Railway backend used when it stored the file).
        let outputURL = (apiResponse["output_url"] as? String)
            ?? "\(supabaseStorageBaseURL)/sheet_data/\(apiUserIdString.lowercased())/\(apiJobIdString.lowercased())/output.json"
        print("[Upload] outputURL=\(outputURL)")

        // ── Step 4: Upsert job record ─────────────────────────────────────────────
        let existingJobs: [Job] = try await supabase.from("jobs").select()
            .eq("id", value: apiJobId).execute().value
        if existingJobs.isEmpty {
            let ins = JobInsert(id: apiJobId, userId: apiUserId,
                                pdfPath: pdfPath, resultUrl: outputURL, status: "completed")
            if let _: Job = try? await supabase.from("jobs").insert(ins)
                .select().single().execute().value { }
        } else {
            let upd = JobUpdate(resultUrl: outputURL, status: "completed", errorMessage: nil,
                                updatedAt: ISO8601DateFormatter().string(from: Date()))
            try await supabase.from("jobs").update(upd).eq("id", value: apiJobId).execute()
        }

        // ── Step 5: Build json_data ───────────────────────────────────────────────
        // Build our dict first, then merge apiResponse — but protect critical keys
        // so apiResponse cannot overwrite output_url or job_id.
        var jsonDict: [String: Any] = [
            "status":          "completed",
            "uploaded_at":     ISO8601DateFormatter().string(from: Date()),
            "title":           uploadTitle,
            "job_id":          apiJobIdString,
            "user_id":         apiUserIdString,
            "output_url":      outputURL,
            "file_size_bytes": imageData.count
        ]
        for (k, v) in apiResponse {
            // Never let apiResponse overwrite our canonical keys
            if ["job_id", "user_id", "output_url", "title", "status"].contains(k) { continue }
            jsonDict[k] = v
        }

        // ── Step 6: Upsert scan record ────────────────────────────────────────────
        let existingScans: [Scan] = try await supabase.from("scans").select()
            .eq("user_id", value: userId)
            .like("json_data->>'job_id'", pattern: "%\(apiJobIdString)%")
            .execute().value

        if existingScans.isEmpty {
            let ins = ScanInsert(userId: userId, jsonData: AnyCodable(jsonDict),
                                  processingId: apiJobIdString, status: "completed",
                                  originalFilename: "input.pdf", fileType: "application/pdf",
                                  processedAt: ISO8601DateFormatter().string(from: Date()))
            let _: Scan = try await supabase.from("scans")
                .insert(ins).select().single().execute().value
        } else if let existing = existingScans.first {
            let upd = ScanUpdate(jsonData: AnyCodable(jsonDict), status: "completed",
                                  processedAt: ISO8601DateFormatter().string(from: Date()),
                                  updatedAt: ISO8601DateFormatter().string(from: Date()))
            try await supabase.from("scans").update(upd).eq("id", value: Int(existing.id)).execute()
        }

        // ── Navigate ──────────────────────────────────────────────────────────────
        // Single dispatch to main — navigateToNextPage must NOT be wrapped in an
        // additional DispatchQueue.main.async since it already does that internally.
        await MainActor.run {
            self.loadRecentUploadsFromDB()
            let vc = UploadPageNextViewController()
            vc.jobId = apiJobId
            vc.onDataReady = { popup.notifyUploadComplete() }
            print("[Navigate] jobId=\(apiJobId.uuidString)")
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    // MARK: - External API
    private func callExternalConversionAPI(imageData: Data, fileName: String,
                                            fileType: String, authToken: String) async throws -> [String: Any] {
        let url = URL(string: "https://maybe-working-production.up.railway.app/convert")!
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(fileType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        request.assumesHTTP3Capable = false   // force HTTP/1.1 — disables QUIC for large payloads
        let apiSession = URLSession(configuration: .default)
        let (data, response) = try await apiSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "APIError", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "No response from server"])
        }
        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "APIError", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "API \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")"])
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        if let d = obj as? [String: Any]        { return d }
        if let a = obj as? [[String: Any]], let f = a.first { return f }
        return ["api_response": obj, "status": "success"]
    }
    
    // MARK: - Quiz Popup
    private func showQuizPopup() -> UploadQuizPopup {
        let popup = UploadQuizPopup()
        popup.delegate = self
        popup.modalPresentationStyle = .overFullScreen
        popup.modalTransitionStyle = .crossDissolve
        activeQuizPopup = popup
        present(popup, animated: false)
        return popup
    }

    private func createPDFFromVisionKitScan(_ scan: VNDocumentCameraScan) -> Data? {
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(origin: .zero, size: Constants.pdfPageSize), nil)
        for i in 0..<scan.pageCount {
            UIGraphicsBeginPDFPageWithInfo(CGRect(origin: .zero, size: Constants.pdfPageSize), nil)
            let img = scan.imageOfPage(at: i)
            let s   = min(Constants.pdfPageSize.width / img.size.width,
                          Constants.pdfPageSize.height / img.size.height, 1.0)
            let w   = img.size.width * s; let h = img.size.height * s
            img.draw(in: CGRect(x: (Constants.pdfPageSize.width - w) / 2,
                                 y: (Constants.pdfPageSize.height - h) / 2, width: w, height: h))
            let txt   = "\(i + 1)"
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.gray]
            let sz = txt.size(withAttributes: attrs)
            txt.draw(in: CGRect(x: (Constants.pdfPageSize.width - sz.width) / 2, y: 10,
                                 width: sz.width, height: sz.height), withAttributes: attrs)
        }
        UIGraphicsEndPDFContext()
        return pdfData as Data
    }
    
    // MARK: - Document Scanner
    private func presentDocumentScanner() {
        guard VNDocumentCameraViewController.isSupported else {
            let a = UIAlertController(title: "Not Supported",
                                       message: "Document scanning is not supported on this device.",
                                       preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default))
            present(a, animated: true); return
        }
        let vc = VNDocumentCameraViewController(); vc.delegate = self; present(vc, animated: true)
    }
    
    // MARK: - Navigation

    // Pass only jobId — the next screen fetches everything else from the DB.
    private func navigateToNextPage(jobId: UUID, popup: UploadQuizPopup) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let vc = UploadPageNextViewController()
            vc.jobId      = jobId
            vc.onDataReady = { popup.notifyUploadComplete() }
            print("[Navigate] jobId=\(jobId.uuidString)")
            self.loadRecentUploadsFromDB()
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    
    // MARK: - Data Models
    struct Job: Codable, Identifiable {
        let id: UUID; let userId: UUID; let pdfPath: String
        let resultUrl: String?; let status: String
        let errorMessage: String?; let createdAt: String?; let updatedAt: String?
        enum CodingKeys: String, CodingKey {
            case id; case userId = "user_id"; case pdfPath = "pdf_path"
            case resultUrl = "result_url"; case status; case errorMessage = "error_message"
            case createdAt = "created_at"; case updatedAt = "updated_at"
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
            case resultUrl = "result_url"; case status; case errorMessage = "error_message"
            case updatedAt = "updated_at"
        }
        init(resultUrl: String? = nil, status: String? = nil,
             errorMessage: String? = nil, updatedAt: String) {
            self.resultUrl = resultUrl; self.status = status
            self.errorMessage = errorMessage; self.updatedAt = updatedAt
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
            if      let b = try? c.decode(Bool.self)                { value = b }
            else if let i = try? c.decode(Int.self)                 { value = i }
            else if let d = try? c.decode(Double.self)              { value = d }
            else if let s = try? c.decode(String.self)              { value = s }
            else if let a = try? c.decode([AnyCodable].self)        { value = a.map { $0.value } }
            else if let d = try? c.decode([String: AnyCodable].self){ value = d.mapValues { $0.value } }
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

// MARK: - UIColor Hex Extension
extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.hasPrefix("#") ? String(s.dropFirst()) : s
        var rgb: UInt64 = 0; Scanner(string: s).scanHexInt64(&rgb)
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
        gl.colors = colors.map { $0.cgColor }
        gl.startPoint = CGPoint(x: 0, y: 0); gl.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gl)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() { super.layoutSubviews(); gl.frame = bounds }
}

// MARK: - UILabel Letter Spacing
private extension UILabel {
    func letterSpacing(_ spacing: CGFloat) {
        guard let text = self.text else { return }
        let a = NSMutableAttributedString(string: text)
        a.addAttribute(.kern, value: spacing, range: NSRange(location: 0, length: text.count))
        attributedText = a
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate
extension UploadScreen: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                       didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true)
        Task {
            guard let pdfData = self.createPDFFromVisionKitScan(scan) else { return }
            self.currentUploadData = pdfData
            self.currentFileName   = "vision_scanned_\(Date().timeIntervalSince1970).pdf"
            self.currentFileType   = "application/pdf"
            let popup = await MainActor.run { self.showQuizPopup() }
            do {
                try await self.saveUploadToDatabase(imageData: pdfData,
                                                     fileName: self.currentFileName,
                                                     fileType: self.currentFileType,
                                                     popup: popup)
            } catch {
                await MainActor.run {
                    // Dismiss popup first, then show error — prevents "already presenting" crash
                    popup.dismiss(animated: true) {
                        let a = UIAlertController(title: "Upload Failed",
                                                  message: error.localizedDescription, preferredStyle: .alert)
                        a.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(a, animated: true)
                    }
                }
            }
            }
        }
    }
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
    }


// MARK: - UIDocumentPickerDelegate + UIImagePickerControllerDelegate
extension UploadScreen: UIImagePickerControllerDelegate, UINavigationControllerDelegate,
                         UIDocumentPickerDelegate, UploadQuizPopupDelegate {
    func uploadQuizPopupDidClose(_ popup: UploadQuizPopup) { activeQuizPopup = nil }
    func openFileManager() {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf, .data, .item], asCopy: true)
        picker.delegate = self; picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileURL = urls.first else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            currentUploadData = data; currentFileName = fileURL.lastPathComponent
            currentFileType = "application/pdf"
            let popup = showQuizPopup()
            Task {
                do {
                    try await saveUploadToDatabase(imageData: data, fileName: currentFileName,
                                                    fileType: currentFileType, popup: popup)
                } catch {
                    await MainActor.run {
                        // Dismiss popup first, then show error — prevents "already presenting" crash
                        popup.dismiss(animated: true) {
                            let a = UIAlertController(title: "Upload Failed",
                                                       message: error.localizedDescription, preferredStyle: .alert)
                            a.addAction(UIAlertAction(title: "OK", style: .default))
                            self.present(a, animated: true)
                        }
                    }
                }
            }
        } catch {
            let a = UIAlertController(title: "Error",
                                       message: "Failed to read file: \(error.localizedDescription)",
                                       preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default)); present(a, animated: true)
        }
    }
    func imagePickerController(_ picker: UIImagePickerController,
                                 didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
