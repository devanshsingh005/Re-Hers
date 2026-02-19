import UIKit

// MARK: - Models

enum ChapterStatus {
    case completed, current, locked
}

struct MusicLesson {
    let title: String
    let noteName: String
    let noteEnglish: String
    let description: String
    let variants: [String]
}

struct MusicChapter {
    let id = UUID()
    let title: String
    let subtitle: String
    let status: ChapterStatus
    let stars: Int
    let lesson: MusicLesson
}

let allChapters: [MusicChapter] = [
    MusicChapter(title: "The Staff", subtitle: "Learn about music staff lines", status: .completed, stars: 3,
        lesson: MusicLesson(title: "The Staff", noteName: "Staff", noteEnglish: "Lines & Spaces", description: "The staff consists of 5 horizontal lines and 4 spaces where notes are placed.", variants: ["Treble","Bass","Alto","Tenor"])),
    MusicChapter(title: "Treble Clef", subtitle: "Master the treble clef symbol", status: .completed, stars: 2,
        lesson: MusicLesson(title: "Treble Clef", noteName: "G Clef", noteEnglish: "G (Sol)", description: "The treble clef marks the second line as G above middle C.", variants: ["Treble","Soprano","Mezzo","Violin"])),
    MusicChapter(title: "Note C", subtitle: "Your first note on the keyboard", status: .current, stars: 0,
        lesson: MusicLesson(title: "The Basics", noteName: "C", noteEnglish: "C (Do)", description: "Middle C is one of the most important reference notes in all of music.", variants: ["Do","Minor","Major","Sharp","Dim","Aug"])),
    MusicChapter(title: "Note D", subtitle: "Second white key after C", status: .locked, stars: 0,
        lesson: MusicLesson(title: "Note D", noteName: "D", noteEnglish: "D (Re)", description: "D is the second note of the C major scale.", variants: ["Re","Minor","Major","Sharp","Flat"])),
    MusicChapter(title: "Note E", subtitle: "Third note of the C scale", status: .locked, stars: 0,
        lesson: MusicLesson(title: "Note E", noteName: "E", noteEnglish: "E (Mi)", description: "E is the third note of the C major scale.", variants: ["Mi","Minor","Major","Flat"])),
    MusicChapter(title: "Note F", subtitle: "Learn the F note position", status: .locked, stars: 0,
        lesson: MusicLesson(title: "Note F", noteName: "F", noteEnglish: "F (Fa)", description: "F sits just below the first line of the treble clef staff.", variants: ["Fa","Minor","Major","Sharp"])),
    MusicChapter(title: "Note G", subtitle: "G note on the second line", status: .locked, stars: 0,
        lesson: MusicLesson(title: "Note G", noteName: "G", noteEnglish: "G (Sol)", description: "G is the note that the treble clef wraps around.", variants: ["Sol","Minor","Major","Sharp","Flat"])),
    MusicChapter(title: "Note A", subtitle: "The concert pitch reference", status: .locked, stars: 0,
        lesson: MusicLesson(title: "Note A", noteName: "A", noteEnglish: "A (La)", description: "Concert A at 440Hz is the universal tuning reference.", variants: ["La","Minor","Major","Sharp","Flat"])),
    MusicChapter(title: "Note B", subtitle: "Complete the C major scale", status: .locked, stars: 0,
        lesson: MusicLesson(title: "Note B", noteName: "B", noteEnglish: "B (Ti)", description: "B is the seventh note of the C major scale.", variants: ["Ti","Minor","Major","Sharp","Flat"])),
    MusicChapter(title: "Chords", subtitle: "Combine notes into harmony", status: .locked, stars: 0,
        lesson: MusicLesson(title: "Basic Chords", noteName: "C Chord", noteEnglish: "C Major", description: "A chord is three or more notes played simultaneously.", variants: ["Major","Minor","Diminished","Augmented","7th"])),
]

// MARK: - Chapter Node View

class ChapterNodeView: UIView {

    var chapter: MusicChapter
    var onTap: (() -> Void)?

    private let circleView = UIView()
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let starsStack = UIStackView()
    // Badge for current node (shows chapter title in orange pill)
    private let badgeLabel = UILabel()

    // Node diameter matches reference image (~72pt)
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
            circleView.backgroundColor = UIColor.systemOrange
            circleView.layer.shadowColor = UIColor.systemOrange.cgColor
            circleView.layer.shadowOpacity = 0.45
            circleView.layer.shadowRadius = 10
            circleView.layer.shadowOffset = CGSize(width: 0, height: 5)
            iconLabel.text = "✓"
            iconLabel.font = .systemFont(ofSize: 28, weight: .heavy)
            iconLabel.textColor = .white

        case .current:
            // Outer orange ring with white fill
            circleView.backgroundColor = .white
            circleView.layer.borderColor = UIColor.systemOrange.cgColor
            circleView.layer.borderWidth = 5
            circleView.layer.shadowColor = UIColor.systemOrange.cgColor
            circleView.layer.shadowOpacity = 0.3
            circleView.layer.shadowRadius = 12
            circleView.layer.shadowOffset = CGSize(width: 0, height: 5)
            // Music note icon in orange
            iconLabel.text = "♩"
            iconLabel.font = .systemFont(ofSize: 30, weight: .bold)
            iconLabel.textColor = UIColor.systemOrange

        case .locked:
            circleView.backgroundColor = UIColor.systemGray5
            circleView.layer.borderColor = UIColor.systemGray4.cgColor
            circleView.layer.borderWidth = 2
            iconLabel.text = "🔒"
            iconLabel.font = .systemFont(ofSize: 24)
        }

        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.textAlignment = .center
        circleView.addSubview(iconLabel)

        // Stars above circle (completed only)
        starsStack.translatesAutoresizingMaskIntoConstraints = false
        starsStack.axis = .horizontal
        starsStack.spacing = 1
        starsStack.alignment = .center
        if chapter.stars > 0 {
            for _ in 0..<chapter.stars {
                let star = UILabel()
                star.text = "⭐"
                star.font = .systemFont(ofSize: 10)
                starsStack.addArrangedSubview(star)
            }
        }

        // Title below circle
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = chapter.title
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = chapter.status == .locked ? UIColor.systemGray3 : UIColor.label

        // Badge pill for current node (orange rounded rect with title)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.text = chapter.title.uppercased()
        badgeLabel.font = .systemFont(ofSize: 11, weight: .heavy)
        badgeLabel.textColor = .white
        badgeLabel.textAlignment = .center
        badgeLabel.backgroundColor = UIColor.systemOrange
        badgeLabel.layer.cornerRadius = 11
        badgeLabel.layer.masksToBounds = true
        badgeLabel.isHidden = (chapter.status != .current)

        addSubview(starsStack)
        addSubview(circleView)
        addSubview(titleLabel)
        addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            // Stars above circle
            starsStack.bottomAnchor.constraint(equalTo: circleView.topAnchor, constant: -4),
            starsStack.centerXAnchor.constraint(equalTo: centerXAnchor),

            // Circle
            circleView.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            circleView.centerXAnchor.constraint(equalTo: centerXAnchor),
            circleView.widthAnchor.constraint(equalToConstant: d),
            circleView.heightAnchor.constraint(equalToConstant: d),

            // Icon
            iconLabel.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),

            // Badge pill below circle (current node)
            badgeLabel.topAnchor.constraint(equalTo: circleView.bottomAnchor, constant: 6),
            badgeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            badgeLabel.heightAnchor.constraint(equalToConstant: 22),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),

            // Title label (shown for non-current, hidden via alpha for current)
            titleLabel.topAnchor.constraint(equalTo: circleView.bottomAnchor, constant: 6),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // For current node, badge sits on top of titleLabel space
        if chapter.status == .current {
            titleLabel.isHidden = true
            badgeLabel.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        }

        // All statuses get tap gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    @objc private func handleTap() {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 5) {
                self.transform = .identity
            }
        }
        onTap?()
    }
}

// MARK: - Popup Card View

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
        // Card container
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 20
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.14
        containerView.layer.shadowRadius = 20
        containerView.layer.shadowOffset = CGSize(width: 0, height: 6)
        addSubview(containerView)

        // Status icon circle
        let statusView = UIView()
        statusView.translatesAutoresizingMaskIntoConstraints = false
        statusView.layer.cornerRadius = 28
        statusView.layer.masksToBounds = true

        let statusIcon = UILabel()
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.textAlignment = .center

        switch chapter.status {
        case .completed:
            statusView.backgroundColor = UIColor.systemOrange
            statusIcon.text = "✓"
            statusIcon.font = .systemFont(ofSize: 22, weight: .heavy)
            statusIcon.textColor = .white
        case .current:
            statusView.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
            statusIcon.text = "♩"
            statusIcon.font = .systemFont(ofSize: 24, weight: .bold)
            statusIcon.textColor = .systemOrange
        case .locked:
            statusView.backgroundColor = UIColor.systemGray5
            statusIcon.text = "🔒"
            statusIcon.font = .systemFont(ofSize: 20)
        }

        statusView.addSubview(statusIcon)

        // Title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = chapter.title
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .label

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = chapter.subtitle
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .systemGray
        subtitleLabel.numberOfLines = 2

        // Dismiss button
        let dismissBtn = UIButton(type: .system)
        dismissBtn.translatesAutoresizingMaskIntoConstraints = false
        dismissBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        dismissBtn.tintColor = .systemGray2
        dismissBtn.backgroundColor = UIColor.systemGray6
        dismissBtn.layer.cornerRadius = 15
        dismissBtn.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)

        // Primary action button
        let primaryBtn = UIButton(type: .system)
        primaryBtn.translatesAutoresizingMaskIntoConstraints = false
        primaryBtn.layer.cornerRadius = 24
        primaryBtn.layer.masksToBounds = true

        switch chapter.status {
        case .completed:
            let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            primaryBtn.setImage(UIImage(systemName: "arrow.counterclockwise", withConfiguration: cfg), for: .normal)
            primaryBtn.setTitle("  Practice Again", for: .normal)
            primaryBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
            primaryBtn.tintColor = .white
            primaryBtn.backgroundColor = .systemOrange
            primaryBtn.layer.shadowColor = UIColor.systemOrange.cgColor
            primaryBtn.layer.shadowOpacity = 0.35
            primaryBtn.layer.shadowRadius = 8
            primaryBtn.layer.shadowOffset = CGSize(width: 0, height: 4)
            primaryBtn.layer.masksToBounds = false
        case .current:
            let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            primaryBtn.setImage(UIImage(systemName: "play.fill", withConfiguration: cfg), for: .normal)
            primaryBtn.setTitle("  Start Lesson", for: .normal)
            primaryBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
            primaryBtn.tintColor = .white
            primaryBtn.backgroundColor = .systemOrange
            primaryBtn.layer.shadowColor = UIColor.systemOrange.cgColor
            primaryBtn.layer.shadowOpacity = 0.35
            primaryBtn.layer.shadowRadius = 8
            primaryBtn.layer.shadowOffset = CGSize(width: 0, height: 4)
            primaryBtn.layer.masksToBounds = false
        case .locked:
            let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            primaryBtn.setImage(UIImage(systemName: "lock.fill", withConfiguration: cfg), for: .normal)
            primaryBtn.setTitle("  Locked", for: .normal)
            primaryBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
            primaryBtn.tintColor = UIColor.systemGray2
            primaryBtn.backgroundColor = UIColor.systemGray5
            primaryBtn.isEnabled = false
        }

        primaryBtn.addTarget(self, action: #selector(didTapPrimary), for: .touchUpInside)

        containerView.addSubview(statusView)
        containerView.addSubview(statusIcon)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(dismissBtn)
        containerView.addSubview(primaryBtn)

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



// MARK: - LessonMapViewController

class LessonMapViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private var popupCard: ChapterPopupCard?
    private var popupOverlay: UIView?
    private var nodeViews: [ChapterNodeView] = []
    
    // Mutable chapters so we can unlock them at runtime
    private var chapters: [MusicChapter] = allChapters

    private var progress: Float {
        let completed = chapters.filter { $0.status == .completed }.count
        return Float(completed) / Float(chapters.count)
    }
    private let nodeSize: CGFloat = ChapterNodeView.diameter
    // Tighter vertical spacing to match reference (not too elongated)
    private let vSpacing: CGFloat = 130

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 1, green: 0.98, blue: 0.95, alpha: 1)
        setupScrollView()
        setupHeader()
        setupPath()
    }

    // MARK: - Scroll View

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - Header

    private func setupHeader() {
        // Title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Basics"
        titleLabel.font = .systemFont(ofSize: 30, weight: .heavy)
        titleLabel.textColor = .label

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Interactive lessons"
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .systemGray

        // Avatar circle (photo-like)
        let avatarView = UIView()
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.2)
        avatarView.layer.cornerRadius = 22
        avatarView.layer.masksToBounds = true
        avatarView.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.4).cgColor
        avatarView.layer.borderWidth = 2

        let avatarIcon = UILabel()
        avatarIcon.translatesAutoresizingMaskIntoConstraints = false
        avatarIcon.text = "👩"
        avatarIcon.font = .systemFont(ofSize: 22)
        avatarView.addSubview(avatarIcon)

        // Progress row
        let progressLabel = UILabel()
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        let pText = NSMutableAttributedString(string: "PROGRESS    ", attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.systemGray
        ])
        pText.append(NSAttributedString(string: "\(Int(progress * 100))%", attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.systemOrange
        ]))
        progressLabel.attributedText = pText

        let progressBG = UIView()
        progressBG.translatesAutoresizingMaskIntoConstraints = false
        progressBG.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.18)
        progressBG.layer.cornerRadius = 4

        let progressFill = UIView()
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = .systemOrange
        progressFill.layer.cornerRadius = 4
        progressBG.addSubview(progressFill)

        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(avatarView)
        contentView.addSubview(progressLabel)
        contentView.addSubview(progressBG)

        NSLayoutConstraint.activate([
            avatarIcon.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarIcon.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            avatarView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            avatarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            avatarView.widthAnchor.constraint(equalToConstant: 44),
            avatarView.heightAnchor.constraint(equalToConstant: 44),

            progressLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            progressLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            progressBG.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 5),
            progressBG.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            progressBG.widthAnchor.constraint(equalToConstant: 130),
            progressBG.heightAnchor.constraint(equalToConstant: 7),

            progressFill.leadingAnchor.constraint(equalTo: progressBG.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressBG.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBG.bottomAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressBG.widthAnchor, multiplier: CGFloat(progress)),
        ])
    }

    // MARK: - Path & Nodes

    private func setupPath() {
        let totalHeight = CGFloat(chapters.count) * vSpacing + 140
        let pathTopOffset: CGFloat = 120

        let w = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width

        let pathCanvas = PathCanvasView(
            chapters: chapters,
            nodeSize: nodeSize,
            vSpacing: vSpacing,
            width: w
        )
        pathCanvas.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pathCanvas)

        NSLayoutConstraint.activate([
            pathCanvas.topAnchor.constraint(equalTo: contentView.topAnchor, constant: pathTopOffset),
            pathCanvas.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pathCanvas.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pathCanvas.heightAnchor.constraint(equalToConstant: totalHeight),
            pathCanvas.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])

        for (i, chapter) in chapters.enumerated() {
            let node = ChapterNodeView(chapter: chapter)
            node.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(node)

            let pos = nodePosition(index: i, width: w)
            // node width: enough room for title
            let nodeContainerW: CGFloat = nodeSize + 40
            NSLayoutConstraint.activate([
                node.topAnchor.constraint(equalTo: contentView.topAnchor, constant: pathTopOffset + pos.y),
                node.centerXAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pos.x + nodeSize / 2),
                node.widthAnchor.constraint(equalToConstant: nodeContainerW),
            ])

            let capturedChapter = chapter
            let capturedIndex = i
            node.onTap = { [weak self] in
                self?.showPopup(for: capturedChapter, nodeIndex: capturedIndex)
            }
            nodeViews.append(node)
        }
    }

    /// Positions for nodes: gentle S-curve, center-biased (not edge-to-edge)
    private func nodePosition(index: Int, width: CGFloat) -> CGPoint {
        let y = CGFloat(index) * vSpacing + 10
        // Inset from edges so path is compact like the reference
        let inset: CGFloat = width * 0.12
        let leftX  = inset
        let rightX = width - nodeSize - inset - 40
        let x: CGFloat

        // Pattern from image: right, left, center-right, left, ...
        // Simpler: alternate right/left but with moderate insets
        switch index % 4 {
        case 0: x = rightX
        case 1: x = leftX
        case 2: x = rightX * 0.75 + leftX * 0.25
        case 3: x = leftX + (rightX - leftX) * 0.2
        default: x = index % 2 == 0 ? rightX : leftX
        }
        return CGPoint(x: x, y: y)
    }

    // MARK: - Popup

    private func showPopup(for chapter: MusicChapter, nodeIndex: Int) {
        // Always dismiss existing popup first (animated = false so no overlap)
        dismissPopup(animated: false)

        // Transparent overlay to catch outside taps
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.08)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissPopupAnimated))
        overlay.addGestureRecognizer(dismissTap)
        view.addSubview(overlay)
        popupOverlay = overlay

        let card = ChapterPopupCard(chapter: chapter)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.alpha = 0
        card.transform = CGAffineTransform(translationX: 0, y: 24)
        view.addSubview(card)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])

        card.onDismiss = { [weak self] in self?.dismissPopupAnimated() }
        card.onPrimary = { [weak self] in
            guard let self = self else { return }
            guard chapter.status != .locked else { return }
            self.dismissPopup(animated: true)
            let vc = LessonDetailViewController(lesson: chapter.lesson)
            vc.modalPresentationStyle = .fullScreen
            // Pass completion callback so L2 can signal back
            vc.onLessonCompleted = { [weak self] (stars: Int) in
                self?.handleLessonCompleted(chapterIndex: nodeIndex, stars: stars)
            }
            self.present(vc, animated: true)
        }

        popupCard = card

        UIView.animate(withDuration: 0.38, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.4) {
            card.alpha = 1
            card.transform = .identity
        }
    }

    // MARK: - Lesson Completion & Unlock

    /// Called when the user finishes a lesson at 100%
    func handleLessonCompleted(chapterIndex: Int, stars: Int = 3) {
        guard chapterIndex < chapters.count else { return }

        // Mark current chapter as completed (3 stars)
        let completed = chapters[chapterIndex]
        chapters[chapterIndex] = MusicChapter(
            title: completed.title,
            subtitle: completed.subtitle,
            status: .completed,
            stars: stars,
            lesson: completed.lesson
        )

        // Unlock next chapter
        let nextIndex = chapterIndex + 1
        var unlockedTitle: String? = nil
        if nextIndex < chapters.count {
            let next = chapters[nextIndex]
            if next.status == .locked {
                chapters[nextIndex] = MusicChapter(
                    title: next.title,
                    subtitle: next.subtitle,
                    status: .current,
                    stars: 0,
                    lesson: next.lesson
                )
                unlockedTitle = next.title
            }
        }

        // Rebuild the path UI to reflect new states
        rebuildPath()

        // Show the "Next Lesson Unlocked" banner if applicable
        if let title = unlockedTitle {
            showUnlockBanner(lessonTitle: title)
        }
    }

    private func rebuildPath() {
        // Remove old nodes and path canvas
        nodeViews.forEach { $0.removeFromSuperview() }
        nodeViews.removeAll()
        // Remove old PathCanvasView
        contentView.subviews
            .filter { $0 is PathCanvasView }
            .forEach { $0.removeFromSuperview() }
        setupPath()
    }

    // MARK: - Unlock Banner Popup

    private func showUnlockBanner(lessonTitle: String) {
        let banner = UnlockBannerView(lessonTitle: lessonTitle)
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.alpha = 0
        banner.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        view.addSubview(banner)

        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            banner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        // Dim overlay
        let dimOverlay = UIView(frame: view.bounds)
        dimOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dimOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimOverlay.alpha = 0
        view.insertSubview(dimOverlay, belowSubview: banner)

        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.5) {
            banner.alpha = 1
            banner.transform = .identity
            dimOverlay.alpha = 1
        }

        banner.onContinue = {
            UIView.animate(withDuration: 0.25, animations: {
                banner.alpha = 0
                banner.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                dimOverlay.alpha = 0
            }) { _ in
                banner.removeFromSuperview()
                dimOverlay.removeFromSuperview()
            }
        }

        // Auto-dismiss after 4 seconds if user doesn't tap
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            guard banner.superview != nil else { return }
            banner.onContinue?()
        }
    }

    @objc private func dismissPopupAnimated() {
        dismissPopup(animated: true)
    }

    private func dismissPopup(animated: Bool) {
        guard let card = popupCard else { return }
        if animated {
            UIView.animate(withDuration: 0.22, animations: {
                card.alpha = 0
                card.transform = CGAffineTransform(translationX: 0, y: 18)
            }) { _ in
                card.removeFromSuperview()
            }
            UIView.animate(withDuration: 0.18) {
                self.popupOverlay?.alpha = 0
            } completion: { _ in
                self.popupOverlay?.removeFromSuperview()
                self.popupOverlay = nil
            }
        } else {
            card.removeFromSuperview()
            popupOverlay?.removeFromSuperview()
            popupOverlay = nil
        }
        popupCard = nil
    }
}

// MARK: - Unlock Banner View

class UnlockBannerView: UIView {

    var onContinue: (() -> Void)?

    init(lessonTitle: String) {
        super.init(frame: .zero)
        setupView(lessonTitle: lessonTitle)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupView(lessonTitle: String) {
        backgroundColor = .white
        layer.cornerRadius = 28
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 24
        layer.shadowOffset = CGSize(width: 0, height: 8)

        // Confetti-like top accent bar
        let accentBar = UIView()
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.backgroundColor = .systemOrange
        accentBar.layer.cornerRadius = 4
        addSubview(accentBar)

        // Lock-open icon circle
        let iconCircle = UIView()
        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
        iconCircle.layer.cornerRadius = 38
        addSubview(iconCircle)

        let iconLabel = UILabel()
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.text = "🔓"
        iconLabel.font = .systemFont(ofSize: 40)
        iconLabel.textAlignment = .center
        iconCircle.addSubview(iconLabel)

        // Stars row
        let starsStack = UIStackView()
        starsStack.translatesAutoresizingMaskIntoConstraints = false
        starsStack.axis = .horizontal
        starsStack.spacing = 4
        starsStack.alignment = .center
        for _ in 0..<3 {
            let s = UILabel()
            s.text = "⭐"
            s.font = .systemFont(ofSize: 22)
            starsStack.addArrangedSubview(s)
        }
        addSubview(starsStack)

        // Title
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Lesson Unlocked!"
        titleLabel.font = .systemFont(ofSize: 24, weight: .heavy)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        addSubview(titleLabel)

        // Lesson name pill
        let pillView = UIView()
        pillView.translatesAutoresizingMaskIntoConstraints = false
        pillView.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
        pillView.layer.cornerRadius = 16
        addSubview(pillView)

        let pillLabel = UILabel()
        pillLabel.translatesAutoresizingMaskIntoConstraints = false
        pillLabel.text = "🎵  \(lessonTitle)"
        pillLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        pillLabel.textColor = .systemOrange
        pillLabel.textAlignment = .center
        pillView.addSubview(pillLabel)

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Great work! Your next lesson is ready to explore."
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .systemGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        addSubview(subtitleLabel)

        // Continue button
        let continueBtn = UIButton(type: .system)
        continueBtn.translatesAutoresizingMaskIntoConstraints = false
        continueBtn.setTitle("Continue  🎉", for: .normal)
        continueBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        continueBtn.setTitleColor(.white, for: .normal)
        continueBtn.backgroundColor = .systemOrange
        continueBtn.layer.cornerRadius = 26
        continueBtn.layer.shadowColor = UIColor.systemOrange.cgColor
        continueBtn.layer.shadowOpacity = 0.35
        continueBtn.layer.shadowRadius = 12
        continueBtn.layer.shadowOffset = CGSize(width: 0, height: 5)
        continueBtn.addTarget(self, action: #selector(didTapContinue), for: .touchUpInside)
        addSubview(continueBtn)

        NSLayoutConstraint.activate([
            accentBar.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            accentBar.centerXAnchor.constraint(equalTo: centerXAnchor),
            accentBar.widthAnchor.constraint(equalToConstant: 48),
            accentBar.heightAnchor.constraint(equalToConstant: 5),

            iconCircle.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: 20),
            iconCircle.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 76),
            iconCircle.heightAnchor.constraint(equalToConstant: 76),

            iconLabel.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),

            starsStack.topAnchor.constraint(equalTo: iconCircle.bottomAnchor, constant: 14),
            starsStack.centerXAnchor.constraint(equalTo: centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: starsStack.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            pillView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            pillView.centerXAnchor.constraint(equalTo: centerXAnchor),

            pillLabel.topAnchor.constraint(equalTo: pillView.topAnchor, constant: 10),
            pillLabel.bottomAnchor.constraint(equalTo: pillView.bottomAnchor, constant: -10),
            pillLabel.leadingAnchor.constraint(equalTo: pillView.leadingAnchor, constant: 18),
            pillLabel.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -18),

            subtitleLabel.topAnchor.constraint(equalTo: pillView.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            continueBtn.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            continueBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            continueBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            continueBtn.heightAnchor.constraint(equalToConstant: 52),
            continueBtn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
        ])
    }

    @objc private func didTapContinue() {
        onContinue?()
    }
}

// MARK: - Path Canvas

class PathCanvasView: UIView {
    let chapters: [MusicChapter]
    let nodeSize: CGFloat
    let vSpacing: CGFloat
    let canvasWidth: CGFloat

    // Fixed watermark positions — pre-calculated to not overlap nodes
    // Format: (x, y, iconIndex, rotation degrees)
    private let watermarkDefs: [(CGFloat, CGFloat, Int, CGFloat)] = [
        (0.08,  0.06, 0, -15),   // music note top-left
        (0.78,  0.12, 1,  10),   // staff lines top-right
        (0.05,  0.28, 2,  -8),   // swirl left
        (0.72,  0.34, 0,  20),   // music note right
        (0.10,  0.50, 1, -12),   // staff lines left
        (0.75,  0.56, 2,  15),   // swirl right
        (0.06,  0.70, 0,  -5),   // note lower-left
        (0.78,  0.76, 1,  18),   // staff right
        (0.12,  0.88, 2, -20),   // swirl bottom-left
    ]

    init(chapters: [MusicChapter], nodeSize: CGFloat, vSpacing: CGFloat, width: CGFloat) {
        self.chapters = chapters
        self.nodeSize = nodeSize
        self.vSpacing = vSpacing
        self.canvasWidth = width
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Draw watermarks first (behind path)
        drawWatermarks(ctx: ctx, rect: rect)

        // Draw dashed path
        ctx.setStrokeColor(UIColor.systemOrange.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(5)
        ctx.setLineDash(phase: 0, lengths: [12, 9])
        ctx.setLineCap(.round)

        for i in 0..<chapters.count - 1 {
            let from = nodeCenter(index: i)
            let to   = nodeCenter(index: i + 1)

            // True S-curve: cp1 stays near `from` x, cp2 stays near `to` x
            // This creates a smooth flowing S rather than a sharp crossing
            let cp1 = CGPoint(x: from.x, y: from.y + vSpacing * 0.5)
            let cp2 = CGPoint(x: to.x,   y: to.y   - vSpacing * 0.5)

            ctx.move(to: from)
            ctx.addCurve(to: to, control1: cp1, control2: cp2)
        }
        ctx.strokePath()
    }

    private func drawWatermarks(ctx: CGContext, rect: CGRect) {
        let h = rect.height

        // Icon 0: music note ♩, Icon 1: staff lines (drawn), Icon 2: treble-like swirl ♬
        let iconChars = ["♩", "♫", "♬"]
        let fontSize: CGFloat = 32
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.systemOrange.withAlphaComponent(0.18)
        ]
        // Staff lines icon — drawn as 4 horizontal lines
        func drawStaffLines(at center: CGPoint, rotation: CGFloat) {
            ctx.saveGState()
            ctx.translateBy(x: center.x, y: center.y)
            ctx.rotate(by: rotation * .pi / 180)
            ctx.setStrokeColor(UIColor.systemOrange.withAlphaComponent(0.18).cgColor)
            ctx.setLineWidth(2)
            ctx.setLineDash(phase: 0, lengths: [])
            let lineW: CGFloat = 28
            let lineSpacing: CGFloat = 5
            let totalH = lineSpacing * 3
            for j in 0..<4 {
                let ly = -totalH / 2 + CGFloat(j) * lineSpacing
                ctx.move(to: CGPoint(x: -lineW/2, y: ly))
                ctx.addLine(to: CGPoint(x: lineW/2, y: ly))
            }
            ctx.strokePath()
            ctx.restoreGState()
        }

        for def in watermarkDefs {
            let (xRatio, yRatio, iconIdx, rotation) = def
            let cx = xRatio * canvasWidth
            let cy = yRatio * h

            if iconIdx == 1 {
                // Staff lines
                drawStaffLines(at: CGPoint(x: cx, y: cy), rotation: rotation)
            } else {
                let char = iconChars[iconIdx % iconChars.count]
                ctx.saveGState()
                ctx.translateBy(x: cx, y: cy)
                ctx.rotate(by: rotation * .pi / 180)
                let size = (char as NSString).size(withAttributes: attrs)
                (char as NSString).draw(at: CGPoint(x: -size.width/2, y: -size.height/2), withAttributes: attrs)
                ctx.restoreGState()
            }
        }
    }

    func nodeCenter(index: Int) -> CGPoint {
        let y = CGFloat(index) * vSpacing + 10 + nodeSize / 2
        let inset: CGFloat = canvasWidth * 0.12
        let leftX  = inset + nodeSize / 2
        let rightX = canvasWidth - nodeSize / 2 - inset - 40

        let x: CGFloat
        switch index % 4 {
        case 0: x = rightX
        case 1: x = leftX
        case 2: x = rightX * 0.75 + leftX * 0.25
        case 3: x = leftX + (rightX - leftX) * 0.2
        default: x = index % 2 == 0 ? rightX : leftX
        }
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Lesson Detail (placeholder)
