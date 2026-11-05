//
//  ProfileSkeletonView.swift
//  Re-Hearse_v1
//
//  Pixel-matched skeleton for UserProfileViewController.
//  Aligned exactly to the real view anchors:
//    • 28pt top padding for Avatar (matches real contentView constraint)
//    • 110pt Avatar ring circle
//    • 100pt Stat cards row
//    • 130pt Chart area
//

import UIKit

final class ProfileSkeletonView: SkeletonContainerView {

    override init() {
        super.init()
        backgroundColor = ComponentColors.ProfileScreen.background
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        // We use a scroll view inside the skeleton so it handles safe areas same as real VC
        let scroll = UIScrollView()
        scroll.isScrollEnabled = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),

            content.topAnchor.constraint(equalTo: scroll.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])

        let stack = UIStackView()
        stack.axis      = .vertical
        stack.spacing   = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            // EXACT MATCH: real VC uses constant 28 for ringView.topAnchor
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -32),
        ])

        stack.addArrangedSubview(makeAvatarSection())
        stack.addArrangedSubview(makeStatCardsRow())
        stack.addArrangedSubview(makePracticeCard())
        stack.addArrangedSubview(makeAppearanceCard())
    }

    private func makeAvatarSection() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let ringSize: CGFloat = 110
        let ringOuter = SkeletonCircle(diameter: ringSize)
        ringOuter.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(ringOuter)

        let nameLine = SkeletonBox(height: 24, cornerRadius: 12)
        nameLine.translatesAutoresizingMaskIntoConstraints = false
        nameLine.widthAnchor.constraint(equalToConstant: 160).isActive = true
        container.addSubview(nameLine)

        let handleLine = SkeletonBox(height: 14, cornerRadius: 7)
        handleLine.translatesAutoresizingMaskIntoConstraints = false
        handleLine.widthAnchor.constraint(equalToConstant: 100).isActive = true
        container.addSubview(handleLine)

        NSLayoutConstraint.activate([
            ringOuter.topAnchor.constraint(equalTo: container.topAnchor),
            ringOuter.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            ringOuter.widthAnchor.constraint(equalToConstant: ringSize),
            ringOuter.heightAnchor.constraint(equalToConstant: ringSize),

            nameLine.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            nameLine.topAnchor.constraint(equalTo: ringOuter.bottomAnchor, constant: 16),

            handleLine.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            handleLine.topAnchor.constraint(equalTo: nameLine.bottomAnchor, constant: 4),
            handleLine.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func makeStatCardsRow() -> UIView {
        let row = UIStackView()
        row.axis         = .horizontal
        row.distribution = .fillEqually
        row.spacing      = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 100)
        ])

        for _ in 0..<3 {
            let card = UIView()
            card.backgroundColor = ComponentColors.ProfileScreen.statCardFill
            card.layer.cornerRadius = 16
            card.layer.borderWidth = 0.5
            card.layer.borderColor = ComponentColors.ProfileScreen.statCardBorder.cgColor
            
            let icon = SkeletonCircle(diameter: 22)
            let val = SkeletonBox(height: 22, cornerRadius: 11)
            val.widthAnchor.constraint(equalToConstant: 40).isActive = true
            let sub = SkeletonBox(height: 10, cornerRadius: 5)
            sub.widthAnchor.constraint(equalToConstant: 50).isActive = true
            
            let stack = UIStackView(arrangedSubviews: [icon, val, sub])
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 6
            stack.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(stack)
            
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: card.centerYAnchor)
            ])
            
            row.addArrangedSubview(card)
        }
        return row
    }

    private func makePracticeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = ComponentColors.ProfileScreen.headerCardFill
        card.layer.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let title = SkeletonBox(height: 20, cornerRadius: 10)
        title.widthAnchor.constraint(equalToConstant: 160).isActive = true
        
        let hours = SkeletonBox(height: 36, cornerRadius: 12)
        hours.widthAnchor.constraint(equalToConstant: 80).isActive = true
        
        let chart = SkeletonBox(height: 130, cornerRadius: 12) // EXACT MATCH: 130pt height
        
        let stack = UIStackView(arrangedSubviews: [title, hours, chart])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width - 32),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
        return card
    }

    private func makeAppearanceCard() -> UIView {
        let card = UIView()
        card.backgroundColor = ComponentColors.ProfileScreen.settingsCellFill
        card.layer.cornerRadius = 20
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let title = SkeletonBox(height: 18, cornerRadius: 9)
        title.widthAnchor.constraint(equalToConstant: 120).isActive = true
        
        let row = SkeletonBox(height: 44, cornerRadius: 10)
        
        let stack = UIStackView(arrangedSubviews: [title, row])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width - 32),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
        return card
    }
}
