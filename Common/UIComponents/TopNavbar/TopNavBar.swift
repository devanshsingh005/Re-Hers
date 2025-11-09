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
        didSet { appLabel.text = appTitle }
    }
    
    public var dayText: String = "🔥 Day 5" {
        didSet { dayBadge.setTitle(dayText, for: .normal) }
    }
    
    public var welcomeText: String = "Welcome back, Mukul" {
        didSet { welcomeLabel.text = welcomeText }
    }
    
    public var profileImage: UIImage? {
        didSet { updateProfileImage() }
    }
    
    public var dayBadgeAction: (() -> Void)?
    
    public var isWelcomeTextHidden: Bool = false {
        didSet { welcomeLabel.isHidden = isWelcomeTextHidden }
    }
    
    // MARK: - Subviews
    
    private let appLabel: UILabel = {
        let label = UILabel()
        label.text = "Re-Hearse"
        label.font = .boldSystemFont(ofSize: 22)
        label.textColor = .label
        return label
    }()
    
    private let dayBadge: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("🔥 Day 5", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 14)
        button.backgroundColor = UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)
        button.layer.cornerRadius = 16
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        return button
    }()
    
    private let profileImg: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = .gray
        iv.backgroundColor = .lightGray
        iv.layer.cornerRadius = 18
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFill
        return iv
    }()
    
    private let welcomeLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome back, Mukul"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    // MARK: - Stack Views (Now Declared at Class Level)
    
    private let topRowStack = UIStackView()
    private let rightStack = UIStackView()
    private let mainStack = UIStackView()
    
    // MARK: - Init
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupConstraints()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .clear
        
        // MARK: Configure stacks
        topRowStack.axis = .horizontal
        topRowStack.alignment = .center
        topRowStack.distribution = .fill
        topRowStack.spacing = 8
        
        rightStack.axis = .horizontal
        rightStack.alignment = .center
        rightStack.spacing = 8
        
        mainStack.axis = .vertical
        mainStack.alignment = .fill
        mainStack.spacing = 6
        
        // MARK: Build hierarchy
        rightStack.addArrangedSubview(dayBadge)
        rightStack.addArrangedSubview(profileImg)
        
        // Create a flexible spacer
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews to top row
        topRowStack.addArrangedSubview(appLabel)
        topRowStack.addArrangedSubview(spacer)
        topRowStack.addArrangedSubview(rightStack)
        
        // Spacer expands to push content to opposite sides
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Add both rows to main stack
        mainStack.addArrangedSubview(topRowStack)
        mainStack.addArrangedSubview(welcomeLabel)
        
        addSubview(mainStack)
        
        // MARK: Layout constraints
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor,constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor,constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
        
        // MARK: Profile image size
        profileImg.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            profileImg.widthAnchor.constraint(equalToConstant: 36),
            profileImg.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        // Add tap to badge
        dayBadge.addTarget(self, action: #selector(dayBadgeTapped), for: .touchUpInside)
    }

    
    private func setupConstraints() {
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
            mainStack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8)
        ])
    }
    
    // MARK: - Helpers
    
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
    
    // MARK: - Factory Method
    
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

