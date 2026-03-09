import UIKit

// MARK: - LessonNavBarView  — Liquid Glass effect
//
// Layout:  ← back  |  TITLE (centred)  |  0.5×──●──2×  1×  ⋯
// Uses UIVisualEffectView (ultraThinMaterial) for liquid glass look.
// No opaque background — blurs whatever is behind it.

final class LessonNavBarView: UIView {

    var onBackTap:      (()->Void)?
    var onTempoChanged: ((Double)->Void)?
    var onMenuTap:      (()->Void)?
    private(set) var tempoMultiplier: Double = 1.0

    private let blurView    = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let backBtn     = UIButton(type: .system)
    private let titleLabel  = UILabel()
    private let tempoSlider = UISlider()
    private let tempoLabel  = UILabel()
    private let menuBtn     = UIButton(type: .system)

    func setSongTitle(_ t: String) { titleLabel.text = t }

    override init(frame: CGRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        blurView.frame = bounds
    }

    private func build() {
        backgroundColor = .clear

        insertSubview(blurView, at: 0)

        let border = CALayer()
        border.backgroundColor = UIColor.separator.cgColor
        DispatchQueue.main.async {
            border.frame = CGRect(x: 0, y: self.bounds.height - 0.5,
                                  width: self.bounds.width, height: 0.5)
            self.layer.addSublayer(border)
        }

        // ── Back button ──────────────────────────────────────────────────
        let backCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        backBtn.setImage(UIImage(systemName: "chevron.left", withConfiguration: backCfg), for: .normal)
        backBtn.tintColor = .label
        backBtn.addTarget(self, action: #selector(didBack), for: .touchUpInside)

        // ── Title ────────────────────────────────────────────────────────
        titleLabel.text = "TITLE"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        // ── Tempo slider ─────────────────────────────────────────────────
        tempoSlider.minimumValue = 0.5
        tempoSlider.maximumValue = 2.0
        tempoSlider.value        = 1.0
        tempoSlider.minimumTrackTintColor = .systemBlue
        tempoSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.4)
        tempoSlider.setThumbImage(thumbImage(), for: .normal)
        tempoSlider.addTarget(self, action: #selector(sliderMoved), for: .valueChanged)
        tempoSlider.widthAnchor.constraint(equalToConstant: 110).isActive = true

        let minL = tinyLbl("0.5×")
        let maxL = tinyLbl("2×")

        tempoLabel.text = "1×"
        tempoLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        tempoLabel.textColor = .label
        tempoLabel.textAlignment = .center
        tempoLabel.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let sliderRow = UIStackView(arrangedSubviews: [minL, tempoSlider, maxL, tempoLabel])
        sliderRow.axis = .horizontal; sliderRow.spacing = 5; sliderRow.alignment = .center

        // ── Menu button ──────────────────────────────────────────────────
        let menuCfg = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        menuBtn.setImage(UIImage(systemName: "ellipsis.circle", withConfiguration: menuCfg), for: .normal)
        menuBtn.tintColor = .label
        menuBtn.addTarget(self, action: #selector(didMenu), for: .touchUpInside)
        menuBtn.widthAnchor.constraint(equalToConstant: 36).isActive = true
        menuBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true

        // ── Right cluster ────────────────────────────────────────────────
        let right = UIStackView(arrangedSubviews: [sliderRow, menuBtn])
        right.axis = .horizontal; right.spacing = 8; right.alignment = .center

        // ── Assemble ─────────────────────────────────────────────────────
        [backBtn, titleLabel, right].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            backBtn.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 8),
            backBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            backBtn.widthAnchor.constraint(equalToConstant: 44),
            backBtn.heightAnchor.constraint(equalToConstant: 44),

            right.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -10),
            right.centerYAnchor.constraint(equalTo: centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backBtn.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: right.leadingAnchor, constant: -8)
        ])
    }

    private func tinyLbl(_ t: String) -> UILabel {
        let l = UILabel(); l.text = t
        l.font = .systemFont(ofSize: 9); l.textColor = .secondaryLabel
        return l
    }

    private func thumbImage() -> UIImage {
        let s = CGSize(width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(s, false, 0)
        UIColor.systemBlue.setFill()
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: s)).fill()
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }

    @objc private func didBack() { onBackTap?() }
    @objc private func didMenu() { onMenuTap?() }

    @objc private func sliderMoved() {
        let snap = (Double(tempoSlider.value) * 4).rounded() / 4
        tempoSlider.value  = Float(snap)
        tempoMultiplier    = snap
        tempoLabel.text    = snap == 1.0 ? "1×" : String(format: "%.2g×", snap)
        onTempoChanged?(snap)
    }
}
