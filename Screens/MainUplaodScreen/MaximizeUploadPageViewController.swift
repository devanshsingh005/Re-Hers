//
//  MaximizeViewController.swift
//  Re-Hearse_v1
//

import UIKit

final class MaximizeViewController: UIViewController {

    // MARK: - Public API
    var sheetImage: UIImage? {
        didSet { sheetImageView.image = sheetImage }
    }

    // MARK: - Top Navbar
    private let navBar = TopNavBar()

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let sheetContainer = UIView()
    private let sheetImageView = UIImageView()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupNavBar()
        setupUI()
        buildHierarchy()
        applyConstraints()
        enableSwipeDismiss()
    }

    // MARK: - Navbar
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false

        navBar.isBackButtonVisible = true
        navBar.isChordIconVisible = false
        navBar.isProfileVisible = false
        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        navBar.setTitle("Sheet Music")

        navBar.backAction = { [weak self] in
            self?.dismiss(animated: true)
        }

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: - UI Setup
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // Bigger dark card
        sheetContainer.backgroundColor = UIColor(white: 0.22, alpha: 1)
        sheetContainer.layer.cornerRadius = 34
        sheetContainer.translatesAutoresizingMaskIntoConstraints = false

        // Bigger image
        sheetImageView.contentMode = .scaleAspectFit
        sheetImageView.clipsToBounds = true
        sheetImageView.layer.cornerRadius = 22
        sheetImageView.backgroundColor = .white
        sheetImageView.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Hierarchy
    private func buildHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(sheetContainer)
        sheetContainer.addSubview(sheetImageView)
    }

    // MARK: - Constraints
    private func applyConstraints() {

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        // Bigger container + bigger image
        NSLayoutConstraint.activate([
            sheetContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            sheetContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            sheetContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            sheetContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),

            sheetImageView.topAnchor.constraint(equalTo: sheetContainer.topAnchor, constant: 30),
            sheetImageView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 30),
            sheetImageView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -30),
            sheetImageView.bottomAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: -30),

            // Bigger height
            sheetImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 550)
        ])
    }

    // MARK: - Swipe to dismiss
    private func enableSwipeDismiss() {
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        swipe.direction = .down
        view.addGestureRecognizer(swipe)
    }

    @objc private func handleSwipeDown() {
        dismiss(animated: true)
    }
}
