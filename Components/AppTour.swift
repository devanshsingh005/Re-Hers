//
//  AppTour.swift
//  Re-Hearse_v1
//
//  First-run tips: the first time someone opens a main screen, a spotlight moves over its
//  controls one at a time, each with a short note, Next and Skip (tapping anywhere also goes
//  on). The tours are for people new to the app: each shows once (it counts as seen as soon as
//  it starts), and someone who has used Re-Hearse before gets none. Settings → "Show Tips
//  Again" brings them all back.
//

import UIKit
import Supabase

/// One stop on a tour: the view to point at and what to say about it.
struct TourStep {
    /// Looked up when the step is shown; a step whose view is missing, hidden or off screen is
    /// left out.
    let target: () -> UIView?
    let title: String
    let message: String
}

@MainActor
enum AppTour {
    enum ID: String, CaseIterable {
        case home, library, songPage, uploadResult, animation, playAlong, settings
    }

    private static func key(_ id: ID) -> String { "appTour.seen.\(id.rawValue)" }
    private static weak var current: TourOverlayView?

    static func hasSeen(_ id: ID) -> Bool { UserDefaults.standard.bool(forKey: key(id)) }
    static func markSeen(_ id: ID) { UserDefaults.standard.set(true, forKey: key(id)) }

    /// Decided once per account (or guest), the first time a tour could show: someone who has
    /// used Re-Hearse before (an account more than two days old, uploads, a song played) is no
    /// newcomer, and every tour is marked as seen for them.
    private static func skipToursForReturningUser() {
        let user = SupabaseManager.shared.client.auth.currentUser
        let checked = "appTour.checked.\(user?.id.uuidString.lowercased() ?? "guest")"
        guard !UserDefaults.standard.bool(forKey: checked) else { return }
        UserDefaults.standard.set(true, forKey: checked)
        let accountIsOld = user.map { Date().timeIntervalSince($0.createdAt) > 2 * 24 * 3600 } ?? false
        let hasHistory = !LocalSheetLibrary.shared.uploads().isEmpty || LastPlayedStore.shared.current != nil
        if accountIsOld || hasHistory { ID.allCases.forEach(markSeen) }
    }

    /// Every tour shows again, the next time its screen opens.
    static func resetAll() {
        ID.allCases.forEach { UserDefaults.standard.removeObject(forKey: key($0)) }
    }

    /// Runs `id`'s tour over `controller` once its screen has settled, unless it has been seen,
    /// another tour is showing, or something covers the screen. `steps` is read at that moment.
    static func showIfNeeded(_ id: ID, in controller: UIViewController, after delay: TimeInterval = 0.7,
                             steps: @escaping () -> [TourStep]) {
        guard !isRunningTests else { return }
        skipToursForReturningUser()
        guard !hasSeen(id), current == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak controller] in
            guard let controller, !hasSeen(id), current == nil,
                  let window = controller.viewIfLoaded?.window,
                  controller.presentedViewController == nil,
                  isFrontmost(controller, in: window) else { return }
            let shown = steps()
            guard !shown.isEmpty else { return }
            // seen from the moment it shows: leaving the screen or closing the app part-way
            // through doesn't bring it back
            markSeen(id)
            UserDefaults.standard.synchronize()
            let overlay = TourOverlayView(steps: shown) {}
            current = overlay
            overlay.show(in: window)
        }
    }

    /// The screen belongs to the topmost presented controller, so no sheet, alert or other
    /// presented screen covers it. (A screen pushed over, or in another tab, is out of the window.)
    private static func isFrontmost(_ controller: UIViewController, in window: UIWindow) -> Bool {
        var top = window.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed { top = presented }
        var node: UIViewController? = controller
        while let n = node {
            if n === top { return true }
            node = n.parent
        }
        return false
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

// MARK: - Overlay

/// Dims the window except for a rounded spotlight on the step's view, with a card beside it.
@MainActor
private final class TourOverlayView: UIView {
    private let steps: [TourStep]
    private let onFinish: () -> Void
    private var index = 0
    private var hole: CGRect = .zero
    /// Scrolling the next view into place: taps wait (the overlay still takes them, so none
    /// reaches the screen underneath).
    private var isMoving = false
    /// Where the current step's view was, to follow it if it moves or changes size.
    private var targetFrame: CGRect = .zero
    private var followTimer: Timer?

    private let dim = CAShapeLayer()
    private let ring = CAShapeLayer()
    private let card = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let countLabel = UILabel()
    private let skipButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private var cardTop: NSLayoutConstraint?
    private var cardCenterX: NSLayoutConstraint?

    init(steps: [TourStep], onFinish: @escaping () -> Void) {
        self.steps = steps
        self.onFinish = onFinish
        super.init(frame: .zero)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    func show(in window: UIWindow) {
        frame = window.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        alpha = 0
        window.addSubview(self)
        guard showStep(0, animated: false) else { finish(); return }
        UIView.animate(withDuration: 0.25) { self.alpha = 1 }
        // follow the view if it moves or changes size (content loading, a label getting shorter)
        followTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.followTarget() }
        }
        UIAccessibility.post(notification: .screenChanged, argument: card)
    }

    // MARK: Build

    private func build() {
        dim.fillRule = .evenOdd
        dim.fillColor = UIColor.black.withAlphaComponent(0.62).cgColor
        layer.addSublayer(dim)
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = BrandColors.brand.cgColor
        ring.lineWidth = 2
        layer.addSublayer(ring)

        card.backgroundColor = .tertiarySystemBackground   // white in light mode, raised grey in dark
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.2
        card.layer.shadowRadius = 16
        card.layer.shadowOffset = CGSize(width: 0, height: 6)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.accessibilityViewIsModal = true
        addSubview(card)

        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 15)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        countLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        countLabel.textColor = .tertiaryLabel

        var skip = UIButton.Configuration.plain()
        skip.title = "Skip"
        skip.baseForegroundColor = .secondaryLabel
        skip.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        skipButton.configuration = skip
        skipButton.accessibilityHint = "Ends these tips"
        skipButton.addAction(UIAction { [weak self] _ in self?.finish() }, for: .touchUpInside)

        var next = UIButton.Configuration.filled()
        next.cornerStyle = .capsule
        next.baseBackgroundColor = BrandColors.brand
        next.baseForegroundColor = .black
        next.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 18)
        nextButton.configuration = next
        nextButton.addAction(UIAction { [weak self] _ in self?.advance() }, for: .touchUpInside)

        let spacer = UIView()
        let footer = UIStackView(arrangedSubviews: [countLabel, spacer, skipButton, nextButton])
        footer.alignment = .center
        footer.spacing = 6
        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, footer])
        stack.axis = .vertical
        stack.spacing = 6
        stack.setCustomSpacing(14, after: messageLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let top = card.topAnchor.constraint(equalTo: topAnchor)
        let centerX = card.centerXAnchor.constraint(equalTo: leadingAnchor)
        centerX.priority = .defaultHigh
        let width = card.widthAnchor.constraint(equalToConstant: 340)
        width.priority = .defaultHigh
        NSLayoutConstraint.activate([
            top, centerX, width,
            card.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
        cardTop = top
        cardCenterX = centerX

        // a tap anywhere outside the card goes on to the next tip
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backgroundTapped)))
    }

    @objc private func backgroundTapped(_ tap: UITapGestureRecognizer) {
        guard !card.frame.contains(tap.location(in: self)) else { return }
        advance()
    }

    // MARK: Steps

    private func advance() {
        guard !isMoving else { return }
        var next = index + 1
        while next < steps.count {
            if showStep(next, animated: true) { return }
            next += 1
        }
        finish()
    }

    /// Shows step `i` if its view is on screen (scrolling it into view first); false to skip it.
    @discardableResult
    private func showStep(_ i: Int, animated: Bool) -> Bool {
        guard let target = steps[i].target(), target.window != nil, !target.isHidden, target.alpha > 0.01,
              target.bounds.width > 1, target.bounds.height > 1 else { return false }
        if scrollIntoView(target) {
            // let the scroll finish, then point at the view where it ended up
            isMoving = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.isMoving = false
                if !self.place(on: target, step: i, animated: true) { self.advance() }
            }
            index = i
            return true
        }
        return place(on: target, step: i, animated: animated)
    }

    private func place(on target: UIView, step i: Int, animated: Bool) -> Bool {
        var visible = target.convert(target.bounds, to: self).intersection(bounds)
        if let scroll = verticalScrollView(around: target) {
            visible = visible.intersection(scroll.convert(shownArea(of: scroll), to: self))
        }
        guard visible.width > 8, visible.height > 8 else { return false }
        index = i
        targetFrame = target.convert(target.bounds, to: self)
        hole = visible.insetBy(dx: -8, dy: -8)
        let radius = min(18, max(target.layer.cornerRadius + 6, 12), hole.height / 2)

        let step = steps[i]
        titleLabel.text = step.title
        messageLabel.text = step.message
        countLabel.text = steps.count > 1 ? "\(i + 1) of \(steps.count)" : nil
        let isLast = !steps.indices.contains { $0 > i && steps[$0].target() != nil }
        nextButton.configuration?.title = isLast ? "Done" : "Next"
        skipButton.isHidden = isLast

        let path = UIBezierPath(rect: bounds)
        let holePath = UIBezierPath(roundedRect: hole, cornerRadius: radius)
        path.append(holePath)
        animatePath(dim, to: path.cgPath, animated: animated)
        animatePath(ring, to: holePath.cgPath, animated: animated)

        // the card below the spotlight when it fits, above it otherwise
        layoutIfNeeded()
        let cardHeight = card.systemLayoutSizeFitting(CGSize(width: min(340, bounds.width - 32), height: 0),
                                                      withHorizontalFittingPriority: .required,
                                                      verticalFittingPriority: .fittingSizeLevel).height
        let safe = bounds.inset(by: safeAreaInsets)
        let below = hole.maxY + 14
        let above = hole.minY - 14 - cardHeight
        let y: CGFloat
        if below + cardHeight <= safe.maxY { y = below }
        else if above >= safe.minY { y = above }
        else { y = max(safe.minY, safe.maxY - cardHeight - 8) }   // a very tall spotlight: card over its lower part
        cardTop?.constant = y
        cardCenterX?.constant = hole.midX
        UIView.animate(withDuration: animated ? 0.3 : 0, delay: 0, options: .curveEaseInOut) {
            self.layoutIfNeeded()
        }
        UIAccessibility.post(notification: .layoutChanged, argument: titleLabel)
        return true
    }

    private func followTarget() {
        guard !isMoving, superview != nil, let target = steps[index].target(), target.window != nil else { return }
        let frame = target.convert(target.bounds, to: self)
        if frame != targetFrame { _ = place(on: target, step: index, animated: true) }
    }

    private func animatePath(_ layer: CAShapeLayer, to path: CGPath, animated: Bool) {
        if animated, let from = layer.path {
            let animation = CABasicAnimation(keyPath: "path")
            animation.fromValue = from
            animation.toValue = path
            animation.duration = 0.3
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(animation, forKey: "path")
        }
        layer.path = path
    }

    /// What the scroll view shows, in its own coordinates: not under its insets or under the
    /// status and navigation bars (its safe area).
    private func shownArea(of scroll: UIScrollView) -> CGRect {
        let a = scroll.adjustedContentInset, s = scroll.safeAreaInsets
        let insets = UIEdgeInsets(top: max(a.top, s.top), left: 0, bottom: max(a.bottom, s.bottom), right: 0)
        return scroll.bounds.inset(by: insets)
    }

    /// The nearest scroll view around `target` that scrolls up and down.
    private func verticalScrollView(around target: UIView) -> UIScrollView? {
        var view = target.superview
        while let v = view {
            if let scroll = v as? UIScrollView, scroll.isScrollEnabled, !(scroll is UITextView),
               scroll.contentSize.height > scroll.bounds.height - scroll.adjustedContentInset.top
                                                               - scroll.adjustedContentInset.bottom {
                return scroll
            }
            view = v.superview
        }
        return nil
    }

    /// Scrolls the view's scroll view so it is on screen (with a little room around it); true if
    /// it had to move. (Sets the offset itself: scrollRectToVisible does nothing in a scroll view
    /// whose content width is unset, as Home's is.)
    private func scrollIntoView(_ target: UIView) -> Bool {
        guard let scroll = verticalScrollView(around: target) else { return false }
        let rect = target.convert(target.bounds, to: scroll).insetBy(dx: 0, dy: -24)
        let shown = shownArea(of: scroll)
        var y = scroll.contentOffset.y
        if rect.height > shown.height || rect.minY < shown.minY {
            y -= shown.minY - rect.minY            // its top at the top of what's shown
        } else if rect.maxY > shown.maxY {
            y += rect.maxY - shown.maxY            // its bottom at the bottom
        }
        let inset = scroll.adjustedContentInset
        let maxY = max(-inset.top, scroll.contentSize.height - scroll.bounds.height + inset.bottom)
        y = min(max(y, -inset.top), maxY)
        guard abs(y - scroll.contentOffset.y) > 1 else { return false }
        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: y), animated: true)
        return true
    }

    private func finish() {
        followTimer?.invalidate()
        followTimer = nil
        onFinish()
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in self.removeFromSuperview() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // the window changed size (rotation, iPad multitasking): point at the step again
        if dim.frame != bounds {
            dim.frame = bounds
            ring.frame = bounds
            if let target = steps[index].target() { _ = place(on: target, step: index, animated: false) }
        }
    }
}
