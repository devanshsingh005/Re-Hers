//  ProfileScreen.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase

struct Profile: Decodable {
    let id: UUID
    var full_name: String?
    var username: String?
    var avatar_url: String?
    var bio: String?
    var daily_goal_minutes: Int?
}

final class UserProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - UI
    private let navBar = UIView()
    private let backButton = UIButton(type: .system)

    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    
    // Header elements we update
    private let profileImageView = UIImageView()
    private let cameraBadgeView = UIView()
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()
    private let bioLabel = UILabel()
    private let editButton = UIButton(type: .system)
    private let signOutButton = UIButton(type: .system)
    
    // Background gradient
    private let backgroundGradient = CAGradientLayer()
    
    // Daily goal UI elements
    private let dailyGoalProgressView = UIProgressView()
    private let dailyGoalTimeLabel = UILabel()
    
    // Data
    private var currentProfile: Profile?
    private var currentDailyGoalMinutes: Int = 20
    private var currentDailyProgressMinutes: Int = 14

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0) // Light cream/beige
        navigationController?.navigationBar.isHidden = true

        setupGradientBackground()
        setupNavBar()
        setupScroll()
        buildUI()
        view.bringSubviewToFront(navBar)
        
        loadProfile()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradient.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height * 0.45)
    }
    
    // MARK: - Gradient Background
    private func setupGradientBackground() {
        backgroundGradient.colors = [
            UIColor(red: 1.0, green: 0.78, blue: 0.36, alpha: 1.0).cgColor,  // Warm orange/gold
            UIColor(red: 1.0, green: 0.85, blue: 0.55, alpha: 1.0).cgColor,  // Lighter gold
            UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0).cgColor  // Fade to cream
        ]
        backgroundGradient.locations = [0.0, 0.5, 1.0]
        backgroundGradient.startPoint = CGPoint(x: 0.5, y: 0)
        backgroundGradient.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer.insertSublayer(backgroundGradient, at: 0)
    }

    // MARK: - NAVBAR
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.backgroundColor = .clear

        // Back button - simple chevron without background
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)), for: .normal)
        backButton.tintColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(backButton)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 56),

            backButton.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: 20),
            backButton.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    @objc private func goBack() {
        // Send notification before popping to refresh navbar
        NotificationCenter.default.post(name: TopNavBar.profileDidUpdateNotification, object: nil)
        navigationController?.popViewController(animated: true)
    }

    // MARK: - ScrollView
    private func setupScroll() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.axis = .vertical
        contentView.spacing = 20
        contentView.alignment = .fill

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    // MARK: - Build Screen UI
    private func buildUI() {
        // Avatar with edit button (compact header)
        contentView.addArrangedSubview(buildCompactHeader())
        contentView.setCustomSpacing(24, after: contentView.arrangedSubviews.last!)
        
        // Daily goal section
        contentView.addArrangedSubview(buildDailyGoalSection())
        contentView.setCustomSpacing(24, after: contentView.arrangedSubviews.last!)
        
        // Practice graph section
        contentView.addArrangedSubview(buildPracticeGraphSection())
        contentView.setCustomSpacing(24, after: contentView.arrangedSubviews.last!)
        
        // Stats section (Days Streak & Hours Spent)
        contentView.addArrangedSubview(buildAchievementsSection())
        contentView.setCustomSpacing(24, after: contentView.arrangedSubviews.last!)
        
        // Add Sign Out Button
        contentView.addArrangedSubview(buildSignOutButton())
        contentView.setCustomSpacing(32, after: contentView.arrangedSubviews.last!)

        // Add bottom spacer
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 60).isActive = true
        contentView.addArrangedSubview(spacer)
    }

    // MARK: - COMPACT HEADER (Avatar + Edit)
    private func buildCompactHeader() -> UIView {
        let container = UIView()
        
        let header = UIView()
        header.backgroundColor = .clear
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)
        
        // Profile image - larger and more prominent
        profileImageView.image = UIImage(systemName: "person.fill")
        profileImageView.tintColor = .white
        profileImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.35)
        profileImageView.layer.cornerRadius = 40
        profileImageView.clipsToBounds = true
        profileImageView.layer.borderColor = UIColor.white.cgColor
        profileImageView.layer.borderWidth = 3
        profileImageView.layer.shadowColor = UIColor.black.cgColor
        profileImageView.layer.shadowOpacity = 0.15
        profileImageView.layer.shadowOffset = CGSize(width: 0, height: 4)
        profileImageView.layer.shadowRadius = 8
        profileImageView.isUserInteractionEnabled = true
        profileImageView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(changeAvatarTapped))
        )
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Camera badge overlay
        cameraBadgeView.backgroundColor = UIColor.systemOrange
        cameraBadgeView.layer.cornerRadius = 14
        cameraBadgeView.layer.shadowColor = UIColor.black.cgColor
        cameraBadgeView.layer.shadowOpacity = 0.2
        cameraBadgeView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cameraBadgeView.layer.shadowRadius = 4
        cameraBadgeView.isUserInteractionEnabled = true
        cameraBadgeView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(changeAvatarTapped))
        )
        cameraBadgeView.translatesAutoresizingMaskIntoConstraints = false
        
        let cameraIcon = UIImageView(image: UIImage(systemName: "camera.fill"))
        cameraIcon.tintColor = .white
        cameraIcon.contentMode = .scaleAspectFit
        cameraBadgeView.addSubview(cameraIcon)
        cameraIcon.translatesAutoresizingMaskIntoConstraints = false
        
        // Name and username in vertical stack
        nameLabel.text = "Loading..."
        nameLabel.font = .systemFont(ofSize: 20, weight: .bold)
        nameLabel.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        usernameLabel.text = "@username"
        usernameLabel.font = .systemFont(ofSize: 14, weight: .regular)
        usernameLabel.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let textStack = UIStackView(arrangedSubviews: [nameLabel, usernameLabel])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Edit button - pill shape
        editButton.setImage(UIImage(systemName: "pencil"), for: .normal)
        editButton.tintColor = .white
        editButton.backgroundColor = UIColor.systemOrange
        editButton.layer.cornerRadius = 20
        editButton.layer.shadowColor = UIColor.systemOrange.cgColor
        editButton.layer.shadowOpacity = 0.4
        editButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        editButton.layer.shadowRadius = 8
        editButton.addTarget(self, action: #selector(editProfileTapped), for: .touchUpInside)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        
        header.addSubviews(profileImageView, cameraBadgeView, textStack, editButton)
        
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            header.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            header.heightAnchor.constraint(equalToConstant: 80),
            
            profileImageView.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            profileImageView.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 80),
            profileImageView.heightAnchor.constraint(equalToConstant: 80),
            
            cameraBadgeView.widthAnchor.constraint(equalToConstant: 28),
            cameraBadgeView.heightAnchor.constraint(equalToConstant: 28),
            cameraBadgeView.trailingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 4),
            cameraBadgeView.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 4),
            
            cameraIcon.centerXAnchor.constraint(equalTo: cameraBadgeView.centerXAnchor),
            cameraIcon.centerYAnchor.constraint(equalTo: cameraBadgeView.centerYAnchor),
            cameraIcon.widthAnchor.constraint(equalToConstant: 14),
            cameraIcon.heightAnchor.constraint(equalToConstant: 14),
            
            textStack.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 16),
            textStack.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            
            editButton.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            editButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            editButton.widthAnchor.constraint(equalToConstant: 44),
            editButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        return container
    }
    
    // MARK: - DAILY GOAL SECTION
    private func buildDailyGoalSection() -> UIView {
        let container = UIView()
        
        let card = UIView()
        card.backgroundColor = UIColor(red: 0.25, green: 0.25, blue: 0.27, alpha: 0.95) // Dark charcoal
        card.layer.cornerRadius = 20
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.15
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)
        
        let label = UILabel()
        label.text = "Daily goal"
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1.0) // Cream white
        label.translatesAutoresizingMaskIntoConstraints = false
        
        dailyGoalProgressView.progress = 0.7
        dailyGoalProgressView.progressTintColor = UIColor(red: 0.3, green: 0.75, blue: 0.45, alpha: 1.0) // Fresh green
        dailyGoalProgressView.trackTintColor = UIColor.white.withAlphaComponent(0.15)
        dailyGoalProgressView.layer.cornerRadius = 4
        dailyGoalProgressView.clipsToBounds = true
        dailyGoalProgressView.translatesAutoresizingMaskIntoConstraints = false
        
        // Make progress bar thicker
        dailyGoalProgressView.transform = CGAffineTransform(scaleX: 1.0, y: 2.0)
        
        // Add tap to edit
        let tapCard = UITapGestureRecognizer(target: self, action: #selector(editDailyGoalTapped))
        card.addGestureRecognizer(tapCard)
        card.isUserInteractionEnabled = true
        
        dailyGoalTimeLabel.text = "20 mins"
        dailyGoalTimeLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        dailyGoalTimeLabel.textColor = UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1.0)
        dailyGoalTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubviews(label, dailyGoalProgressView, dailyGoalTimeLabel)
        
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            card.heightAnchor.constraint(equalToConstant: 56),
            
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            
            dailyGoalProgressView.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 16),
            dailyGoalProgressView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            dailyGoalProgressView.trailingAnchor.constraint(equalTo: dailyGoalTimeLabel.leadingAnchor, constant: -16),
            
            dailyGoalTimeLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            dailyGoalTimeLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            dailyGoalTimeLabel.widthAnchor.constraint(equalToConstant: 60)
        ])
        
        return container
    }

    // MARK: - PRACTICE GRAPH SECTION
    private func buildPracticeGraphSection() -> UIView {
        let container = UIView()
        
        let card = UIView()
        card.backgroundColor = UIColor(red: 0.25, green: 0.25, blue: 0.27, alpha: 0.95) // Dark charcoal
        card.layer.cornerRadius = 20
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.15
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 12
        // Dashed border effect
        card.layer.borderWidth = 1.5
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Practice Graph"
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Toggle buttons container
        let toggleContainer = UIView()
        toggleContainer.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        toggleContainer.layer.cornerRadius = 10
        toggleContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let sevenDaysBtn = UIButton(type: .system)
        sevenDaysBtn.setTitle("7 Days", for: .normal)
        sevenDaysBtn.backgroundColor = .white
        sevenDaysBtn.layer.cornerRadius = 8
        sevenDaysBtn.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        sevenDaysBtn.setTitleColor(UIColor(red: 0.25, green: 0.25, blue: 0.27, alpha: 1.0), for: .normal)
        sevenDaysBtn.translatesAutoresizingMaskIntoConstraints = false
        
        let oneMonthBtn = UIButton(type: .system)
        oneMonthBtn.setTitle("1 Month", for: .normal)
        oneMonthBtn.backgroundColor = .clear
        oneMonthBtn.layer.cornerRadius = 8
        oneMonthBtn.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        oneMonthBtn.setTitleColor(.white, for: .normal)
        oneMonthBtn.translatesAutoresizingMaskIntoConstraints = false
        
        toggleContainer.addSubview(sevenDaysBtn)
        toggleContainer.addSubview(oneMonthBtn)
        
        // Y-axis labels
        let yAxisStack = UIStackView()
        yAxisStack.axis = .vertical
        yAxisStack.distribution = .equalSpacing
        yAxisStack.alignment = .trailing
        yAxisStack.translatesAutoresizingMaskIntoConstraints = false
        
        for minutes in ["30m", "25m", "20m", "15m", "10m", "5m", "0m"] {
            let label = UILabel()
            label.text = minutes
            label.font = .systemFont(ofSize: 9, weight: .regular)
            label.textColor = UIColor.white.withAlphaComponent(0.5)
            yAxisStack.addArrangedSubview(label)
        }
        
        // Simple static graph
        let graphView = buildStaticPracticeGraph()
        
        card.addSubviews(titleLabel, toggleContainer, yAxisStack, graphView)
        
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            card.heightAnchor.constraint(equalToConstant: 300),
            
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            
            toggleContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            toggleContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            toggleContainer.heightAnchor.constraint(equalToConstant: 32),
            toggleContainer.widthAnchor.constraint(equalToConstant: 140),
            
            sevenDaysBtn.leadingAnchor.constraint(equalTo: toggleContainer.leadingAnchor, constant: 3),
            sevenDaysBtn.topAnchor.constraint(equalTo: toggleContainer.topAnchor, constant: 3),
            sevenDaysBtn.bottomAnchor.constraint(equalTo: toggleContainer.bottomAnchor, constant: -3),
            sevenDaysBtn.widthAnchor.constraint(equalToConstant: 64),
            
            oneMonthBtn.trailingAnchor.constraint(equalTo: toggleContainer.trailingAnchor, constant: -3),
            oneMonthBtn.topAnchor.constraint(equalTo: toggleContainer.topAnchor, constant: 3),
            oneMonthBtn.bottomAnchor.constraint(equalTo: toggleContainer.bottomAnchor, constant: -3),
            oneMonthBtn.widthAnchor.constraint(equalToConstant: 64),
            
            yAxisStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            yAxisStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            yAxisStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -50),
            yAxisStack.widthAnchor.constraint(equalToConstant: 28),
            
            graphView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            graphView.leadingAnchor.constraint(equalTo: yAxisStack.trailingAnchor, constant: 8),
            graphView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            graphView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
        
        return container
    }
    
    private func buildStaticPracticeGraph() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let days = ["mon", "tues", "wed", "thurs", "fri", "sat", "sun"]
        let values: [CGFloat] = [0, 0, 18, 22, 16, 25, 28] // minutes - first two days no activity
        let maxValue: CGFloat = 30
        
        let graphHeight: CGFloat = 160
        let barWidth: CGFloat = 30
        let spacing: CGFloat = 10
        
        for (index, day) in days.enumerated() {
            let value = values[index]
            let barHeight = max((value / maxValue) * graphHeight, value > 0 ? 20 : 0)
            
            // Bar with gradient look
            let bar = UIView()
            if value > 0 {
                bar.backgroundColor = UIColor.systemOrange
                bar.layer.cornerRadius = 4
            } else {
                bar.backgroundColor = UIColor.white.withAlphaComponent(0.15)
                bar.layer.cornerRadius = 4
            }
            bar.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(bar)
            
            // Day label
            let label = UILabel()
            label.text = day
            label.font = .systemFont(ofSize: 10, weight: .medium)
            label.textColor = UIColor.white.withAlphaComponent(0.6)
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            
            let xPos = CGFloat(index) * (barWidth + spacing)
            
            NSLayoutConstraint.activate([
                bar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: xPos),
                bar.widthAnchor.constraint(equalToConstant: barWidth),
                bar.heightAnchor.constraint(equalToConstant: barHeight),
                bar.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -28),
                
                label.centerXAnchor.constraint(equalTo: bar.centerXAnchor),
                label.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 8)
            ])
        }
        
        return container
    }
    
    // MARK: - ACHIEVEMENTS SECTION (Days Streak & Hours Spent)
    private func buildAchievementsSection() -> UIView {
        let container = UIView()
        
        let streakCard = UIView()
        streakCard.backgroundColor = .white
        streakCard.layer.cornerRadius = 20
        streakCard.layer.shadowColor = UIColor.black.cgColor
        streakCard.layer.shadowOpacity = 0.08
        streakCard.layer.shadowRadius = 12
        streakCard.layer.shadowOffset = CGSize(width: 0, height: 4)
        streakCard.translatesAutoresizingMaskIntoConstraints = false
        
        let hoursCard = UIView()
        hoursCard.backgroundColor = .white
        hoursCard.layer.cornerRadius = 20
        hoursCard.layer.shadowColor = UIColor.black.cgColor
        hoursCard.layer.shadowOpacity = 0.08
        hoursCard.layer.shadowRadius = 12
        hoursCard.layer.shadowOffset = CGSize(width: 0, height: 4)
        hoursCard.translatesAutoresizingMaskIntoConstraints = false
        
        // Streak card content
        let streakIcon = UIImageView(image: UIImage(systemName: "flame.fill"))
        streakIcon.tintColor = UIColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1.0)
        streakIcon.contentMode = .scaleAspectFit
        streakIcon.translatesAutoresizingMaskIntoConstraints = false
        
        let streakNumber = UILabel()
        streakNumber.text = "5"
        streakNumber.font = .systemFont(ofSize: 42, weight: .bold)
        streakNumber.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        streakNumber.textAlignment = .center
        streakNumber.translatesAutoresizingMaskIntoConstraints = false
        
        let streakLabel = UILabel()
        streakLabel.text = "Days Streak"
        streakLabel.font = .systemFont(ofSize: 14, weight: .medium)
        streakLabel.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        streakLabel.textAlignment = .center
        streakLabel.translatesAutoresizingMaskIntoConstraints = false
        
        streakCard.addSubviews(streakIcon, streakNumber, streakLabel)
        
        // Hours card content
        let hoursIcon = UIImageView(image: UIImage(systemName: "stopwatch.fill"))
        hoursIcon.tintColor = .systemOrange
        hoursIcon.contentMode = .scaleAspectFit
        hoursIcon.translatesAutoresizingMaskIntoConstraints = false
        
        let hoursNumber = UILabel()
        hoursNumber.text = "24"
        hoursNumber.font = .systemFont(ofSize: 42, weight: .bold)
        hoursNumber.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        hoursNumber.textAlignment = .center
        hoursNumber.translatesAutoresizingMaskIntoConstraints = false
        
        let hoursLabel = UILabel()
        hoursLabel.text = "Hours Spent"
        hoursLabel.font = .systemFont(ofSize: 14, weight: .medium)
        hoursLabel.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        hoursLabel.textAlignment = .center
        hoursLabel.translatesAutoresizingMaskIntoConstraints = false
        
        hoursCard.addSubviews(hoursIcon, hoursNumber, hoursLabel)
        
        // Layout cards side by side
        container.addSubviews(streakCard, hoursCard)
        
        NSLayoutConstraint.activate([
            streakCard.topAnchor.constraint(equalTo: container.topAnchor),
            streakCard.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            streakCard.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            streakCard.heightAnchor.constraint(equalToConstant: 150),
            
            hoursCard.topAnchor.constraint(equalTo: container.topAnchor),
            hoursCard.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            hoursCard.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hoursCard.heightAnchor.constraint(equalToConstant: 150),
            
            streakCard.trailingAnchor.constraint(equalTo: hoursCard.leadingAnchor, constant: -16),
            streakCard.widthAnchor.constraint(equalTo: hoursCard.widthAnchor),
            
            // Streak card contents
            streakIcon.topAnchor.constraint(equalTo: streakCard.topAnchor, constant: 18),
            streakIcon.centerXAnchor.constraint(equalTo: streakCard.centerXAnchor),
            streakIcon.widthAnchor.constraint(equalToConstant: 36),
            streakIcon.heightAnchor.constraint(equalToConstant: 36),
            
            streakNumber.topAnchor.constraint(equalTo: streakIcon.bottomAnchor, constant: 8),
            streakNumber.centerXAnchor.constraint(equalTo: streakCard.centerXAnchor),
            
            streakLabel.topAnchor.constraint(equalTo: streakNumber.bottomAnchor, constant: 4),
            streakLabel.centerXAnchor.constraint(equalTo: streakCard.centerXAnchor),
            
            // Hours card contents
            hoursIcon.topAnchor.constraint(equalTo: hoursCard.topAnchor, constant: 18),
            hoursIcon.centerXAnchor.constraint(equalTo: hoursCard.centerXAnchor),
            hoursIcon.widthAnchor.constraint(equalToConstant: 36),
            hoursIcon.heightAnchor.constraint(equalToConstant: 36),
            
            hoursNumber.topAnchor.constraint(equalTo: hoursIcon.bottomAnchor, constant: 8),
            hoursNumber.centerXAnchor.constraint(equalTo: hoursCard.centerXAnchor),
            
            hoursLabel.topAnchor.constraint(equalTo: hoursNumber.bottomAnchor, constant: 4),
            hoursLabel.centerXAnchor.constraint(equalTo: hoursCard.centerXAnchor)
        ])
        
        return container
    }
    
    // MARK: - MOST PLAYED SECTION
    private func buildMostPlayedSection() -> UIView {
        let container = UIView()
        
        // Section header
        let headerLabel = UILabel()
        headerLabel.text = "Most Played"
        headerLabel.font = .systemFont(ofSize: 20, weight: .bold)
        headerLabel.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerLabel)
        
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 20
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowRadius = 12
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)
        
        let stack = UIStackView(arrangedSubviews: [
            mostPlayedRow(title: "Go Away", artist: "Weezer", plays: "23\nTimes"),
            mostPlayedRow(title: "Ride Home", artist: "Weezer", plays: "16\nTimes")
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: container.topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            
            card.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return container
    }
    
    private func mostPlayedRow(title: String, artist: String, plays: String) -> UIView {
        let row = UIView()

        // Album art placeholder
        let albumArt = UIView()
        albumArt.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.15)
        albumArt.layer.cornerRadius = 12
        albumArt.clipsToBounds = true
        albumArt.translatesAutoresizingMaskIntoConstraints = false
        
        let musicIcon = UIImageView(image: UIImage(systemName: "music.note"))
        musicIcon.tintColor = .systemOrange
        musicIcon.contentMode = .scaleAspectFit
        musicIcon.translatesAutoresizingMaskIntoConstraints = false
        albumArt.addSubview(musicIcon)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let artistLabel = UILabel()
        artistLabel.text = artist
        artistLabel.font = .systemFont(ofSize: 13, weight: .regular)
        artistLabel.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        artistLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, artistLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let playsLabel = UILabel()
        playsLabel.text = plays
        playsLabel.font = .systemFont(ofSize: 16, weight: .bold)
        playsLabel.textColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        playsLabel.numberOfLines = 2
        playsLabel.textAlignment = .right
        playsLabel.translatesAutoresizingMaskIntoConstraints = false

        row.addSubviews(albumArt, textStack, playsLabel)
        
        NSLayoutConstraint.activate([
            albumArt.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            albumArt.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            albumArt.heightAnchor.constraint(equalToConstant: 56),
            albumArt.widthAnchor.constraint(equalToConstant: 56),
            
            musicIcon.centerXAnchor.constraint(equalTo: albumArt.centerXAnchor),
            musicIcon.centerYAnchor.constraint(equalTo: albumArt.centerYAnchor),
            musicIcon.widthAnchor.constraint(equalToConstant: 24),
            musicIcon.heightAnchor.constraint(equalToConstant: 24),

            textStack.leadingAnchor.constraint(equalTo: albumArt.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            playsLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            playsLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            playsLabel.widthAnchor.constraint(equalToConstant: 60),

            row.heightAnchor.constraint(equalToConstant: 72)
        ])

        return row
    }

    private func buildSignOutButton() -> UIView {
        let container = UIView()
        
        signOutButton.setTitle("Sign Out", for: .normal)
        signOutButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        signOutButton.setTitleColor(.white, for: .normal)
        signOutButton.backgroundColor = .primaryColor
        signOutButton.layer.cornerRadius = 28 // Unified pill shape
        signOutButton.layer.shadowColor = UIColor.black.cgColor
        signOutButton.layer.shadowOpacity = 0.08
        signOutButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        signOutButton.layer.shadowRadius = 8
        signOutButton.addTarget(self, action: #selector(signOutTapped), for: .touchUpInside)
        signOutButton.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(signOutButton)
        
        NSLayoutConstraint.activate([
            signOutButton.topAnchor.constraint(equalTo: container.topAnchor),
            signOutButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            signOutButton.widthAnchor.constraint(equalToConstant: 240), // Slightly wider for consistency with login buttons
            signOutButton.heightAnchor.constraint(equalToConstant: 56),
            signOutButton.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }

    @objc private func signOutTapped() {
        let alert = UIAlertController(title: "Sign Out",
                                      message: "Are you sure you want to log out?",
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive, handler: { _ in
            self.performSignOut()
        }))
        
        present(alert, animated: true)
    }
    
    private func performSignOut() {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.signOut()
                
                await MainActor.run {
                    // Transition to Login Screen
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    if let loginVC = storyboard.instantiateInitialViewController() {
                        if let window = self.view.window {
                            window.rootViewController = loginVC
                            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "Error", message: "Failed to sign out: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func editDailyGoalTapped() {
        let alert = UIAlertController(title: "Set Daily Goal",
                                      message: "Enter your daily practice goal in minutes",
                                      preferredStyle: .alert)
        
        alert.addTextField { tf in
            tf.placeholder = "Minutes"
            tf.text = "\(self.currentDailyGoalMinutes)"
            tf.keyboardType = .numberPad
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { _ in
            if let minutesStr = alert.textFields?[0].text,
               let minutes = Int(minutesStr),
               minutes > 0 {
                self.currentDailyGoalMinutes = minutes
                self.updateDailyGoal(minutes: minutes)
            } else {
                self.showAlert(title: "Invalid Input", message: "Please enter a valid number")
            }
        }))
        
        present(alert, animated: true)
    }
    
    private func updateDailyGoal(minutes: Int) {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            
            do {
                let updates: [String: Int] = ["daily_goal_minutes": minutes]
                
                _ = try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(updates)
                    .eq("id", value: user.id.uuidString)
                    .execute()
                
                self.currentProfile?.daily_goal_minutes = minutes
                
                await MainActor.run {
                    // Update DailyGoalManager to sync with home screen
                    DailyGoalManager.shared.dailyGoalMinutes = minutes
                    
                    self.dailyGoalTimeLabel.text = "\(minutes) mins"
                    self.showAlert(title: "Success", message: "Daily goal updated!")
                }
            } catch {
                print("Error updating daily goal:", error)
                await MainActor.run {
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Supabase: Load & Update Profile
private extension UserProfileViewController {
    
    func loadProfile() {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else {
                await MainActor.run {
                    self.nameLabel.text = "Not logged in"
                    self.usernameLabel.text = "@username"
                }
                return
            }
            
            do {
                let profile: Profile = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .eq("id", value: user.id.uuidString)
                    .single()
                    .execute()
                    .value
                
                self.currentProfile = profile
                
                // Update name with user's name
                let displayName = profile.full_name?.isEmpty == false ? profile.full_name ?? "User" : "User"
                
                await MainActor.run {
                    self.nameLabel.text = displayName
                    
                    if let username = profile.username, !username.isEmpty {
                        self.usernameLabel.text = "@\(username)"
                    } else {
                        self.usernameLabel.text = "@username"
                    }
                    
                    // Set daily goal and sync with DailyGoalManager
                    if let goalMinutes = profile.daily_goal_minutes {
                        self.currentDailyGoalMinutes = goalMinutes
                        DailyGoalManager.shared.dailyGoalMinutes = goalMinutes
                        self.dailyGoalTimeLabel.text = "\(goalMinutes) mins"
                        self.dailyGoalProgressView.progress = Float(self.currentDailyProgressMinutes) / Float(goalMinutes)
                    }
                    
                    self.updateAvatar(with: profile.avatar_url)
                }
            } catch {
                print("Error loading profile:", error)
                await MainActor.run {
                    self.nameLabel.text = "Profile Error"
                    self.usernameLabel.text = "@username"
                    self.updateAvatar(with: nil)
                }
            }
        }
    }
    
    /// Load avatar image from a URL string stored in `avatar_url`
    func updateAvatar(with urlString: String?) {
        // Reset to default first
        self.profileImageView.image = UIImage(systemName: "person.fill")
        self.profileImageView.tintColor = .white
        self.profileImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.35)
        self.profileImageView.contentMode = .center
        
        guard
            let urlString = urlString,
            !urlString.isEmpty
        else {
            return  // keep default
        }
        
        Task {
            do {
                // Check if URL is valid
                var finalURLString = urlString
                
                // Fix the URL if it's missing /public/
                if urlString.contains("supabase.co/storage/v1/object/useprofile/") && !urlString.contains("/public/") {
                    // Replace /object/useprofile/ with /object/public/useprofile/
                    finalURLString = urlString.replacingOccurrences(of: "/object/useprofile/", with: "/object/public/useprofile/")
                }
                
                guard let url = URL(string: finalURLString) else {
                    print("Invalid URL string: \(finalURLString)")
                    return
                }
                
                print("Loading avatar from: \(url)")
                
                // Load image with timeout
                let request = URLRequest(url: url, timeoutInterval: 30)
                let (data, _) = try await URLSession.shared.data(for: request)
                
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.profileImageView.image = image
                        self.profileImageView.contentMode = .scaleAspectFill
                        self.profileImageView.backgroundColor = .clear
                        self.profileImageView.tintColor = .clear
                    }
                }
            } catch {
                print("Failed to load avatar image:", error)
                print("URL attempted: \(urlString)")
            }
        }
    }

    // MARK: - Edit Profile (name/username and password) - PENCIL BUTTON
    @objc func editProfileTapped() {
        let alert = UIAlertController(title: "Edit Profile",
                                      message: "What would you like to update?",
                                      preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Update Name & Username", style: .default, handler: { _ in
            self.showNameUsernameEditor()
        }))
        
        alert.addAction(UIAlertAction(title: "Change Password", style: .default, handler: { _ in
            self.showPasswordChangeDialog()
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = editButton
            popoverController.sourceRect = editButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func showNameUsernameEditor() {
        let alert = UIAlertController(title: "Update Profile",
                                      message: "Update your name and username",
                                      preferredStyle: .alert)
        
        alert.addTextField { tf in
            tf.placeholder = "Full Name"
            tf.text = self.currentProfile?.full_name ?? self.nameLabel.text
        }
        alert.addTextField { tf in
            tf.placeholder = "Username"
            if let username = self.currentProfile?.username {
                tf.text = username
            } else if let text = self.usernameLabel.text, text.hasPrefix("@") {
                tf.text = String(text.dropFirst())
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { _ in
            let fullName = alert.textFields?[0].text ?? ""
            let username = alert.textFields?[1].text ?? ""
            self.updateProfile(fullName: fullName, username: username)
        }))
        
        present(alert, animated: true)
    }
    
    private func showPasswordChangeDialog() {
        let alert = UIAlertController(title: "Change Password",
                                      message: "Enter your new password",
                                      preferredStyle: .alert)
        
        alert.addTextField { tf in
            tf.placeholder = "New Password"
            tf.isSecureTextEntry = true
        }
        
        alert.addTextField { tf in
            tf.placeholder = "Confirm New Password"
            tf.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Change", style: .default, handler: { _ in
            let newPassword = alert.textFields?[0].text ?? ""
            let confirmPassword = alert.textFields?[1].text ?? ""
            
            if newPassword.isEmpty {
                self.showAlert(title: "Error", message: "Password cannot be empty")
            } else if newPassword != confirmPassword {
                self.showAlert(title: "Error", message: "Passwords do not match")
            } else if newPassword.count < 6 {
                self.showAlert(title: "Error", message: "Password must be at least 6 characters")
            } else {
                self.updatePassword(newPassword: newPassword)
            }
        }))
        
        present(alert, animated: true)
    }
    
    func updateProfile(fullName: String, username: String) {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            
            // Create updates dictionary with only String values
            var updates: [String: String?] = [
                "full_name": fullName.isEmpty ? nil : fullName
            ]
            
            // Only add username if it's not empty
            if !username.isEmpty {
                updates["username"] = username
            } else {
                updates["username"] = nil
            }
            
            do {
                // Filter out nil values for the update
                let filteredUpdates = updates.compactMapValues { $0 }
                
                _ = try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(filteredUpdates)
                    .eq("id", value: user.id.uuidString)
                    .execute()
                
                // Create a new Profile object with updated values
                self.currentProfile = Profile(
                    id: self.currentProfile?.id ?? user.id,
                    full_name: fullName.isEmpty ? nil : fullName,
                    username: username.isEmpty ? nil : username,
                    avatar_url: self.currentProfile?.avatar_url,
                    bio: self.currentProfile?.bio,
                    daily_goal_minutes: self.currentProfile?.daily_goal_minutes
                )
                
                await MainActor.run {
                    self.nameLabel.text = fullName.isEmpty ? "No Name" : fullName
                    self.usernameLabel.text = username.isEmpty ? "@username" : "@\(username)"
                    self.showAlert(title: "Success", message: "Profile updated successfully")
                    
                    // Send notification to refresh navbar
                    NotificationCenter.default.post(name: TopNavBar.profileDidUpdateNotification, object: nil)
                }
            } catch {
                print("Error updating profile:", error)
                await MainActor.run {
                    self.showAlert(title: "Update failed", message: error.localizedDescription)
                }
            }
        }
        
    }
    
    func updatePassword(newPassword: String) {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.update(user: .init(password: newPassword))
                
                await MainActor.run {
                    self.showAlert(title: "Success", message: "Password updated successfully")
                }
            } catch {
                print("Error updating password:", error)
                await MainActor.run {
                    self.showAlert(title: "Update failed", message: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Avatar: Pick & Upload to Supabase (bucket: useprofile) - CAMERA BADGE
extension UserProfileViewController {
    
    @objc func changeAvatarTapped() {
        let alert = UIAlertController(title: "Change Profile Picture",
                                      message: "Choose an option",
                                      preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Choose from Library", style: .default, handler: { _ in
            self.openPhotoLibrary()
        }))
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Take Photo", style: .default, handler: { _ in
                self.openCamera()
            }))
        }
        
        // Check if user has existing avatar to allow removal
        if let currentProfile = currentProfile, currentProfile.avatar_url != nil {
            alert.addAction(UIAlertAction(title: "Remove Current Photo", style: .destructive, handler: { _ in
                self.removeAvatar()
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = cameraBadgeView
            popoverController.sourceRect = cameraBadgeView.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func openPhotoLibrary() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = self
        picker.modalPresentationStyle = .fullScreen
        present(picker, animated: true)
    }
    
    private func openCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = self
        picker.modalPresentationStyle = .fullScreen
        present(picker, animated: true)
    }
    
    private func removeAvatar() {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            
            do {
                // Update database to remove avatar_url
                let updates: [String: String?] = [
                    "avatar_url": nil
                ]
                
                // Filter out nil values
                let filteredUpdates = updates.compactMapValues { $0 }
                
                _ = try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(filteredUpdates)
                    .eq("id", value: user.id.uuidString)
                    .execute()
                
                // Create a new Profile object without avatar_url
                self.currentProfile = Profile(
                    id: self.currentProfile?.id ?? user.id,
                    full_name: self.currentProfile?.full_name,
                    username: self.currentProfile?.username,
                    avatar_url: nil,
                    bio: self.currentProfile?.bio,
                    daily_goal_minutes: self.currentProfile?.daily_goal_minutes
                )
                
                await MainActor.run {
                    self.profileImageView.image = UIImage(systemName: "person.fill")
                    self.profileImageView.tintColor = .white
                    self.profileImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.35)
                    self.profileImageView.contentMode = .center
                    self.showAlert(title: "Success", message: "Profile picture removed")
                }
            } catch {
                print("Error removing avatar:", error)
                await MainActor.run {
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    // UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage else {
            self.showAlert(title: "Error", message: "Could not select image")
            return
        }
        
        // Update UI immediately
        self.profileImageView.image = image
        self.profileImageView.contentMode = .scaleAspectFill
        self.profileImageView.backgroundColor = .clear
        self.profileImageView.tintColor = .clear
        
        // Upload to Supabase Storage
        uploadAvatarImage(image)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func uploadAvatarImage(_ image: UIImage) {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else {
                await MainActor.run {
                    self.showAlert(title: "Error", message: "Not logged in")
                }
                return
            }
            
            guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
                await MainActor.run {
                    self.showAlert(title: "Error", message: "Could not prepare image data.")
                }
                return
            }
            
            let client = SupabaseManager.shared.client
            
            // Unique file name
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "avatar_\(user.id.uuidString)_\(timestamp).jpg"
            
            do {
                // METHOD 1: Try simplest upload without options
                try await client.storage
                    .from("useprofile")
                    .upload(
                        path: fileName,
                        file: jpegData
                    )
                
                print("✅ Upload successful")
                
            } catch {
                print("❌ Method 1 failed, trying Method 2:", error)
                
                // METHOD 2: Try with FileOptions (FIXED ORDER - cacheControl before contentType)
                do {
                    try await client.storage
                        .from("useprofile")
                        .upload(
                            path: fileName,
                            file: jpegData,
                            options: FileOptions(
                                cacheControl: "3600",
                                contentType: "image/jpeg"
                            )
                        )
                    
                    print("✅ Method 2 upload successful")
                    
                } catch {
                    print("❌ All upload methods failed:", error)
                    await MainActor.run {
                        // Revert to default image
                        self.profileImageView.image = UIImage(systemName: "person.fill")
                        self.profileImageView.tintColor = .white
                        self.profileImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.35)
                        self.profileImageView.contentMode = .center
                        
                        let errorMessage: String
                        if (error as NSError).code == -1005 {
                            errorMessage = "Network connection lost. Please check your internet and try again."
                        } else {
                            errorMessage = "Upload failed: \(error.localizedDescription)"
                        }
                        self.showAlert(title: "Upload Error", message: errorMessage)
                    }
                    return
                }
            }
            
            // If we get here, upload was successful
            // Get the correct public URL
            let projectRef = "djqgmowfjxsnjdffdohw" // REPLACE WITH YOUR PROJECT REF
            let publicURL = "https://\(projectRef).supabase.co/storage/v1/object/public/useprofile/\(fileName)"
            
            // Save URL in profiles.avatar_url
            let updates: [String: String] = [
                "avatar_url": publicURL
            ]
            
            do {
                _ = try await client
                    .from("profiles")
                    .update(updates)
                    .eq("id", value: user.id.uuidString)
                    .execute()
                
                // Create a new Profile object with updated avatar_url
                self.currentProfile = Profile(
                    id: self.currentProfile?.id ?? user.id,
                    full_name: self.currentProfile?.full_name,
                    username: self.currentProfile?.username,
                    avatar_url: publicURL,
                    bio: self.currentProfile?.bio,
                    daily_goal_minutes: self.currentProfile?.daily_goal_minutes
                )
                
                await MainActor.run {
                    self.showAlert(title: "Success", message: "Profile picture updated!")
                    
                    // Send notification to refresh navbar
                    NotificationCenter.default.post(name: TopNavBar.profileDidUpdateNotification, object: nil)
                }
                
            } catch {
                print("❌ Error saving to database:", error)
                await MainActor.run {
                    self.showAlert(title: "Database Error", message: "Image uploaded but couldn't update profile.")
                }
            }
        }
    }
}

// MARK: - Helpers
private extension UserProfileViewController {
    func showAlert(title: String, message: String) {
        if presentedViewController is UIAlertController { return }
        
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Gradient Header
final class GradientHeaderView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        gradient.colors = [
            UIColor(red: 1.0, green: 0.75, blue: 0.36, alpha: 1).cgColor,
            UIColor(red: 1.0, green: 0.93, blue: 0.83, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradient, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}

extension UIView {
    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }
}
