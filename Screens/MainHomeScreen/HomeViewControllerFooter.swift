//
//  HomeViewControllerFooter.swift
//  Re-Hearse_v1
//

import UIKit

extension HomeViewController {

    public func makeBrandFooter() -> UIView {

        let footer = UIView()
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0) // warm cream

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor(red: 0.85, green: 0.82, blue: 0.77, alpha: 0.6)

        func italicFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            if let descriptor = base.fontDescriptor.withSymbolicTraits(.traitItalic) {
                return UIFont(descriptor: descriptor, size: size)
            }
            return base
        }

        let hashtag = UILabel()
        hashtag.text = "#LetsReHearse"
        hashtag.font = italicFont(size: 19, weight: .semibold)
        hashtag.textColor = UIColor(red: 0.13, green: 0.12, blue: 0.10, alpha: 1.0)

        let line1 = UILabel()
        line1.text = "🎹 Built for music learners"
        line1.font = .systemFont(ofSize: 13)
        line1.textColor = UIColor(red: 0.45, green: 0.43, blue: 0.39, alpha: 1.0)

        let line2 = UILabel()
        line2.text = "❤️ Crafted in Chennai"
        line2.font = .systemFont(ofSize: 13)
        line2.textColor = UIColor(red: 0.45, green: 0.43, blue: 0.39, alpha: 1.0)

        let textStack = UIStackView(arrangedSubviews: [hashtag, line1, line2])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.alignment = .leading

        footer.addSubview(divider)
        footer.addSubview(textStack)

        let bottomInset = UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
        footer.heightAnchor.constraint(equalToConstant: 130 + bottomInset).isActive = true

        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: footer.topAnchor),
            divider.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            textStack.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 24),
            textStack.topAnchor.constraint(equalTo: footer.topAnchor, constant: 24),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: footer.bottomAnchor, constant: -24 - bottomInset)
        ])

        return footer
    }
}
