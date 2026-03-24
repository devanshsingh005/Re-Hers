//
//  HomeViewControllerContinueCard.swift
//  Re-Hearse_v1
//

import UIKit

private final class PracticeCardBackgroundView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let musicNoteView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        gradientLayer.colors = [
            UIColor(red: 0.23, green: 0.00, blue: 0.48, alpha: 1.0).cgColor, // Deep Purple
            UIColor(red: 0.42, green: 0.00, blue: 0.71, alpha: 1.0).cgColor  // Vibrant Purple
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

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

extension HomeViewController {
    func addTopPracticeCard() {
        let wrapper = PracticeCardBackgroundView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.layer.cornerRadius = 28
        wrapper.layer.masksToBounds = true
        
        let outerContainer = UIView()
        outerContainer.translatesAutoresizingMaskIntoConstraints = false
        outerContainer.layer.shadowColor = UIColor(red: 0.23, green: 0.00, blue: 0.48, alpha: 1.0).cgColor
        outerContainer.layer.shadowOpacity = 0.3
        outerContainer.layer.shadowRadius = 24
        outerContainer.layer.shadowOffset = CGSize(width: 0, height: 12)
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

        // We'll store a reference to the tagsStack to update it dynamically
        self.topCardTagLabel = UILabel() // dummy
        self.topCardTagLabel?.isHidden = true

        // Initial placeholders
        tagsStack.addArrangedSubview(makePillTag(text: "MEDIUM"))
        tagsStack.addArrangedSubview(makePillTag(text: "RH ONLY"))

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
        
        func makeDetailItem(icon: String, text: String) -> UIView {
            let stack = UIStackView()
            stack.axis = .horizontal; stack.spacing = 6
            let img = UIImageView(image: UIImage(systemName: icon))
            img.tintColor = .white.withAlphaComponent(0.6)
            img.contentMode = .scaleAspectFit
            img.widthAnchor.constraint(equalToConstant: 14).isActive = true
            img.heightAnchor.constraint(equalToConstant: 14).isActive = true
            
            let lbl = UILabel()
            lbl.text = text
            lbl.font = .systemFont(ofSize: 13, weight: .medium)
            lbl.textColor = .white.withAlphaComponent(0.9)
            
            stack.addArrangedSubview(img)
            stack.addArrangedSubview(lbl)
            return stack
        }

        detailsStack.addArrangedSubview(makeDetailItem(icon: "gauge.with.needle", text: "Intermediate"))
        detailsStack.addArrangedSubview(makeDetailItem(icon: "music.note.list", text: "Traditional"))
        detailsStack.addArrangedSubview(makeDetailItem(icon: "metronome", text: "72 BPM"))

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
        
        contentView.addArrangedSubview(outerContainer)
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
