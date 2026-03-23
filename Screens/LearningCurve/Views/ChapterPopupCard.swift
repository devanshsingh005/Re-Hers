import UIKit

class ChapterPopupCard: UIView {

    var onPrimary: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let containerView = UIView()

    init(chapter: MusicChapter) {
        super.init(frame: .zero)
        setupView(chapter: chapter)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupView(chapter: MusicChapter) {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = ComponentColors.LearningCurve.popupBackground
        containerView.layer.cornerRadius = 24
        containerView.layer.shadowColor = ComponentColors.LearningCurve.popupShadow.cgColor
        containerView.layer.shadowOpacity  = 0.14
        containerView.layer.shadowRadius   = 20
        containerView.layer.shadowOffset   = CGSize(width: 0, height: 6)
        addSubview(containerView)

        let statusView = UIView()
        statusView.translatesAutoresizingMaskIntoConstraints = false
        statusView.layer.cornerRadius   = 28
        statusView.layer.masksToBounds  = true

        let statusIcon = UILabel()
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.textAlignment = .center

        switch chapter.status {
        case .completed:
            statusView.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
            statusIcon.text = "✓"; statusIcon.font = .systemFont(ofSize: 22, weight: .heavy)
            statusIcon.textColor = .white
        case .current:
            statusView.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.12)
            statusIcon.text = "♩"; statusIcon.font = .systemFont(ofSize: 24, weight: .bold)
            statusIcon.textColor = ComponentColors.HomeScreen.actionButtonFill
        case .locked:
            statusView.backgroundColor = UIColor.systemGray5
            statusIcon.text = "🔒"; statusIcon.font = .systemFont(ofSize: 20)
        }
        statusView.addSubview(statusIcon)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text      = chapter.title
        titleLabel.font      = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text          = chapter.subtitle
        subtitleLabel.font          = .systemFont(ofSize: 13)
        subtitleLabel.textColor     = .systemGray
        subtitleLabel.numberOfLines = 2

        let dismissBtn = UIButton(type: .system)
        dismissBtn.translatesAutoresizingMaskIntoConstraints = false
        dismissBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        dismissBtn.tintColor       = .systemGray2
        dismissBtn.backgroundColor = UIColor.systemGray6
        dismissBtn.layer.cornerRadius = 15
        dismissBtn.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)

        let primaryBtn = UIButton(type: .system)
        primaryBtn.translatesAutoresizingMaskIntoConstraints = false
        primaryBtn.layer.cornerRadius   = 24
        primaryBtn.layer.masksToBounds  = true

        let status = chapter.status
        if status == .completed {
            let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            primaryBtn.setImage(UIImage(systemName: "arrow.counterclockwise", withConfiguration: cfg), for: .normal)
            primaryBtn.setTitle(NSLocalizedString("practice_again_btn", comment: ""), for: .normal)
            primaryBtn.titleLabel?.font      = .systemFont(ofSize: 16, weight: .bold)
            primaryBtn.tintColor             = ComponentColors.PrimaryButton.text
            primaryBtn.backgroundColor       = ComponentColors.LearningCurve.pathCompleted
            primaryBtn.layer.shadowColor     = ComponentColors.HomeScreen.actionButtonFill.cgColor
            primaryBtn.layer.shadowOpacity   = 0.35
            primaryBtn.layer.shadowRadius    = 8
            primaryBtn.layer.shadowOffset    = CGSize(width: 0, height: 4)
            primaryBtn.layer.masksToBounds   = false
        } else if status == .current {
            let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            primaryBtn.setImage(UIImage(systemName: "play.fill", withConfiguration: cfg), for: .normal)
            primaryBtn.setTitle(NSLocalizedString("start_lesson_btn", comment: ""), for: .normal)
            primaryBtn.titleLabel?.font      = .systemFont(ofSize: 16, weight: .bold)
            primaryBtn.tintColor             = ComponentColors.PrimaryButton.text
            primaryBtn.backgroundColor       = ComponentColors.LearningCurve.pathCompleted
            primaryBtn.layer.shadowColor     = ComponentColors.HomeScreen.actionButtonFill.cgColor
            primaryBtn.layer.shadowOpacity   = 0.35
            primaryBtn.layer.shadowRadius    = 8
            primaryBtn.layer.shadowOffset    = CGSize(width: 0, height: 4)
            primaryBtn.layer.masksToBounds   = false
        } else { // .locked
            let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            primaryBtn.setImage(UIImage(systemName: "lock.fill", withConfiguration: cfg), for: .normal)
            primaryBtn.setTitle("  Locked", for: .normal)
            primaryBtn.titleLabel?.font  = .systemFont(ofSize: 16, weight: .bold)
            primaryBtn.tintColor         = ComponentColors.LearningCurve.nodeIconLocked
            primaryBtn.backgroundColor   = ComponentColors.LearningCurve.nodeLockedFill
            primaryBtn.isEnabled         = false
        }
        primaryBtn.addTarget(self, action: #selector(didTapPrimary), for: .touchUpInside)

        containerView.addSubview(statusView); containerView.addSubview(statusIcon)
        containerView.addSubview(titleLabel); containerView.addSubview(subtitleLabel)
        containerView.addSubview(dismissBtn); containerView.addSubview(primaryBtn)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            dismissBtn.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            dismissBtn.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            dismissBtn.widthAnchor.constraint(equalToConstant: 30),
            dismissBtn.heightAnchor.constraint(equalToConstant: 30),

            statusView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            statusView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            statusView.widthAnchor.constraint(equalToConstant: 56),
            statusView.heightAnchor.constraint(equalToConstant: 56),

            statusIcon.centerXAnchor.constraint(equalTo: statusView.centerXAnchor),
            statusIcon.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: dismissBtn.leadingAnchor, constant: -8),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            subtitleLabel.leadingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: 14),
            subtitleLabel.trailingAnchor.constraint(equalTo: dismissBtn.leadingAnchor, constant: -8),

            primaryBtn.topAnchor.constraint(equalTo: statusView.bottomAnchor, constant: 16),
            primaryBtn.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            primaryBtn.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            primaryBtn.heightAnchor.constraint(equalToConstant: 48),
            primaryBtn.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -18),
        ])
    }

    @objc private func didTapPrimary() {
        UIView.animate(withDuration: 0.08, animations: {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }) { _ in
            UIView.animate(withDuration: 0.12) { self.transform = .identity }
        }
        onPrimary?()
    }
    @objc private func didTapDismiss() { onDismiss?() }
}
