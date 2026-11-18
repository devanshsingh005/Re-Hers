//
//  SeasonalDecorations.swift
//  Re-Hearse_v1
//
//  Decorations for the seasonal theme set in the admin dashboard's Theme Studio (see SeasonalTheme).
//  They only add art on top of the normal screens: no colour or layout changes, no touches, nothing
//  for VoiceOver. Each one shows and hides itself when the theme changes, so a screen adds it once.
//  The art is vector (Assets.xcassets/Christmas), so it stays sharp on iPhone and iPad at little size.
//

import UIKit

/// Calls `onChange` now and whenever the seasonal theme changes.
final class SeasonalThemeObserver {
    private var token: NSObjectProtocol?

    init(_ onChange: @escaping (SeasonalTheme) -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: AppThemeManager.seasonalThemeDidChangeNotification, object: nil, queue: .main
        ) { _ in onChange(AppThemeManager.shared.seasonalTheme) }
        onChange(AppThemeManager.shared.seasonalTheme)
    }

    deinit {
        if let token { NotificationCenter.default.removeObserver(token) }
    }
}

private extension UIView {
    func makeDecorative() {
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
    }
}

/// A piece of art that's only on screen while the Christmas theme is on.
final class ChristmasArtView: UIImageView {
    private var observer: SeasonalThemeObserver?

    convenience init(_ name: String, mirrored: Bool = false) {
        self.init(art: UIImage(named: name), mirrored: mirrored)
    }

    init(art: UIImage?, mirrored: Bool = false) {
        super.init(image: art)
        contentMode = .scaleAspectFit
        translatesAutoresizingMaskIntoConstraints = false
        if mirrored { transform = CGAffineTransform(scaleX: -1, y: 1) }
        makeDecorative()
        observer = SeasonalThemeObserver { [weak self] theme in self?.isHidden = theme != .christmas }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Fixed size, scaled up on iPad like the rest of the layout.
    @discardableResult
    func sized(_ width: CGFloat, _ height: CGFloat) -> Self {
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: DeviceLayout.s(width)),
            heightAnchor.constraint(equalToConstant: DeviceLayout.s(height)),
        ])
        return self
    }
}

/// A plain container that's only shown while the Christmas theme is on.
class ChristmasContainerView: UIView {
    private var observer: SeasonalThemeObserver?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        makeDecorative()
        observer = SeasonalThemeObserver { [weak self] theme in
            self?.isHidden = theme != .christmas
            self?.seasonalThemeDidChange(theme)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func seasonalThemeDidChange(_ theme: SeasonalTheme) {}
}

enum ChristmasDecor {
    /// Amber like the app's accent, soft enough to stay in the background.
    static var snowflakeColor: UIColor { BrandColors.brand.withAlphaComponent(0.45) }

    /// The pine branch hanging in at the top-right of a tab's header (Home, Library, Search),
    /// behind the bell. It scrolls away with the header.
    @discardableResult
    static func addHeaderBranch(to header: UIView) -> ChristmasArtView {
        let branch = ChristmasArtView("xmas-pine-branch").sized(146, 58)
        header.insertSubview(branch, at: 0)
        NSLayoutConstraint.activate([
            branch.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            branch.bottomAnchor.constraint(equalTo: header.topAnchor, constant: DeviceLayout.s(24)),
        ])
        return branch
    }

    /// A small snowflake (SF Symbol) at a fraction of `container`'s size.
    static func addSnowflake(to container: UIView, x: CGFloat, y: CGFloat, size: CGFloat) {
        let flake = ChristmasArtView(art: UIImage(systemName: "snowflake"))
        flake.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: DeviceLayout.s(size), weight: .light)
        flake.tintColor = snowflakeColor
        flake.contentMode = .center
        container.insertSubview(flake, at: 0)
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: flake, attribute: .centerX, relatedBy: .equal,
                               toItem: container, attribute: .trailing, multiplier: x, constant: 0),
            NSLayoutConstraint(item: flake, attribute: .centerY, relatedBy: .equal,
                               toItem: container, attribute: .bottom, multiplier: y, constant: 0),
        ])
    }

    /// Holly in the top corners and pine in the bottom-left of a piano player (Play Along, the
    /// piano animation). Placed behind everything else on the screen, so it only shows in the
    /// margins around the toolbar, the sheet music and the keyboard and can never cover them.
    static func installPlayerEdges(in view: UIView) {
        let container = ChristmasContainerView()
        view.insertSubview(container, at: 0)
        let topLeft = ChristmasArtView("xmas-holly-corner").sized(48, 59)
        let topRight = ChristmasArtView("xmas-holly-corner", mirrored: true).sized(48, 59)
        let bottomLeft = ChristmasArtView("xmas-pine-corner").sized(70, 81)
        let bottomRight = ChristmasArtView("xmas-pine-corner", mirrored: true).sized(70, 81)
        [topLeft, topRight, bottomLeft, bottomRight].forEach(container.addSubview)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topLeft.topAnchor.constraint(equalTo: container.topAnchor),
            topLeft.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            topRight.topAnchor.constraint(equalTo: container.topAnchor),
            topRight.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomLeft.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bottomLeft.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottomRight.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bottomRight.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
    }
}

/// Snowy hills, fir trees and a cottage along the bottom of the Home scan card, clipped to its
/// rounded corners. Sits behind the card's text.
final class ChristmasScanCardScene: ChristmasContainerView {
    init(cornerRadius: CGFloat) {
        super.init(frame: .zero)
        clipsToBounds = true
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]

        let scene = ChristmasArtView("xmas-snow-scene")
        scene.contentMode = .scaleToFill
        addSubview(scene)
        NSLayoutConstraint.activate([
            scene.leadingAnchor.constraint(equalTo: leadingAnchor),
            scene.trailingAnchor.constraint(equalTo: trailingAnchor),
            scene.bottomAnchor.constraint(equalTo: bottomAnchor),
            scene.topAnchor.constraint(equalTo: topAnchor),
            // the art's own proportions (360 x 92)
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: 92.0 / 360.0),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}

/// A layer of snow along the top of a playlist tile, with a few drips.
final class SnowCapView: ChristmasContainerView {
    private let snow = CAShapeLayer()
    private let shade = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        shade.fillColor = UIColor(hex: "#C9D4DF").cgColor
        snow.fillColor = UIColor.white.cgColor
        layer.addSublayer(shade)
        layer.addSublayer(snow)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width, h = bounds.height
        guard w > 0, h > 0 else { return }
        // a wavy lower edge, deepest in three drips
        let drips: [(x: CGFloat, depth: CGFloat)] = [(0.16, 1.0), (0.52, 0.8), (0.84, 0.95)]
        let base = h * 0.45
        let path = UIBezierPath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: base))
        var x = w
        for drip in drips.reversed() {
            let cx = drip.x * w, half = w * 0.07
            path.addQuadCurve(to: CGPoint(x: cx + half, y: base + h * 0.05),
                              controlPoint: CGPoint(x: (x + cx + half) / 2, y: base - h * 0.12))
            path.addCurve(to: CGPoint(x: cx - half, y: base + h * 0.05),
                          controlPoint1: CGPoint(x: cx + half * 0.6, y: h * drip.depth),
                          controlPoint2: CGPoint(x: cx - half * 0.6, y: h * drip.depth))
            x = cx - half
        }
        path.addQuadCurve(to: CGPoint(x: 0, y: base), controlPoint: CGPoint(x: x / 2, y: base - h * 0.12))
        path.close()
        snow.path = path.cgPath
        shade.path = path.cgPath
        shade.frame = bounds.offsetBy(dx: 0, dy: 1.5)
        snow.frame = bounds
    }
}

/// Gently falling snow for Home. It only runs while Home is on screen and the Christmas theme is
/// on, and never with Reduce Motion or Low Power Mode. It takes no touches.
final class SnowfallView: UIView {
    private let emitter = CAEmitterLayer()
    private var observer: SeasonalThemeObserver?
    private var isOnScreen = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        makeDecorative()
        emitter.emitterShape = .line
        emitter.emitterMode = .outline
        emitter.renderMode = .unordered
        emitter.birthRate = 0
        layer.addSublayer(emitter)

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(update),
                           name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(update),
                           name: .NSProcessInfoPowerStateDidChange, object: nil)
        observer = SeasonalThemeObserver { [weak self] _ in self?.update() }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.emitter.emitterCells = [self.makeCell()]
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    deinit { NotificationCenter.default.removeObserver(self) }

    /// Home calls this as it appears and disappears.
    func setOnScreen(_ onScreen: Bool) {
        isOnScreen = onScreen
        update()
    }

    var isSnowing: Bool { emitter.birthRate > 0 }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -12)
        emitter.emitterSize = CGSize(width: bounds.width * 1.1, height: 1)
    }

    @objc private func update() {
        let snow = isOnScreen
            && AppThemeManager.shared.seasonalTheme == .christmas
            && !UIAccessibility.isReduceMotionEnabled
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
        isHidden = !snow
        if snow, emitter.birthRate == 0 {
            emitter.emitterCells = [makeCell()]
            emitter.beginTime = CACurrentMediaTime()
            emitter.birthRate = 1
        } else if !snow, emitter.birthRate > 0 {
            emitter.birthRate = 0
            emitter.emitterCells = nil   // clears the flakes already falling
        }
    }

    private func makeCell() -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = Self.flakeImage.cgImage
        // sparse, small and slow: a hint of snow, not a storm
        cell.birthRate = DeviceLayout.isPad ? 3.5 : 2
        cell.lifetime = 26
        cell.velocity = 34
        cell.velocityRange = 10
        cell.yAcceleration = 2
        cell.xAcceleration = 1
        cell.emissionLongitude = .pi
        cell.emissionRange = .pi / 12
        cell.scale = 0.42
        cell.scaleRange = 0.22
        cell.alphaRange = 0.35
        // white on dark; a soft blue-grey on light, where white snow wouldn't show
        let dark = traitCollection.userInterfaceStyle == .dark
        cell.color = (dark ? UIColor.white.withAlphaComponent(0.7)
                           : UIColor(hex: "#9FB1C5").withAlphaComponent(0.8)).cgColor
        return cell
    }

    private static let flakeImage: UIImage = {
        let size = CGSize(width: 12, height: 12)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.55, 1])!
            ctx.cgContext.drawRadialGradient(gradient, startCenter: CGPoint(x: 6, y: 6), startRadius: 0,
                                             endCenter: CGPoint(x: 6, y: 6), endRadius: 6, options: [])
        }
    }()
}
