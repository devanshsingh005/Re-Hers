//
//  HomeViewControllerButtons.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {

    func createFilledButton(_ title: String) -> UIButton {
        let button = PillButton()
        let attrs:   [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: UIColor.white]
        let hlAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: UIColor.white.withAlphaComponent(0.6)]
        button.setAttributedTitle(NSAttributedString(string: title, attributes: attrs),   for: .normal)
        button.setAttributedTitle(NSAttributedString(string: title, attributes: hlAttrs), for: .highlighted)
        return button
    }

    func createBorderedButton(_ title: String) -> UIButton {
        let button = UIButton()
        button.backgroundColor = ComponentColors.SecondaryButton.fill
        button.clipsToBounds   = true

        let attrs:   [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: ComponentColors.SongCard.titleText]
        let hlAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: ComponentColors.SongCard.titleText.withAlphaComponent(0.5)]
        button.setAttributedTitle(NSAttributedString(string: title, attributes: attrs),   for: .normal)
        button.setAttributedTitle(NSAttributedString(string: title, attributes: hlAttrs), for: .highlighted)

        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}
