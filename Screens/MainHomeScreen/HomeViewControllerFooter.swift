
import Foundation
//
//  HomeViewController+DailyGoal.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {
    
    // MARK: - Daily Goal
  public  func makeBrandFooter() -> UIView {
        let footer = UIView()
        footer.backgroundColor = .systemBackground
        footer.translatesAutoresizingMaskIntoConstraints = false

        let bgImage = UIImageView()
        bgImage.image = UIImage(named: "footer_illustration")
        bgImage.contentMode = .scaleAspectFill
        bgImage.alpha = 0.12
        bgImage.translatesAutoresizingMaskIntoConstraints = false

        let hashtag = UILabel()
        hashtag.text = "#LetsReHearse"
        hashtag.font = .systemFont(ofSize: 22, weight: .bold)
        hashtag.textColor = .secondaryLabel

        let line1 = UILabel()
        line1.text = "🎹 Built for music learners"
        line1.font = .systemFont(ofSize: 13)
        line1.textColor = .secondaryLabel

        let line2 = UILabel()
        line2.text = "❤️ Crafted in Chennai"
        line2.font = .systemFont(ofSize: 13)
        line2.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [hashtag, line1, line2])
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        footer.addSubview(bgImage)
        footer.addSubview(textStack)

        NSLayoutConstraint.activate([
            footer.heightAnchor.constraint(equalToConstant: 120),

            bgImage.topAnchor.constraint(equalTo: footer.topAnchor),
            bgImage.bottomAnchor.constraint(equalTo: footer.bottomAnchor),
            bgImage.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            bgImage.trailingAnchor.constraint(equalTo: footer.trailingAnchor),

            textStack.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 20),
            textStack.centerYAnchor.constraint(equalTo: footer.centerYAnchor)
        ])

        return footer
    }

}

