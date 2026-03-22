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
    var total_study_seconds: Int?
}

struct OnboardingData: Codable {
    let practice_mins: Int
}

// MARK: - Stats model fetched from lesson_events
struct ProfileStats {
    var totalPracticeSeconds: Int = 0
    var totalLessons: Int = 0
    var currentStreak: Int = 0
    var weeklyData: [CGFloat] = [0, 0, 0, 0, 0, 0, 0] // Mon–Sun in hours
}

final class UserProfileViewController: UIViewController {

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Header
    private let profileImageView = UIImageView()
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()
    private let titleLabel = UILabel()
    private let editProfileButton = UIButton(type: .system)

    // Stat cards
    private let practiceLabel = UILabel()
    private let lessonsLabel = UILabel()
    private let streakLabel = UILabel()

    // Practice Progress
    private let weeklyHoursLabel = UILabel()
    private let goalBadgeBg = UIView()
    private let goalBadgeLabel = UILabel()
    private var chartBars: [UIView] = []
    private var chartDots: [UIView] = []

    // Sign out
    private let signOutButton = UIButton(type: .system)

    // Data
    private var currentProfile: Profile?
    private var stats = ProfileStats()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.ProfileScreen.background // #F8F8F4
        navigationController?.navigationBar.isHidden = true
        setupUI()
        loadData()
    }

    // MARK: - Setup UI
    private func setupUI() {
        // Scroll
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        buildHeaderSection()
        buildStatsSection()
        buildPracticeProgressSection()
        buildSignOutSection()
    }

    // MARK: - HEADER (avatar + name + username + edit)
    private func buildHeaderSection() {
        // Back button
        let backBtn = UIButton(type: .system)
        backBtn.setImage(UIImage(systemName: "chevron.left",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)),
                         for: .normal)
        backBtn.tintColor = ComponentColors.NavBar.backButton
        backBtn.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backBtn)

        titleLabel.text = "Profile"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = ComponentColors.ProfileScreen.userName
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Avatar ring
        let ringSize: CGFloat = 110
        let ringView = UIView()
        ringView.translatesAutoresizingMaskIntoConstraints = false
        // Gradient ring via CAGradientLayer mask
        let ringGradient = CAGradientLayer()
        ringGradient.colors = [
            ComponentColors.ProfileScreen.avatarBorder.cgColor,
            ComponentColors.ProfileScreen.avatarBorder.cgColor
        ]
        ringGradient.startPoint = CGPoint(x: 0, y: 0)
        ringGradient.endPoint = CGPoint(x: 1, y: 1)
        ringGradient.cornerRadius = ringSize / 2
        ringView.layer.addSublayer(ringGradient)
        ringView.layer.cornerRadius = ringSize / 2
        ringView.clipsToBounds = false
        contentView.addSubview(ringView)

        profileImageView.image = UIImage(systemName: "person.fill")
        profileImageView.tintColor = .white
        profileImageView.backgroundColor = ComponentColors.ProfileScreen.headerCardFill
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = (ringSize - 8) / 2
        profileImageView.isUserInteractionEnabled = true
        profileImageView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(changeAvatarTapped))
        )
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(profileImageView)

        nameLabel.text = "Loading..."
        nameLabel.font = .systemFont(ofSize: 24, weight: .bold)
        nameLabel.textColor = ComponentColors.ProfileScreen.userName
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        usernameLabel.text = "@username"
        usernameLabel.font = .systemFont(ofSize: 15, weight: .regular)
        usernameLabel.textColor = ComponentColors.ProfileScreen.userHandle
        usernameLabel.textAlignment = .center
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(usernameLabel)

        editProfileButton.setTitle("Profile", for: .normal)
        editProfileButton.setTitleColor(ComponentColors.ProfileScreen.editProfileText, for: .normal)
        editProfileButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        editProfileButton.addTarget(self, action: #selector(editProfileTapped), for: .touchUpInside)
        editProfileButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(editProfileButton)

        NSLayoutConstraint.activate([
            backBtn.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 16),
            backBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            backBtn.widthAnchor.constraint(equalToConstant: 32),
            backBtn.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.centerYAnchor.constraint(equalTo: backBtn.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            ringView.topAnchor.constraint(equalTo: backBtn.bottomAnchor, constant: 28),
            ringView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            ringView.widthAnchor.constraint(equalToConstant: ringSize),
            ringView.heightAnchor.constraint(equalToConstant: ringSize),

            profileImageView.centerXAnchor.constraint(equalTo: ringView.centerXAnchor),
            profileImageView.centerYAnchor.constraint(equalTo: ringView.centerYAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: ringSize - 8),
            profileImageView.heightAnchor.constraint(equalToConstant: ringSize - 8),

            nameLabel.topAnchor.constraint(equalTo: ringView.bottomAnchor, constant: 16),
            nameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            usernameLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            editProfileButton.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 8),
            editProfileButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])

        // Layout ring gradient after constraints settle
        DispatchQueue.main.async {
            ringGradient.frame = ringView.bounds
        }
    }

    // MARK: - STATS (3 cards: Practice, Lessons, Streak)
    private func buildStatsSection() {
        let statsContainer = UIView()
        statsContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statsContainer)

        // Find editProfileButton to anchor below it
        let brandColor = ComponentColors.ProfileScreen.editProfileText // #EF9408
        let cards = [
            makeStatCard(iconName: "clock", iconColor: brandColor,
                         valueLabel: practiceLabel, valueText: "–", subtitleText: "Practice"),
            makeStatCard(iconName: "book.fill", iconColor: brandColor,
                         valueLabel: lessonsLabel, valueText: "–", subtitleText: "Lessons"),
            makeStatCard(iconName: "flame.fill", iconColor: brandColor,
                         valueLabel: streakLabel, valueText: "–", subtitleText: "Streak")
        ]

        let stack = UIStackView(arrangedSubviews: cards)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        statsContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: statsContainer.topAnchor),
            stack.leadingAnchor.constraint(equalTo: statsContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: statsContainer.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: statsContainer.bottomAnchor),
        ])

        // Anchor statsContainer below editProfileButton
        NSLayoutConstraint.activate([
            statsContainer.topAnchor.constraint(equalTo: editProfileButton.bottomAnchor, constant: 28),
            statsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            statsContainer.heightAnchor.constraint(equalToConstant: 100),
        ])
    }

    private func makeStatCard(iconName: String, iconColor: UIColor,
                               valueLabel: UILabel, valueText: String,
                               subtitleText: String) -> UIView {
        let card = UIView()
        card.backgroundColor = ComponentColors.ProfileScreen.statCardFill // #FBF1DA 80%
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 0.5
        card.layer.borderColor = ComponentColors.ProfileScreen.statCardBorder.cgColor // #EF9408 at 40%

        let icon = UIImageView(image: UIImage(systemName: iconName))
        icon.tintColor = iconColor
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.text = valueText
        valueLabel.font = .systemFont(ofSize: 22, weight: .bold)
        valueLabel.textColor = ComponentColors.ProfileScreen.userName
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = subtitleText
        subtitle.font = .systemFont(ofSize: 10, weight: .semibold)
        subtitle.textColor = ComponentColors.ProfileScreen.statLabel
        subtitle.textAlignment = .center
        let subtitleAttrs = NSMutableAttributedString(string: subtitleText)
        subtitleAttrs.addAttribute(.kern, value: 1.2, range: NSRange(location: 0, length: subtitleText.count))
        subtitle.attributedText = subtitleAttrs
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(icon)
        card.addSubview(valueLabel)
        card.addSubview(subtitle)

        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            icon.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

            valueLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 6),
            valueLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            subtitle.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            subtitle.centerXAnchor.constraint(equalTo: card.centerXAnchor),
        ])

        return card
    }

    // MARK: - PRACTICE PROGRESS SECTION
    private func buildPracticeProgressSection() {
        let card = UIView()
        card.backgroundColor = ComponentColors.ProfileScreen.headerCardFill
        card.layer.cornerRadius = 20
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        // Title row
        let titleLabel = UILabel()
        titleLabel.text = "Practice Progress"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = ComponentColors.ProfileScreen.userName
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)

        // Goal badge
        goalBadgeBg.backgroundColor = ComponentColors.ProfileScreen.statCardFill
        goalBadgeBg.layer.cornerRadius = 12
        goalBadgeBg.isUserInteractionEnabled = true
        goalBadgeBg.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dailyGoalBadgeTapped)))
        goalBadgeBg.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(goalBadgeBg)

        goalBadgeLabel.text = "Goal: –"
        goalBadgeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        goalBadgeLabel.textColor = ComponentColors.ProfileScreen.editProfileText
        goalBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        goalBadgeBg.addSubview(goalBadgeLabel)

        // Weekly hours
        weeklyHoursLabel.text = "– h"
        weeklyHoursLabel.font = .systemFont(ofSize: 36, weight: .bold)
        weeklyHoursLabel.textColor = ComponentColors.ProfileScreen.userName
        weeklyHoursLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(weeklyHoursLabel)

        let thisWeekLabel = UILabel()
        thisWeekLabel.text = "This Week"
        thisWeekLabel.font = .systemFont(ofSize: 14, weight: .regular)
        thisWeekLabel.textColor = ComponentColors.ProfileScreen.statLabel
        thisWeekLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(thisWeekLabel)

        // Chart area
        let chartContainer = buildAreaChartView()
        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(chartContainer)

        // Find statsContainer (3rd subview of contentView after back btn, titleLabel)
        // We'll anchor card below statsContainer
        // Get statsContainer by finding the last added subview before this
        let statsContainer = contentView.subviews.last(where: { $0 != card })!

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: statsContainer.bottomAnchor, constant: 20),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),

            goalBadgeBg.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            goalBadgeBg.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            goalBadgeBg.heightAnchor.constraint(equalToConstant: 28),

            goalBadgeLabel.topAnchor.constraint(equalTo: goalBadgeBg.topAnchor, constant: 6),
            goalBadgeLabel.bottomAnchor.constraint(equalTo: goalBadgeBg.bottomAnchor, constant: -6),
            goalBadgeLabel.leadingAnchor.constraint(equalTo: goalBadgeBg.leadingAnchor, constant: 10),
            goalBadgeLabel.trailingAnchor.constraint(equalTo: goalBadgeBg.trailingAnchor, constant: -10),

            weeklyHoursLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            weeklyHoursLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),

            thisWeekLabel.leadingAnchor.constraint(equalTo: weeklyHoursLabel.trailingAnchor, constant: 8),
            thisWeekLabel.lastBaselineAnchor.constraint(equalTo: weeklyHoursLabel.lastBaselineAnchor),

            chartContainer.topAnchor.constraint(equalTo: weeklyHoursLabel.bottomAnchor, constant: 8),
            chartContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            chartContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            chartContainer.heightAnchor.constraint(equalToConstant: 130),
            chartContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
    }

    private func buildAreaChartView() -> UIView {
        // We'll draw this as a custom CAShapeLayer view
        let chartView = PracticeChartView()
        chartView.weeklyData = stats.weeklyData
        chartView.tag = 9901 // so we can find and update it
        return chartView
    }

    // MARK: - SIGN OUT SECTION
    private func buildSignOutSection() {
        signOutButton.setTitle("Sign Out", for: .normal)
        signOutButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        signOutButton.setTitleColor(ComponentColors.ProfileScreen.destructiveText, for: .normal)
        signOutButton.backgroundColor = ComponentColors.DestructiveButton.fill
        signOutButton.layer.cornerRadius = 28
        signOutButton.addTarget(self, action: #selector(signOutTapped), for: .touchUpInside)
        signOutButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(signOutButton)

        // Anchor below practice progress card
        let practiceCard = contentView.subviews.last(where: { $0 != signOutButton })!

        NSLayoutConstraint.activate([
            signOutButton.topAnchor.constraint(equalTo: practiceCard.bottomAnchor, constant: 28),
            signOutButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            signOutButton.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -48),
            signOutButton.heightAnchor.constraint(equalToConstant: 56),
            signOutButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -48),
        ])
    }

    // MARK: - Load Data
    private func loadData() {
        Task {
            await loadProfile()
            await loadStats()
        }
    }

    private func loadProfile() async {
        guard let user = SupabaseManager.shared.client.auth.currentUser else {
            await MainActor.run { nameLabel.text = "Not logged in" }
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

            await MainActor.run {
                nameLabel.text = profile.full_name?.isEmpty == false ? profile.full_name : "No Name"
                usernameLabel.text = profile.username.map { "@\($0)" } ?? "@username"
                updateAvatar(with: profile.avatar_url)
            }
            
            // Fetch daily goal from user_onboarding
            do {
                let onboarding: OnboardingData = try await SupabaseManager.shared.client
                    .from("user_onboarding")
                    .select("practice_mins")
                    .eq("id", value: user.id.uuidString)
                    .single()
                    .execute()
                    .value
                
                await MainActor.run {
                    let goalMins = onboarding.practice_mins
                    let goalHours = Double(goalMins) / 60.0
                    goalBadgeLabel.text = goalHours == goalHours.rounded() ?
                        "Goal: \(Int(goalHours))h" : String(format: "Goal: %.1fh", goalHours)
                    DailyGoalManager.shared.dailyGoalMinutes = goalMins
                }
            } catch {
                print("Error loading onboarding goal:", error)
            }
        } catch {
            print("Error loading profile:", error)
            await MainActor.run { nameLabel.text = "Error" }
        }
    }

    private func loadStats() async {
        guard let user = SupabaseManager.shared.client.auth.currentUser else { return }

        do {
            // Fetch lesson_events for this user
            struct LessonEvent: Decodable {
                let duration_seconds: Int?
                let occurred_at: String
                let event_type: String?
            }

            let events: [LessonEvent] = try await SupabaseManager.shared.client
                .from("lesson_events")
                .select("duration_seconds, occurred_at, event_type")
                .eq("user_id", value: user.id.uuidString)
                .execute()
                .value

            // Calculate totals
            let totalSeconds = events.compactMap { $0.duration_seconds }.reduce(0, +)
            let totalLessons = events.count

            // Weekly data (last 7 days Mon–Sun)
            var weeklySeconds = [Double](repeating: 0, count: 7)
            let calendar = Calendar.current
            let now = Date()

            // Find the most recent Monday
            let weekday = calendar.component(.weekday, from: now) // 1=Sun, 2=Mon...
            let daysSinceMonday = (weekday + 5) % 7
            guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: calendar.startOfDay(for: now)) else { return }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            for event in events {
                guard let seconds = event.duration_seconds,
                      let date = formatter.date(from: event.occurred_at) else { continue }
                let dayStart = calendar.startOfDay(for: date)
                let diff = calendar.dateComponents([.day], from: monday, to: dayStart).day ?? -1
                if diff >= 0 && diff < 7 {
                    weeklySeconds[diff] += Double(seconds)
                }
            }

            let weeklyHours = weeklySeconds.map { $0 / 3600.0 }
            let thisWeekHours = weeklyHours.reduce(0, +)

            // Streak: consecutive days with practice up to today
            var streak = 0
            var checkDate = calendar.startOfDay(for: now)
            let practicedDays = Set(events.compactMap { event -> Date? in
                guard let date = formatter.date(from: event.occurred_at) else { return nil }
                return calendar.startOfDay(for: date)
            })

            while practicedDays.contains(checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            }

            await MainActor.run {
                // Practice hours label
                let totalHours = Double(totalSeconds) / 3600.0
                practiceLabel.text = totalHours < 10 ?
                    String(format: "%.1fh", totalHours) : "\(Int(totalHours))h"

                lessonsLabel.text = "\(totalLessons)"
                streakLabel.text = "\(streak)"

                let weekHours = thisWeekHours < 10 ?
                    String(format: "%.1fh", thisWeekHours) : "\(Int(thisWeekHours))h"
                weeklyHoursLabel.text = weekHours

                // Update chart
                if let chart = contentView.viewWithTag(9901) as? PracticeChartView {
                    chart.weeklyData = weeklyHours.map { CGFloat($0) }
                    chart.setNeedsDisplay()
                }
            }
        } catch {
            print("Error loading stats:", error)
        }
    }

    // MARK: - Actions
    @objc private func goBack() {
        NotificationCenter.default.post(name: TopNavBar.profileDidUpdateNotification, object: nil)
        navigationController?.popViewController(animated: true)
    }

    @objc private func signOutTapped() {
        let alert = UIAlertController(title: "Sign Out",
                                      message: "Are you sure you want to sign out?",
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
                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                    if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
                        sceneDelegate.showSplashAndRoute()
                    }
                }
            } catch {
                await MainActor.run {
                    showAlert(title: "Error", message: "Failed to sign out: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Edit Profile
    @objc func editProfileTapped() {
        let alert = UIAlertController(title: "Edit Profile", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Update Name & Username", style: .default) { _ in
            self.showNameUsernameEditor()
        })
        alert.addAction(UIAlertAction(title: "Change Password", style: .default) { _ in
            self.showPasswordChangeDialog()
        })
        alert.addAction(UIAlertAction(title: "Change Profile Photo", style: .default) { _ in
            self.changeAvatarTapped()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = editProfileButton
            pop.sourceRect = editProfileButton.bounds
        }
        present(alert, animated: true)
    }

    private func showNameUsernameEditor() {
        let alert = UIAlertController(title: "Update Profile", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Full Name"; $0.text = self.currentProfile?.full_name }
        alert.addTextField { $0.placeholder = "Username"; $0.text = self.currentProfile?.username }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let name = alert.textFields?[0].text ?? ""
            let user = alert.textFields?[1].text ?? ""
            self.updateProfile(fullName: name, username: user)
        })
        present(alert, animated: true)
    }

    private func showPasswordChangeDialog() {
        let alert = UIAlertController(title: "Change Password", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "New Password"; $0.isSecureTextEntry = true }
        alert.addTextField { $0.placeholder = "Confirm Password"; $0.isSecureTextEntry = true }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Change", style: .default) { _ in
            let pw = alert.textFields?[0].text ?? ""
            let pw2 = alert.textFields?[1].text ?? ""
            if pw.isEmpty { self.showAlert(title: "Error", message: "Password cannot be empty") }
            else if pw != pw2 { self.showAlert(title: "Error", message: "Passwords don't match") }
            else if pw.count < 6 { self.showAlert(title: "Error", message: "Min 6 characters") }
            else { self.updatePassword(newPassword: pw) }
        })
        present(alert, animated: true)
    }

    @objc private func dailyGoalBadgeTapped() {
        showDailyGoalPicker()
    }

    private func showDailyGoalPicker() {
        let alert = UIAlertController(title: "Select Daily Goal", message: "Choose your practice target in minutes.", preferredStyle: .actionSheet)
        let goals = [10, 15, 20, 30, 45, 60]
        for mins in goals {
            alert.addAction(UIAlertAction(title: "\(mins) minutes", style: .default) { _ in
                self.updateDailyGoal(minutes: mins)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = goalBadgeBg
            pop.sourceRect = goalBadgeBg.bounds
        }
        present(alert, animated: true)
    }

    private func updateDailyGoal(minutes: Int) {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            do {
                _ = try await SupabaseManager.shared.client
                    .from("user_onboarding")
                    .update(["practice_mins": minutes])
                    .eq("id", value: user.id.uuidString).execute()
                
                await MainActor.run {
                    self.goalBadgeLabel.text = "Goal: \(minutes)m"
                    DailyGoalManager.shared.dailyGoalMinutes = minutes
                    self.showAlert(title: "Success", message: "Daily goal updated!")
                }
            } catch {
                await MainActor.run { showAlert(title: "Error", message: error.localizedDescription) }
            }
        }
    }

    func updateProfile(fullName: String, username: String) {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            var updates: [String: String] = [:]
            if !fullName.isEmpty { updates["full_name"] = fullName }
            if !username.isEmpty { updates["username"] = username }
            do {
                _ = try await SupabaseManager.shared.client
                    .from("profiles").update(updates)
                    .eq("id", value: user.id.uuidString).execute()
                await MainActor.run {
                    nameLabel.text = fullName.isEmpty ? "No Name" : fullName
                    usernameLabel.text = username.isEmpty ? "@username" : "@\(username)"
                    NotificationCenter.default.post(name: TopNavBar.profileDidUpdateNotification, object: nil)
                }
            } catch {
                await MainActor.run { showAlert(title: "Error", message: error.localizedDescription) }
            }
        }
    }

    func updatePassword(newPassword: String) {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.update(user: .init(password: newPassword))
                await MainActor.run { showAlert(title: "Success", message: "Password updated!") }
            } catch {
                await MainActor.run { showAlert(title: "Error", message: error.localizedDescription) }
            }
        }
    }
}

// MARK: - Avatar
extension UserProfileViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @objc func changeAvatarTapped() {
        let alert = UIAlertController(title: "Change Photo", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { _ in self.openPhotoLibrary() })
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Camera", style: .default) { _ in self.openCamera() })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = profileImageView
            pop.sourceRect = profileImageView.bounds
        }
        present(alert, animated: true)
    }

    private func openPhotoLibrary() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }

    private func openCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage else { return }
        profileImageView.image = image
        profileImageView.contentMode = .scaleAspectFill
        uploadAvatarImage(image)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func uploadAvatarImage(_ image: UIImage) {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser,
                  let jpegData = image.jpegData(compressionQuality: 0.85) else { return }
            let client = SupabaseManager.shared.client
            let fileName = "avatar_\(user.id.uuidString)_\(Int(Date().timeIntervalSince1970)).jpg"
            do {
                try await client.storage.from("useprofile").upload(fileName, data: jpegData)
                let projectRef = "djqgmowfjxsnjdffdohw"
                let publicURL = "https://\(projectRef).supabase.co/storage/v1/object/public/useprofile/\(fileName)"
                _ = try await client.from("profiles")
                    .update(["avatar_url": publicURL])
                    .eq("id", value: user.id.uuidString).execute()
                self.currentProfile = Profile(
                    id: self.currentProfile?.id ?? user.id,
                    full_name: self.currentProfile?.full_name,
                    username: self.currentProfile?.username,
                    avatar_url: publicURL,
                    bio: self.currentProfile?.bio,
                    total_study_seconds: self.currentProfile?.total_study_seconds
                )
                await MainActor.run {
                    NotificationCenter.default.post(name: TopNavBar.profileDidUpdateNotification, object: nil)
                    showAlert(title: "Success", message: "Photo updated!")
                }
            } catch {
                await MainActor.run { showAlert(title: "Upload Error", message: error.localizedDescription) }
            }
        }
    }

    func updateAvatar(with urlString: String?) {
        profileImageView.image = UIImage(systemName: "person.fill")
        profileImageView.tintColor = .white
        profileImageView.contentMode = .center
        guard let urlString = urlString, !urlString.isEmpty else { return }

        if urlString.lowercased().hasPrefix("icon_"), let img = UIImage(named: urlString) {
            profileImageView.image = img
            profileImageView.contentMode = .scaleAspectFill
            return
        }

        Task {
            var finalURL = urlString
            if finalURL.contains("/object/useprofile/") && !finalURL.contains("/public/") {
                finalURL = finalURL.replacingOccurrences(of: "/object/useprofile/", with: "/object/public/useprofile/")
            }
            guard let url = URL(string: finalURL) else { return }
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = UIImage(data: data) {
                await MainActor.run {
                    profileImageView.image = img
                    profileImageView.contentMode = .scaleAspectFill
                }
            }
        }
    }
}

// MARK: - Helpers
private extension UserProfileViewController {
    func showAlert(title: String, message: String) {
        guard !(presentedViewController is UIAlertController) else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Practice Chart View (Area Chart)
final class PracticeChartView: UIView {

    var weeklyData: [CGFloat] = [0, 0, 0, 0, 0, 0, 0] {
        didSet { setNeedsDisplay() }
    }

    private let days = ["M", "T", "W", "T", "F", "S", "S"]
    private let accentColor = ComponentColors.ProfileScreen.editProfileText // #EF9408

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let labelHeight: CGFloat = 20
        let chartRect = CGRect(x: 16, y: 8,
                               width: rect.width - 32,
                               height: rect.height - labelHeight - 16)

        let maxVal = max(weeklyData.max() ?? 1, 1)
        let count = weeklyData.count
        let step = chartRect.width / CGFloat(count - 1)

        // Build points
        var points: [CGPoint] = []
        for (i, val) in weeklyData.enumerated() {
            let x = chartRect.minX + CGFloat(i) * step
            let y = chartRect.maxY - (val / maxVal) * chartRect.height
            points.append(CGPoint(x: x, y: y))
        }

        // Area path
        let areaPath = UIBezierPath()
        areaPath.move(to: CGPoint(x: points[0].x, y: chartRect.maxY))
        areaPath.addLine(to: points[0])

        // Smooth curve with control points
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let cpX = (prev.x + curr.x) / 2
            areaPath.addCurve(to: curr,
                              controlPoint1: CGPoint(x: cpX, y: prev.y),
                              controlPoint2: CGPoint(x: cpX, y: curr.y))
        }

        areaPath.addLine(to: CGPoint(x: points.last!.x, y: chartRect.maxY))
        areaPath.close()

        // Gradient fill
        ctx.saveGState()
        areaPath.addClip()
        let gradColors = [accentColor.withAlphaComponent(0.35).cgColor,
                          accentColor.withAlphaComponent(0.0).cgColor]
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: gradColors as CFArray,
                              locations: [0.0, 1.0])!
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: 0, y: chartRect.minY),
                               end: CGPoint(x: 0, y: chartRect.maxY),
                               options: [])
        ctx.restoreGState()

        // Line
        let linePath = UIBezierPath()
        linePath.move(to: points[0])
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let cpX = (prev.x + curr.x) / 2
            linePath.addCurve(to: curr,
                              controlPoint1: CGPoint(x: cpX, y: prev.y),
                              controlPoint2: CGPoint(x: cpX, y: curr.y))
        }
        accentColor.setStroke()
        linePath.lineWidth = 2
        linePath.stroke()

        // Dots at data points (only non-zero)
        for (i, pt) in points.enumerated() {
            guard weeklyData[i] > 0 else { continue }
            let dotRect = CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8)
            let dotPath = UIBezierPath(ovalIn: dotRect)
            UIColor.white.setFill()
            dotPath.fill()
            accentColor.setStroke()
            dotPath.lineWidth = 2
            dotPath.stroke()
        }

        // Day labels
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: ComponentColors.ProfileScreen.graphAxisLabel
        ]
        for (i, day) in days.enumerated() {
            let x = chartRect.minX + CGFloat(i) * step
            let str = NSAttributedString(string: day, attributes: labelAttrs)
            let strSize = str.size()
            str.draw(at: CGPoint(x: x - strSize.width / 2,
                                 y: chartRect.maxY + 6))
        }
    }
}



extension UIView {
    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }
}

// MARK: - Gradient Header (kept for other usage)
final class GradientHeaderView: UIView {
    private let gradient = CAGradientLayer()
    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }
    private func setup() {
        gradient.colors = [
            ComponentColors.ProfileScreen.graphLine.withAlphaComponent(0.6).cgColor,
            ComponentColors.ProfileScreen.graphAreaFill.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradient, at: 0)
    }
    override func layoutSubviews() { super.layoutSubviews(); gradient.frame = bounds }
}
