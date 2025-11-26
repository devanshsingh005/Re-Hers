//
//  MaximizeUploadPageViewController.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 26/11/25.
//

import Foundation
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
    }

    // MARK: - Setup NavBar
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
        navBar.profileAction = { [weak self] in
               guard let self = self else { return }
               let vc = ProfileScreen()
               self.navigationController?.pushViewController(vc, animated: true)
           }

           navBar.backAction = { [weak self] in
               self?.navigationController?.popViewController(animated: true)
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

        // Dark Rounded Card
        sheetContainer.backgroundColor = UIColor(white: 0.22, alpha: 1)
        sheetContainer.layer.cornerRadius = 32
        sheetContainer.translatesAutoresizingMaskIntoConstraints = false

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

        // Big center card
        NSLayoutConstraint.activate([
            sheetContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            sheetContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            sheetContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            sheetContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])

        // Image with padding
        NSLayoutConstraint.activate([
            sheetImageView.topAnchor.constraint(equalTo: sheetContainer.topAnchor, constant: 24),
            sheetImageView.leadingAnchor.constraint(equalTo: sheetContainer.leadingAnchor, constant: 24),
            sheetImageView.trailingAnchor.constraint(equalTo: sheetContainer.trailingAnchor, constant: -24),
            sheetImageView.bottomAnchor.constraint(equalTo: sheetContainer.bottomAnchor, constant: -24),
            sheetImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 450)
        ])
    }
}
