//
//  HomeComponents.swift
//  Re-Hearse_v1
//
//  Views for the Home screen: the scan card, playlist tiles and upload rows.
//

import UIKit

/// "Turn your sheet into music": a viewfinder-style card with orange corner brackets.
final class ScanCardView: UIControl {
    private let bracketLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = HomeViewController.cardColor
        layer.cornerRadius = 28
        layer.cornerCurve = .continuous

        bracketLayer.strokeColor = BrandColors.brand.cgColor
        bracketLayer.fillColor = UIColor.clear.cgColor
        bracketLayer.lineWidth = 3
        bracketLayer.lineCap = .round
        bracketLayer.lineJoin = .round
        layer.addSublayer(bracketLayer)

        let icon = UIImageView(image: UIImage(systemName: "music.note"))
        icon.tintColor = BrandColors.brand
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 46, weight: .regular)
        icon.contentMode = .center

        let title = UILabel()
        title.text = "Turn your sheet into music"
        title.font = UIFont.preferredFont(forTextStyle: .title3).withWeight(.semibold)
        title.adjustsFontForContentSizeCategory = true
        title.textColor = .label
        title.textAlignment = .center
        title.numberOfLines = 0

        let subtitle = UILabel()
        subtitle.text = "Scan one page to hear it\nand start playing."
        subtitle.font = .preferredFont(forTextStyle: .subheadline)
        subtitle.adjustsFontForContentSizeCategory = true
        subtitle.textColor = .secondaryLabel
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, title, subtitle])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.setCustomSpacing(14, after: icon)
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let height = heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.86)
        height.priority = .defaultHigh
        NSLayoutConstraint.activate([
            height,
            // a phone-sized cap; iPad Home sets the card's height itself
            heightAnchor.constraint(lessThanOrEqualToConstant: DeviceLayout.isPad ? 900 : 380),
            heightAnchor.constraint(greaterThanOrEqualTo: stack.heightAnchor, constant: 80),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
        ])

        addChristmasDecorations()

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "Scan sheet music"
        accessibilityHint = "Scan one page to hear it and start playing."

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
                self.bracketLayer.strokeColor = BrandColors.brand.resolvedColor(with: self.traitCollection).cgColor
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Christmas theme: a snowy scene along the bottom (behind the text), a few snowflakes and a
    /// Santa hat on the top-right corner. All hidden with the default theme.
    private func addChristmasDecorations() {
        let scene = ChristmasScanCardScene(cornerRadius: layer.cornerRadius)
        insertSubview(scene, at: 0)
        NSLayoutConstraint.activate([
            scene.leadingAnchor.constraint(equalTo: leadingAnchor),
            scene.trailingAnchor.constraint(equalTo: trailingAnchor),
            scene.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        ChristmasDecor.addSnowflake(to: self, x: 0.2, y: 0.22, size: 18)
        ChristmasDecor.addSnowflake(to: self, x: 0.8, y: 0.3, size: 13)
        ChristmasDecor.addSnowflake(to: self, x: 0.12, y: 0.45, size: 11)
        layer.addSublayer(bracketLayer)   // the corner brackets stay above the scene

        let hat = ChristmasArtView("xmas-santa-hat").sized(76, 60)
        addSubview(hat)
        NSLayoutConstraint.activate([
            hat.trailingAnchor.constraint(equalTo: trailingAnchor, constant: DeviceLayout.s(12)),
            hat.topAnchor.constraint(equalTo: topAnchor, constant: DeviceLayout.s(-24)),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 16, arm: CGFloat = 26, radius: CGFloat = 10
        let r = bounds.insetBy(dx: inset, dy: inset)
        let path = UIBezierPath()
        // Each corner: an arm along one edge, a rounded turn, an arm along the other.
        /// The point `radius` along the line from `turn` towards `toward`.
        func near(_ turn: CGPoint, toward: CGPoint) -> CGPoint {
            let dx: CGFloat = (toward.x - turn.x).sign == .minus ? -radius : (toward.x == turn.x ? 0 : radius)
            let dy: CGFloat = (toward.y - turn.y).sign == .minus ? -radius : (toward.y == turn.y ? 0 : radius)
            return CGPoint(x: turn.x + dx, y: turn.y + dy)
        }
        func corner(_ start: CGPoint, _ turn: CGPoint, _ end: CGPoint) {
            path.move(to: start)
            path.addLine(to: near(turn, toward: start))
            path.addQuadCurve(to: near(turn, toward: end), controlPoint: turn)
            path.addLine(to: end)
        }
        corner(CGPoint(x: r.minX, y: r.minY + arm), CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.minX + arm, y: r.minY))
        corner(CGPoint(x: r.maxX - arm, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.minY + arm))
        corner(CGPoint(x: r.maxX, y: r.maxY - arm), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.maxX - arm, y: r.maxY))
        corner(CGPoint(x: r.minX + arm, y: r.maxY), CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY - arm))
        bracketLayer.frame = bounds
        bracketLayer.path = path.cgPath
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: isHighlighted ? 0.12 : 0.25, delay: 0,
                           usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            }
        }
    }
}

/// A square gradient tile with a glyph and a caption, like an album in Apple Music.
final class PlaylistTileView: UIControl {
    private let gradient = CAGradientLayer()
    private let art = UIView()
    /// Christmas theme: snow along the top of the artwork.
    private let snowCap = SnowCapView()

    init(title: String, colors: [UIColor], symbolName: String, size: CGFloat) {
        super.init(frame: .zero)
        art.translatesAutoresizingMaskIntoConstraints = false
        art.layer.cornerRadius = 14
        art.layer.cornerCurve = .continuous
        art.clipsToBounds = true
        art.isUserInteractionEnabled = false
        gradient.colors = colors.map(\.cgColor)
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        art.layer.addSublayer(gradient)

        let glyph = UIImageView(image: UIImage(systemName: symbolName))
        glyph.tintColor = symbolName == "plus" ? .secondaryLabel : UIColor.white.withAlphaComponent(0.9)
        glyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34, weight: .light)
        glyph.translatesAutoresizingMaskIntoConstraints = false
        art.addSubview(glyph)

        let caption = UILabel()
        caption.text = title
        caption.font = UIFont.preferredFont(forTextStyle: .footnote).withWeight(.medium)
        caption.adjustsFontForContentSizeCategory = true
        caption.textColor = .label
        caption.lineBreakMode = .byTruncatingTail
        caption.translatesAutoresizingMaskIntoConstraints = false

        art.addSubview(snowCap)
        addSubview(art)
        addSubview(caption)
        NSLayoutConstraint.activate([
            snowCap.topAnchor.constraint(equalTo: art.topAnchor),
            snowCap.leadingAnchor.constraint(equalTo: art.leadingAnchor),
            snowCap.trailingAnchor.constraint(equalTo: art.trailingAnchor),
            snowCap.heightAnchor.constraint(equalToConstant: min(size * 0.16, 20).rounded()),
            widthAnchor.constraint(equalToConstant: size),
            art.topAnchor.constraint(equalTo: topAnchor),
            art.leadingAnchor.constraint(equalTo: leadingAnchor),
            art.trailingAnchor.constraint(equalTo: trailingAnchor),
            art.heightAnchor.constraint(equalToConstant: size),
            glyph.centerXAnchor.constraint(equalTo: art.centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: art.centerYAnchor),
            caption.topAnchor.constraint(equalTo: art.bottomAnchor, constant: 6),
            caption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            caption.trailingAnchor.constraint(equalTo: trailingAnchor),
            caption.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = title
    }

    /// A playlist's generated cover (the same art its own page shows).
    convenience init(title: String, playlistId: UUID, coverUrl: String?, size: CGFloat) {
        self.init(title: title, colors: [.clear, .clear], symbolName: "", size: size)
        let cover = UIImageView()
        cover.contentMode = .scaleAspectFill
        cover.clipsToBounds = true
        cover.translatesAutoresizingMaskIntoConstraints = false
        art.addSubview(cover)
        NSLayoutConstraint.activate([
            cover.topAnchor.constraint(equalTo: art.topAnchor),
            cover.bottomAnchor.constraint(equalTo: art.bottomAnchor),
            cover.leadingAnchor.constraint(equalTo: art.leadingAnchor),
            cover.trailingAnchor.constraint(equalTo: art.trailingAnchor),
        ])
        art.bringSubviewToFront(snowCap)
        loadPlaylistCoverImage(into: cover, playlistId: playlistId, coverUrl: coverUrl)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = art.bounds
    }

    override var isHighlighted: Bool {
        didSet { art.alpha = isHighlighted ? 0.7 : 1 }
    }
}

/// An upload in the Recent Uploads list: icon, name, "PDF · date · size" and a ••• menu.
final class UploadRowView: UIControl {
    let titleLabel = UILabel()
    let moreButton = UIButton(type: .system)
    private let metaLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = HomeViewController.cardColor
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous

        let iconWrap = UIView()
        iconWrap.backgroundColor = BrandColors.brand.withAlphaComponent(0.16)
        iconWrap.layer.cornerRadius = 10
        iconWrap.layer.cornerCurve = .continuous
        iconWrap.isUserInteractionEnabled = false
        iconWrap.translatesAutoresizingMaskIntoConstraints = false
        let icon = UIImageView(image: UIImage(systemName: "doc.text"))
        icon.tintColor = BrandColors.brand
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: DeviceLayout.value(phone: 18, pad: 22), weight: .medium)
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconWrap.addSubview(icon)

        // iPad: a larger row (title, meta, icon) to match the bigger screen
        titleLabel.font = .preferredFont(forTextStyle: DeviceLayout.isPad ? .body : .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.lineBreakMode = .byTruncatingTail

        metaLabel.font = .preferredFont(forTextStyle: DeviceLayout.isPad ? .footnote : .caption1)
        metaLabel.adjustsFontForContentSizeCategory = true
        metaLabel.textColor = .secondaryLabel
        metaLabel.numberOfLines = 1

        let textStack = UIStackView(arrangedSubviews: [titleLabel, metaLabel])
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.isUserInteractionEnabled = false
        textStack.translatesAutoresizingMaskIntoConstraints = false

        moreButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        moreButton.tintColor = .secondaryLabel
        moreButton.showsMenuAsPrimaryAction = true
        moreButton.accessibilityLabel = "More"
        moreButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconWrap)
        addSubview(textStack)
        addSubview(moreButton)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: DeviceLayout.value(phone: 62, pad: 78)),
            iconWrap.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DeviceLayout.value(phone: 12, pad: 16)),
            iconWrap.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconWrap.widthAnchor.constraint(equalToConstant: DeviceLayout.value(phone: 38, pad: 48)),
            iconWrap.heightAnchor.constraint(equalToConstant: DeviceLayout.value(phone: 38, pad: 48)),
            icon.centerXAnchor.constraint(equalTo: iconWrap.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconWrap.centerYAnchor),
            textStack.leadingAnchor.constraint(equalTo: iconWrap.trailingAnchor, constant: DeviceLayout.value(phone: 12, pad: 16)),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 10),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -4),
            moreButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            moreButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            moreButton.widthAnchor.constraint(equalToConstant: 44),
            moreButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, meta: String, failed: Bool) {
        titleLabel.text = title
        let text = NSMutableAttributedString(string: "PDF", attributes: [
            .font: UIFont.preferredFont(forTextStyle: .caption2).withWeight(.bold),
            .foregroundColor: BrandColors.brand,
        ])
        text.append(NSAttributedString(string: "  " + meta, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: failed ? UIColor.systemRed : UIColor.secondaryLabel,
        ]))
        metaLabel.attributedText = text
        accessibilityLabel = "\(title), PDF, \(meta)"
    }

    override var isAccessibilityElement: Bool {
        get { true }
        set {}
    }

    override var accessibilityTraits: UIAccessibilityTraits {
        get { .button }
        set {}
    }

    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            moreButton.menu?.children.compactMap { $0 as? UIAction }.map { action in
                UIAccessibilityCustomAction(name: action.title) { [weak self] _ in
                    guard let self else { return false }
                    action.performWithSender(self.moreButton, target: nil)
                    return true
                }
            }
        }
        set {}
    }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? .tertiarySystemFill : HomeViewController.cardColor }
    }
}

/// The round bell in the tab headers (Home, Library): opens Notifications and shows the
/// unread count.
final class NotificationBellButton: UIButton {
    /// Red unread count on the bell's corner, like an app icon badge.
    private let badgeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = .glass()
        } else {
            config = .gray()
            config.cornerStyle = .capsule
        }
        config.baseForegroundColor = .label
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .body)
        configuration = config
        accessibilityLabel = "Notifications"
        configuration?.image = UIImage(systemName: "bell")

        badgeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        badgeLabel.textColor = .white
        badgeLabel.textAlignment = .center
        badgeLabel.backgroundColor = .systemRed
        badgeLabel.layer.cornerRadius = 9
        badgeLabel.layer.cornerCurve = .continuous
        badgeLabel.clipsToBounds = true
        badgeLabel.isUserInteractionEnabled = false
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            badgeLabel.heightAnchor.constraint(equalToConstant: 18),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            badgeLabel.centerXAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            badgeLabel.centerYAnchor.constraint(equalTo: topAnchor, constant: 6),
        ])
        updateBadge()
        NotificationCenter.default.addObserver(self, selector: #selector(storeChanged),
                                               name: InAppNotificationStore.didChangeNotification, object: nil)
        addAction(UIAction { [weak self] _ in
            guard let nav = self?.findViewController()?.navigationController else { return }
            nav.pushViewController(NotificationsViewController(), animated: true)
        }, for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func storeChanged() {
        updateBadge()
    }

    private func updateBadge() {
        let unread = InAppNotificationStore.shared.unreadCount
        badgeLabel.isHidden = unread == 0
        badgeLabel.text = unread > 99 ? "99+" : " \(unread) "
        accessibilityValue = unread > 0 ? "\(unread) unread" : nil
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }
}
