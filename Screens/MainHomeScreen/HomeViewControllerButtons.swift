//
//  HomeViewControllerButtons.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/12/25.
//

import Foundation
//
//  HomeViewController+Buttons.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {
    
     func createFilledButton(_ title: String) -> UIButton {
        let button = UIButton(type: .system)

        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = title
            // Apply colors to match previous appearance
            config.baseBackgroundColor = .secondaryColor // #FFAE3D
            config.baseForegroundColor = .black
            // Corner radius roughly matching previous 12pt
            config.cornerStyle = .medium
            // Font
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 16, weight: .semibold)
                return outgoing
            }

            button.configuration = config

            // Keep appearance consistent on highlight/disabled (no dimming)
            button.configurationUpdateHandler = { btn in
                guard var updated = btn.configuration else { return }
                updated.baseBackgroundColor = .secondaryColor
                updated.baseForegroundColor = .black
                btn.configuration = updated
            }
        } else {
            // Fallback for iOS < 15
            button.setTitle(title, for: .normal)
            button.setTitleColor(.black, for: .normal)
            button.tintColor = .black
            button.backgroundColor = .secondaryColor
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            button.layer.cornerRadius = 12
            button.layer.masksToBounds = true
        }

        return button
    }

     func createBorderedButton(_ title: String) -> UIButton {
        let button = UIButton(type: .system)

        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.bordered()
            config.title = title
            // Match previous light gray background and dark text
            config.baseBackgroundColor = .lightGray // #D9D9D9
            config.baseForegroundColor = .darkGray2
            config.cornerStyle = .medium
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 16, weight: .semibold)
                return outgoing
            }

            button.configuration = config

            // Keep colors consistent on state changes
            button.configurationUpdateHandler = { btn in
                guard var updated = btn.configuration else { return }
                updated.baseBackgroundColor = .lightGray
                updated.baseForegroundColor = .darkGray2
                btn.configuration = updated
            }
        } else {
            // Fallback for iOS < 15
            button.setTitle(title, for: .normal)
            button.backgroundColor = .lightGray
            button.setTitleColor(.darkGray2, for: .normal)
            button.layer.borderWidth = 0
            button.layer.borderColor = nil
            button.layer.cornerRadius = 12
            button.layer.masksToBounds = true
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        }

        return button
    }
}

