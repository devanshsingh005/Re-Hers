import UIKit

// MARK: - Constants
private enum PG {
    static let cardBg = UIColor(hex: "#4A4A4A")
    static let orange = UIColor(hex: "#FFA726")
    static let white70 = UIColor.white.withAlphaComponent(0.7)
    static let white20 = UIColor.white.withAlphaComponent(0.2)

    static let radius: CGFloat = 16
    static let pad: CGFloat = 20
    static let hPad: CGFloat = 24

    static let titleSize: CGFloat = 20
    static let segH: CGFloat = 28
    static let segW: CGFloat = 140

    static let graphTop: CGFloat = 16
    static let barSpacing: CGFloat = 24
    static let barW: CGFloat = 18

    static let barHeights: [CGFloat] = [55,100,150,120,100,135,150]
    static let days = ["mon","tues","wed","thurs","fri","sat","sun"]

    static let labelSize: CGFloat = 12
}

// MARK: - Hex Color
extension UIColor {
    convenience init(hex: String) {
        let clean = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&v)

        let a,r,g,b: UInt64
        switch clean.count {
        case 3: (a,r,g,b) = (255,(v>>8)*17,(v>>4&0xF)*17,(v&0xF)*17)
        case 6: (a,r,g,b) = (255,v>>16,v>>8&0xFF,v&0xFF)
        case 8: (a,r,g,b) = (v>>24,v>>16&0xFF,v>>8&0xFF,v&0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }

        self.init(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: CGFloat(a)/255)
    }
}

// MARK: - LayoutTrackingView
final class LayoutTrackingView: UIView {
    var onLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

// MARK: - Practice Graph
final class PracticeGraphCardView: UIView {

    private let cardView = LayoutTrackingView()
    private let titleLabel = UILabel()
    private let segmented = UISegmentedControl(items: ["7 Days","1 Month"])
    private let barStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        buildBars()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {

        cardView.backgroundColor = PG.cardBg
        cardView.layer.cornerRadius = PG.radius
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let dotted = CAShapeLayer()
        dotted.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        dotted.lineDashPattern = [4,3]
        dotted.lineWidth = 2
        dotted.fillColor = UIColor.clear.cgColor
        cardView.layer.addSublayer(dotted)

        cardView.onLayout = { [weak cardView] in
            guard let cv = cardView else { return }
            dotted.frame = cv.bounds
            dotted.path = UIBezierPath(
                roundedRect: cv.bounds,
                cornerRadius: PG.radius
            ).cgPath
        }

        titleLabel.text = "Practice Graph"
        titleLabel.font = .systemFont(ofSize: PG.titleSize, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        segmented.selectedSegmentIndex = 0
        segmented.backgroundColor = PG.white20
        segmented.selectedSegmentTintColor = .white
        segmented.layer.cornerRadius = PG.segH/2
        segmented.clipsToBounds = true
        segmented.translatesAutoresizingMaskIntoConstraints = false

        segmented.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        segmented.setTitleTextAttributes([.foregroundColor: PG.white70], for: .normal)

        cardView.addSubview(titleLabel)
        cardView.addSubview(segmented)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: PG.pad),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: PG.pad),

            segmented.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            segmented.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -PG.pad),
            segmented.widthAnchor.constraint(equalToConstant: PG.segW),
            segmented.heightAnchor.constraint(equalToConstant: PG.segH)
        ])

        barStack.axis = .horizontal
        barStack.spacing = PG.barSpacing
        barStack.distribution = .equalSpacing
        barStack.alignment = .bottom
        barStack.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(barStack)

        NSLayoutConstraint.activate([
            barStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: PG.graphTop),
            barStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: PG.pad),
            barStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -PG.pad),
            barStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -PG.pad)
        ])
    }

    private func buildBars() {
        barStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (i,h) in PG.barHeights.enumerated() {
            let v = UIStackView()
            v.axis = .vertical
            v.alignment = .center
            v.spacing = 8

            let bar = UIView()
            bar.backgroundColor = i < 2 ? .white : PG.orange
            bar.layer.cornerRadius = PG.barW/2
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.widthAnchor.constraint(equalToConstant: PG.barW).isActive = true
            bar.heightAnchor.constraint(equalToConstant: h).isActive = true

            let lbl = UILabel()
            lbl.text = PG.days[i]
            lbl.font = .systemFont(ofSize: PG.labelSize)
            lbl.textColor = PG.white70
            lbl.textAlignment = .center

            v.addArrangedSubview(bar)
            v.addArrangedSubview(lbl)
            barStack.addArrangedSubview(v)
        }
    }
}


// MARK: - MAIN SCREEN
final class UserProfileViewController: UIViewController {

    private let navBar = TopNavBar()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let graphCard = PracticeGraphCardView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupNavBar()
        addTopGradient()
        setupScroll()

        addDailyGoalCard()
        addPracticeGraph()
        addStats()
        addMostPlayed()
    }

    // MARK: NAVBAR
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false

        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        navBar.isChordIconVisible = true

        navBar.chordAction = { [weak self] in
            let vc = ChordRecognitionViewController()
            self?.navigationController?.pushViewController(vc, animated: true)
        }

        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 55)
        ])
    }

    // MARK: GRADIENT (EXACT LIKE SCREENSHOT)
    private func addTopGradient() {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(hex: "#FFA726").cgColor,  // strong orange
            UIColor.white.cgColor             // fade to white
        ]
        gradient.locations = [0, 0.42]  // fade at ~42%
        gradient.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 380)

        let gView = UIView(frame: gradient.frame)
        gView.layer.addSublayer(gradient)
        gView.isUserInteractionEnabled = false

        view.insertSubview(gView, belowSubview: navBar)
    }

    // MARK: SCROLLER
    private func setupScroll() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        contentStack.axis = .vertical
        contentStack.spacing = 22

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    // MARK: DAILY GOAL (FINAL FIXED VERSION)
    private func addDailyGoalCard() {

        let card = UIView()
        card.backgroundColor = UIColor(hex: "#333333")
        card.layer.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false
        card.heightAnchor.constraint(equalToConstant: 53).isActive = true

        // horizontal layout
        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 12
        hStack.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "Daily goal"
        title.font = .systemFont(ofSize: 14)
        title.textColor = .white

        let progressHolder = UIView()
        progressHolder.translatesAutoresizingMaskIntoConstraints = false
        progressHolder.widthAnchor.constraint(equalToConstant: 125).isActive = true // FIXED WIDTH (SOLVES YOUR ISSUE)

        let progress = UIProgressView()
        progress.progress = 0.7
        progress.progressTintColor = .systemGreen
        progress.trackTintColor = UIColor.white.withAlphaComponent(0.2)
        progress.translatesAutoresizingMaskIntoConstraints = false

        progressHolder.addSubview(progress)
        NSLayoutConstraint.activate([
            progress.leadingAnchor.constraint(equalTo: progressHolder.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: progressHolder.trailingAnchor),
            progress.centerYAnchor.constraint(equalTo: progressHolder.centerYAnchor)
        ])

        let mins = UILabel()
        mins.text = "20 mins"
        mins.font = .systemFont(ofSize: 13)
        mins.textColor = .white

        hStack.addArrangedSubview(title)
        hStack.addArrangedSubview(progressHolder)
        hStack.addArrangedSubview(mins)

        card.addSubview(hStack)

        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            hStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            hStack.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])

        contentStack.addArrangedSubview(card)

        // match graph padding
        card.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: PG.hPad).isActive = true
        card.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -PG.hPad).isActive = true
    }

    // MARK: PRACTICE GRAPH
    private func addPracticeGraph() {
        graphCard.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(graphCard)

        graphCard.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: PG.hPad).isActive = true
        graphCard.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -PG.hPad).isActive = true
    }

    // MARK: STATS
    private func addStats() {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.alignment = .center

        row.addArrangedSubview(makeStat(icon: "flame.fill", value: "5", label: "Days Streak"))
        row.addArrangedSubview(makeStat(icon: "timer", value: "24", label: "Hours Spent"))

        contentStack.addArrangedSubview(row)
    }

    private func makeStat(icon: String, value: String, label: String) -> UIView {
        let v = UIStackView()
        v.axis = .vertical
        v.alignment = .center
        v.spacing = 4

        let img = UIImageView(image: UIImage(systemName: icon))
        img.tintColor = .red
        img.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 32, weight: .bold)

        let sub = UILabel()
        sub.text = label
        sub.font = .systemFont(ofSize: 14)
        sub.textColor = .gray

        v.addArrangedSubview(img)
        v.addArrangedSubview(valueLabel)
        v.addArrangedSubview(sub)

        return v
    }

    // MARK: MOST PLAYED
    private func addMostPlayed() {
        let title = UILabel()
        title.text = "Most Played"
        title.font = .systemFont(ofSize: 18, weight: .semibold)

        contentStack.addArrangedSubview(title)

        let list = UIStackView()
        list.axis = .vertical
        list.spacing = 16

        list.addArrangedSubview(makeSong("Go Away", artist: "Weezer", count: "23"))
        list.addArrangedSubview(makeSong("Ride Home", artist: "Weezer", count: "16"))
        list.addArrangedSubview(makeSong("Holiday", artist: "Weezer", count: "18"))
        list.addArrangedSubview(makeSong("Island in the Sun", artist: "Weezer", count: "12"))
        list.addArrangedSubview(makeSong("Buddy Holly", artist: "Weezer", count: "10"))

        contentStack.addArrangedSubview(list)

        list.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: PG.hPad).isActive = true
        list.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: -PG.hPad).isActive = true
    }

    private func makeSong(_ title: String, artist: String, count: String) -> UIView {

        let card = UIView()
        card.backgroundColor = UIColor(white: 0.95, alpha: 1)
        card.layer.cornerRadius = 24
        card.heightAnchor.constraint(equalToConstant: 90).isActive = true

        let h = UIStackView()
        h.axis = .horizontal
        h.spacing = 14
        h.alignment = .center
        h.translatesAutoresizingMaskIntoConstraints = false

        let cover = UIView()
        cover.backgroundColor = .lightGray
        cover.layer.cornerRadius = 12
        cover.translatesAutoresizingMaskIntoConstraints = false
        cover.widthAnchor.constraint(equalToConstant: 70).isActive = true
        cover.heightAnchor.constraint(equalToConstant: 70).isActive = true

        let info = UIStackView()
        info.axis = .vertical
        info.spacing = 2

        let t = UILabel()
        t.text = title
        t.font = .systemFont(ofSize: 18, weight: .semibold)

        let a = UILabel()
        a.text = artist
        a.textColor = .gray
        a.font = .systemFont(ofSize: 13)

        info.addArrangedSubview(t)
        info.addArrangedSubview(a)

        let right = UILabel()
        right.text = "\(count) Times"
        right.font = .systemFont(ofSize: 15)

        h.addArrangedSubview(cover)
        h.addArrangedSubview(info)
        h.addArrangedSubview(right)

        card.addSubview(h)

        NSLayoutConstraint.activate([
            h.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            h.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            h.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])

        return card
    }
}
