//
//  HomeViewControllerLayout.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {

    func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.isChordIconVisible = false
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])
        navBar.profileAction = { [weak self] in
            guard let self = self else { return }
            let vc = UserProfileViewController()
            self.navigationController?.pushViewController(vc, animated: true)
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
        contentView.axis = .vertical
        contentView.spacing = 20
        contentView.alignment = .fill
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        // No subtitle label — removed per request
    }

    @objc func openPianoPage() {
        let vc = PianoAnimationViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func playAlongTapped() {
        let vc = PlayAlongViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
}
