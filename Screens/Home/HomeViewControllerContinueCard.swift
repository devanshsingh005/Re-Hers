//
//  HomeViewControllerContinueCard.swift
//  Re-Hearse_v1
//

import UIKit

struct PracticeCardTheme {
    let start: UIColor
    let end: UIColor
    let shadow: UIColor
    let bgLight: UIColor
    let bgDark: UIColor
    
    static let palettes: [PracticeCardTheme] = [
        // Deep Purple
        PracticeCardTheme(
            start: UIColor(red: 0.23, green: 0.00, blue: 0.48, alpha: 1.0),
            end: UIColor(red: 0.42, green: 0.00, blue: 0.71, alpha: 1.0),
            shadow: UIColor(red: 0.23, green: 0.00, blue: 0.48, alpha: 1.0),
            bgLight: UIColor(hex: "#F4F2F8"), bgDark: UIColor(hex: "#0A0514")
        ),
        // Ocean Blue
        PracticeCardTheme(
            start: UIColor(red: 0.00, green: 0.23, blue: 0.48, alpha: 1.0),
            end: UIColor(red: 0.00, green: 0.40, blue: 0.80, alpha: 1.0),
            shadow: UIColor(red: 0.00, green: 0.23, blue: 0.48, alpha: 1.0),
            bgLight: UIColor(hex: "#F2F5F8"), bgDark: UIColor(hex: "#050A14")
        ),
        // Crimson Red
        PracticeCardTheme(
            start: UIColor(red: 0.48, green: 0.00, blue: 0.08, alpha: 1.0),
            end: UIColor(red: 0.71, green: 0.00, blue: 0.14, alpha: 1.0),
            shadow: UIColor(red: 0.48, green: 0.00, blue: 0.08, alpha: 1.0),
            bgLight: UIColor(hex: "#F8F2F3"), bgDark: UIColor(hex: "#140508")
        ),
        // Teal Aurora
        PracticeCardTheme(
            start: UIColor(red: 0.00, green: 0.45, blue: 0.45, alpha: 1.0),
            end: UIColor(red: 0.00, green: 0.65, blue: 0.65, alpha: 1.0),
            shadow: UIColor(red: 0.00, green: 0.45, blue: 0.45, alpha: 1.0),
            bgLight: UIColor(hex: "#F2F8F8"), bgDark: UIColor(hex: "#051414")
        ),
        // Golden Hour
        PracticeCardTheme(
            start: UIColor(red: 0.65, green: 0.45, blue: 0.00, alpha: 1.0),
            end: UIColor(red: 0.85, green: 0.65, blue: 0.00, alpha: 1.0),
            shadow: UIColor(red: 0.65, green: 0.45, blue: 0.00, alpha: 1.0),
            bgLight: UIColor(hex: "#F8F6EF"), bgDark: UIColor(hex: "#141105")
        ),
        // Indigo Dusk
        PracticeCardTheme(
            start: UIColor(red: 0.25, green: 0.20, blue: 0.60, alpha: 1.0),
            end: UIColor(red: 0.45, green: 0.40, blue: 0.85, alpha: 1.0),
            shadow: UIColor(red: 0.25, green: 0.20, blue: 0.60, alpha: 1.0),
            bgLight: UIColor(hex: "#F4F3F8"), bgDark: UIColor(hex: "#0B0A1A")
        ),
        // Slate Glass
        PracticeCardTheme(
            start: UIColor(red: 0.20, green: 0.25, blue: 0.30, alpha: 1.0),
            end: UIColor(red: 0.35, green: 0.45, blue: 0.55, alpha: 1.0),
            shadow: UIColor(red: 0.20, green: 0.25, blue: 0.30, alpha: 1.0),
            bgLight: UIColor(hex: "#F4F5F6"), bgDark: UIColor(hex: "#0A0D10")
        )
    ]
    
    static func theme(for title: String) -> PracticeCardTheme {
        let hash = abs(title.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        return palettes[hash % palettes.count]
    }
}

final class PracticeCardBackgroundView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let musicNoteView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        gradientLayer.colors = [
            UIColor(red: 0.23, green: 0.00, blue: 0.48, alpha: 1.0).cgColor,
            UIColor(red: 0.42, green: 0.00, blue: 0.71, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)

        musicNoteView.image = UIImage(systemName: "music.note")
        musicNoteView.tintColor = .white.withAlphaComponent(0.08)
        musicNoteView.contentMode = .scaleAspectFit
        musicNoteView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(musicNoteView)

        NSLayoutConstraint.activate([
            musicNoteView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 40),
            musicNoteView.topAnchor.constraint(equalTo: topAnchor, constant: -20),
            musicNoteView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.6),
            musicNoteView.heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.6)
        ])
    }
    
    func updateColors(start: UIColor, end: UIColor) {
        UIView.animate(withDuration: 0.4) {
            self.gradientLayer.colors = [start.cgColor, end.cgColor]
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

extension HomeViewController {
    func addTopPracticeCardView() -> UIView {
        let wrapper = PracticeCardBackgroundView()
        wrapper.tag = 991
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.layer.cornerRadius = 28
        wrapper.layer.masksToBounds = true
        
        let outerContainer = UIView()
        outerContainer.tag = 992
        outerContainer.translatesAutoresizingMaskIntoConstraints = false
        outerContainer.addSubview(wrapper)
        
        NSLayoutConstraint.activate([
            wrapper.topAnchor.constraint(equalTo: outerContainer.topAnchor),
            wrapper.leadingAnchor.constraint(equalTo: outerContainer.leadingAnchor),
            wrapper.trailingAnchor.constraint(equalTo: outerContainer.trailingAnchor),
            wrapper.bottomAnchor.constraint(equalTo: outerContainer.bottomAnchor),
        ])

        // Tags Container (Top Left)
        let tagsStack = UIStackView()
        tagsStack.axis = .horizontal
        tagsStack.spacing = 8
        tagsStack.translatesAutoresizingMaskIntoConstraints = false
        self.topCardTagsStack = tagsStack
        wrapper.addSubview(tagsStack)

        // Initial placeholders
        tagsStack.addArrangedSubview(makePillTag(text: "MEDIUM"))
        tagsStack.addArrangedSubview(makePillTag(text: "RIGHT_ONLY"))

        // Dynamic Title
        let titleLabel = UILabel()
        titleLabel.text = "Twinkle Twinkle Little Star"
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.topCardTitleLabel = titleLabel
        wrapper.addSubview(titleLabel)

        // Replacement for Progress/Mastery: Song Insights Row
        let detailsStack = UIStackView()
        detailsStack.axis = .horizontal
        detailsStack.distribution = .equalCentering
        detailsStack.translatesAutoresizingMaskIntoConstraints = false
        self.topCardDetailsStack = detailsStack
        
        detailsStack.addArrangedSubview(self.makeDetailItem(icon: "gauge.with.needle", text: "Intermediate"))
        detailsStack.addArrangedSubview(self.makeDetailItem(icon: "person.fill", text: "Traditional"))
        detailsStack.addArrangedSubview(self.makeDetailItem(icon: "metronome", text: "72 BPM"))

        let startBtn = UIButton(type: .system)
        startBtn.setTitle("Start Practice", for: .normal)
        startBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        startBtn.setTitleColor(.white, for: .normal)
        startBtn.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        startBtn.layer.cornerRadius = 20
        startBtn.translatesAutoresizingMaskIntoConstraints = false
        
        startBtn.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            NavigationBarHelper.animateButtonPress(startBtn) {
                self.openPianoPage()
            }
        }, for: .touchUpInside)

        wrapper.addSubview(detailsStack)
        wrapper.addSubview(startBtn)

        NSLayoutConstraint.activate([
            tagsStack.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 16),
            tagsStack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 24),

            titleLabel.topAnchor.constraint(equalTo: tagsStack.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -24),

            detailsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            detailsStack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 24),
            detailsStack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -24),

            startBtn.topAnchor.constraint(equalTo: detailsStack.bottomAnchor, constant: 24),
            startBtn.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 24),
            startBtn.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -24),
            startBtn.heightAnchor.constraint(equalToConstant: 54),
            startBtn.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -24)
        ])
        
        return outerContainer
    }

    // MARK: - Helpers
    func makePillTag(text: String) -> UIView {
        let tagView = UIView()
        tagView.backgroundColor = .white.withAlphaComponent(0.15)
        tagView.layer.cornerRadius = 14
        
        let label = UILabel()
        label.text = text.uppercased()
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        tagView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: tagView.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: tagView.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: tagView.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: tagView.trailingAnchor, constant: -14)
        ])
        return tagView
    }
}
