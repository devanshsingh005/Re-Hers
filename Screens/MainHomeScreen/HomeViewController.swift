//
//  HomeViewController.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 04/11/25.
//

import UIKit

class HomeViewController: UIViewController {
    
    // MARK: - UI Elements
    private let navBar = TopNavBar.make(
        title: "Re-Hearse")
    
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup UI
    private func setupUI() {
        view.backgroundColor = .white
        navigationController?.navigationBar.isHidden = true
        
        setupNavBar()
        setupScrollView()
        addDailyGoal()
        addContinueCard()
        addContinueLearningSection()
        addUploadSection()
    }
    
    // MARK: - Navbar Setup
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.isChordIconVisible = false
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])
    }

    // MARK: - ScrollView Setup
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        contentView.axis = .vertical
        contentView.spacing = 18
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    // MARK: - Daily Goal
    /*private func addDailyGoal() {
        let container = UIView()
        container.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        container.layer.cornerRadius = 20
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 48).isActive = true
        
        let label = UILabel()
        label.text = "Daily goal"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .white

        let progress = UIProgressView()
        progress.progress = 0.7
        progress.progressTintColor = .systemGreen
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
            time.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        contentView.addArrangedSubview(container)
    }*/
    // MARK: - Daily Goal
    public func addDailyGoal() {
        let container = UIView()
        container.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        container.layer.cornerRadius = 20
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 48).isActive = true
        
        // 👉 Enable tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(openUserProfile))
        container.addGestureRecognizer(tap)
        
        let label = UILabel()
        label.text = "Daily goal"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .white

        let progress = UIProgressView()
        progress.progress = 0.7
        progress.progressTintColor = .systemGreen
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
            time.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        contentView.addArrangedSubview(container)
    }
    @objc private func openUserProfile() {
        let vc = UserProfileViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Navigation to Piano Page
    @objc func openPianoPage() {
        let vc = PianoAnimationViewController()
        navigationController?.pushViewController(vc, animated: true)
    }


    // MARK: - Continue Card
    private func addContinueCard() {
        let card = UIView()
        card.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        card.layer.cornerRadius = 22
        card.translatesAutoresizingMaskIntoConstraints = false

        // MARK: - Image
        let image = UIImageView()
        image.image = UIImage(named: "ride_home") ?? UIImage(systemName: "music.note")
        image.layer.cornerRadius = 10
        image.clipsToBounds = true
        image.contentMode = .scaleAspectFill
        image.translatesAutoresizingMaskIntoConstraints = false

        // MARK: - Title + Subtitle
        let title = UILabel()
        title.text = "Continue: Ride Home"
        title.textColor = .white
        title.font = .systemFont(ofSize: 19, weight: .bold)

        let subtitle = UILabel()
        subtitle.text = "Bars 5–6 | Right-Hand focus"
        subtitle.textColor = UIColor(white: 0.7, alpha: 1)
        subtitle.font = .systemFont(ofSize: 13)

        let titleStack = UIStackView(arrangedSubviews: [title, subtitle])
        titleStack.axis = .vertical
        titleStack.spacing = 4
        titleStack.alignment = .leading

        let topRow = UIStackView(arrangedSubviews: [image, titleStack])
        topRow.axis = .horizontal
        topRow.spacing = 12
        topRow.alignment = .top

        // MARK: - Tags
        let tag1 = createTagLabel("Right-Hand dexterity")
        let tag2 = createTagLabel("Accuracy > 80%")

        tag1.heightAnchor.constraint(equalToConstant: 21).isActive = true
        tag2.heightAnchor.constraint(equalToConstant: 21).isActive = true

        let tagsStack = UIStackView(arrangedSubviews: [tag1, tag2])
        tagsStack.axis = .vertical
        tagsStack.spacing = 6
        tagsStack.alignment = .leading

        // MARK: - Progress
        let progressView = UIProgressView()
        progressView.progress = 0.4
        progressView.progressTintColor = .white
        progressView.trackTintColor = UIColor(white: 0.3, alpha: 1)
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.heightAnchor.constraint(equalToConstant: 4).isActive = true

        // MARK: - Buttons
        let continueBtn = createFilledButton("Continue")
        continueBtn.addTarget(self, action: #selector(openPianoPage), for: .touchUpInside)

        let playBtn = createBorderedButton("Play Along")

        continueBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        playBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let buttonStack = UIStackView(arrangedSubviews: [continueBtn, playBtn])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually

        // MARK: - Main Card Stack
        let mainStack = UIStackView(arrangedSubviews: [
            topRow,
            tagsStack,
            progressView,
            buttonStack
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 16
        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(mainStack)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 300),

            mainStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            mainStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            mainStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),

            image.widthAnchor.constraint(equalToConstant: 80),
            image.heightAnchor.constraint(equalToConstant: 80),
        ])

        contentView.addArrangedSubview(card)
    }


//    // MARK: - Continue Learning Section
//    private func addContinueLearningSection() {
//        let sectionHeader = UILabel()
//        sectionHeader.text = "Continue Learning"
//        sectionHeader.font = .systemFont(ofSize: 18, weight: .semibold)
//        sectionHeader.textColor = .black
//        contentView.addArrangedSubview(sectionHeader)
//        
//        let headerSpacer = UIView()
//        headerSpacer.heightAnchor.constraint(equalToConstant: 12).isActive = true
//        contentView.addArrangedSubview(headerSpacer)
//        
//        let scrollView = UIScrollView()
//        scrollView.showsHorizontalScrollIndicator = false
//        let stackView = UIStackView()
//        stackView.axis = .horizontal
//        stackView.spacing = 16
//        scrollView.addSubview(stackView)
//        stackView.translatesAutoresizingMaskIntoConstraints = false
//        
//        NSLayoutConstraint.activate([
//            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
//            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
//            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
//            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
//            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
//        ])
//        
//        let imageNames = ["cl_1", "cl_2", "ride_home", "cl_1", "cl_2"]
//        imageNames.forEach {
//            stackView.addArrangedSubview(createImageCard(imageName: $0, title: getTitleForImage($0)))
//        }
//        
//        contentView.addArrangedSubview(scrollView)
//        scrollView.heightAnchor.constraint(equalToConstant: 180).isActive = true
//    }
    private func addContinueLearningSection() {
        // Top spacing (to match other sections)
//        let topSpacer = UIView()
//        topSpacer.heightAnchor.constraint(equalToConstant: 2).isActive = true
//        contentView.addArrangedSubview(topSpacer)
//        
        // Section title
        let sectionHeader = UILabel()
        sectionHeader.text = "Continue Learning"
        sectionHeader.font = .systemFont(ofSize: 18, weight: .semibold)
        sectionHeader.textColor = .black
        contentView.addArrangedSubview(sectionHeader)

        // Small spacer under title (8 looks best visually)
//        let headerSpacer = UIView()
//        headerSpacer.heightAnchor.constraint(equalToConstant: 2).isActive = true
//        contentView.addArrangedSubview(headerSpacer)
        
        // Horizontal scroll section
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        contentView.addArrangedSubview(scrollView)
        scrollView.heightAnchor.constraint(equalToConstant: 180).isActive = true
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 14
        scrollView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        let imageNames = ["cl_5", "cl_4", "ride_home", "cl_1", "cl_2"]
        imageNames.forEach {
            stackView.addArrangedSubview(createImageCard(imageName: $0, title: getTitleForImage($0)))
        }
    }


    // MARK: - Upload Section
    private func addUploadSection() {
        let container = UIView()
        container.backgroundColor = UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)
        container.layer.cornerRadius = 22
        container.heightAnchor.constraint(equalToConstant: 120).isActive = true
        
        let icon = UIImageView(image: UIImage(systemName: "icloud.and.arrow.up"))
        icon.tintColor = .black
        let text = UILabel()
        text.text = "Sheet to Music"
        text.font = .systemFont(ofSize: 20, weight: .bold)
        text.textColor = .black
        
        let stack = UIStackView(arrangedSubviews: [text, icon])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        contentView.addArrangedSubview(container)
    }
    
    // MARK: - Helper Components
    private func createTagLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.black.withAlphaComponent(0.9)
        label.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 1
        
        // 👉 Increase width using contentInset-like padding
        label.layer.cornerRadius = 10  //  smaller radius
        label.clipsToBounds = true
        
        // Add width padding manually
        label.sizeToFit()
        label.frame = CGRect(
            x: 0,
            y: 0,
            width: label.frame.width + 30,   // wider tags
            height: label.frame.height + 10  // vertical padding
        )
        
        return label
    }


    private func createFilledButton(_ title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemOrange
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 12
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
        return button
    }

    private func createImageCard(imageName: String, title: String) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = 12
        card.clipsToBounds = true
        
        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.backgroundColor = UIColor(white: 0, alpha: 0.7)
        
        card.addSubview(imageView)
        card.addSubview(titleLabel)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
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

    private func getTitleForImage(_ name: String) -> String {
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
        return titles[name] ?? name.capitalized
    }
}

