//
//  PadCardPairCell.swift
//  Re-Hearse_v1
//
//  iPad: two list items side by side in a table row, each a rounded card (icon, title,
//  subtitle, chevron), as the Library shows its songs. Used where a phone list would stretch
//  across the iPad's width.
//

import UIKit

final class PadCardPairCell: UITableViewCell {
    static let reuseID = "PadCardPairCell"
    /// Called with 0 (left card) or 1 (right card).
    var onTap: ((Int) -> Void)?

    private let cards = [Card(), Card()]

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        backgroundConfiguration = .clear()
        selectionStyle = .none
        let pair = UIStackView(arrangedSubviews: cards)
        pair.axis = .horizontal
        pair.spacing = 16
        pair.distribution = .fillEqually
        pair.alignment = .fill
        pair.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pair)
        NSLayoutConstraint.activate([
            pair.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            pair.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            pair.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            pair.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
        ])
        for (i, card) in cards.enumerated() {
            card.addAction(UIAction { [weak self] _ in self?.onTap?(i) }, for: .touchUpInside)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// `right` is nil for the last row of an odd number of items. `menus` (long press, in place
    /// of a phone list's swipe actions), `dots` (an unread mark instead of the chevron) and
    /// `heights` are per card.
    func configure(left: UIListContentConfiguration, right: UIListContentConfiguration?,
                   menus: [UIMenu?] = [nil, nil], dots: [UIColor?] = [nil, nil]) {
        cards[0].set(left, menu: menus[0], dot: dots[0])
        cards[1].alpha = right == nil ? 0 : 1
        cards[1].isUserInteractionEnabled = right != nil
        if let right { cards[1].set(right, menu: menus[1], dot: dots[1]) }
    }

    /// One item: the list content in a rounded card with a chevron; dims while pressed.
    final class Card: UIControl {
        private let content = UIListContentView(configuration: .subtitleCell())
        private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        private let dotView = UIView()
        private var menu: UIMenu?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = ComponentColors.HomeScreen.cardBackground
            layer.cornerRadius = 18
            layer.cornerCurve = .continuous
            isAccessibilityElement = true
            accessibilityTraits = .button
            content.isUserInteractionEnabled = false
            content.translatesAutoresizingMaskIntoConstraints = false
            chevron.tintColor = .tertiaryLabel
            chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            chevron.translatesAutoresizingMaskIntoConstraints = false
            chevron.setContentHuggingPriority(.required, for: .horizontal)
            dotView.layer.cornerRadius = 5
            dotView.translatesAutoresizingMaskIntoConstraints = false
            dotView.isHidden = true
            addSubview(content)
            addSubview(chevron)
            addSubview(dotView)
            isContextMenuInteractionEnabled = true
            NSLayoutConstraint.activate([
                content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
                content.topAnchor.constraint(equalTo: topAnchor, constant: 4),
                content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
                content.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
                chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
                chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
                dotView.centerXAnchor.constraint(equalTo: chevron.centerXAnchor),
                dotView.centerYAnchor.constraint(equalTo: centerYAnchor),
                dotView.widthAnchor.constraint(equalToConstant: 10),
                dotView.heightAnchor.constraint(equalToConstant: 10),
            ])
        }

        override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                    configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
            guard let menu, isUserInteractionEnabled else { return nil }
            return UIContextMenuConfiguration(actionProvider: { _ in menu })
        }

        required init?(coder: NSCoder) { fatalError() }

        func set(_ configuration: UIListContentConfiguration, menu: UIMenu? = nil, dot: UIColor? = nil) {
            content.configuration = configuration
            self.menu = menu
            dotView.backgroundColor = dot
            dotView.isHidden = dot == nil
            chevron.isHidden = dot != nil
            accessibilityValue = dot == nil ? nil : "Unread"
            accessibilityLabel = [configuration.text, configuration.secondaryText].compactMap { $0 }.joined(separator: ", ")
        }

        override var isHighlighted: Bool {
            didSet { UIView.animate(withDuration: 0.15) { self.alpha = self.isHighlighted ? 0.6 : 1 } }
        }
    }
}
