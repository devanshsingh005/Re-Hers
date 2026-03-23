//
//  HomeViewControllerContinueCard.swift
//  Re-Hearse_v1
//

import UIKit

private final class GradientOverlayView: UIView {
    private let gradientLayer = CAGradientLayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.7).cgColor]
        gradientLayer.locations = [0.4, 1.0]
        layer.insertSublayer(gradientLayer, at: 0)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

extension HomeViewController {
    func addTopPracticeCard() {
        let headerRow = UIView()
        
    

        contentView.addArrangedSubview(headerRow)
        contentView.setCustomSpacing(12, after: headerRow)

        let cardBgColor = UIColor { trait in trait.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 1) : .white }
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.backgroundColor = cardBgColor
        wrapper.layer.cornerRadius = 24
        wrapper.layer.masksToBounds = true
        
        let outerContainer = UIView()
        outerContainer.translatesAutoresizingMaskIntoConstraints = false
        outerContainer.layer.shadowColor = UIColor.black.cgColor
        outerContainer.layer.shadowOpacity = 0.08
        outerContainer.layer.shadowRadius = 16
        outerContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        outerContainer.addSubview(wrapper)
        NSLayoutConstraint.activate([
            wrapper.topAnchor.constraint(equalTo: outerContainer.topAnchor),
            wrapper.leadingAnchor.constraint(equalTo: outerContainer.leadingAnchor),
            wrapper.trailingAnchor.constraint(equalTo: outerContainer.trailingAnchor),
            wrapper.bottomAnchor.constraint(equalTo: outerContainer.bottomAnchor),
        ])

        // Image header
        let randomStartImage = "trackimage_\(Int.random(in: 1...16))"
        let imageView = UIImageView(image: UIImage(named: randomStartImage))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        self.topCardImageView = imageView
        wrapper.addSubview(imageView)
        
        // Gradient overlay for text readability
        let gradientView = GradientOverlayView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(gradientView)

        // Dynamic Title
        let titleLabel = UILabel()
        titleLabel.text = "Loading..."
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.topCardTitleLabel = titleLabel
        wrapper.addSubview(titleLabel)

        // Tag: "RIGHT HAND FOCUS | SLOW"
        let tagBg = UIView()
        tagBg.backgroundColor = .white
        tagBg.layer.cornerRadius = 12
        tagBg.translatesAutoresizingMaskIntoConstraints = false
        
        let tagLabel = UILabel()
        tagLabel.text = "..."
        tagLabel.font = .systemFont(ofSize: 10, weight: .bold)
        tagLabel.textColor = .black
        tagLabel.translatesAutoresizingMaskIntoConstraints = false
        self.topCardTagLabel = tagLabel
        tagBg.addSubview(tagLabel)
        wrapper.addSubview(tagBg)

        // Progress section
        let progressTitle = UILabel()
        progressTitle.text = "Your Progress"
        progressTitle.font = .systemFont(ofSize: 12, weight: .medium)
        progressTitle.textColor = ComponentColors.SongCard.titleText
        progressTitle.translatesAutoresizingMaskIntoConstraints = false
        
        let progressValue = UILabel()
        progressValue.text = "65%"
        progressValue.font = .systemFont(ofSize: 12, weight: .semibold)
        progressValue.textColor = ComponentColors.SongCard.titleText
        progressValue.translatesAutoresizingMaskIntoConstraints = false

        let progressTrack = UIView()
        progressTrack.backgroundColor = ComponentColors.SongCard.border // or similar cream
        progressTrack.layer.cornerRadius = 3
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        
        let progressFill = UIView()
        progressFill.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        progressFill.layer.cornerRadius = 3
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)

        let progressHeaderStack = UIStackView(arrangedSubviews: [progressTitle, UIView(), progressValue])
        progressHeaderStack.axis = .horizontal
        progressHeaderStack.translatesAutoresizingMaskIntoConstraints = false

        let startBtn = UIButton(type: .system)
        startBtn.setTitle("Start Practice", for: .normal)
        startBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        startBtn.setTitleColor(.white, for: .normal)
        startBtn.backgroundColor = ComponentColors.HomeScreen.actionButtonFill
        startBtn.layer.cornerRadius = 24
        startBtn.translatesAutoresizingMaskIntoConstraints = false
        // Placeholder action, can link to player later
        startBtn.addAction(UIAction { [weak self] _ in self?.openPianoPage() }, for: .touchUpInside)

        wrapper.addSubview(progressHeaderStack)
        wrapper.addSubview(progressTrack)
        wrapper.addSubview(startBtn)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: wrapper.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 160),

            gradientView.topAnchor.constraint(equalTo: imageView.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),

            tagLabel.topAnchor.constraint(equalTo: tagBg.topAnchor, constant: 4),
            tagLabel.bottomAnchor.constraint(equalTo: tagBg.bottomAnchor, constant: -4),
            tagLabel.leadingAnchor.constraint(equalTo: tagBg.leadingAnchor, constant: 10),
            tagLabel.trailingAnchor.constraint(equalTo: tagBg.trailingAnchor, constant: -10),

            tagBg.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
            tagBg.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -18),
            
            titleLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 18),
            titleLabel.bottomAnchor.constraint(equalTo: tagBg.topAnchor, constant: -8),

            progressHeaderStack.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 18),
            progressHeaderStack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 18),
            progressHeaderStack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -18),

            progressTrack.topAnchor.constraint(equalTo: progressHeaderStack.bottomAnchor, constant: 8),
            progressTrack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 18),
            progressTrack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -18),
            progressTrack.heightAnchor.constraint(equalToConstant: 6),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: 0.65),

            startBtn.topAnchor.constraint(equalTo: progressTrack.bottomAnchor, constant: 22),
            startBtn.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 18),
            startBtn.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -18),
            startBtn.heightAnchor.constraint(equalToConstant: 48),
            startBtn.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -20)
        ])
        
        contentView.addArrangedSubview(outerContainer)
    }
}
