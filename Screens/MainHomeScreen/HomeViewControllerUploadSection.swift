//
//  HomeViewControllerUploadSection.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {

    @discardableResult
    func addUploadSection() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1.0)
        container.layer.cornerRadius = 20
        container.layer.shadowColor   = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.06
        container.layer.shadowRadius  = 10
        container.layer.shadowOffset  = CGSize(width: 0, height: 3)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 82).isActive = true

        let iconContainer = UIView()
        iconContainer.backgroundColor = kAppOrange
        iconContainer.layer.cornerRadius = 13
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.widthAnchor.constraint(equalToConstant: 44).isActive = true
        iconContainer.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "arrow.up.square.fill"))
        icon.tintColor = .white; icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24)
        ])

        let titleLabel = UILabel()
        titleLabel.text = "Stuck on a sheet?"
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.10, green: 0.09, blue: 0.07, alpha: 1.0)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Upload it and we'll guide you."
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = UIColor(red: 0.50, green: 0.48, blue: 0.44, alpha: 1.0)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical; textStack.spacing = 3; textStack.alignment = .leading

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = kAppOrange; chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.widthAnchor.constraint(equalToConstant: 14).isActive = true
        chevron.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let mainStack = UIStackView(arrangedSubviews: [iconContainer, textStack, UIView(), chevron])
        mainStack.axis = .horizontal; mainStack.spacing = 12; mainStack.alignment = .center
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            mainStack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(openUploadScreenFromHome))
        container.addGestureRecognizer(tap); container.isUserInteractionEnabled = true

        contentView.addArrangedSubview(container)

        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 28).isActive = true
        contentView.addArrangedSubview(spacer)
        return container
    }

    @objc private func openUploadScreenFromHome() {
        guard let tabBarController = self.tabBarController else { return }
        tabBarController.selectedIndex = 1
        if let nav = tabBarController.viewControllers?[1] as? UINavigationController,
           let uploadVC = nav.viewControllers.first as? UploadScreen {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { uploadVC.startUploadFlow() }
        }
    }
}
