//
//  HomeViewController.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 04/11/25.
//

import UIKit

class HomeViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .white
        navigationController?.navigationBar.isHidden = true
        
        setupScrollView()
        addHeaderSection()
        addDailyGoal()
        addContinueCard()
        addContinueLearningSection()
        addUploadSection()
    }
    
    // MARK: - ScrollView
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leftAnchor.constraint(equalTo: view.leftAnchor),
            scrollView.rightAnchor.constraint(equalTo: view.rightAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        contentView.axis = .vertical
        contentView.spacing = 18
        contentView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    // MARK: - Header
    private func addHeaderSection() {
        let topNav = TopNavBar.make(
            appTitle: "Re-Hearse",
            dayText: "🔥 Day 5",
            welcomeText: "Welcome back, Mukul",
            profileImage: nil,
            dayBadgeAction: { [weak self] in
                // Handle day badge tap if needed
                print("Day badge tapped")
            }
        )
        contentView.addArrangedSubview(topNav)
    }

    // MARK: - Daily Goal
    private func addDailyGoal() {
        let container = UIView()
        container.backgroundColor = UIColor.black.withAlphaComponent(0.8) // light → dark adapts automatically

        container.layer.cornerRadius = 20
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 48).isActive = true
        
        let label = UILabel()
        label.text = "Daily goal"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .white                      // ✅ White text

        let progress = UIProgressView()
        progress.progress = 0.7
        progress.progressTintColor = .systemGreen     // ✅ Green progress
        progress.trackTintColor = UIColor.white.withAlphaComponent(0.2)
        progress.translatesAutoresizingMaskIntoConstraints = false

        let time = UILabel()
        time.text = "20 mins"
        time.font = .systemFont(ofSize: 12)
        time.textColor = .white

        container.addSubview(label)
        container.addSubview(progress)
        container.addSubview(time)

        label.translatesAutoresizingMaskIntoConstraints = false
        time.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            progress.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            progress.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            progress.widthAnchor.constraint(equalToConstant: 180),
            
            time.leadingAnchor.constraint(equalTo: progress.trailingAnchor, constant: 8),
            time.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        contentView.addArrangedSubview(container)
    }

    
    // MARK: - Continue Card
    // MARK: - Continue Card
    private func addContinueCard() {
        let card = UIView()
        card.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        card.layer.cornerRadius = 22
        card.translatesAutoresizingMaskIntoConstraints = false

        // Album cover image
        let image = UIImageView()
        if let imageAsset = UIImage(named: "ride_home") {
            image.image = imageAsset
        } else {
            // Fallback placeholder
            image.backgroundColor = UIColor(white: 0.15, alpha: 1)
        }
        image.layer.cornerRadius = 10
        image.clipsToBounds = true
        image.contentMode = .scaleAspectFill
        image.translatesAutoresizingMaskIntoConstraints = false
        
        // Title and subtitle stack (aligned with image top)
        let title = UILabel()
        title.text = "Continue: Ride Home"
        title.textColor = .white
        title.font = .systemFont(ofSize: 19, weight: .bold)
        title.numberOfLines = 1
        
        let subtitle = UILabel()
        subtitle.text = "Bars 5-6 | Right-Hand focus"
        subtitle.textColor = UIColor(white: 0.7, alpha: 1)
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.numberOfLines = 1
        
        let titleStack = UIStackView(arrangedSubviews: [title, subtitle])
        titleStack.axis = .vertical
        titleStack.spacing = 4
        titleStack.alignment = .leading
        
        // Top row: Image + Title/Subtitle
        let topRow = UIStackView(arrangedSubviews: [image, titleStack])
        topRow.axis = .horizontal
        topRow.spacing = 12
        topRow.alignment = .top
        
        // Tags with white oval background - VERTICAL STACK
        let tag1 = createTagLabel("Right-Hand dexterity")
        let tag2 = createTagLabel("Accuracy 80%")
        
        let tagsStack = UIStackView(arrangedSubviews: [tag1, tag2])
        tagsStack.axis = .vertical
        tagsStack.spacing = 6
        tagsStack.alignment = .leading
        
        // Progress bar - full width
        let progressView = UIProgressView()
        progressView.progress = 0.4
        progressView.progressTintColor = .white
        progressView.trackTintColor = UIColor(white: 0.3, alpha: 1)
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        
        // Buttons - equally spaced and big
        let continueBtn = createFilledButton("Continue")
        let playBtn = createBorderedButton("Play Along")
        
        let buttonStack = UIStackView(arrangedSubviews: [continueBtn, playBtn])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        
        // Spacer views to create proper gaps
        let spacer1 = UIView()
        spacer1.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        let spacer2 = UIView()
        spacer2.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        let spacer3 = UIView()
        spacer3.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        // Main vertical stack with proper spacing
        let mainStack = UIStackView(arrangedSubviews: [
            topRow,
            spacer1,      // Gap after top row
            tagsStack,
            spacer2,      // Gap after tags
            progressView,
            spacer3,      // Gap after progress bar
            buttonStack
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 0
        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(mainStack)

        NSLayoutConstraint.activate([
            // Card constraints - larger card
            card.heightAnchor.constraint(equalToConstant: 300),
            
            // Main stack constraints
            mainStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            mainStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            mainStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
            
            // Image constraints
            image.widthAnchor.constraint(equalToConstant: 80),
            image.heightAnchor.constraint(equalToConstant: 80),
            
            // Spacer constraints for proper gaps
            spacer1.heightAnchor.constraint(equalToConstant: 16), // Gap between topRow and tags
            spacer2.heightAnchor.constraint(equalToConstant: 12), // Gap between tags and progress bar
            spacer3.heightAnchor.constraint(equalToConstant: 20), // Gap between progress and buttons
            
            // Progress bar height
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            // Button constraints
            continueBtn.heightAnchor.constraint(equalToConstant: 52),
            playBtn.heightAnchor.constraint(equalToConstant: 52),
            
            // Tag height constraints
            tag1.heightAnchor.constraint(equalToConstant: 24),
            tag2.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        contentView.addArrangedSubview(card)
    }

    // MARK: - Helper Methods
    private func createTagLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .black
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.backgroundColor = .white
        label.layer.cornerRadius = 12 // Oval shape
        label.clipsToBounds = true
        label.textAlignment = .center
        
        // Add padding using constraints for longer ovals
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Calculate approximate width based on text length
        let padding: CGFloat = 16 // Increased from default for longer ovals
        let textSize = text.size(withAttributes: [.font: label.font!])
        let labelWidth = textSize.width + (padding * 2)
        
        NSLayoutConstraint.activate([
            label.heightAnchor.constraint(equalToConstant: 24),
            label.widthAnchor.constraint(equalToConstant: labelWidth) // Fixed width for consistent oval shape
        ])
        
        return label
    }
    private func createFilledButton(_ title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemOrange
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return button
    }

    private func createBorderedButton(_ title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .clear
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(white: 0.3, alpha: 1).cgColor
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return button
    }

   

    // MARK: - Continue Learning Section
    // MARK: - Continue Learning Section
    private func addContinueLearningSection() {
        let sectionHeader = UILabel()
        sectionHeader.text = "Continue Learning"
        sectionHeader.font = .systemFont(ofSize: 18, weight: .semibold)
        sectionHeader.textColor = .black;        contentView.addArrangedSubview(sectionHeader)
        
        // Add some spacing after header
        let headerSpacer = UIView()
        headerSpacer.translatesAutoresizingMaskIntoConstraints = false
        headerSpacer.heightAnchor.constraint(equalToConstant: 12).isActive = true
        contentView.addArrangedSubview(headerSpacer)
        
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        // Array of 8 image names for the carousel
        let imageNames = ["cl_1", "cl_2", "ride_home", "cl_1", "cl_2", "ride_home", "cl_1", "cl_2"]
        
        // Add 8 image cards to the carousel
        imageNames.forEach { name in
            let cardView = createImageCard(imageName: name, title: getTitleForImage(name))
            stackView.addArrangedSubview(cardView)
        }
        
        contentView.addArrangedSubview(scrollView)
        scrollView.heightAnchor.constraint(equalToConstant: 180).isActive = true
    }

    // Helper method to create image cards with titles
    private func createImageCard(imageName: String, title: String) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 12
        card.clipsToBounds = true
        
        let imageView = UIImageView()
        if let image = UIImage(named: imageName) {
            imageView.image = image
        } else {
            // Fallback placeholder
            imageView.backgroundColor = UIColor(white: 0.15, alpha: 1)
            imageView.image = UIImage(systemName: "music.note")?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
        }
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.backgroundColor = UIColor(white: 0, alpha: 0.7)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(imageView)
        card.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: 140),
            card.heightAnchor.constraint(equalToConstant: 160),
            
            imageView.topAnchor.constraint(equalTo: card.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return card
    }

    // Helper method to get titles for images
    private func getTitleForImage(_ imageName: String) -> String {
        let titles: [String: String] = [
            "arrival": "The Arrival",
            "meridian": "Meridian",
            "classic": "Classic Suite",
            "fur_elise": "Fur Elise",
            "nocturne": "Nocturne",
            "sonata": "Moonlight Sonata",
            "prelude": "Prelude",
            "rhapsody": "Rhapsody"
        ]
        return titles[imageName] ?? imageName.capitalized
    }

    // MARK: - Upload Section
    private func addUploadSection() {
        let container = UIView()
        container.backgroundColor = UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)
        container.layer.cornerRadius = 22
        container.heightAnchor.constraint(equalToConstant: 120).isActive = true
        
        let icon = UIImageView(image: UIImage(systemName: "icloud.and.arrow.up"))
        icon.tintColor = .black
        icon.translatesAutoresizingMaskIntoConstraints = false
        
        let text = UILabel()
        text.text = "Sheet to Music"
        text.font = .systemFont(ofSize: 20, weight: .bold)
        text.textColor = .black
        
        let stack = UIStackView(arrangedSubviews: [text, icon])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        contentView.addArrangedSubview(container)
    }
    
    private func tagLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12)
        label.textColor = .black
        label.backgroundColor = .white
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.textAlignment = .center
        label.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return label
    }
    
    private func buttonFilled(_ title: String) -> UIButton {
        let btn = UIButton()
        btn.setTitle(title, for: .normal)
        btn.backgroundColor = UIColor(red:1, green:0.75, blue:0.2, alpha:1)
        btn.setTitleColor(.black, for: .normal)
        btn.layer.cornerRadius = 18
        btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return btn
    }
    
    private func buttonGhost(_ title: String) -> UIButton {
        let btn = UIButton()
        btn.setTitle(title, for: .normal)
        btn.backgroundColor = .white
        btn.setTitleColor(.black, for: .normal)
        btn.layer.cornerRadius = 18
        btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return btn
    }
}

