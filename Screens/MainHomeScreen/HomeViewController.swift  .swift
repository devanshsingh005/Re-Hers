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
        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.spacing = 10
        titleRow.distribution = .equalSpacing
        
        let appLabel = UILabel()
        appLabel.text = "Re-Hearse"
        appLabel.font = .systemFont(ofSize: 22, weight: .bold)
        
        let dayBadge = UIButton()
        dayBadge.setTitle("🔥 Day 5", for: .normal)
        dayBadge.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        dayBadge.backgroundColor = UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)
        dayBadge.layer.cornerRadius = 16
        dayBadge.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        
        let profileImg = UIImageView()
        profileImg.image = UIImage(systemName: "person.crop.circle.fill")
        profileImg.tintColor = .gray
        profileImg.layer.cornerRadius = 18
        profileImg.clipsToBounds = true
        profileImg.backgroundColor = .lightGray
        profileImg.widthAnchor.constraint(equalToConstant: 36).isActive = true
        profileImg.heightAnchor.constraint(equalToConstant: 36).isActive = true
        
        let rightRow = UIStackView(arrangedSubviews: [dayBadge, profileImg])
        rightRow.spacing = 10
        
        titleRow.addArrangedSubview(appLabel)
        titleRow.addArrangedSubview(rightRow)
        
        contentView.addArrangedSubview(titleRow)
        
        // Welcome Text
        let welcome = UILabel()
        welcome.text = "Welcome back, Mukul"
        welcome.font = .systemFont(ofSize: 18, weight: .semibold)
        contentView.addArrangedSubview(welcome)
    }

    // MARK: - Daily Goal
    private func addDailyGoal() {
        let container = UIView()
        container.backgroundColor = UIColor(white: 0.95, alpha: 1)
        container.layer.cornerRadius = 20
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 48).isActive = true
        
        let label = UILabel()
        label.text = "Daily goal"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        
        let progress = UIProgressView()
        progress.progress = 0.7
        progress.translatesAutoresizingMaskIntoConstraints = false
        
        let time = UILabel()
        time.text = "20 mins"
        time.font = .systemFont(ofSize: 12)

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
        card.backgroundColor = UIColor(white: 0.08, alpha: 1)
        card.layer.cornerRadius = 22
        card.translatesAutoresizingMaskIntoConstraints = false

        // Album cover image
        let image = UIImageView()
        if let imageAsset = UIImage(named: "fur_elise") {
            image.image = imageAsset
        } else {
            // Fallback placeholder
            image.backgroundColor = UIColor(white: 0.15, alpha: 1)
        }
        image.layer.cornerRadius = 10
        image.clipsToBounds = true
        image.contentMode = .scaleAspectFill
        image.translatesAutoresizingMaskIntoConstraints = false
        
        // Title label - "Continue: Fur Elise"
        let title = UILabel()
        title.text = "Continue: Fur Elise"
        title.textColor = .white
        title.font = .systemFont(ofSize: 19, weight: .bold)
        title.numberOfLines = 1
        
        // Subtitle label - "Bars 5-6 | Right-Hand focus"
        let subtitle = UILabel()
        subtitle.text = "Bars 5-6 | Right-Hand focus"
        subtitle.textColor = UIColor(white: 0.7, alpha: 1)
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.numberOfLines = 1
        
        // Tags - Left aligned
        let tag1 = UILabel()
        tag1.text = "Right-Hand dexterity"
        tag1.textColor = UIColor(white: 0.7, alpha: 1)
        tag1.font = .systemFont(ofSize: 13, weight: .regular)
        
        let tag2 = UILabel()
        tag2.text = "Accuracy"
        tag2.textColor = UIColor(white: 0.7, alpha: 1)
        tag2.font = .systemFont(ofSize: 13, weight: .regular)
        
        let tagsStack = UIStackView(arrangedSubviews: [tag1, tag2])
        tagsStack.axis = .vertical
        tagsStack.spacing = 6
        tagsStack.alignment = .leading
        
        // Progress bar
        let progressView = UIProgressView()
        progressView.progress = 0.4
        progressView.progressTintColor = .white
        progressView.trackTintColor = UIColor(white: 0.2, alpha: 1)
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        
        // Buttons
        let continueBtn = createFilledButton("Continue")
        let playBtn = createBorderedButton("Play Along")
        
        let buttonStack = UIStackView(arrangedSubviews: [continueBtn, playBtn])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.distribution = .fillEqually
        
        // Right side content stack with more spacing
        let rightContentStack = UIStackView(arrangedSubviews: [
            title,
            subtitle,
            tagsStack,
            progressView,
            UIView(), // Flexible spacer
            buttonStack
        ])
        rightContentStack.axis = .vertical
        rightContentStack.spacing = 16
        rightContentStack.alignment = .leading
        rightContentStack.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(image)
        card.addSubview(rightContentStack)

        NSLayoutConstraint.activate([
            // Card constraints - taller for more space
            card.heightAnchor.constraint(equalToConstant: 260),
            
            // Image constraints - larger image with more space
            image.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            image.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            image.widthAnchor.constraint(equalToConstant: 80),
            image.heightAnchor.constraint(equalToConstant: 80),
            
            // Right content stack constraints - more padding
            rightContentStack.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 16),
            rightContentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            rightContentStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            rightContentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
            
            // Progress bar width
            progressView.widthAnchor.constraint(equalTo: rightContentStack.widthAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            // Button constraints - slightly larger buttons
            continueBtn.heightAnchor.constraint(equalToConstant: 48),
            playBtn.heightAnchor.constraint(equalToConstant: 48),
            continueBtn.widthAnchor.constraint(equalTo: playBtn.widthAnchor)
        ])
        
        contentView.addArrangedSubview(card)
    }

    // MARK: - Helper Methods
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
   

    // MARK: - Continue Learning Section
    private func addContinueLearningSection() {
        let label = UILabel()
        label.text = "Continue Learning"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        contentView.addArrangedSubview(label)
        
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.heightAnchor.constraint(equalToConstant: 150)
        ])
        
        ["arrival","meridian","classic"].forEach { name in
            let img = UIImageView(image: UIImage(named: name))
            img.layer.cornerRadius = 12
            img.clipsToBounds = true
            img.contentMode = .scaleAspectFill
            img.widthAnchor.constraint(equalToConstant: 140).isActive = true
            img.heightAnchor.constraint(equalToConstant: 150).isActive = true
            stack.addArrangedSubview(img)
        }
        
        contentView.addArrangedSubview(scroll)
        scroll.heightAnchor.constraint(equalToConstant: 150).isActive = true
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
