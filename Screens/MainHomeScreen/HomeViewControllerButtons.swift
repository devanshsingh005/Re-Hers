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
        button.backgroundColor = UIColor(red: 0.93, green: 0.91, blue: 0.87, alpha: 1.0)
        button.clipsToBounds   = true

        let attrs:   [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: UIColor(red: 0.15, green: 0.13, blue: 0.10, alpha: 1.0)]
        let hlAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: UIColor(red: 0.15, green: 0.13, blue: 0.10, alpha: 0.5)]
        button.setAttributedTitle(NSAttributedString(string: title, attributes: attrs),   for: .normal)
        button.setAttributedTitle(NSAttributedString(string: title, attributes: hlAttrs), for: .highlighted)

        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}
