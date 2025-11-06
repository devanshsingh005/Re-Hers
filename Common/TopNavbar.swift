//
//  TopNavbar.swift
//  Re-Hearse_v1
//
//  Created by admin20 on 06/11/25.
//

import Foundation
import UIKit

// Main UI Component
class TopNavBar: UIView {
    
    // MARK: - UI Components
    private let titleRow = UIStackView()
    private let appLabel = UILabel()
    private let dayBadge = UIButton()
    private let profileImg = UIImageView()
    private let welcomeLabel = UILabel()
    
    // MARK: - React-style Factory
    static func create(props: TopNavBarProps) -> TopNavBar {
        let navbar = TopNavBar()
        navbar.configure(with: props)
        return navbar
    }
    
    // MARK: - Configuration
    func configure(with props: TopNavBarProps) {
        welcomeLabel.text = "Welcome back, \(props.username)"
        dayBadge.setTitle("🔥 Day \(props.dayNumber)", for: .normal)
        
        profileImg.image = props.profileImage ?? UIImage(systemName: "person.crop.circle.fill")
        
        setupUI()
        setupActions(
            onProfileTap: props.onProfileTap,
            onDayBadgeTap: props.onDayBadgeTap
        )
    }
    
    private func setupUI() {
        // Your existing UI setup code
        backgroundColor = .white
        
        titleRow.axis = .horizontal
        titleRow.distribution = .equalSpacing
        titleRow.translatesAutoresizingMaskIntoConstraints = false
        
        appLabel.text = "Re-Hearse"
        appLabel.font = .systemFont(ofSize: 22, weight: .bold)
        
        dayBadge.setTitleColor(.black, for: .normal)
        dayBadge.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        dayBadge.backgroundColor = UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)
        dayBadge.layer.cornerRadius = 16
        dayBadge.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        
        profileImg.tintColor = .gray
        profileImg.layer.cornerRadius = 18
        profileImg.clipsToBounds = true
        profileImg.backgroundColor = .systemGray6
        profileImg.isUserInteractionEnabled = true
        profileImg.translatesAutoresizingMaskIntoConstraints = false
        
        let rightRow = UIStackView(arrangedSubviews: [dayBadge, profileImg])
        rightRow.spacing = 10
        rightRow.alignment = .center
        
        welcomeLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        welcomeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        titleRow.addArrangedSubview(appLabel)
        titleRow.addArrangedSubview(rightRow)
        
        addSubview(titleRow)
        addSubview(welcomeLabel)
        
        NSLayoutConstraint.activate([
            titleRow.topAnchor.constraint(equalTo: topAnchor),
            titleRow.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleRow.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleRow.heightAnchor.constraint(equalToConstant: 44),
            
            profileImg.widthAnchor.constraint(equalToConstant: 36),
            profileImg.heightAnchor.constraint(equalToConstant: 36),
            
            welcomeLabel.topAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: 8),
            welcomeLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            welcomeLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            welcomeLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func setupActions(onProfileTap: (() -> Void)?, onDayBadgeTap: (() -> Void)?) {
        let profileTap = UITapGestureRecognizer(target: self, action: #selector(handleProfileTap))
        profileImg.addGestureRecognizer(profileTap)
        
        dayBadge.addTarget(self, action: #selector(handleDayBadgeTap), for: .touchUpInside)
        
        // Store closures
        self.onProfileTap = onProfileTap
        self.onDayBadgeTap = onDayBadgeTap
    }
    
    // MARK: - Action Handlers
    private var onProfileTap: (() -> Void)?
    private var onDayBadgeTap: (() -> Void)?
    
    @objc private func handleProfileTap() {
        onProfileTap?()
    }
    
    @objc private func handleDayBadgeTap() {
        onDayBadgeTap?()
    }
}
