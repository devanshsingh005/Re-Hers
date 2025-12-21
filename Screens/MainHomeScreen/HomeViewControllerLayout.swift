//
//  HomeViewControllerLayout.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/12/25.
//

import Foundation
//
//  HomeViewController+Layout.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {
    
    // MARK: - Navbar Setup
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

    // MARK: - ScrollView Setup
     func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        contentView.axis = .vertical
        contentView.spacing = 18
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }
    
    // MARK: - Navigation to Piano Page
    @objc func openPianoPage() {
        let vc = PianoAnimationViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    @objc func playAlongTapped() {
        print("🔥 PLAY ALONG TAP DETECTED")
        let vc = PlayAlongViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

}


