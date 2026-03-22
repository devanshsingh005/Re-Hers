import UIKit

class ChapterNodeView: UIView {

    var chapter: MusicChapter
    var onTap: (() -> Void)?

    private let circleView  = UIView()
    private let iconLabel   = UILabel()
    private let titleLabel  = UILabel()
    private let starsStack  = UIStackView()
    private let badgeLabel  = UILabel()

    static let diameter: CGFloat = 72

    init(chapter: MusicChapter) {
        self.chapter = chapter
        super.init(frame: .zero)
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        let d = ChapterNodeView.diameter

        circleView.translatesAutoresizingMaskIntoConstraints = false
        circleView.layer.cornerRadius = d / 2
        circleView.layer.masksToBounds = false

        switch chapter.status {
        case .completed:
            circleView.backgroundColor     = ComponentColors.LearningCurve.nodeCompletedFill
            circleView.layer.borderColor   = ComponentColors.LearningCurve.pathCompleted.cgColor
            circleView.layer.shadowColor   = ComponentColors.HomeScreen.actionButtonFill.cgColor
            circleView.layer.shadowOpacity = 0.45
            circleView.layer.shadowRadius  = 10
            circleView.layer.shadowOffset  = CGSize(width: 0, height: 5)
            iconLabel.text      = "✓"
            iconLabel.font      = .systemFont(ofSize: 28, weight: .heavy)
            iconLabel.textColor = ComponentColors.LearningCurve.nodeIconCompleted
        case .current:
            circleView.backgroundColor   = ComponentColors.LearningCurve.nodeActiveFill
            circleView.layer.borderColor = ComponentColors.LearningCurve.pathCompleted.cgColor
            circleView.layer.borderWidth = 5
            circleView.layer.shadowColor   = ComponentColors.HomeScreen.actionButtonFill.cgColor
            circleView.layer.shadowOpacity = 0.3
            circleView.layer.shadowRadius  = 12
            circleView.layer.shadowOffset  = CGSize(width: 0, height: 5)
            iconLabel.text      = "♩"
            iconLabel.textColor = ComponentColors.LearningCurve.nodeIconActive
        case .locked:
            circleView.backgroundColor   = ComponentColors.LearningCurve.nodeLockedFill
            circleView.layer.borderColor = ComponentColors.LearningCurve.nodeLockedBorder.cgColor
            circleView.layer.borderWidth = 2
            iconLabel.text      = "🔒"
            iconLabel.textColor = ComponentColors.LearningCurve.nodeIconLocked
        }
        iconLabel.font = .systemFont(ofSize: 24)

        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.textAlignment = .center
        circleView.addSubview(iconLabel)

        starsStack.translatesAutoresizingMaskIntoConstraints = false
        starsStack.axis = .horizontal; starsStack.spacing = 1; starsStack.alignment = .center
        if chapter.stars > 0 {
            for _ in 0..<chapter.stars {
                let star = UILabel(); star.text = "⭐"; star.font = .systemFont(ofSize: 10)
                starsStack.addArrangedSubview(star)
            }
        }

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text          = chapter.title
        titleLabel.font          = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = chapter.status == .locked ? ComponentColors.LearningCurve.nodeIconLocked : ComponentColors.LearningCurve.headerTitle
        
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.text            = chapter.title.uppercased()
        badgeLabel.font            = .systemFont(ofSize: 11, weight: .heavy)
        badgeLabel.textColor       = ComponentColors.LearningCurve.chapterBadgeText
        badgeLabel.textAlignment   = .center
        badgeLabel.backgroundColor = ComponentColors.LearningCurve.chapterBadgeFill
        badgeLabel.layer.cornerRadius  = 11
        badgeLabel.layer.masksToBounds = true
        badgeLabel.isHidden            = (chapter.status != .current)

        addSubview(starsStack); addSubview(circleView)
        addSubview(titleLabel); addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            starsStack.bottomAnchor.constraint(equalTo: circleView.topAnchor, constant: -4),
            starsStack.centerXAnchor.constraint(equalTo: centerXAnchor),

            circleView.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            circleView.centerXAnchor.constraint(equalTo: centerXAnchor),
            circleView.widthAnchor.constraint(equalToConstant: d),
            circleView.heightAnchor.constraint(equalToConstant: d),

            iconLabel.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),

            badgeLabel.topAnchor.constraint(equalTo: circleView.bottomAnchor, constant: 6),
            badgeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            badgeLabel.heightAnchor.constraint(equalToConstant: 22),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),

            titleLabel.topAnchor.constraint(equalTo: circleView.bottomAnchor, constant: 6),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        if chapter.status == .current {
            titleLabel.isHidden = true
            badgeLabel.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap); isUserInteractionEnabled = true
    }

    @objc private func handleTap() {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0,
                           usingSpringWithDamping: 0.5, initialSpringVelocity: 5) {
                self.transform = .identity
            }
        }
        onTap?()
    }
}
