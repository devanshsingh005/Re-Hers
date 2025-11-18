//
//  TopNavBar.swift
//  Re-Hearse_v1
//

import UIKit

public final class TopNavBar: UIView {
    
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
    public var chordAction: (() -> Void)?
    
    public var isStreakVisible: Bool = true {
        didSet { dayBadge.isHidden = !isStreakVisible }
    }
    
    public var isChordIconVisible: Bool = false {
        didSet { chordButton.isHidden = !isChordIconVisible }
    }
    
    // MARK: - UI Components
    
    private let appLabel: UILabel = {
        let label = UILabel()
        label.text = "Re-Hearse"
        label.font = .boldSystemFont(ofSize: 22)
        label.textColor = .label
        return label
    }()
    
    private let dayBadge: UIButton = {
        let button = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.title = "🔥 Day 5"
            config.baseForegroundColor = .black
            config.background.backgroundColor = UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)
            config.background.cornerRadius = 16
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            // Apply attributed title to enforce bold 14 font
            var att = AttributedString("🔥 Day 5")
            att.font = .boldSystemFont(ofSize: 14)
            config.attributedTitle = att
            button.configuration = config
        } else {
            button.setTitle("🔥 Day 5", for: .normal)
            button.setTitleColor(.black, for: .normal)
            button.titleLabel?.font = .boldSystemFont(ofSize: 14)
            button.backgroundColor = UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)
            button.layer.cornerRadius = 16
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        }
        return button
    }()
    
    private let chordButton: UIButton = {
        let button = UIButton(type: .system)
        let icon = UIImage(systemName: "music.note.list")?.withRenderingMode(.alwaysTemplate)
        button.setImage(icon, for: .normal)
        button.tintColor = .black
        button.imageView?.contentMode = .scaleAspectFit
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
    public var isWelcomeTextHidden: Bool = false {
        didSet { welcomeLabel.isHidden = isWelcomeTextHidden }
    }
    private let welcomeLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome back, Mukul"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let topRowStack = UIStackView()
    private let rightStack = UIStackView()
    private let mainStack = UIStackView()
    
    // MARK: - Init
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureUI()
    }
    
    // MARK: - Setup
    
    private func configureUI() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        
        setupStacks()
        buildHierarchy()
        applyConstraints()
        
        // Actions
        dayBadge.addTarget(self, action: #selector(dayBadgeTapped), for: .touchUpInside)
        chordButton.addTarget(self, action: #selector(chordTapped), for: .touchUpInside)
    }
    
    private func setupStacks() {
        topRowStack.axis = .horizontal
        topRowStack.alignment = .center
        topRowStack.distribution = .fill
        topRowStack.spacing = 8
        
        rightStack.axis = .horizontal
        rightStack.alignment = .center
        rightStack.spacing = 10
        
        mainStack.axis = .vertical
        mainStack.alignment = .fill
        mainStack.spacing = 6
    }
    
    private func buildHierarchy() {
        rightStack.addArrangedSubview(dayBadge)
        rightStack.addArrangedSubview(chordButton)
        rightStack.addArrangedSubview(profileImg)
        
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        topRowStack.addArrangedSubview(appLabel)
        topRowStack.addArrangedSubview(spacer)
        topRowStack.addArrangedSubview(rightStack)
        
        mainStack.addArrangedSubview(topRowStack)
        mainStack.addArrangedSubview(welcomeLabel)
        
        addSubview(mainStack)
    }
    
    private func applyConstraints() {
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        profileImg.translatesAutoresizingMaskIntoConstraints = false
        chordButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            profileImg.widthAnchor.constraint(equalToConstant: 36),
            profileImg.heightAnchor.constraint(equalToConstant: 36),
            
            chordButton.widthAnchor.constraint(equalToConstant: 30),
            chordButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func dayBadgeTapped() {
        dayBadgeAction?()
    }
    
    @objc private func chordTapped() {
        chordAction?()
    }
    
    // MARK: - Helpers
    
    private func updateProfileImage() {
        if let img = profileImage {
            profileImg.image = img
            profileImg.backgroundColor = .clear
        } else {
            let defaultIcon = UIImage(systemName: "person.crop.circle.fill")?.withRenderingMode(.alwaysTemplate)
            profileImg.image = defaultIcon
            profileImg.tintColor = .gray
            profileImg.backgroundColor = .lightGray
        }
    }
    
    // MARK: - Factory
    
    public static func make(
        appTitle: String = "Re-Hearse",
        dayText: String = "🔥 Day 5",
        welcomeText: String = "Welcome back, Mukul",
        profileImage: UIImage? = nil,
        dayBadgeAction: (() -> Void)? = nil,
        chordAction: (() -> Void)? = nil
    ) -> TopNavBar {
        let nav = TopNavBar()
        nav.appTitle = appTitle
        nav.dayText = dayText
        nav.welcomeText = welcomeText
        nav.profileImage = profileImage
        nav.dayBadgeAction = dayBadgeAction
        nav.chordAction = chordAction
        return nav
    }
}

