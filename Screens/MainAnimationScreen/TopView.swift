import UIKit

// MARK: - LessonNavBarView  — Three floating pills
// Layout:  [<]  [ -----O------------- ]  [...]

final class LessonNavBarView: UIView {

    var onBackTap:      (()->Void)?
    var onSeekProgress: ((Double)->Void)?
    var onMenuTap:      (()->Void)?

    private let backBtn = UIButton(type: .system)
    private let progressSlider = UISlider() // Native iOS Slider
    private let menuBtn = UIButton(type: .system)
    
    // Tracks if user is actively scrubbing so we don't jump the thumb
    private var isScrubbing = false

    var onTempoChanged: ((Double)->Void)?

    func setSongTitle(_ t: String) {}
    func setPlaybackControlsHidden(_ hidden: Bool) {}

    override init(frame: CGRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        backgroundColor = .clear

        let btnSize: CGFloat = 40 // Slimmer, native touch target size

        // ── Left: Back Button Pill ────────────────────────────────────
        let backContainer = makePillContainer(size: btnSize)
        
        // Native iOS back chevron weight and size
        let backCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        backBtn.setImage(UIImage(systemName: "chevron.left", withConfiguration: backCfg), for: .normal)
        backBtn.tintColor = .label
        backBtn.addTarget(self, action: #selector(didBack), for: .touchUpInside)
        
        backContainer.contentView.addSubview(backBtn)
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        
        // ── Right: Menu Button Pill ───────────────────────────────────
        let menuContainer = makePillContainer(size: btnSize)
        
        let menuCfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        menuBtn.setImage(UIImage(systemName: "ellipsis.circle", withConfiguration: menuCfg), for: .normal)
        menuBtn.tintColor = .label
        menuBtn.addTarget(self, action: #selector(didMenu), for: .touchUpInside)
        
        menuContainer.contentView.addSubview(menuBtn)
        menuBtn.translatesAutoresizingMaskIntoConstraints = false

        // ── Center: Slider Pill ─────────────────────────────────────
        let sliderContainer = makePillContainer(size: btnSize)
        
        progressSlider.minimumValue = 0.0
        progressSlider.maximumValue = 1.0
        progressSlider.value        = 0.0
        progressSlider.minimumTrackTintColor = BrandColors.brand
        progressSlider.maximumTrackTintColor = UIColor.tertiaryLabel
        progressSlider.setThumbImage(thumbImage(), for: .normal)
        progressSlider.addTarget(self, action: #selector(sliderBegan), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(sliderEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        sliderContainer.contentView.addSubview(progressSlider)
        progressSlider.translatesAutoresizingMaskIntoConstraints = false
        
        // ── Assemble ──────────────────────────────────────────────────
        [backContainer, sliderContainer, menuContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            // Back Container
            backContainer.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            backContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            backContainer.widthAnchor.constraint(equalToConstant: btnSize),
            backContainer.heightAnchor.constraint(equalToConstant: btnSize),
            
            backBtn.centerXAnchor.constraint(equalTo: backContainer.centerXAnchor),
            backBtn.centerYAnchor.constraint(equalTo: backContainer.centerYAnchor),
            backBtn.widthAnchor.constraint(equalToConstant: btnSize),
            backBtn.heightAnchor.constraint(equalToConstant: btnSize),
            
            // Menu Container
            menuContainer.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            menuContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            menuContainer.widthAnchor.constraint(equalToConstant: btnSize),
            menuContainer.heightAnchor.constraint(equalToConstant: btnSize),
            
            menuBtn.centerXAnchor.constraint(equalTo: menuContainer.centerXAnchor),
            menuBtn.centerYAnchor.constraint(equalTo: menuContainer.centerYAnchor),
            menuBtn.widthAnchor.constraint(equalToConstant: btnSize),
            menuBtn.heightAnchor.constraint(equalToConstant: btnSize),
            
            // Slider Container
            sliderContainer.leadingAnchor.constraint(equalTo: backContainer.trailingAnchor, constant: 16),
            sliderContainer.trailingAnchor.constraint(equalTo: menuContainer.leadingAnchor, constant: -16),
            sliderContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            sliderContainer.heightAnchor.constraint(equalToConstant: btnSize),
            
            // Progress Slider inside Container (padded)
            progressSlider.leadingAnchor.constraint(equalTo: sliderContainer.leadingAnchor, constant: 20),
            progressSlider.trailingAnchor.constraint(equalTo: sliderContainer.trailingAnchor, constant: -20),
            progressSlider.centerYAnchor.constraint(equalTo: sliderContainer.centerYAnchor)
        ])
    }

    private func makePillContainer(size: CGFloat) -> UIVisualEffectView {
        // Native iOS glass material, adapting perfectly to light/dark mode sheet music
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blur.layer.cornerRadius = size / 2
        blur.clipsToBounds = true
        return blur
    }

    private func thumbImage() -> UIImage {
        let s = CGSize(width: 14, height: 14) // Native, delicate thumb
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

    // Called from AnimationViewController to visually update progress
    func updateProgress(_ process: Double) {
        guard !isScrubbing else { return }
        progressSlider.value = Float(max(0, min(1, process)))
    }
}
