//
//  HomeViewControllerLayout.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {

    func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.isChordIconVisible  = false
        navBar.isWelcomeTextHidden = false
        navBar.setTitle("Home")
        

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            // Same 20 pt edge as contentView so title + cards are pixel-aligned
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        navBar.profileAction = { [weak self] in
            guard let self else { return }
            navigationController?.pushViewController(UserProfileViewController(), animated: true)
        }
        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = false

        scrollView.addSubview(contentView)
        contentView.axis      = .vertical
        contentView.spacing   = 20
        contentView.alignment = .fill
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // 20 pt breathing room between subtitle and first card
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            // 20 pt inset matches nav bar leading/trailing — everything pixel-aligned
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])
    }

    // MARK: - Section header with optional "See all"
    func makeSectionHeader(_ text: String, action: (() -> Void)? = nil) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = text
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = ComponentColors.HomeScreen.sectionHeaderText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        guard let action else { return titleLabel }

        let seeAll = UIButton(type: .system)
        seeAll.setTitle("See all", for: .normal)
        seeAll.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        seeAll.setTitleColor(ComponentColors.HomeScreen.actionButtonFill, for: .normal)
        seeAll.translatesAutoresizingMaskIntoConstraints = false
        seeAll.addAction(UIAction { _ in action() }, for: .touchUpInside)

        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(titleLabel); row.addSubview(seeAll)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            seeAll.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            seeAll.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: seeAll.leadingAnchor, constant: -8),
            row.heightAnchor.constraint(equalToConstant: 30),
        ])
        return row
    }

    @objc func openPianoPage() {
        navigationController?.pushViewController(PianoAnimationkeyboardViewController(), animated: true)
    }

    @objc func playAlongTapped() {
        navigationController?.pushViewController(PlayAlongViewController(), animated: true)
    }
}
