//
//  HomeViewControllerUploadSection.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/12/25.
//

import Foundation
//
//  HomeViewController+UploadSection.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {
    
    // MARK: - Upload Section
     func addUploadSection() {
        let container = UIView()
        container.backgroundColor = .secondaryColor
        container.layer.cornerRadius = 22
        container.heightAnchor.constraint(equalToConstant: 120).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "icloud.and.arrow.up"))
        icon.tintColor = .darkGray2

        let text = UILabel()
        text.text = "Sheet to Music"
        text.font = .systemFont(ofSize: 20, weight: .semibold)
        text.textColor = .darkGray2

        let stack = UIStackView(arrangedSubviews: [text, icon])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8

        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        contentView.addArrangedSubview(container)
    }
}
