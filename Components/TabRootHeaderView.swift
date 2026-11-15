//
//  TabRootHeaderView.swift
//  Re-Hearse_v1
//
//  The header every tab root uses (Home, Library, Settings, Search, Practice): a big title and
//  subtitle on the left and one round glass button on the same row. It scrolls with the page;
//  NavigationBarHelper fades the small title into the bar once it has gone.
//

import UIKit

final class TabRootHeaderView: UIView {
    static let height: CGFloat = 80
    /// Where the header sits below the top of the screen (status bar plus bar height).
    static let topOffset: CGFloat = 96

    let titleLabel = UILabel()
    let subtitleLabel = UILabel()

    init(title: String, subtitle: String, accessory: UIView? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 34, weight: .heavy)
        titleLabel.textColor = ComponentColors.NavBar.title
        titleLabel.accessibilityTraits = .header

        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = ComponentColors.NavBar.title.withAlphaComponent(0.6)

        let labelStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labelStack.axis = .vertical
        labelStack.spacing = -2
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            labelStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            labelStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        if let accessory {
            accessory.translatesAutoresizingMaskIntoConstraints = false
            addSubview(accessory)
            NSLayoutConstraint.activate([
                accessory.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
                accessory.centerYAnchor.constraint(equalTo: centerYAnchor),
                accessory.widthAnchor.constraint(equalToConstant: 44),
                accessory.heightAnchor.constraint(equalToConstant: 44),
                labelStack.trailingAnchor.constraint(lessThanOrEqualTo: accessory.leadingAnchor, constant: -12),
            ])
        } else {
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20).isActive = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// A round glass button for the header's right side, e.g. a ••• menu.
    static func glassButton(systemName: String, accessibilityLabel: String) -> UIButton {
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .glass()
        } else {
            config = .gray()
            config.cornerStyle = .capsule
        }
        config.image = UIImage(systemName: systemName)
        config.baseForegroundColor = .label
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .body)
        let button = UIButton(configuration: config)
        button.accessibilityLabel = accessibilityLabel
        return button
    }
}
