//
//  HomeViewControllerUploadSection.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {

    @discardableResult
    func addUploadSectionView() -> UIView {
        let wrapper = UIView()
        wrapper.clipsToBounds = false
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let cardBgColor = ComponentColors.SongCard.background
        let container = UIView()
        container.backgroundColor = cardBgColor
        container.layer.cornerRadius = 18
        container.layer.masksToBounds = true
        container.layer.borderWidth = 1.0
        container.layer.borderColor = ComponentColors.SongCard.border.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconContainer = UIView()
        iconContainer.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        iconContainer.layer.cornerRadius = 12
        iconContainer.clipsToBounds = true
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "wand.and.stars.inverse") ?? UIImage(systemName: "wand.and.stars"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(icon)

        let titleLabel = UILabel()
        titleLabel.text = "Stuck on a sheet?"
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = ComponentColors.SongCard.titleText

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Upload it and we'll guide you."
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = ComponentColors.SongCard.metadataText

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical; textStack.spacing = 2; textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let illustration = UIImageView(image: UIImage(named: "footer"))
        illustration.contentMode = .scaleAspectFit
        illustration.clipsToBounds = false
        illustration.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconContainer)
        container.addSubview(textStack)
        wrapper.addSubview(container)
        wrapper.addSubview(illustration)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 6),
            container.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -6),
            container.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            container.heightAnchor.constraint(equalToConstant: 80),

            iconContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 48),
            iconContainer.heightAnchor.constraint(equalToConstant: 48),

            icon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: illustration.leadingAnchor, constant: -4),

            illustration.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -4),
            illustration.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -6),
            illustration.widthAnchor.constraint(equalToConstant: 100),
            illustration.heightAnchor.constraint(equalToConstant: 100),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(openUploadScreenFromHome))
        container.addGestureRecognizer(tap); container.isUserInteractionEnabled = true

        return wrapper
    }

    @objc private func openUploadScreenFromHome() {
        executeUploadTransition()
    }

    private func executeUploadTransition() {
        guard let tabBarController = self.tabBarController else { return }
        tabBarController.selectedIndex = 1
        if let nav = tabBarController.viewControllers?[1] as? UINavigationController,
           let uploadVC = nav.viewControllers.first as? UploadScreen {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { uploadVC.startUploadFlow() }
        }
    }
}
