import UIKit

// MARK: - LessonNavBarView — Floating Glass Pills
//
// Layout:  ( ← )     ( ───────●─────── )      ( ⋯ )
// Uses individual UIVisualEffectView pills for a floating glass look
// layered over the piano/sheet music.

final class LessonNavBarView: UIView {

    var onBackTap:      (()->Void)?
    var onSeekProgress: ((Double)->Void)?
    var onMenuTap:      (()->Void)?
    var onTempoChanged: ((Double)->Void)?

    private let backBtn = UIButton(type: .system)
    private let progressSlider = UISlider()
    private let menuBtn = UIButton(type: .system)
    
    // Tracks if user is actively scrubbing so we don't jump the thumb
    private var isScrubbing = false

    // Pill containers
    private var progressPill: UIView?
    private var rightPill:    UIView?
    
    func updateProgress(_ process: Double) {
        guard !isScrubbing else { return }
        progressSlider.value = Float(max(0, min(1, process)))
    }

    override init(frame: CGRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        backgroundColor = .clear

        // ── 1. Back pill ────────────────────────────────────────────────────────
        let backCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        backBtn.setImage(UIImage(systemName: "chevron.left", withConfiguration: backCfg), for: .normal)
        backBtn.tintColor = .label
        backBtn.addTarget(self, action: #selector(didBack), for: .touchUpInside)
        let bPill = makePill(for: backBtn, insets: .zero, cornerRadius: 22)
        addSubview(bPill)

        // ── 2. Progress pill (Center) ───────────────────────────────────────────
        progressSlider.minimumValue = 0.0
        progressSlider.maximumValue = 1.0
        progressSlider.value = 0.0
        progressSlider.minimumTrackTintColor = BrandColors.brand
        progressSlider.maximumTrackTintColor = .systemGray4.withAlphaComponent(0.3)
        progressSlider.setThumbImage(thumbImage(size: 14), for: .normal)
        progressSlider.addTarget(self, action: #selector(sliderBegan), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(sliderEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        let pPill = makePill(for: progressSlider, insets: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16), cornerRadius: 18)
        self.progressPill = pPill
        addSubview(pPill)

        // ── 3. Right Pill (Menu) ────────────────────────────────────────────────
        let menuCfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        menuBtn.setImage(UIImage(systemName: "ellipsis.circle", withConfiguration: menuCfg), for: .normal)
        menuBtn.tintColor = .label
        menuBtn.addTarget(self, action: #selector(didMenu), for: .touchUpInside)
        menuBtn.widthAnchor.constraint(equalToConstant: 44).isActive = true
        menuBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let rPill = makePill(for: menuBtn, insets: .zero, cornerRadius: 22)
        self.rightPill = rPill
        addSubview(rPill)

        // ── Constraints ─────────────────────────────────────────────────────────
        NSLayoutConstraint.activate([
            // Back
            bPill.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            bPill.centerYAnchor.constraint(equalTo: centerYAnchor),
            bPill.widthAnchor.constraint(equalToConstant: 44),
            bPill.heightAnchor.constraint(equalToConstant: 44),

            // Menu
            rPill.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            rPill.centerYAnchor.constraint(equalTo: centerYAnchor),
            rPill.widthAnchor.constraint(equalToConstant: 44),
            rPill.heightAnchor.constraint(equalToConstant: 44),

            // Progress stretches between Back and Menu
            pPill.centerYAnchor.constraint(equalTo: centerYAnchor),
            pPill.heightAnchor.constraint(equalToConstant: 36),
            pPill.leadingAnchor.constraint(equalTo: bPill.trailingAnchor, constant: 16),
            pPill.trailingAnchor.constraint(equalTo: rPill.leadingAnchor, constant: -16)
        ])
    }

    private func makePill(for contentView: UIView, insets: UIEdgeInsets, cornerRadius: CGFloat) -> UIView {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blur.layer.cornerRadius = cornerRadius
        blur.layer.borderWidth = 0.5
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false

        contentView.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: insets.top),
            contentView.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -insets.bottom),
            contentView.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: insets.left),
            contentView.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -insets.right)
        ])
        
        let shadowWrap = UIView()
        shadowWrap.translatesAutoresizingMaskIntoConstraints = false
        shadowWrap.layer.shadowColor = UIColor.black.cgColor
        shadowWrap.layer.shadowOpacity = 0.15
        shadowWrap.layer.shadowOffset = CGSize(width: 0, height: 4)
        shadowWrap.layer.shadowRadius = 8
        shadowWrap.addSubview(blur)
        
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: shadowWrap.topAnchor),
            blur.bottomAnchor.constraint(equalTo: shadowWrap.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: shadowWrap.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: shadowWrap.trailingAnchor)
        ])
        
        return shadowWrap
    }

    private func thumbImage(size: CGFloat) -> UIImage {
        let s = CGSize(width: size, height: size)
        UIGraphicsBeginImageContextWithOptions(s, false, 0)
        BrandColors.brand.setFill()
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: s)).fill()
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }

    @objc private func didBack() {
        NavigationBarHelper.animateButtonPress(backBtn) { [weak self] in
            self?.onBackTap?()
        }
    }
    
    @objc private func didMenu() {
        NavigationBarHelper.animateButtonPress(menuBtn) { [weak self] in
            self?.onMenuTap?()
        }
    }

    @objc private func sliderBegan() {
        isScrubbing = true
    }

    @objc private func sliderChanged() {
        // Continuous seeking while dragging
        onSeekProgress?(Double(progressSlider.value))
    }

    @objc private func sliderEnded() {
        isScrubbing = false
        onSeekProgress?(Double(progressSlider.value))
    }
}
