//
//  SkeletonView.swift
//  Re-Hearse_v1
//
//  Zero-dependency shimmer skeleton system.
//  Build skeletons by composing SkeletonBox and SkeletonStackView,
//  then call startShimmering() / stopShimmering() on any UIView.
//

import UIKit

// MARK: - Design Tokens

enum SkeletonTokens {
    /// Placeholder base — uses the app's defined skeleton colour (adapts light/dark)
    static var base:  UIColor { BrandColors.skeletonBase }
    /// Shimmer highlight — sweeps across the base
    static var shine: UIColor { BrandColors.skeletonHighlight }
    /// Full animation cycle duration in seconds
    static let duration: CFTimeInterval = 1.4
    /// Fade transition when skeleton appears / disappears
    static let fadeDuration: TimeInterval = 0.28
}

// MARK: - ShimmerLayer

/// A `CAGradientLayer` that sweeps a highlight band left → right continuously.
final class ShimmerLayer: CAGradientLayer {

    // MARK: Init
    override init() {
        super.init()
        commonInit()
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        let base  = SkeletonTokens.base.cgColor
        let shine = SkeletonTokens.shine.cgColor
        colors        = [base, shine, base]
        locations     = [-1.0, -0.5, 0.0]
        startPoint    = CGPoint(x: 0, y: 0.5)
        endPoint      = CGPoint(x: 1, y: 0.5)
    }

    // MARK: API

    func startShimmering() {
        guard animation(forKey: "shimmer") == nil else { return }
        let anim                = CABasicAnimation(keyPath: "locations")
        anim.fromValue          = [-1.0, -0.5, 0.0]
        anim.toValue            = [1.0,  1.5,  2.0]
        anim.duration           = SkeletonTokens.duration
        anim.repeatCount        = .infinity
        anim.isRemovedOnCompletion = false
        add(anim, forKey: "shimmer")
    }

    func stopShimmering() {
        removeAnimation(forKey: "shimmer")
    }
}

// MARK: - UIView shimmer extension

extension UIView {

    private static var shimmerLayerKey: UInt8 = 0

    /// Lazily creates and returns the `ShimmerLayer` for this view.
    var shimmerLayer: ShimmerLayer {
        if let existing = objc_getAssociatedObject(self, &UIView.shimmerLayerKey) as? ShimmerLayer {
            return existing
        }
        let layer = ShimmerLayer()
        objc_setAssociatedObject(self, &UIView.shimmerLayerKey, layer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return layer
    }

    /// Add the shimmer gradient and begin animating.
    func startShimmering() {
        let sl = shimmerLayer
        sl.frame = bounds
        sl.cornerRadius = layer.cornerRadius
        if sl.superlayer == nil {
            layer.addSublayer(sl)
        }
        sl.startShimmering()
    }

    /// Remove the shimmer animation and gradient.
    func stopShimmering() {
        shimmerLayer.stopShimmering()
        shimmerLayer.removeFromSuperlayer()
        objc_setAssociatedObject(self, &UIView.shimmerLayerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Resize shimmer layer when view layout changes.
    func resizeShimmerIfNeeded() {
        shimmerLayer.frame = bounds
        shimmerLayer.cornerRadius = layer.cornerRadius
    }
}

// MARK: - SkeletonBox

/// A solid rectangle with rounded corners and shimmer animation.
/// Use this as the building block for all skeleton shapes.
final class SkeletonBox: UIView {

    // MARK: Init

    /// - Parameters:
    ///   - height: Fixed height of the box. Pass `nil` to let Auto Layout control height.
    ///   - cornerRadius: Corner rounding. Default 8.
    ///   - widthRatio: If you want the box to fill a % of its parent, set a width constraint externally.
    init(height: CGFloat? = nil, cornerRadius: CGFloat = 8) {
        super.init(frame: .zero)
        backgroundColor = SkeletonTokens.base
        layer.cornerRadius = cornerRadius
        translatesAutoresizingMaskIntoConstraints = false
        if let h = height {
            heightAnchor.constraint(equalToConstant: h).isActive = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        resizeShimmerIfNeeded()
    }
}

// MARK: - SkeletonCircle

/// A circular skeleton box — useful for avatars and icon placeholders.
final class SkeletonCircle: UIView {

    init(diameter: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        backgroundColor = SkeletonTokens.base
        layer.cornerRadius = diameter / 2
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: diameter).isActive = true
        heightAnchor.constraint(equalToConstant: diameter).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        resizeShimmerIfNeeded()
    }
}

// MARK: - SkeletonLineGroup

/// Creates a stack of skeleton lines simulating text paragraphs.
/// Last line is narrower to mimic natural text wrap.
final class SkeletonLineGroup: UIStackView {

    /// - Parameters:
    ///   - lines: Number of text-line placeholders.
    ///   - lineHeight: Height of each line. Default 14.
    ///   - spacing: Vertical gap between lines. Default 8.
    ///   - lastLineWidthRatio: Width of final line relative to the others (0–1). Default 0.6.
    init(lines: Int,
         lineHeight: CGFloat = 14,
         spacing: CGFloat = 8,
         lastLineWidthRatio: CGFloat = 0.6) {
        super.init(frame: .zero)
        axis = .vertical
        self.spacing = spacing
        translatesAutoresizingMaskIntoConstraints = false

        for i in 0..<lines {
            let box = SkeletonBox(height: lineHeight, cornerRadius: lineHeight / 2)
            addArrangedSubview(box)
            // Shrink the last line
            if i == lines - 1 && lines > 1 {
                box.widthAnchor.constraint(
                    equalTo: widthAnchor,
                    multiplier: lastLineWidthRatio
                ).isActive = true
            }
        }
    }

    required init(coder: NSCoder) { fatalError() }
}

// MARK: - SkeletonContainerView

/// A full-screen overlay that holds skeleton subviews.
/// Call `show(in:)` to mount it, `hide()` to fade out and remove.
class SkeletonContainerView: UIView {

    // MARK: Init
    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        isHidden = true          // hidden until show() / showInPlace() is called
        alpha = 0
        accessibilityLabel = "Loading…"
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: API

    /// Pin this container to `parent`'s edges and start all skeleton animations.
    /// Use when the skeleton is **not** already in the view hierarchy.
    func show(in parent: UIView, below belowView: UIView? = nil) {
        guard superview == nil else {
            // Already mounted — just animate in place
            showInPlace()
            return
        }
        alpha = 0
        isHidden = false
        if let below = belowView {
            parent.insertSubview(self, belowSubview: below)
        } else {
            parent.addSubview(self)
        }
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parent.topAnchor),
            leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor),
        ])
        startAllShimmering()
        UIView.animate(withDuration: SkeletonTokens.fadeDuration) { self.alpha = 1 }
    }

    /// Show a skeleton that is **already pinned** in the view hierarchy
    /// (e.g. PDF skeleton pre-constrained alongside the PDFView).
    func showInPlace() {
        isHidden = false
        alpha = 0
        startAllShimmering()
        UIView.animate(withDuration: SkeletonTokens.fadeDuration) { self.alpha = 1 }
    }

    /// Fade out. If the skeleton was added via `show(in:)` it is removed from superview;
    /// if it was pre-positioned (`showInPlace`) it is hidden in place instead.
    func hide(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: SkeletonTokens.fadeDuration, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.stopAllShimmering()
            self.isHidden = true
            completion?()
        })
    }

    // MARK: Shimmer helpers

    private func startAllShimmering() {
        allSkeletonBoxes(in: self).forEach { $0.startShimmering() }
    }

    private func stopAllShimmering() {
        allSkeletonBoxes(in: self).forEach { $0.stopShimmering() }
    }

    private func allSkeletonBoxes(in view: UIView) -> [UIView] {
        var result: [UIView] = []
        for sub in view.subviews {
            if sub is SkeletonBox || sub is SkeletonCircle {
                result.append(sub)
            }
            result.append(contentsOf: allSkeletonBoxes(in: sub))
        }
        return result
    }

    // MARK: Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        allSkeletonBoxes(in: self).forEach { $0.resizeShimmerIfNeeded() }
    }
}
