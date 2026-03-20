//
//  HomeViewControllerUploadSection.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {

    @discardableResult
    func addUploadSection() -> UIView {
        // Outer wrapper — allows illustration to overflow above the card
        let wrapper = UIView()
        wrapper.clipsToBounds = false
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        // Cream card — compact height
        let container = UIView()
        container.backgroundColor   = ComponentColors.SongCard.background
        container.layer.cornerRadius = 16
        container.layer.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 72).isActive = true

        // Orange icon tile
        let iconContainer = UIView()
        iconContainer.backgroundColor   = ComponentColors.HomeScreen.actionButtonFill
        iconContainer.layer.cornerRadius = 11
        iconContainer.layer.masksToBounds = true
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.widthAnchor.constraint(equalToConstant: 40).isActive = true
        iconContainer.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "square.and.arrow.up"))
        icon.tintColor     = .white
        icon.contentMode   = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
        ])

        // Text
        let titleLabel = UILabel()
        titleLabel.text      = "Stuck on a sheet?"
        titleLabel.font      = .systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor = ComponentColors.SongCard.titleText

        let subtitleLabel = UILabel()
        subtitleLabel.text      = "Upload it and we'll guide you."
        subtitleLabel.font      = .systemFont(ofSize: 11)
        subtitleLabel.textColor = ComponentColors.SongCard.metadataText

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical; textStack.spacing = 2; textStack.alignment = .leading

        let leftStack = UIStackView(arrangedSubviews: [iconContainer, textStack])
        leftStack.axis = .horizontal; leftStack.spacing = 10; leftStack.alignment = .center
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        // UploadBtn illustration — overflows top of card
        let illustration = UIImageView(image: UIImage(named: "UploadBtn"))
        illustration.contentMode = .scaleAspectFit
        illustration.clipsToBounds = false
        illustration.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(leftStack)
        wrapper.addSubview(container)
        wrapper.addSubview(illustration)

        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            leftStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            leftStack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -120),

            // Card at bottom of wrapper
            container.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),

            // Illustration: flush right, bottom aligned to card bottom + 4 overshoot, overflows top
            illustration.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: 4),
            illustration.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 4),
            illustration.widthAnchor.constraint(equalToConstant: 100),
            illustration.heightAnchor.constraint(equalToConstant: 110),

            // Wrapper height = illustration height (tallest element)
            wrapper.heightAnchor.constraint(equalToConstant: 110),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(openUploadScreenFromHome))
        container.addGestureRecognizer(tap); container.isUserInteractionEnabled = true

        contentView.addArrangedSubview(wrapper)

        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
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
