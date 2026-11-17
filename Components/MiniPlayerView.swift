//
//  MiniPlayerView.swift
//  Re-Hearse_v1
//
//  The last-played sheet, shown like Apple Music's mini player: on iOS 26 it is the tab bar's
//  bottom accessory, so it sits above the tab bar and folds in beside it when the tab bar
//  minimizes on scroll. Tapping it opens the sheet; the play button jumps straight back into
//  Play Along or Animation.
//

import UIKit

final class MiniPlayerView: UIView {
    var onOpen: (() -> Void)?
    var onResume: (() -> Void)?

    private let artworkView = UIView()
    private let artworkGradient = CAGradientLayer()
    private let artworkIcon = UIImageView(image: UIImage(systemName: "music.note"))
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private var artworkSize: NSLayoutConstraint?

    /// iPad: a taller bar with bigger artwork, text and play button.
    var isLarge = false {
        didSet {
            guard isLarge != oldValue else { return }
            titleLabel.font = UIFont.preferredFont(forTextStyle: isLarge ? .headline : .subheadline).withWeight(.semibold)
            detailLabel.font = UIFont.preferredFont(forTextStyle: isLarge ? .subheadline : .caption1)
            playButton.configuration?.preferredSymbolConfigurationForImage =
                UIImage.SymbolConfiguration(textStyle: isLarge ? .title2 : .title3)
            artworkIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: isLarge ? 20 : 15,
                                                                                  weight: .semibold)
            applyEnvironment()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with item: LastPlayedItem) {
        titleLabel.text = item.title
        detailLabel.text = item.detail
        let palette = MiniPlayerView.palette(for: item.title)
        artworkGradient.colors = palette.map(\.cgColor)
        playButton.accessibilityLabel = "Resume \(item.mode.title)"
        accessibilityLabel = "\(item.title), \(item.detail)"
        accessibilityHint = "Opens the sheet"
    }

    /// Two gradient stops picked from the title, so a sheet keeps its colour.
    static func palette(for title: String) -> [UIColor] {
        let palettes: [[UIColor]] = [
            [UIColor(red: 0.71, green: 0.87, blue: 0.75, alpha: 1), UIColor(red: 0.30, green: 0.60, blue: 0.56, alpha: 1)],
            [UIColor(red: 0.94, green: 0.77, blue: 0.60, alpha: 1), UIColor(red: 0.85, green: 0.47, blue: 0.43, alpha: 1)],
            [UIColor(red: 0.70, green: 0.76, blue: 0.95, alpha: 1), UIColor(red: 0.38, green: 0.42, blue: 0.80, alpha: 1)],
            [UIColor(red: 0.98, green: 0.80, blue: 0.45, alpha: 1), UIColor(red: 0.94, green: 0.52, blue: 0.20, alpha: 1)],
            [UIColor(red: 0.85, green: 0.72, blue: 0.93, alpha: 1), UIColor(red: 0.55, green: 0.38, blue: 0.75, alpha: 1)],
        ]
        let hash = title.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
        return palettes[hash % palettes.count]
    }

    private func build() {
        isAccessibilityElement = false

        artworkView.translatesAutoresizingMaskIntoConstraints = false
        artworkView.layer.cornerRadius = 8
        artworkView.layer.cornerCurve = .continuous
        artworkView.clipsToBounds = true
        artworkGradient.startPoint = CGPoint(x: 0, y: 0)
        artworkGradient.endPoint = CGPoint(x: 1, y: 1)
        artworkView.layer.addSublayer(artworkGradient)
        artworkIcon.tintColor = .white
        artworkIcon.contentMode = .scaleAspectFit
        artworkIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        artworkIcon.translatesAutoresizingMaskIntoConstraints = false
        artworkView.addSubview(artworkIcon)

        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline).withWeight(.semibold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.lineBreakMode = .byTruncatingTail
        detailLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        detailLabel.lineBreakMode = .byTruncatingTail

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.isUserInteractionEnabled = false
        // Text shrinks before the artwork and button do.
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "play.fill")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .title3)
        config.baseForegroundColor = .label
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        playButton.configuration = config
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.addAction(UIAction { [weak self] _ in self?.onResume?() }, for: .touchUpInside)
        playButton.setContentHuggingPriority(.required, for: .horizontal)

        // One accessible element for the bar, one for the play button.
        let openTarget = UIControl()
        openTarget.translatesAutoresizingMaskIntoConstraints = false
        openTarget.isAccessibilityElement = true
        openTarget.accessibilityTraits = .button
        openTarget.addAction(UIAction { [weak self] _ in self?.onOpen?() }, for: .touchUpInside)
        openTarget.addAction(UIAction { [weak self] _ in
            UIView.animate(withDuration: 0.12) { self?.textStackAndArtworkAlpha(0.55) }
        }, for: .touchDown)
        openTarget.addAction(UIAction { [weak self] _ in
            UIView.animate(withDuration: 0.2) { self?.textStackAndArtworkAlpha(1) }
        }, for: [.touchUpInside, .touchUpOutside, .touchCancel])
        self.openTarget = openTarget

        addSubview(artworkView)
        addSubview(textStack)
        addSubview(openTarget)
        addSubview(playButton)

        let size = artworkView.widthAnchor.constraint(equalToConstant: 32)
        artworkSize = size
        NSLayoutConstraint.activate([
            artworkView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            artworkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            size,
            artworkView.heightAnchor.constraint(equalTo: artworkView.widthAnchor),
            artworkIcon.centerXAnchor.constraint(equalTo: artworkView.centerXAnchor),
            artworkIcon.centerYAnchor.constraint(equalTo: artworkView.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 10),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -6),

            playButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            openTarget.leadingAnchor.constraint(equalTo: leadingAnchor),
            openTarget.topAnchor.constraint(equalTo: topAnchor),
            openTarget.bottomAnchor.constraint(equalTo: bottomAnchor),
            openTarget.trailingAnchor.constraint(equalTo: playButton.leadingAnchor),
        ])

        if #available(iOS 26.0, *) {
            registerForTraitChanges([UITraitTabAccessoryEnvironment.self]) { (self: Self, _) in
                self.applyEnvironment()
            }
        }
        applyEnvironment()
    }

    private weak var openTarget: UIControl?

    private func textStackAndArtworkAlpha(_ alpha: CGFloat) {
        artworkView.alpha = alpha
        titleLabel.alpha = alpha
        detailLabel.alpha = alpha
    }

    /// Inline (folded in beside the minimized tab bar) shows just the artwork, title and button.
    private func applyEnvironment() {
        var inline = false
        if #available(iOS 26.0, *) {
            inline = traitCollection.tabAccessoryEnvironment == .inline
        }
        detailLabel.isHidden = inline
        artworkSize?.constant = inline ? 26 : (isLarge ? 48 : 32)
        openTarget?.accessibilityLabel = accessibilityLabel
    }

    override var accessibilityLabel: String? {
        didSet { openTarget?.accessibilityLabel = accessibilityLabel }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        artworkGradient.frame = artworkView.bounds
        CATransaction.commit()
    }
}

extension UIFont {
    /// The same Dynamic Type font at another weight.
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: 0)
    }
}
