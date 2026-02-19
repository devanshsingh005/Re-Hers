//
//  HomeViewControllerButtons.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {

    func createFilledButton(_ title: String) -> UIButton {
        let button = PillButton()
        // Override the default "Start Practice" text
        let normal: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let hl: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.6)
        ]
        button.setAttributedTitle(NSAttributedString(string: title, attributes: normal), for: .normal)
        button.setAttributedTitle(NSAttributedString(string: title, attributes: hl), for: .highlighted)
        return button
    }

    func createBorderedButton(_ title: String) -> UIButton {
        let button = UIButton()
        button.backgroundColor = UIColor(red: 0.93, green: 0.91, blue: 0.87, alpha: 1.0)
        button.clipsToBounds = true

        let normal: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: UIColor(red: 0.15, green: 0.13, blue: 0.10, alpha: 1.0)
        ]
        let hl: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: UIColor(red: 0.15, green: 0.13, blue: 0.10, alpha: 0.5)
        ]
        button.setAttributedTitle(NSAttributedString(string: title, attributes: normal), for: .normal)
        button.setAttributedTitle(NSAttributedString(string: title, attributes: hl), for: .highlighted)

        // Pill via layout
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}
