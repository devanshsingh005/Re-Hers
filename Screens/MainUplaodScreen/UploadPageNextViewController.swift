//
//  UploadPageNextViewController.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 25/11/25.
//

import UIKit

final class UploadPageNextViewController: UIViewController {
    // MARK: - Public API
    // Set this from Upload Screen before pushing this controller
    var uploadedImage: UIImage? {
        didSet { imageView.image = uploadedImage }
    }

    // MARK: - UI
    private let topNavBar = UIView()
    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let imageView = UIImageView()

    private let bottomNavBar = UIView()
    private let primaryButton = UIButton(type: .system)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        buildHierarchy()
        applyConstraints()
        configureContent()
    }

    // MARK: - Setup
    private func configureView() {
        view.backgroundColor = .systemBackground

        // Top Nav Bar
        topNavBar.backgroundColor = .secondarySystemBackground
        topNavBar.translatesAutoresizingMaskIntoConstraints = false

        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.setTitle("", for: .normal)
        backButton.tintColor = .label
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "Preview"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Scroll + Content
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentView.translatesAutoresizingMaskIntoConstraints = false

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .tertiarySystemFill // visible placeholder if no image
        imageView.translatesAutoresizingMaskIntoConstraints = false

        // Bottom Nav Bar
        bottomNavBar.backgroundColor = .secondarySystemBackground
        bottomNavBar.translatesAutoresizingMaskIntoConstraints = false

        primaryButton.setTitle("Continue", for: .normal)
        primaryButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        primaryButton.backgroundColor = .label
        primaryButton.setTitleColor(.systemBackground, for: .normal)
        primaryButton.layer.cornerRadius = 12
        primaryButton.addTarget(self, action: #selector(didTapPrimary), for: .touchUpInside)
        primaryButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func buildHierarchy() {
        view.addSubview(topNavBar)
        topNavBar.addSubview(backButton)
        topNavBar.addSubview(titleLabel)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(imageView)

        view.addSubview(bottomNavBar)
        bottomNavBar.addSubview(primaryButton)
    }

    private func applyConstraints() {
        let topBarHeight: CGFloat = 56
        let bottomBarHeight: CGFloat = 88
        let horizontalInset: CGFloat = 20

        NSLayoutConstraint.activate([
            // Top bar
            topNavBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topNavBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topNavBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topNavBar.heightAnchor.constraint(equalToConstant: topBarHeight),

            backButton.leadingAnchor.constraint(equalTo: topNavBar.leadingAnchor, constant: 12),
            backButton.centerYAnchor.constraint(equalTo: topNavBar.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.centerXAnchor.constraint(equalTo: topNavBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topNavBar.centerYAnchor),

            // Bottom bar
            bottomNavBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomNavBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomNavBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomNavBar.heightAnchor.constraint(equalToConstant: bottomBarHeight),

            primaryButton.leadingAnchor.constraint(equalTo: bottomNavBar.leadingAnchor, constant: horizontalInset),
            primaryButton.trailingAnchor.constraint(equalTo: bottomNavBar.trailingAnchor, constant: -horizontalInset),
            primaryButton.centerYAnchor.constraint(equalTo: bottomNavBar.centerYAnchor),
            primaryButton.heightAnchor.constraint(equalToConstant: 52),

            // Scroll area
            scrollView.topAnchor.constraint(equalTo: topNavBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomNavBar.topAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalInset),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalInset),
            imageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 240),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func configureContent() {
        imageView.image = uploadedImage
    }

    // MARK: - Actions
    @objc private func didTapBack() {
        if let nav = navigationController {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func didTapPrimary() {
        // TODO: Handle next action
        // e.g., push another controller or call a delegate
        let alert = UIAlertController(title: "Continue", message: "Primary action tapped.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
