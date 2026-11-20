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

    /// Keeps the art inside the window's edges when constraints of lower priority push it out
    /// (art hanging off a button that sits near the screen's edge, as on iPad).
    var staysOnScreen = false
    private var screenConstraints: [NSLayoutConstraint] = []

    override func didMoveToWindow() {
        super.didMoveToWindow()
        NSLayoutConstraint.deactivate(screenConstraints)
        screenConstraints = []
        guard staysOnScreen, let window else { return }
        screenConstraints = [
            leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor),
            trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor),
            topAnchor.constraint(greaterThanOrEqualTo: window.topAnchor),
        ]
        NSLayoutConstraint.activate(screenConstraints)
    }

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
    /// Soft white on the red scan card, enough to stay in the background.
    static var snowflakeColor: UIColor { UIColor.white.withAlphaComponent(0.4) }

    /// Christmas red of the Home upload section (Figma "Christmas theme"): the Scan to Play button.
    static let red = UIColor(hex: "#C8302C")
    /// The scan card's red, dark at the top and warmer at the bottom.
    static let cardRedTop = UIColor(hex: "#4A1513")
    static let cardRedBottom = UIColor(hex: "#8C2622")
    /// Gold for the scan card's brackets and note, and the Upload Music Sheet link.
    static let gold = UIColor(hex: "#E3B663")

    /// `normal`, or `christmas` while the Christmas theme is on. UIKit redraws it by itself when
    /// the theme changes (it reads `SeasonalThemeTrait`).
    static func color(_ normal: UIColor, christmas: UIColor) -> UIColor {
        UIColor { traits in
            (traits.seasonalTheme == .christmas ? christmas : normal).resolvedColor(with: traits)
        }
    }

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

    /// Holly hanging from the outer corners of a piano player's top bar (Play Along, the piano
    /// animation): on the back button and on the buttons at the right end, drawn over them. The
    /// sheet music and the keyboard fill the rest of the screen (on iPad edge to edge), so the bar
    /// is the one place the art shows without covering notes or keys. Call after laying out `bar`.
    static func installPlayerBar(leading: UIView, trailing: UIView, in bar: UIView) {
        // the sprig grows down the art's left edge and its leaves fan along the top, so sitting
        // half outside the button it covers only the button's rim, never its icon
        // Same size on iPad: the buttons aren't scaled up there either. Where a button is near the
        // screen's edge (iPad), the sprig slides in to stay on screen.
        let left = ChristmasArtView("xmas-holly-corner")
        let right = ChristmasArtView("xmas-holly-corner", mirrored: true)
        for art in [left, right] {
            art.staysOnScreen = true
            bar.addSubview(art)
            NSLayoutConstraint.activate([
                art.widthAnchor.constraint(equalToConstant: 38),
                art.heightAnchor.constraint(equalToConstant: 47),
            ])
        }
        let side: CGFloat = 14, up: CGFloat = 6
        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: leading.leadingAnchor, constant: -side).withPriority(.defaultHigh),
            left.topAnchor.constraint(equalTo: leading.topAnchor, constant: -up).withPriority(.defaultHigh),
            right.trailingAnchor.constraint(equalTo: trailing.trailingAnchor, constant: side).withPriority(.defaultHigh),
            right.topAnchor.constraint(equalTo: trailing.topAnchor, constant: -up).withPriority(.defaultHigh),
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

/// The Home scan card's red (dark at the top, warmer at the bottom), filling the card under
/// everything else on it.
final class ChristmasCardFill: ChristmasContainerView {
    private let gradient = CAGradientLayer()

    init(cornerRadius: CGFloat) {
        super.init(frame: .zero)
        gradient.colors = [ChristmasDecor.cardRedTop.cgColor, ChristmasDecor.cardRedBottom.cgColor]
        gradient.cornerRadius = cornerRadius
        gradient.cornerCurve = .continuous
        layer.addSublayer(gradient)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
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

/// A few faint snowflakes drifting slowly down behind a tab's content (Home, Library, Search,
/// Settings): add it to the screen's view under everything else with `install(in:)`. It snows
/// only while the view is in a window and the Christmas theme is on, never with Reduce Motion or
/// Low Power Mode. It takes no touches.
final class SnowfallView: UIView {
    private let emitter = CAEmitterLayer()
    private var observer: SeasonalThemeObserver?

    /// Adds the snow filling `view`, behind everything in it (or just behind `content`).
    @discardableResult
    static func install(in view: UIView, below content: UIView? = nil) -> SnowfallView {
        let snow = SnowfallView()
        if let content { view.insertSubview(snow, belowSubview: content) } else { view.insertSubview(snow, at: 0) }
        NSLayoutConstraint.activate([
            snow.topAnchor.constraint(equalTo: view.topAnchor),
            snow.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            snow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            snow.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        return snow
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        makeDecorative()
        clipsToBounds = true
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
            if self.isSnowing { self.emitter.emitterCells = [self.makeCell()] }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    deinit { NotificationCenter.default.removeObserver(self) }

    var isSnowing: Bool { emitter.birthRate > 0 }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        update()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -10)
        emitter.emitterSize = CGSize(width: bounds.width * 1.2, height: 1)
    }

    @objc private func update() {
        let allowed = AppThemeManager.shared.seasonalTheme == .christmas
            && !UIAccessibility.isReduceMotionEnabled
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
        isHidden = !allowed
        if !allowed {
            emitter.birthRate = 0
            emitter.emitterCells = nil   // clears the flakes already falling
        } else if emitter.birthRate == 0, window != nil {
            // Starts as if it had been snowing a while, so the screen isn't bare at first. It
            // keeps going while the screen is away (nothing is drawn then), so no flakes jump.
            emitter.emitterCells = [makeCell()]
            emitter.beginTime = CACurrentMediaTime() - 45
            emitter.birthRate = 1
        }
    }

    private func makeCell() -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = Self.flakeImage.cgImage
        // few, faint and slow: a hint of snow far behind the content
        cell.birthRate = DeviceLayout.isPad ? 0.28 : 0.15
        cell.lifetime = 90
        cell.velocity = 11
        cell.velocityRange = 4
        cell.yAcceleration = 0.4
        cell.xAcceleration = 0.3
        cell.emissionLongitude = .pi
        cell.emissionRange = .pi / 14
        cell.spin = 0.15
        cell.spinRange = 0.3
        cell.scale = 0.4
        cell.scaleRange = 0.15
        cell.alphaRange = 0.08
        // white on dark; a soft blue-grey on light, where white snow wouldn't show
        let dark = traitCollection.userInterfaceStyle == .dark
        cell.color = (dark ? UIColor.white.withAlphaComponent(0.18)
                           : UIColor(hex: "#9FB1C5").withAlphaComponent(0.35)).cgColor
        return cell
    }

    /// A six-armed snowflake, drawn once (white, tinted by the cell's colour).
    private static let flakeImage: UIImage = {
        let side: CGFloat = 28
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: side / 2, y: side / 2)
            cg.setStrokeColor(UIColor.white.cgColor)
            cg.setLineWidth(1.6)
            cg.setLineCap(.round)
            let arm = side / 2 - 2
            for i in 0..<6 {
                cg.saveGState()
                cg.rotate(by: CGFloat(i) * .pi / 3)
                cg.move(to: .zero)
                cg.addLine(to: CGPoint(x: 0, y: -arm))
                // two small branches on each arm
                for (at, len) in [(0.5, 0.28), (0.75, 0.2)] as [(CGFloat, CGFloat)] {
                    let y = -arm * at, l = arm * len
                    cg.move(to: CGPoint(x: 0, y: y))
                    cg.addLine(to: CGPoint(x: -l * 0.8, y: y - l * 0.7))
                    cg.move(to: CGPoint(x: 0, y: y))
                    cg.addLine(to: CGPoint(x: l * 0.8, y: y - l * 0.7))
                }
                cg.strokePath()
                cg.restoreGState()
            }
        }
    }()
}
