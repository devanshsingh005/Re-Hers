//
//  UploadPickerViewController.swift
//  Re-Hearse_v1
//
//  Presents the user's uploaded scans as a selectable list for adding to a playlist.

import UIKit

class UploadPickerViewController: UIViewController {

    // MARK: - Callback

    /// Called when the user picks an upload. The VC dismisses itself before calling back.
    var onSelect: ((UploadScanItem) -> Void)?

    // MARK: - UI

    private let handleBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemGray4
        v.layer.cornerRadius = 3
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Add from Uploads"
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Choose one of your uploaded files"
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.alwaysBounceVertical = true
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 10
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(style: .medium)
        a.color = ComponentColors.SongCard.fileIcon
        a.hidesWhenStopped = true
        a.translatesAutoresizingMaskIntoConstraints = false
        return a
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.App.screenBackground
        setupHeader()
        setupScrollView()
        setupLoadingIndicator()
        loadUploads()
    }

    // MARK: - Layout

    private func setupHeader() {
        view.addSubview(handleBar)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            handleBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            handleBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 40),
            handleBar.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
        ])
    }

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -30),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])
    }

    private func setupLoadingIndicator() {
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - Data

    private func loadUploads() {
        loadingIndicator.startAnimating()
        Task {
            do {
                let uploads = try await PlaylistsManager.shared.fetchUserUploads()
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    self.renderRows(uploads)
                }
            } catch {
                print("[UploadPicker] fetch error: \(error)")
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    self.renderRows([])
                }
            }
        }
    }

    // MARK: - Render

    private func renderRows(_ uploads: [UploadScanItem]) {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if uploads.isEmpty {
            contentStack.addArrangedSubview(makeEmptyState())
            return
        }
        for upload in uploads {
            contentStack.addArrangedSubview(makeRow(for: upload))
        }
    }

    private func makeRow(for upload: UploadScanItem) -> UIView {
        let meta = [upload.dateString, upload.sizeString]
            .filter { !$0.isEmpty }
            .joined(separator: " • ")

        // Card container
        let card = UIView()
        card.backgroundColor = ComponentColors.SongCard.background
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowRadius = 8
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.clipsToBounds = false
        card.translatesAutoresizingMaskIntoConstraints = false

        // Icon wrap
        let iconWrap = makeGradientIconView()
        let iconImg = UIImageView(image: UIImage(systemName: "doc.fill"))
        iconImg.tintColor = .white
        iconImg.contentMode = .scaleAspectFit
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.addSubview(iconImg)

        // Title
        let titleLbl = UILabel()
        titleLbl.text = upload.title
        titleLbl.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLbl.lineBreakMode = .byTruncatingTail

        // Badge
        let badge = UILabel()
        badge.text = upload.fileType
        badge.font = .systemFont(ofSize: 11, weight: .bold)
        badge.textColor = ComponentColors.SongCard.fileIcon
        badge.backgroundColor = ComponentColors.SongCard.fileIcon.withAlphaComponent(0.12)
        badge.layer.cornerRadius = 5
        badge.clipsToBounds = true
        badge.textAlignment = .center
        badge.translatesAutoresizingMaskIntoConstraints = false

        // Meta
        let metaLbl = UILabel()
        metaLbl.text = meta
        metaLbl.font = .systemFont(ofSize: 12)
        metaLbl.textColor = .tertiaryLabel

        let metaRow = UIStackView(arrangedSubviews: [badge, metaLbl])
        metaRow.axis = .horizontal
        metaRow.spacing = 6
        metaRow.alignment = .center

        let textStack = UIStackView(arrangedSubviews: [titleLbl, metaRow])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        // Add button
        let addBtn = UIButton(type: .system)
        addBtn.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        addBtn.tintColor = ComponentColors.SongCard.fileIcon
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        addBtn.widthAnchor.constraint(equalToConstant: 36).isActive = true
        addBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let capturedUpload = upload
        addBtn.addAction(UIAction { [weak self] _ in
            self?.didSelectUpload(capturedUpload)
        }, for: .touchUpInside)

        card.addSubview(iconWrap)
        card.addSubview(textStack)
        card.addSubview(addBtn)

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
            textStack.trailingAnchor.constraint(equalTo: addBtn.leadingAnchor, constant: -8),

            addBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            addBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            badge.widthAnchor.constraint(equalToConstant: 38),
            badge.heightAnchor.constraint(equalToConstant: 20),
        ])

        return card
    }

    private func makeEmptyState() -> UIView {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 14

        let img = UIImageView(image: UIImage(systemName: "square.and.arrow.up"))
        img.tintColor = .tertiaryLabel
        img.contentMode = .scaleAspectFit
        img.translatesAutoresizingMaskIntoConstraints = false

        let lbl = UILabel()
        lbl.text = "No uploads yet.\nUpload something first!"
        lbl.textColor = .secondaryLabel
        lbl.font = .systemFont(ofSize: 14)
        lbl.textAlignment = .center
        lbl.numberOfLines = 0
        lbl.translatesAutoresizingMaskIntoConstraints = false

        v.addSubview(img)
        v.addSubview(lbl)
        NSLayoutConstraint.activate([
            v.heightAnchor.constraint(equalToConstant: 120),
            img.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            img.topAnchor.constraint(equalTo: v.topAnchor, constant: 20),
            img.widthAnchor.constraint(equalToConstant: 34),
            img.heightAnchor.constraint(equalToConstant: 34),
            lbl.topAnchor.constraint(equalTo: img.bottomAnchor, constant: 10),
            lbl.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 20),
            lbl.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -20),
        ])
        return v
    }

    // MARK: - Selection

    private func didSelectUpload(_ upload: UploadScanItem) {
        dismiss(animated: true) { [weak self] in
            self?.onSelect?(upload)
        }
    }

    // MARK: - Helpers

    private func makeGradientIconView() -> GradientIconView {
        let v = GradientIconView()
        v.colors = [ComponentColors.HomeScreen.actionButtonFill, ComponentColors.SongCard.fileIcon]
        v.layer.cornerRadius = 12
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }
}

// MARK: - Gradient helper (private to this file)

private class GradientIconView: UIView {
    var colors: [UIColor] = [] {
        didSet { gl.colors = colors.map { $0.cgColor } }
    }
    private let gl = CAGradientLayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        gl.startPoint = CGPoint(x: 0, y: 0)
        gl.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gl)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() { super.layoutSubviews(); gl.frame = bounds }
}
