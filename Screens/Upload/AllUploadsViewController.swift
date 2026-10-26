//
//  AllUploadsViewController.swift
//  Re-Hearse_v1
//

import UIKit

class AllUploadsViewController: UIViewController {

    // MARK: - UI
    private let scrollView       = UIScrollView()
    private let contentStack     = UIStackView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private var uploadLoadErrorMessage: String?
    private var shownUploads: [LocalSheetLibrary.Upload] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.App.screenBackground
        navigationController?.setNavigationBarHidden(false, animated: false)
        setupNavBar()
        setupScrollView()
        setupLoadingIndicator()
        loadUploads()
        NotificationCenter.default.addObserver(self, selector: #selector(handleLibraryChange),
                                               name: LocalSheetLibrary.didChangeNotification, object: nil)
    }

    @objc private func handleLibraryChange(_ note: Notification) {
        // progress ticks don't change the list; status, title and membership do
        guard let id = note.userInfo?["id"] as? UUID else { return }
        let current = LocalSheetLibrary.shared.upload(id: id)
        let shown = shownUploads.first { $0.id == id }
        if current?.status != shown?.status || current?.title != shown?.title || (current == nil) != (shown == nil) {
            loadUploads()
        }
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
        navigationItem.rightBarButtonItems = nil
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
        uploadLoadErrorMessage = nil
        shownUploads = LocalSheetLibrary.shared.uploads()
        renderRows(shownUploads)
    }

    // MARK: - Render
    private func renderRows(_ uploads: [LocalSheetLibrary.Upload]) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if uploads.isEmpty {
            contentStack.addArrangedSubview(makeEmptyState(message: uploadLoadErrorMessage))
            return
        }
        for upload in uploads { contentStack.addArrangedSubview(makeRow(for: upload)) }
    }

    private func makeRow(for upload: LocalSheetLibrary.Upload) -> UIView {
        let title    = upload.title
        let fileType = "PDF"
        let meta: String = {
            switch upload.status {
            case .processing: return "Converting on device…"
            case .failed:     return "Conversion failed"
            case .completed:  return [relativeDate(upload.uploadedAt), formatSize(upload.fileSizeBytes)].joined(separator: " • ")
            }
        }()

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
        moreBtn.showsMenuAsPrimaryAction = true
        let scanId = upload.scanId
        let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { [weak self, weak titleLbl] _ in
            self?.showRenameAlert(for: scanId, currentTitle: titleLbl?.text ?? title, titleLabel: titleLbl)
        }
        let delete = UIAction(
            title: "Delete Upload",
            image: UIImage(systemName: "trash"),
            attributes: .destructive
        ) { [weak self, weak titleLbl] _ in
            self?.confirmDeleteScan(id: scanId, title: titleLbl?.text ?? title)
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

        // ── Tap: open the result screen (it shows progress while still converting) ──
        card.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            guard let current = LocalSheetLibrary.shared.upload(id: upload.id) else {
                self.loadUploads()
                return
            }
            if current.status == .failed {
                self.presentFailedUploadAlert(current)
                return
            }
            let vc   = UploadPageNextViewController()
            vc.jobId = current.id
            debugLog("[AllUploads] upload=\(current.id.uuidString.lowercased()) status=\(current.status.rawValue)")
            self.navigationController?.pushViewController(vc, animated: true)
        }, for: .touchUpInside)

        card.addTarget(self, action: #selector(cardDown(_:)), for: .touchDown)
        card.addTarget(self, action: #selector(cardUp(_:)),
                       for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return card
    }

    private func presentFailedUploadAlert(_ upload: LocalSheetLibrary.Upload) {
        let alert = UIAlertController(
            title: "Conversion Failed",
            message: upload.errorMessage ?? "We couldn't convert this sheet music. The file may be unclear, unsupported, or incomplete.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
            LocalSheetLibrary.shared.retry(id: upload.id)
            let vc   = UploadPageNextViewController()
            vc.jobId = upload.id
            self?.navigationController?.pushViewController(vc, animated: true)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
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
    private func makeEmptyState(message: String?) -> UIView {
        let v = UIView()
        v.backgroundColor    = .secondarySystemBackground
        v.layer.cornerRadius = 14
        let lbl = UILabel()
        lbl.text = message ?? "No uploads yet"
        lbl.textColor = .tertiaryLabel
        lbl.font = .systemFont(ofSize: 15); lbl.textAlignment = .center
        lbl.numberOfLines = 0
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
            guard let self else { return }
            let name = InputValidator.limit(
                InputValidator.trimOnSubmit(alert.textFields?.first?.text ?? ""),
                maxLength: InputValidator.nameMaxLength
            )
            guard InputValidator.validateRequired(name, message: "File name is required.") == nil else {
                self.showErrorAlert(message: "File name is required.")
                return
            }
            titleLabel?.text = name
            Task { await self.renameScan(id: scanId, newTitle: name) }
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
                self.showErrorAlert(message: "File name is required.")
            }
            return
        }

        do {
            try LocalSheetLibrary.shared.rename(scanId: scanId, to: sanitizedTitle)
        } catch {
            debugLog("[AllUploads] rename failed: \(error)")
            let message = AppUserFacingError.message(
                for: "rename that upload",
                error: error,
                fallback: "We couldn't rename that file right now. Please try again."
            )
            await MainActor.run {
                self.loadUploads()
                self.showErrorAlert(
                    title: AppUserFacingError.title(for: error),
                    message: message
                )
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
            try LocalSheetLibrary.shared.delete(scanId: scanId)
            loadUploads()
        } catch {
            debugLog("[AllUploads] delete failed: \(error)")
            let message = AppUserFacingError.message(
                for: "delete that upload",
                error: error,
                fallback: "We couldn't delete this upload right now. Please try again."
            )
            await MainActor.run {
                self.showErrorAlert(
                    title: AppUserFacingError.title(for: error),
                    message: message
                )
            }
        }
    }

    private func showErrorAlert(title: String = "Error", message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Formatting Helpers
    private func relativeDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: date)
    }

    private func formatSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        return kb < 1024 ? String(format: "%.0f KB", kb) : String(format: "%.1f MB", kb / 1024.0)
    }

    @objc private func handleBack() {
        navigationController?.popViewController(animated: true)
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
