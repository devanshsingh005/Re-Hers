import UIKit

extension HomeViewController {

    public func makeBrandFooter() -> UIView {

        // MARK: Container (full-width section)
        let footer = UIView()
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.backgroundColor = .secondarySystemBackground

        // Height (website footer is taller)
       

        // MARK: Top Divider (important for website feel)
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor.separator.withAlphaComponent(0.4)

        // MARK: Background Image (very subtle)
        let bgImage = UIImageView()
        bgImage.translatesAutoresizingMaskIntoConstraints = false
        bgImage.image = UIImage(named: "Image_1")
        bgImage.contentMode = .scaleAspectFill
        bgImage.alpha = 0.08
        bgImage.clipsToBounds = true

        // MARK: Overlay for readability
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.6)

        // MARK: Font Helper
        func italicFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            let descriptor = base.fontDescriptor.withSymbolicTraits(.traitItalic)!
            return UIFont(descriptor: descriptor, size: size)
        }

        // MARK: Text
        let hashtag = UILabel()
        hashtag.text = "#LetsReHearse"
        hashtag.font = italicFont(size: 20, weight: .semibold)
        hashtag.textColor = .label

        let line1 = UILabel()
        line1.text = "🎹 Built for music learners"
        line1.font = .systemFont(ofSize: 13)
        line1.textColor = .secondaryLabel

        let line2 = UILabel()
        line2.text = "❤️ Crafted in Chennai"
        line2.font = .systemFont(ofSize: 13)
        line2.textColor = .secondaryLabel

        // MARK: Stack (top-aligned = website style)
        let textStack = UIStackView(arrangedSubviews: [hashtag, line1, line2])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.alignment = .leading

        // MARK: Hierarchy
        footer.addSubview(bgImage)
        footer.addSubview(overlay)
        footer.addSubview(divider)
        footer.addSubview(textStack)

        // MARK: Constraints
        let bottomInset = UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0

        footer.heightAnchor.constraint(equalToConstant: 140 + bottomInset).isActive = true

        NSLayoutConstraint.activate([
            // Background image
            bgImage.topAnchor.constraint(equalTo: footer.topAnchor),
            bgImage.bottomAnchor.constraint(equalTo: footer.bottomAnchor),
            bgImage.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            bgImage.trailingAnchor.constraint(equalTo: footer.trailingAnchor),

            // Overlay
            overlay.topAnchor.constraint(equalTo: footer.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: footer.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: footer.trailingAnchor),

            // Divider
            divider.topAnchor.constraint(equalTo: footer.topAnchor),
            divider.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            // Text (safe-area aware)
            textStack.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 24),
            textStack.topAnchor.constraint(equalTo: footer.topAnchor, constant: 24),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: footer.bottomAnchor,
                                              constant: -24 - bottomInset)
        ])


        return footer
    }
}
