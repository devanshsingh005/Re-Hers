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
    private func addContinueCard() {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.08, alpha: 1)
        card.layer.cornerRadius = 22
        card.translatesAutoresizingMaskIntoConstraints = false

        let image = UIImageView(image: UIImage(named: "fur_elise"))
        image.layer.cornerRadius = 10
        image.clipsToBounds = true
        image.contentMode = .scaleAspectFill
        image.translatesAutoresizingMaskIntoConstraints = false
        
        let title = UILabel()
        title.text = "Continue: Fur Elise"
        title.textColor = .white
        title.font = .systemFont(ofSize: 19, weight: .bold)
        
        let subtitle = UILabel()
        subtitle.text = "Bars 5-6 | Right-Hand focus"
        subtitle.textColor = .lightGray
        subtitle.font = .systemFont(ofSize: 13)
        
        let tag1 = tagLabel("Right-Hand dexterity")
        let tag2 = tagLabel("Accuracy")
        
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        
        let continueBtn = buttonFilled("Continue")
        let playBtn = buttonGhost("Play Along")
        
        buttonStack.addArrangedSubview(continueBtn)
        buttonStack.addArrangedSubview(playBtn)
        
        let textStack = UIStackView(arrangedSubviews: [
            title, subtitle
        ])
        textStack.axis = .vertical
        textStack.spacing = 4
        
        let tagsStack = UIStackView(arrangedSubviews: [
            tag1, tag2
        ])
        tagsStack.axis = .horizontal
        tagsStack.spacing = 8
        
        let main = UIStackView(arrangedSubviews: [
            textStack, tagsStack, buttonStack
        ])
        main.axis = .vertical
        main.spacing = 16
        main.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(image)
        card.addSubview(main)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 220),
            
            image.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            image.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            image.widthAnchor.constraint(equalToConstant: 80),
            image.heightAnchor.constraint(equalToConstant: 80),
            
            main.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 16),
            main.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            main.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            main.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            
            continueBtn.heightAnchor.constraint(equalToConstant: 44),
            playBtn.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        contentView.addArrangedSubview(card)
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
