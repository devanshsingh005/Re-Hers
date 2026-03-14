//
//  LaunchLoadingViewController.swift
//  Re-Hearse_v1
//

import UIKit

/// Displayed while the app checks for an active Supabase session on launch.
/// Shows a branded animation so there's no black/white flash during the async check.
class LaunchLoadingViewController: UIViewController {

    // MARK: - UI

    private let containerView = UIView()

    private let iconContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // Pulsing ring behind the icon
    private let pulseRing: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 55
        v.backgroundColor = UIColor.primaryColor.withAlphaComponent(0.15)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // Icon circle
    private let iconCircle: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 44
        v.backgroundColor = .primaryColor
        v.layer.shadowColor = UIColor.primaryColor.cgColor
        v.layer.shadowOpacity = 0.35
        v.layer.shadowRadius = 16
        v.layer.shadowOffset = CGSize(width: 0, height: 6)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let iconLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "🎹"
        lbl.font = .systemFont(ofSize: 40)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let appNameLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Re-Hearse"
        lbl.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        lbl.textColor = .darkGray2
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let taglineLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Your personal music coach"
        lbl.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        lbl.textColor = UIColor.darkGray1.withAlphaComponent(0.6)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    // Three dot loading indicator at bottom
    private let dotsStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private var dotViews: [UIView] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBackground
        setupLayout()
        makeDots()
        // Start invisible for fade-in
        containerView.alpha = 0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fadeIn()
        startPulseAnimation()
        startDotsAnimation()
    }

    // MARK: - Layout

    private func setupLayout() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Subviews
        containerView.addSubview(pulseRing)
        containerView.addSubview(iconCircle)
        iconCircle.addSubview(iconLabel)
        containerView.addSubview(appNameLabel)
        containerView.addSubview(taglineLabel)
        containerView.addSubview(dotsStack)

        NSLayoutConstraint.activate([
            // Center container
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            // Pulse ring (behind icon)
            pulseRing.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            pulseRing.topAnchor.constraint(equalTo: containerView.topAnchor),
            pulseRing.widthAnchor.constraint(equalToConstant: 110),
            pulseRing.heightAnchor.constraint(equalToConstant: 110),

            // Icon circle
            iconCircle.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconCircle.centerYAnchor.constraint(equalTo: pulseRing.centerYAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 88),
            iconCircle.heightAnchor.constraint(equalToConstant: 88),

            // Icon emoji inside circle
            iconLabel.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),

            // App name
            appNameLabel.topAnchor.constraint(equalTo: pulseRing.bottomAnchor, constant: 24),
            appNameLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            appNameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            appNameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            // Tagline
            taglineLabel.topAnchor.constraint(equalTo: appNameLabel.bottomAnchor, constant: 6),
            taglineLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            taglineLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            taglineLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            // Dots
            dotsStack.topAnchor.constraint(equalTo: taglineLabel.bottomAnchor, constant: 36),
            dotsStack.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            dotsStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }

    // MARK: - Three Dot Loader

    private func makeDots() {
        for _ in 0..<3 {
            let dot = UIView()
            dot.widthAnchor.constraint(equalToConstant: 8).isActive  = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            dot.layer.cornerRadius = 4
            dot.backgroundColor = UIColor.primaryColor.withAlphaComponent(0.4)
            dot.translatesAutoresizingMaskIntoConstraints = false
            dotsStack.addArrangedSubview(dot)
            dotViews.append(dot)
        }
    }

    private func startDotsAnimation() {
        for (index, dot) in dotViews.enumerated() {
            let delay = Double(index) * 0.2
            UIView.animate(
                withDuration: 0.6,
                delay: delay,
                options: [.repeat, .autoreverse, .curveEaseInOut],
                animations: {
                    dot.backgroundColor = UIColor.primaryColor
                    dot.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
                }
            )
        }
    }

    // MARK: - Pulse Animation

    private func startPulseAnimation() {
        UIView.animate(
            withDuration: 1.2,
            delay: 0,
            options: [.repeat, .autoreverse, .curveEaseInOut],
            animations: {
                self.pulseRing.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                self.pulseRing.alpha = 0.4
            }
        )
    }

    // MARK: - Fade In

    private func fadeIn() {
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut) {
            self.containerView.alpha = 1
        }
    }
}
