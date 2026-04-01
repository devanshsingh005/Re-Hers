//
//  AllUploadsViewController.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase
import Auth
internal import PostgREST

class AllUploadsViewController: UIViewController {

    // MARK: - UI
    private let scrollView       = UIScrollView()
    private let contentStack     = UIStackView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: - Supabase
    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.App.screenBackground
        navigationController?.setNavigationBarHidden(false, animated: false)
        setupNavBar()
        setupScrollView()
        setupLoadingIndicator()
        loadUploads()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadUploads()
    }

    // MARK: - NavBar
    private func setupNavBar() {
        _ = NavigationBarHelper.configureInlineNavigationBar(
            for: self,
            title: "Recents",
            subtitle: "Recent uploads",
            backAction: #selector(handleBack)
        )
        navigationItem.rightBarButtonItems = NavigationBarHelper.createNativeRightBarButtonItems(
            target: self,
            profileAction: #selector(handleProfile)
        )
    }

    // MARK: - Scroll
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical        = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.addSubview(contentStack)
        contentStack.axis    = .vertical
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -30),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }

    private func setupLoadingIndicator() {
        loadingIndicator.color = ComponentColors.HomeScreen.actionButtonFill
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Data
    private func loadUploads() {
        loadingIndicator.startAnimating()
        Task {
            do {
                let scans = try await fetchScans()
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    self.renderRows(scans)
                }
            } catch {
                debugLog("[AllUploads] fetch error: \(error)")
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    self.renderRows([])
                }
            }
        }
    }

    private func fetchScans() async throws -> [Scan] {
        guard let uidStr = try? await supabase.auth.session.user.id.uuidString,
              let userId = UUID(uuidString: uidStr) else { return [] }
        let response: [Scan] = try await supabase
            .from("scans").select()
            .eq("user_id", value: userId)
            .order("updated_at", ascending: false)
            .limit(50)
            .execute().value
        var seen = Set<Int64>()
        return response.filter { seen.insert($0.id).inserted }
    }

    // MARK: - Render
    private func renderRows(_ scans: [Scan]) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if scans.isEmpty { contentStack.addArrangedSubview(makeEmptyState()); return }
        for scan in scans { contentStack.addArrangedSubview(makeRow(for: scan)) }
    }

    private func makeRow(for scan: Scan) -> UIView {
        let jsonDict = scan.jsonData?.value as? [String: Any]

        // Title: prefer json_data.title → json_data.original_filename → scan.originalFilename → date
        let title: String = {
            if let t = jsonDict?["title"] as? String, !t.isEmpty { return t }
            if let f = jsonDict?["original_filename"] as? String {
                return f.hasSuffix(".pdf") ? String(f.dropLast(4)) : f
            }
            return scan.originalFilename ?? formatDate(jsonDict?["uploaded_at"] as? String
                                                       ?? scan.processedAt ?? scan.updatedAt)
        }()

        let fileType = (scan.fileType ?? "application/pdf").contains("pdf") ? "PDF" : "FILE"
        let dateStr  = formatDate(jsonDict?["uploaded_at"] as? String ?? scan.processedAt ?? scan.updatedAt)
        let sizeStr  = formatSize(jsonDict)
        let meta     = [dateStr, sizeStr].filter { !$0.isEmpty }.joined(separator: " • ")

        // Card
        let card = UIButton(type: .custom)
        card.backgroundColor = ComponentColors.SongCard.background
        card.layer.cornerRadius  = 16
        card.layer.shadowColor   = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.05
        card.layer.shadowRadius  = 8
        card.layer.shadowOffset  = CGSize(width: 0, height: 2)
        card.clipsToBounds       = false
        card.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconWrap = UIView()
        iconWrap.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.12)
        iconWrap.layer.cornerRadius = 12; iconWrap.clipsToBounds = true
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.isUserInteractionEnabled = false
        let iconImg = UIImageView(image: UIImage(systemName: "doc.fill"))
        iconImg.tintColor = ComponentColors.HomeScreen.actionButtonFill; iconImg.contentMode = .scaleAspectFit
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.addSubview(iconImg)

        // Labels
        let titleLbl = UILabel()
        titleLbl.text = title; titleLbl.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLbl.textColor = .label; titleLbl.lineBreakMode = .byTruncatingTail

        let badge = UILabel()
        badge.text = fileType; badge.font = .systemFont(ofSize: 11, weight: .bold)
        badge.textColor = ComponentColors.SongCard.fileIcon
        badge.backgroundColor = ComponentColors.SongCard.fileIcon.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 5; badge.clipsToBounds = true; badge.textAlignment = .center
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.widthAnchor.constraint(equalToConstant: 38).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let metaLbl = UILabel()
        metaLbl.text = meta; metaLbl.font = .systemFont(ofSize: 12); metaLbl.textColor = .tertiaryLabel

        let metaRow = UIStackView(arrangedSubviews: [badge, metaLbl])
        metaRow.axis = .horizontal; metaRow.spacing = 6; metaRow.alignment = .center

        let textStack = UIStackView(arrangedSubviews: [titleLbl, metaRow])
        textStack.axis = .vertical; textStack.spacing = 5
        textStack.isUserInteractionEnabled = false
        textStack.translatesAutoresizingMaskIntoConstraints = false

        // More button
        let moreBtn = UIButton(type: .system)
        moreBtn.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        moreBtn.tintColor = .tertiaryLabel
        moreBtn.translatesAutoresizingMaskIntoConstraints = false
        let scanId = scan.id
        moreBtn.addAction(UIAction { [weak self, weak titleLbl] _ in
            self?.showRenameAlert(for: scanId, currentTitle: titleLbl?.text ?? title, titleLabel: titleLbl)
        }, for: .touchUpInside)

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

        // ── Tap: pass jobId + resultURL to UploadPageNextViewController ──
        card.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            guard let jobIdStr = jsonDict?["job_id"] as? String,
                  let jobId    = UUID(uuidString: jobIdStr) else {
                debugLog("[AllUploads] ❌ No job_id in scan \(scan.id)")
                return
            }
            let outputURL = jsonDict?["output_url"] as? String
            let vc        = UploadPageNextViewController()
            vc.jobId      = jobId
            vc.resultURL  = outputURL
            debugLog("[AllUploads] jobId=\(jobId.uuidString.lowercased())  hasResultURL=\(outputURL?.isEmpty == false)")
            self.navigationController?.pushViewController(vc, animated: true)
        }, for: .touchUpInside)

        card.addTarget(self, action: #selector(cardDown(_:)), for: .touchDown)
        card.addTarget(self, action: #selector(cardUp(_:)),
                       for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return card
    }

    @objc private func cardDown(_ s: UIButton) {
        UIView.animate(withDuration: 0.12) { s.transform = CGAffineTransform(scaleX: 0.97, y: 0.97) }
    }
    @objc private func cardUp(_ s: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            s.transform = .identity
        }
    }

    // MARK: - Empty State
    private func makeEmptyState() -> UIView {
        let v = UIView()
        v.backgroundColor    = .secondarySystemBackground
        v.layer.cornerRadius = 14
        let lbl = UILabel()
        lbl.text = "No uploads yet"; lbl.textColor = .tertiaryLabel
        lbl.font = .systemFont(ofSize: 15); lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            lbl.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            v.heightAnchor.constraint(equalToConstant: 80)
        ])
        return v
    }

    // MARK: - Rename
    private func showRenameAlert(for scanId: Int64, currentTitle: String, titleLabel: UILabel?) {
        let alert = UIAlertController(title: "Rename File", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = currentTitle; tf.placeholder = "Enter new name"
            tf.clearButtonMode = .whileEditing; tf.autocapitalizationType = .words
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
            let upd = ScanUpdate(jsonData: AnyCodable(dict), status: scan.status ?? "completed",
                                  processedAt: scan.processedAt ?? ISO8601DateFormatter().string(from: Date()),
                                  updatedAt: ISO8601DateFormatter().string(from: Date()))
            try await supabase.from("scans").update(upd).eq("id", value: Int(scanId)).execute()
        } catch {
            debugLog("[AllUploads] rename failed: \(error)")
            await MainActor.run { self.loadUploads() }
        }
    }

    // MARK: - Formatting Helpers
    private func formatDate(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return relativeDate(d) }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return relativeDate(d) }
        return ""
    }

    private func relativeDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: date)
    }

    private func formatSize(_ dict: [String: Any]?) -> String {
        guard let d = dict else { return "" }
        let bytes: Int? = (d["file_size_bytes"] as? Int)
            ?? (d["file_size_bytes"] as? Double).map { Int($0) }
            ?? (d["file_size"] as? Int)
            ?? (d["file_size"] as? String).flatMap { Int($0) }
        guard let b = bytes else { return "" }
        let kb = Double(b) / 1024.0
        return kb < 1024 ? String(format: "%.0f KB", kb) : String(format: "%.1f MB", kb / 1024.0)
    }

    // MARK: - Data Models
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

    @objc private func handleBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleProfile() {
        navigationController?.pushViewController(UserProfileViewController(), animated: true)
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
