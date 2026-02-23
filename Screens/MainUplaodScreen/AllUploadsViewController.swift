//
//  AllUploadsViewController.swift
//  Re-Hearse_v1
//  Screens/MainUplaodScreen/
//

import UIKit
import Supabase

class AllUploadsViewController: UIViewController {
    
    // MARK: - UI
    private let navBar = TopNavBar.make(title: "Recents")
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private var uploadsStack: UIStackView?
    private var loadingIndicator: UIActivityIndicatorView?
    
    // MARK: - Supabase
    private var supabase: SupabaseClient {
        return SupabaseManager.shared.client
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.96, green: 0.95, blue: 0.94, alpha: 1.0)
        navigationController?.navigationBar.isHidden = true
        
        setupNavBar()
        setupScrollView()
        setupUploadsStack()
        setupLoadingIndicator()
        
        loadAllUploads()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadAllUploads()
    }
    
    // MARK: - NavBar
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Show back button, hide streak + chord, keep profile visible
        navBar.isBackButtonVisible = true
        navBar.isStreakVisible = false
        navBar.isChordIconVisible = false
        navBar.isProfileVisible = true
        navBar.isWelcomeTextHidden = true
        
        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
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
        contentView.spacing = 10
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -30),
            contentView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }
    
    // MARK: - Uploads list stack
    private func setupUploadsStack() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        uploadsStack = stack
        contentView.addArrangedSubview(stack)
    }
    
    // MARK: - Loading Indicator
    private func setupLoadingIndicator() {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = UIColor(hex: "#FF6B00")
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        loadingIndicator = indicator
    }
    
    // MARK: - Load ALL uploads (no limit)
    private func loadAllUploads() {
        loadingIndicator?.startAnimating()
        
        Task {
            do {
                let scans = try await fetchAllScans()
                DispatchQueue.main.async {
                    self.loadingIndicator?.stopAnimating()
                    self.renderRows(scans)
                }
            } catch {
                print("AllUploads fetch error: \(error)")
                DispatchQueue.main.async {
                    self.loadingIndicator?.stopAnimating()
                    self.renderRows([])
                }
            }
        }
    }
    
    private func fetchAllScans() async throws -> [Scan] {
        guard let userIdString = await getCurrentUserId(),
              let userId = UUID(uuidString: userIdString) else { return [] }
        
        let response: [Scan] = try await supabase
            .from("scans")
            .select()
            .eq("user_id", value: userId)
            .order("updated_at", ascending: false)
            .limit(10)
            .execute()
            .value
        
        // Deduplicate by id
        var seen = Set<Int64>()
        return response.filter { seen.insert($0.id).inserted }
    }
    
    private func getCurrentUserId() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.user.id.uuidString
        } catch { return nil }
    }
    
    // MARK: - Render rows
    private func renderRows(_ scans: [Scan]) {
        guard let stack = uploadsStack else { return }
        
        for view in stack.arrangedSubviews { view.removeFromSuperview() }
        
        if scans.isEmpty {
            let empty = makeEmptyState()
            stack.addArrangedSubview(empty)
            return
        }
        
        for scan in scans {
            let title = extractTitle(from: scan.jsonData) ?? scan.originalFilename ?? extractDate(from: scan)
            let fileType = (scan.fileType ?? "application/pdf").contains("pdf") ? "PDF" : "FILE"
            let dateStr = extractDate(from: scan)
            let sizeStr = extractFileSize(from: scan.jsonData)
            let metaStr = [dateStr, sizeStr].compactMap { $0.isEmpty ? nil : $0 }.joined(separator: " • ")
            stack.addArrangedSubview(makeRow(title: title, fileType: fileType, metaStr: metaStr, scan: scan))
        }
    }
    
    // MARK: - Row UI (matches UploadScreen style exactly)
    private func makeRow(title: String, fileType: String, metaStr: String, scan: Scan) -> UIView {
        let card = UIButton(type: .custom)
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.05
        card.layer.shadowRadius = 8
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.clipsToBounds = false
        card.translatesAutoresizingMaskIntoConstraints = false
        
        // Gradient PDF icon
        let iconWrap = GradientView(colors: [UIColor(hex: "#EF9408"), UIColor(hex: "#FF6B00")])
        iconWrap.layer.cornerRadius = 12
        iconWrap.clipsToBounds = true
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.isUserInteractionEnabled = false
        
        let iconImg = UIImageView(image: UIImage(systemName: "doc.fill"))
        iconImg.tintColor = .white
        iconImg.contentMode = .scaleAspectFit
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        
        // Text stack
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 5
        textStack.isUserInteractionEnabled = false
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLbl.textColor = .label
        titleLbl.lineBreakMode = .byTruncatingTail
        
        // Meta row
        let metaRow = UIStackView()
        metaRow.axis = .horizontal
        metaRow.spacing = 6
        metaRow.alignment = .center
        
        let badge = UILabel()
        badge.text = fileType
        badge.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        badge.textColor = UIColor(hex: "#FF6B00")
        badge.backgroundColor = UIColor(hex: "#FF6B00").withAlphaComponent(0.12)
        badge.layer.cornerRadius = 5
        badge.clipsToBounds = true
        badge.textAlignment = .center
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.widthAnchor.constraint(equalToConstant: 38).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        let metaLbl = UILabel()
        metaLbl.text = metaStr
        metaLbl.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        metaLbl.textColor = .tertiaryLabel
        
        metaRow.addArrangedSubview(badge)
        metaRow.addArrangedSubview(metaLbl)
        textStack.addArrangedSubview(titleLbl)
        textStack.addArrangedSubview(metaRow)
        
        // Ellipsis button — interactive
        let moreBtn = UIButton(type: .system)
        moreBtn.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        moreBtn.tintColor = .tertiaryLabel
        moreBtn.translatesAutoresizingMaskIntoConstraints = false
        moreBtn.isUserInteractionEnabled = true
        
        let scanId = scan.id
        moreBtn.addAction(UIAction { [weak self, weak titleLbl] _ in
            guard let self = self else { return }
            self.showRowOptions(for: scanId, currentTitle: titleLbl?.text ?? title, titleLabel: titleLbl)
        }, for: .touchUpInside)
        
        // Assemble
        iconWrap.addSubview(iconImg)
        card.addSubview(iconWrap)
        card.addSubview(textStack)
        card.addSubview(moreBtn)
        
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
        
        card.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let vc = UploadPageNextViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }, for: .touchUpInside)
        
        // Press animation
        card.addTarget(self, action: #selector(cardDown(_:)), for: .touchDown)
        card.addTarget(self, action: #selector(cardUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        return card
    }
    
    @objc private func cardDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12) { sender.transform = CGAffineTransform(scaleX: 0.97, y: 0.97) }
    }
    
    @objc private func cardUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            sender.transform = .identity
        }
    }
    
    // MARK: - Empty state
    private func makeEmptyState() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 14
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let lbl = UILabel()
        lbl.text = "No uploads yet"
        lbl.textColor = .tertiaryLabel
        lbl.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            lbl.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 80)
        ])
        return container
    }
    
    // MARK: - Ellipsis menu
    private func showRowOptions(for scanId: Int64, currentTitle: String, titleLabel: UILabel?) {
        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self] _ in
            self?.showRenameAlert(for: scanId, currentTitle: currentTitle, titleLabel: titleLabel)
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let pop = ac.popoverPresentationController {
            pop.sourceView = self.view
            pop.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        present(ac, animated: true)
    }
    
    private func showRenameAlert(for scanId: Int64, currentTitle: String, titleLabel: UILabel?) {
        let alert = UIAlertController(title: "Rename File", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = currentTitle
            tf.placeholder = "Enter new name"
            tf.clearButtonMode = .whileEditing
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self,
                  let newName = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !newName.isEmpty else { return }
            // Optimistic update
            titleLabel?.text = newName
            Task { await self.renameScan(scanId: scanId, newTitle: newName) }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Persist rename to scans.json_data["title"]
    private func renameScan(scanId: Int64, newTitle: String) async {
        do {
            let scans: [Scan] = try await supabase
                .from("scans")
                .select()
                .eq("id", value: Int(scanId))
                .limit(1)
                .execute()
                .value
            
            guard let scan = scans.first else { return }
            
            var jsonDict = (scan.jsonData?.value as? [String: Any]) ?? [:]
            jsonDict["title"] = newTitle
            
            let update = ScanUpdate(
                jsonData: AnyCodable(jsonDict),
                status: scan.status ?? "completed",
                processedAt: scan.processedAt ?? ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            try await supabase
                .from("scans")
                .update(update)
                .eq("id", value: Int(scanId))
                .execute()
            
            print("Renamed scan \(scanId) → \(newTitle)")
        } catch {
            print("Rename failed: \(error)")
            DispatchQueue.main.async { self.loadAllUploads() }
        }
    }
    
    // MARK: - Data Helpers
    private func extractTitle(from jsonData: AnyCodable?) -> String? {
        guard let dict = jsonData?.value as? [String: Any] else { return nil }
        return dict["title"] as? String
    }
    
    private func extractDate(from scan: Scan) -> String {
        let dict = scan.jsonData?.value as? [String: Any]
        let raw = (dict?["uploaded_at"] as? String) ?? scan.processedAt ?? scan.updatedAt
        return formatDateString(raw)
    }
    
    private func extractFileSize(from jsonData: AnyCodable?) -> String {
        guard let dict = jsonData?.value as? [String: Any] else { return "" }
        if let b = dict["file_size_bytes"] as? Int { return formatBytes(b) }
        if let b = dict["file_size_bytes"] as? Double { return formatBytes(Int(b)) }
        if let b = dict["file_size"] as? Int { return formatBytes(b) }
        if let s = dict["file_size"] as? String, let b = Int(s) { return formatBytes(b) }
        return ""
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        return kb < 1024 ? String(format: "%.0f KB", kb) : String(format: "%.1f MB", kb / 1024.0)
    }
    
    private func formatDateString(_ raw: String?) -> String {
        guard let raw = raw, !raw.isEmpty else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return shortDate(date) }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return shortDate(date) }
        return ""
    }
    
    private func shortDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: date)
    }
    
    // MARK: - Data Models (mirrors UploadScreen — needed since they're nested there)
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
            if let b = try? c.decode(Bool.self) { value = b }
            else if let i = try? c.decode(Int.self) { value = i }
            else if let d = try? c.decode(Double.self) { value = d }
            else if let s = try? c.decode(String.self) { value = s }
            else if let a = try? c.decode([AnyCodable].self) { value = a.map { $0.value } }
            else if let d = try? c.decode([String: AnyCodable].self) { value = d.mapValues { $0.value } }
            else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Cannot decode") }
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch value {
            case let b as Bool: try c.encode(b)
            case let i as Int: try c.encode(i)
            case let d as Double: try c.encode(d)
            case let s as String: try c.encode(s)
            case let a as [Any]: try c.encode(a.map { AnyCodable($0) })
            case let d as [String: Any]: try c.encode(d.mapValues { AnyCodable($0) })
            default: throw EncodingError.invalidValue(value, .init(codingPath: c.codingPath, debugDescription: "Cannot encode"))
            }
        }
    }
}

// MARK: - GradientView (local copy for this file)
private class GradientView: UIView {
    private let gradientLayer = CAGradientLayer()
    init(colors: [UIColor]) {
        super.init(frame: .zero)
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gradientLayer)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

// MARK: - UIColor hex (local extension for this file)
//private extension UIColor {
//    convenience init(hex: String) {
//        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
//        if h.hasPrefix("#") { h = String(h.dropFirst()) }
//        var rgb: UInt64 = 0
//        Scanner(string: h).scanHexInt64(&rgb)
//        self.init(
//            red:   CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
//            green: CGFloat((rgb & 0x00FF00) >> 8)  / 255.0,
//            blue:  CGFloat(rgb & 0x0000FF)          / 255.0,
//            alpha: 1.0
//        )
//    }
//}
