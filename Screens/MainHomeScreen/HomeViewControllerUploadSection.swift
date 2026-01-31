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
 
    @discardableResult
    func addUploadSection() -> UIView {
        assert(contentView.superview != nil, "contentView is not added to scrollView yet")

        let container = UIView()
        container.backgroundColor = .secondaryColor
        container.layer.cornerRadius = 26
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 120).isActive = true // ⬆️ increased

        let icon = UIImageView(image: UIImage(systemName: "icloud.and.arrow.up"))
        icon.tintColor = .darkGray2
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 34).isActive = true  // ⬆️ increased
        icon.heightAnchor.constraint(equalToConstant: 34).isActive = true // ⬆️ increased

        let text = UILabel()
        text.text = "Sheet to Music"
        text.font = .systemFont(ofSize: 24, weight: .semibold) // ⬆️ increased
        text.textColor = .darkGray2

        let stack = UIStackView(arrangedSubviews: [text, icon])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14 // ⬆️ increased
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        contentView.addArrangedSubview(container)
        return container
    }
}
