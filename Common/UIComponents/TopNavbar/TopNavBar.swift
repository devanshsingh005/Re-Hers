//
//  TopNavBar.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/11/25.
//

import UIKit

public class TopNavBar: UIView {
    
    // MARK: - Public properties
    
    public var appTitle: String = "Re-Hearse" {
        didSet {
            appLabel.text = appTitle
        }
    }
    
    public var dayText: String = "🔥 Day 5" {
        didSet {
            dayBadge.setTitle(dayText, for: .normal)
        }
    }
    
    public var welcomeText: String = "Welcome back, Mukul" {
        didSet {
            welcomeLabel.text = welcomeText
        }
    }
    
    public var profileImage: UIImage? {
        didSet {
            updateProfileImage()
        }
    }
    
    public var dayBadgeAction: (() -> Void)?
    
    // MARK: - Subviews
    
    public let appLabel: UILabel = {
        let label = UILabel()
        label.text = "Re-Hearse"
        label.font = .boldSystemFont(ofSize: 22)
        label.textColor = .label
        label.accessibilityIdentifier = "topnav.appLabel"
        label.isAccessibilityElement = true
        return label
    }()
    
    public let dayBadge: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("🔥 Day 5", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 14)
        button.backgroundColor = UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)
        button.layer.cornerRadius = 16
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        button.accessibilityIdentifier = "topnav.dayBadge"
        button.isAccessibilityElement = true
        return button
    }()
    
    public let profileImg: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor = .gray
        iv.backgroundColor = .lightGray
        iv.layer.cornerRadius = 18
        iv.clipsToBounds = true
        iv.accessibilityIdentifier = "topnav.profileImage"
        iv.isAccessibilityElement = true
        iv.contentMode = .scaleAspectFill
        return iv
    }()
    
    public let welcomeLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome back, Mukul"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.accessibilityIdentifier = "topnav.welcomeLabel"
        label.isAccessibilityElement = true
        return label
    }()
    
    // MARK: - Private properties
    
    private let mainStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 9
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let titleRowStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .equalSpacing
        sv.alignment = .center
        return sv
    }()
    
    private let rightStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.alignment = .center
        return sv
    }()
    
    // MARK: - Init
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        dayBadge.addTarget(self, action: #selector(dayBadgeTapped), for: .touchUpInside)
        self.translatesAutoresizingMaskIntoConstraints = false
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupConstraints()
        dayBadge.addTarget(self, action: #selector(dayBadgeTapped), for: .touchUpInside)
        self.translatesAutoresizingMaskIntoConstraints = false
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        addSubview(mainStack)
        
        // Title row: left label + right stack
        titleRowStack.addArrangedSubview(appLabel)
        
        // Right stack: day badge + profile image
        rightStack.addArrangedSubview(dayBadge)
        rightStack.addArrangedSubview(profileImg)
        
        // Profile image size constraints
        NSLayoutConstraint.activate([
            profileImg.widthAnchor.constraint(equalToConstant: 36),
            profileImg.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        titleRowStack.addArrangedSubview(rightStack)
        
        mainStack.addArrangedSubview(titleRowStack)
        mainStack.addArrangedSubview(welcomeLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: self.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
    
    // MARK: - Private Helpers
    
    private func updateProfileImage() {
        if let img = profileImage {
            profileImg.image = img
            profileImg.tintColor = nil
            profileImg.backgroundColor = .clear
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .regular)
            let sysImage = UIImage(systemName: "person.crop.circle.fill", withConfiguration: config)
            profileImg.image = sysImage
            profileImg.tintColor = .gray
            profileImg.backgroundColor = .lightGray
        }
    }
    
    @objc private func dayBadgeTapped() {
        dayBadgeAction?()
    }
    
    // MARK: - Convenience
    
    public static func make(
        appTitle: String = "Re-Hearse",
        dayText: String = "🔥 Day 5",
        welcomeText: String = "Welcome back, Mukul",
        profileImage: UIImage? = nil,
        dayBadgeAction: (() -> Void)? = nil
    ) -> TopNavBar {
        let nav = TopNavBar()
        nav.appTitle = appTitle
        nav.dayText = dayText
        nav.welcomeText = welcomeText
        nav.profileImage = profileImage
        nav.dayBadgeAction = dayBadgeAction
        return nav
    }
}
