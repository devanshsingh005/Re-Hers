//
//  HomeViewControllerUploadSection.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/12/25.
//

import UIKit

extension HomeViewController {

    // MARK: - Upload Section (Sheet to Music)

    @discardableResult
    func addUploadSection() -> UIView {
        assert(contentView.superview != nil, "contentView is not added to scrollView yet")

        let container = UIView()
        container.backgroundColor = .secondaryColor
        container.layer.cornerRadius = 26
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 120).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "icloud.and.arrow.up"))
        icon.tintColor = .darkGray2
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 34).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 34).isActive = true

        let text = UILabel()
        text.text = "Sheet to Music"
        text.font = .systemFont(ofSize: 24, weight: .semibold)
        text.textColor = .darkGray2

        let stack = UIStackView(arrangedSubviews: [text, icon])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        // ✅ Tap gesture
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(openUploadScreenFromHome)
        )
        container.addGestureRecognizer(tap)
        container.isUserInteractionEnabled = true

        contentView.addArrangedSubview(container)
        return container
    }

    // MARK: - Navigation
    @objc private func openUploadScreenFromHome() {
        guard let tabBarController = self.tabBarController else { return }

        // Switch to Upload tab
        tabBarController.selectedIndex = 1

        if let nav = tabBarController.viewControllers?[1] as? UINavigationController,
           let uploadVC = nav.viewControllers.first as? UploadScreen {

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                uploadVC.startUploadFlow()
            }
        }
    }


}
