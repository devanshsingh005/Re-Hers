import UIKit

// MARK: - PlayPauseOverlayView
// Full-screen transparent overlay.
// Tapping anywhere toggles play/pause and shows a brief centred icon flash.
// Touch events pass through to subviews underneath (sheet, piano).

final class PlayPauseOverlayView: UIView {

    // Called when the user taps the overlay
    var onTap: (() -> Void)?

    // MARK: - Private
    private let iconContainer = UIView()
    private let iconView      = UIImageView()
    private var hideTimer:    Timer?

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup
    private func setup() {
        backgroundColor       = .clear
        isUserInteractionEnabled = true

        // Semi-transparent circle behind icon — appears briefly
        iconContainer.backgroundColor    = UIColor.black.withAlphaComponent(0.40)
        iconContainer.layer.cornerRadius = 36
        iconContainer.alpha              = 0
        iconContainer.isUserInteractionEnabled = false
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        iconView.tintColor       = .white
        iconView.contentMode     = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconContainer)
        iconContainer.addSubview(iconView)

        NSLayoutConstraint.activate([
            iconContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 72),
            iconContainer.heightAnchor.constraint(equalToConstant: 72),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32)
        ])

        // Single tap anywhere on overlay
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    // MARK: - Tap
    @objc private func handleTap() {
        onTap?()
    }

    // MARK: - Public: flash icon
    /// Call this after toggling play state to flash the icon.
    func show(isPlaying: Bool) {
        hideTimer?.invalidate()

        let name = isPlaying ? "pause.fill" : "play.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)
        iconView.image = UIImage(systemName: name, withConfiguration: config)

        // Pop in
        iconContainer.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        iconContainer.alpha     = 1

        UIView.animate(withDuration: 0.18,
                       delay: 0,
                       usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.8) {
            self.iconContainer.transform = .identity
        }

        // Auto-hide after 1.0 s
        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            UIView.animate(withDuration: 0.25) {
                self?.iconContainer.alpha = 0
            }
        }
    }
}
