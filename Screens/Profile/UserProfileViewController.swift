//  ProfileScreen.swift
//  Re-Hearse_v1
//

import UIKit
import AVFoundation
import Photos
import Supabase
import Auth
import SwiftUI
internal import PostgREST


struct OnboardingData: Codable {
    let practice_mins: Int
}

// MARK: - Stats model fetched from lesson_events
struct ProfileStats {
    var totalLessons: Int = 0
    var weeklyData: [CGFloat] = [0, 0, 0, 0, 0, 0, 0] // Mon–Sun in hours
}

final class UserProfileViewController: UIViewController {
    private static let practiceEventDateParsers: [ISO8601DateFormatter] = {
        let fractionalSecondsParser = ISO8601DateFormatter()
        fractionalSecondsParser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let standardParser = ISO8601DateFormatter()
        standardParser.formatOptions = [.withInternetDateTime]

        return [fractionalSecondsParser, standardParser]
    }()

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    // pointed at by the first-run tour
    private let leftColumn = UILayoutGuide()
    private let rightColumn = UILayoutGuide()
    private weak var lessonsRow: UIView?
    private weak var tipsRow: UIView?

    // Header
    private let profileImageView = UIImageView()
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()

    // Stat cards
    private let practiceLabel = UILabel()
    private let lessonsLabel = UILabel()
    private let streakLabel = UILabel()

    // Practice Progress
    private let weeklyHoursLabel = UILabel()
    private let goalBadgeBg = UIView()
    private let goalBadgeLabel = UILabel()
    private let appearanceValueLabel = UILabel()

    // Sign out
    private let signOutButton = UIButton(type: .system)

    // Data
    private var currentProfile: UserProfile?
    private var stats = ProfileStats()
    private weak var activeImagePicker: UIImagePickerController?
    private var pendingDeleteAccountBearerToken: String?

    // MARK: - Skeleton
    private let profileSkeleton = ProfileSkeletonView()

    // The Settings tab's header, the same as Home's and Library's, with the ••• menu beside it.
    private let menuButton = TabRootHeaderView.glassButton(systemName: "ellipsis", accessibilityLabel: "Account")
    private lazy var tabHeader = TabRootHeaderView(title: "Settings", subtitle: "Profile, practice and preferences",
                                                   accessory: menuButton)
    private let navBackgroundView = UIVisualEffectView(effect: nil)
    private let navShadowLayer = UIView()

    // MARK: - Init
    // Settings is a tab root, so it keeps the tab bar; AppNavigationController hides the bar
    // when this screen is pushed from somewhere else.
    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func practiceEventDate(from rawValue: String) -> Date? {
        for parser in Self.practiceEventDateParsers {
            if let date = parser.date(from: rawValue) {
                return date
            }
        }

        return nil
    }

    private func practiceHoursText(from seconds: Int) -> String {
        let hours = Double(seconds) / 3600.0
        return hours < 10 ? String(format: "%.1fh", hours) : "\(Int(hours))h"
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.ProfileScreen.background
        
        navigationController?.setNavigationBarHidden(false, animated: false)
        if isTabRoot {
            // The Settings tab: the shared header scrolls away and the small title fades in.
            _ = NavigationBarHelper.configureInlineNavigationBar(
                for: self, title: "Settings", subtitle: "Profile, practice and preferences"
            )
            navigationItem.titleView?.alpha = 0
            menuButton.showsMenuAsPrimaryAction = true
            menuButton.menu = buildProfileMenu()
        } else {
            title = ""
            navigationController?.navigationBar.prefersLargeTitles = false
            navigationItem.largeTitleDisplayMode = .never

            let navBar = navigationController?.navigationBar
            navBar?.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: DeviceLayout.s(17), weight: .bold)
            ]
            navBar?.tintColor = .white
        }
        if !isTabRoot {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "ellipsis"),
                menu: buildProfileMenu()
            )
        }
        
        setupUI()
        if isTabRoot {
            NavigationBarHelper.updateNavigationBackgroundAppearance(
                navBackgroundView, shadowView: navShadowLayer, traitCollection: traitCollection
            )
            NavigationBarHelper.installNavigationBackground(navBackgroundView, shadowView: navShadowLayer, in: view)
        }
        // Show skeleton while data loads
        profileSkeleton.show(in: view)
        loadData()
    }


    /// Settings is a tab now; other screens may still push it.
    private var isTabRoot: Bool {
        navigationController?.viewControllers.first?.screen === self   // (iPad: inside its container)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppTour.showIfNeeded(.settings, in: self) { [weak self] in
            guard self != nil else { return [] }
            return [
                TourStep(target: { [weak self] in self?.lessonsRow },
                         title: "Practice lessons",
                         message: "Step-by-step lessons, from reading notes to playing chords."),
                TourStep(target: { [weak self] in self?.tipsRow },
                         title: "See the tips again",
                         message: "Skipped something? This brings every tip back."),
            ]
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationItem.rightBarButtonItem?.menu = buildProfileMenu()
        menuButton.menu = buildProfileMenu()
        syncNavBarAlpha()
        updateAppearanceValueLabel()
        updateSignInOutButton()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        guard isTabRoot else { return }
        // The page runs under the bars; leave room to scroll past the tab bar and mini player.
        scrollView.contentInset.bottom = view.safeAreaInsets.bottom
        scrollView.verticalScrollIndicatorInsets.bottom = view.safeAreaInsets.bottom
    }

    private func syncNavBarAlpha() {
        guard isTabRoot else { return }
        NavigationBarHelper.syncNavigationBarAlpha(
            scrollView: scrollView, navigationItem: navigationItem, navBackgroundView: navBackgroundView
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Post notification so Home nav bar can refresh profile image when user navigates back
        if isLeavingNavigationStack {
            activeImagePicker?.delegate = nil
            activeImagePicker = nil
            NotificationCenter.default.post(name: NavigationBarHelper.profileDidUpdateNotification, object: nil)
        }
    }

    // MARK: - Setup UI
    private func setupUI() {
        // Scroll
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        if isTabRoot { scrollView.contentInsetAdjustmentBehavior = .never }
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        if isTabRoot {
            contentView.addSubview(tabHeader)
            NSLayoutConstraint.activate([
                tabHeader.topAnchor.constraint(equalTo: contentView.topAnchor, constant: TabRootHeaderView.topOffset),
                tabHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                tabHeader.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            ])
        }
        // iPad: two columns, profile and progress on the left, settings on the right (on the
        // phone both columns are the whole width, one after the other)
        contentView.addLayoutGuide(leftColumn)
        contentView.addLayoutGuide(rightColumn)
        NSLayoutConstraint.activate(DeviceLayout.isPad ? [
            leftColumn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rightColumn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rightColumn.leadingAnchor.constraint(equalTo: leftColumn.trailingAnchor),
            leftColumn.widthAnchor.constraint(equalTo: rightColumn.widthAnchor),
        ] : [
            leftColumn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            leftColumn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rightColumn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rightColumn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
        buildHeaderSection()
        buildStatsSection()
        buildPracticeProgressSection()
        buildPracticeLinksSection()
        buildAppearanceSection()
        buildLegalSection()
        buildSignOutSection()
    }

    // MARK: - HEADER (avatar + name + username)
    private func buildHeaderSection() {
        // Avatar ring
        let ringSize: CGFloat = DeviceLayout.s(110)
        let ringView = UIView()
        ringView.translatesAutoresizingMaskIntoConstraints = false
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
        nameLabel.font = .systemFont(ofSize: DeviceLayout.s(24), weight: .bold)
        nameLabel.textColor = ComponentColors.ProfileScreen.userName
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        usernameLabel.text = "@username"
        usernameLabel.font = .systemFont(ofSize: DeviceLayout.s(15), weight: .regular)
        usernameLabel.textColor = ComponentColors.ProfileScreen.userHandle
        usernameLabel.textAlignment = .center
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(usernameLabel)

        NSLayoutConstraint.activate([
            isTabRoot
                ? ringView.topAnchor.constraint(equalTo: tabHeader.bottomAnchor, constant: DeviceLayout.s(12))
                : ringView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DeviceLayout.s(28)),
            ringView.centerXAnchor.constraint(equalTo: leftColumn.centerXAnchor),
            ringView.widthAnchor.constraint(equalToConstant: ringSize),
            ringView.heightAnchor.constraint(equalToConstant: ringSize),

            profileImageView.centerXAnchor.constraint(equalTo: ringView.centerXAnchor),
            profileImageView.centerYAnchor.constraint(equalTo: ringView.centerYAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: ringSize - 8),
            profileImageView.heightAnchor.constraint(equalToConstant: ringSize - 8),

            nameLabel.topAnchor.constraint(equalTo: ringView.bottomAnchor, constant: DeviceLayout.s(16)),
            nameLabel.centerXAnchor.constraint(equalTo: leftColumn.centerXAnchor),

            usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: DeviceLayout.s(4)),
            usernameLabel.centerXAnchor.constraint(equalTo: leftColumn.centerXAnchor),
        ])

        DispatchQueue.main.async {
            ringGradient.frame = ringView.bounds
        }
    }

    // MARK: - STATS (3 cards: Practice, Lessons, Streak)
    private func buildStatsSection() {
        let statsContainer = UIView()
        statsContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statsContainer)

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
        stack.spacing = DeviceLayout.s(12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        statsContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: statsContainer.topAnchor),
            stack.leadingAnchor.constraint(equalTo: statsContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: statsContainer.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: statsContainer.bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            statsContainer.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: DeviceLayout.s(28)),
            statsContainer.leadingAnchor.constraint(equalTo: leftColumn.leadingAnchor, constant: DeviceLayout.s(20)),
            statsContainer.trailingAnchor.constraint(equalTo: leftColumn.trailingAnchor, constant: DeviceLayout.s(-20)),
            statsContainer.heightAnchor.constraint(equalToConstant: DeviceLayout.s(100)),
        ])
    }

    private func makeStatCard(iconName: String, iconColor: UIColor,
                               valueLabel: UILabel, valueText: String,
                               subtitleText: String) -> UIView {
        let card = UIView()
        card.backgroundColor = ComponentColors.ProfileScreen.statCardFill // #FBF1DA 80%
        card.layer.cornerRadius = DeviceLayout.s(16)
        card.layer.borderWidth = 0.5
        card.layer.borderColor = ComponentColors.ProfileScreen.statCardBorder.cgColor // #EF9408 at 40%

        let icon = UIImageView(image: UIImage(systemName: iconName))
        icon.tintColor = iconColor
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.text = valueText
        valueLabel.font = .systemFont(ofSize: DeviceLayout.s(22), weight: .bold)
        valueLabel.textColor = ComponentColors.ProfileScreen.userName
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = subtitleText
        subtitle.font = .systemFont(ofSize: DeviceLayout.s(10), weight: .semibold)
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
            icon.topAnchor.constraint(equalTo: card.topAnchor, constant: DeviceLayout.s(14)),
            icon.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: DeviceLayout.s(22)),
            icon.heightAnchor.constraint(equalToConstant: DeviceLayout.s(22)),

            valueLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: DeviceLayout.s(6)),
            valueLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            subtitle.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: DeviceLayout.s(2)),
            subtitle.centerXAnchor.constraint(equalTo: card.centerXAnchor),
        ])

        return card
    }

    // MARK: - PRACTICE PROGRESS SECTION
    private func buildPracticeProgressSection() {
        let card = UIView()
        card.backgroundColor = ComponentColors.ProfileScreen.headerCardFill
        card.layer.cornerRadius = DeviceLayout.s(20)
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        // Title row
        let titleLabel = UILabel()
        titleLabel.text = "Practice Progress"
        titleLabel.font = .systemFont(ofSize: DeviceLayout.s(20), weight: .bold)
        titleLabel.textColor = ComponentColors.ProfileScreen.userName
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)

        // Goal badge
        goalBadgeBg.backgroundColor = ComponentColors.ProfileScreen.statCardFill
        goalBadgeBg.layer.cornerRadius = DeviceLayout.s(12)
        goalBadgeBg.isUserInteractionEnabled = true
        goalBadgeBg.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dailyGoalBadgeTapped)))
        goalBadgeBg.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(goalBadgeBg)

        goalBadgeLabel.text = "Goal: –"
        goalBadgeLabel.font = .systemFont(ofSize: DeviceLayout.s(12), weight: .semibold)
        goalBadgeLabel.textColor = ComponentColors.ProfileScreen.editProfileText
        goalBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        goalBadgeBg.addSubview(goalBadgeLabel)

        // Weekly hours
        weeklyHoursLabel.text = "– h"
        weeklyHoursLabel.font = .systemFont(ofSize: DeviceLayout.s(36), weight: .bold)
        weeklyHoursLabel.textColor = ComponentColors.ProfileScreen.userName
        weeklyHoursLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(weeklyHoursLabel)

        let thisWeekLabel = UILabel()
        thisWeekLabel.text = "This Week"
        thisWeekLabel.font = .systemFont(ofSize: DeviceLayout.s(14), weight: .regular)
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
            card.topAnchor.constraint(equalTo: statsContainer.bottomAnchor, constant: DeviceLayout.s(20)),
            card.leadingAnchor.constraint(equalTo: leftColumn.leadingAnchor, constant: DeviceLayout.s(20)),
            card.trailingAnchor.constraint(equalTo: leftColumn.trailingAnchor, constant: DeviceLayout.s(-20)),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: DeviceLayout.s(20)),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DeviceLayout.s(20)),

            goalBadgeBg.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            goalBadgeBg.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: DeviceLayout.s(-16)),
            goalBadgeBg.heightAnchor.constraint(equalToConstant: DeviceLayout.s(28)),

            goalBadgeLabel.topAnchor.constraint(equalTo: goalBadgeBg.topAnchor, constant: DeviceLayout.s(6)),
            goalBadgeLabel.bottomAnchor.constraint(equalTo: goalBadgeBg.bottomAnchor, constant: DeviceLayout.s(-6)),
            goalBadgeLabel.leadingAnchor.constraint(equalTo: goalBadgeBg.leadingAnchor, constant: DeviceLayout.s(10)),
            goalBadgeLabel.trailingAnchor.constraint(equalTo: goalBadgeBg.trailingAnchor, constant: DeviceLayout.s(-10)),

            weeklyHoursLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DeviceLayout.s(16)),
            weeklyHoursLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DeviceLayout.s(20)),

            thisWeekLabel.leadingAnchor.constraint(equalTo: weeklyHoursLabel.trailingAnchor, constant: DeviceLayout.s(8)),
            thisWeekLabel.lastBaselineAnchor.constraint(equalTo: weeklyHoursLabel.lastBaselineAnchor),

            chartContainer.topAnchor.constraint(equalTo: weeklyHoursLabel.bottomAnchor, constant: DeviceLayout.s(8)),
            chartContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DeviceLayout.s(8)),
            chartContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: DeviceLayout.s(-8)),
            chartContainer.heightAnchor.constraint(equalToConstant: DeviceLayout.s(130)),
            chartContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: DeviceLayout.s(-16)),
        ])
        if DeviceLayout.isPad {
            // the left column can be the longer one
            card.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: DeviceLayout.s(-72)).isActive = true
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: DeviceLayout.s(-72))
                .withPriority(.defaultLow).isActive = true
        }
    }

    private func buildAreaChartView() -> UIView {
        // We'll draw this as a custom CAShapeLayer view
        let chartView = PracticeChartView()
        chartView.weeklyData = stats.weeklyData
        chartView.tag = 9901 // so we can find and update it
        return chartView
    }

    // MARK: - PRACTICE (lessons used to be a tab)
    private func buildPracticeLinksSection() {
        let card = UIView()
        card.backgroundColor = ComponentColors.ProfileScreen.headerCardFill
        card.layer.cornerRadius = DeviceLayout.s(20)
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        let sectionTitle = UILabel()
        sectionTitle.text = "Practice"
        sectionTitle.font = .systemFont(ofSize: DeviceLayout.s(20), weight: .bold)
        sectionTitle.textColor = ComponentColors.ProfileScreen.userName
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(sectionTitle)

        let lessons = makeLinkRow(title: "Practice Lessons", symbolName: "map") { [weak self] in
            self?.perform(.practice)
        }
        let notifications = makeLinkRow(title: "Notifications", symbolName: "bell") { [weak self] in
            self?.navigationController?.pushViewController(NotificationsViewController(), animated: true)
        }
        let tips = makeLinkRow(title: "Show Tips Again", symbolName: "lightbulb") { [weak self] in
            AppTour.resetAll()
            let alert = UIAlertController(title: "Tips are back",
                                          message: "You'll see the tips again as you open each screen.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
        lessonsRow = lessons
        tipsRow = tips
        func makeDivider() -> UIView {
            let divider = UIView()
            divider.backgroundColor = ComponentColors.ProfileScreen.statCardBorder
            divider.translatesAutoresizingMaskIntoConstraints = false
            divider.heightAnchor.constraint(equalToConstant: DeviceLayout.s(0.5)).isActive = true
            return divider
        }

        let stack = UIStackView(arrangedSubviews: [lessons, makeDivider(), notifications, makeDivider(), tips])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let previousView = contentView.subviews.last(where: { $0 != card })!

        NSLayoutConstraint.activate([
            // iPad: the right column starts level with the profile, under the page header
            DeviceLayout.isPad
                ? card.topAnchor.constraint(equalTo: isTabRoot ? tabHeader.bottomAnchor : contentView.topAnchor,
                                            constant: DeviceLayout.s(12))
                : card.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: DeviceLayout.s(20)),
            card.leadingAnchor.constraint(equalTo: rightColumn.leadingAnchor, constant: DeviceLayout.s(20)),
            card.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor, constant: DeviceLayout.s(-20)),

            sectionTitle.topAnchor.constraint(equalTo: card.topAnchor, constant: DeviceLayout.s(20)),
            sectionTitle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DeviceLayout.s(20)),

            stack.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: DeviceLayout.s(10)),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: DeviceLayout.s(-8)),

            // a set height (taller text may still grow them); "at least" alone left the rows free
            // to stretch
            lessons.heightAnchor.constraint(greaterThanOrEqualToConstant: DeviceLayout.s(50)),
            notifications.heightAnchor.constraint(greaterThanOrEqualToConstant: DeviceLayout.s(50)),
            tips.heightAnchor.constraint(greaterThanOrEqualToConstant: DeviceLayout.s(50)),
            lessons.heightAnchor.constraint(equalToConstant: DeviceLayout.s(50)).withPriority(.defaultHigh),
            notifications.heightAnchor.constraint(equalToConstant: DeviceLayout.s(50)).withPriority(.defaultHigh),
            tips.heightAnchor.constraint(equalToConstant: DeviceLayout.s(50)).withPriority(.defaultHigh),
        ])
    }

    private func makeLinkRow(title: String, symbolName: String, action: @escaping () -> Void) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = UIImage(systemName: symbolName)
        config.imagePadding = 12
        config.baseForegroundColor = ComponentColors.ProfileScreen.userName
        config.imageColorTransformer = UIConfigurationColorTransformer { _ in BrandColors.brand }
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: DeviceLayout.s(17))
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 44)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = DeviceLayout.isPad ? .systemFont(ofSize: DeviceLayout.s(16), weight: .medium) : UIFont.preferredFont(forTextStyle: .body)
            return attrs
        }
        let button = UIButton(configuration: config, primaryAction: UIAction { _ in action() })
        button.tintColor = BrandColors.brand
        button.contentHorizontalAlignment = .leading
        button.translatesAutoresizingMaskIntoConstraints = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = ComponentColors.ProfileScreen.statLabel
        chevron.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(chevron)
        NSLayoutConstraint.activate([
            chevron.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: DeviceLayout.s(-20))
        ])
        return button
    }

    // MARK: - Shortcuts (from Search)

    enum SettingsShortcut {
        case appearance, dailyGoal, editProfile, terms, privacy, practice
    }

    func perform(_ shortcut: SettingsShortcut) {
        loadViewIfNeeded()
        switch shortcut {
        case .practice:
            navigationController?.pushViewController(LessonMapViewController(), animated: true)
        case .appearance:
            openAppearancePicker()
        case .dailyGoal:
            showDailyGoalPicker()
        case .editProfile:
            let sheet = UIAlertController(title: "Edit Profile", message: nil, preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: "Edit Name", style: .default) { [weak self] _ in self?.showNameEditor() })
            sheet.addAction(UIAlertAction(title: "Edit Username", style: .default) { [weak self] _ in self?.showUsernameEditor() })
            sheet.addAction(UIAlertAction(title: "Change Photo", style: .default) { [weak self] _ in self?.changeAvatarTapped() })
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            sheet.popoverPresentationController?.sourceView = profileImageView
            present(sheet, animated: true)
        case .terms:
            openTermsOfService()
        case .privacy:
            openPrivacyPolicy()
        }
    }

    private func buildAppearanceSection() {
        let card = UIView()
        card.backgroundColor = ComponentColors.ProfileScreen.headerCardFill
        card.layer.cornerRadius = DeviceLayout.s(20)
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        let sectionTitle = UILabel()
        sectionTitle.text = "Appearance"
        sectionTitle.font = .systemFont(ofSize: DeviceLayout.s(20), weight: .bold)
        sectionTitle.textColor = ComponentColors.ProfileScreen.userName
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(sectionTitle)

        let rowButton = UIControl()
        rowButton.translatesAutoresizingMaskIntoConstraints = false
        rowButton.addTarget(self, action: #selector(openAppearancePicker), for: .touchUpInside)
        card.addSubview(rowButton)

        let rowTitleLabel = UILabel()
        rowTitleLabel.text = "Theme"
        rowTitleLabel.font = .systemFont(ofSize: DeviceLayout.s(16), weight: .regular)
        rowTitleLabel.textColor = ComponentColors.ProfileScreen.userName
        rowTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        rowButton.addSubview(rowTitleLabel)

        appearanceValueLabel.font = .systemFont(ofSize: DeviceLayout.s(16), weight: .regular)
        appearanceValueLabel.textColor = ComponentColors.ProfileScreen.statLabel
        appearanceValueLabel.textAlignment = .right
        appearanceValueLabel.translatesAutoresizingMaskIntoConstraints = false
        rowButton.addSubview(appearanceValueLabel)
        updateAppearanceValueLabel()

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = ComponentColors.ProfileScreen.statLabel
        chevron.translatesAutoresizingMaskIntoConstraints = false
        rowButton.addSubview(chevron)

        let previousView = contentView.subviews.last(where: { $0 != card })!

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: DeviceLayout.s(20)),
            card.leadingAnchor.constraint(equalTo: rightColumn.leadingAnchor, constant: DeviceLayout.s(20)),
            card.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor, constant: DeviceLayout.s(-20)),

            sectionTitle.topAnchor.constraint(equalTo: card.topAnchor, constant: DeviceLayout.s(20)),
            sectionTitle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DeviceLayout.s(20)),

            rowButton.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: DeviceLayout.s(10)),
            rowButton.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            rowButton.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            rowButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: DeviceLayout.s(-8)),
            rowButton.heightAnchor.constraint(equalToConstant: DeviceLayout.s(50)),

            rowTitleLabel.leadingAnchor.constraint(equalTo: rowButton.leadingAnchor, constant: DeviceLayout.s(20)),
            rowTitleLabel.centerYAnchor.constraint(equalTo: rowButton.centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: rowButton.trailingAnchor, constant: DeviceLayout.s(-20)),
            chevron.centerYAnchor.constraint(equalTo: rowButton.centerYAnchor),

            appearanceValueLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: DeviceLayout.s(-8)),
            appearanceValueLabel.centerYAnchor.constraint(equalTo: rowButton.centerYAnchor),
            appearanceValueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: rowTitleLabel.trailingAnchor, constant: DeviceLayout.s(12))
        ])
    }

    // MARK: - SIGN OUT SECTION
    private func buildSignOutSection() {
        signOutButton.titleLabel?.font = .systemFont(ofSize: DeviceLayout.s(17), weight: .bold)
        signOutButton.layer.cornerRadius = DeviceLayout.s(28)
        signOutButton.translatesAutoresizingMaskIntoConstraints = false
        updateSignInOutButton()

        guard GuestSessionManager.shared.isGuest() else { return }

        contentView.addSubview(signOutButton)

        // Anchor below practice progress card
        let practiceCard = contentView.subviews.last(where: { $0 != signOutButton })!

        NSLayoutConstraint.activate([
            signOutButton.topAnchor.constraint(equalTo: practiceCard.bottomAnchor, constant: DeviceLayout.s(28)),
            // iPad: a button of its own size, centred, rather than one across the page
            signOutButton.centerXAnchor.constraint(equalTo: rightColumn.centerXAnchor),
            signOutButton.widthAnchor.constraint(equalTo: rightColumn.widthAnchor, constant: DeviceLayout.s(-48)).withPriority(.defaultHigh),
            signOutButton.widthAnchor.constraint(lessThanOrEqualToConstant: DeviceLayout.isPad ? 340 : .greatestFiniteMagnitude),
            signOutButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: DeviceLayout.s(-48)),
            signOutButton.heightAnchor.constraint(equalToConstant: DeviceLayout.s(56)),
        ])
    }

    private func buildLegalSection() {
        let card = UIView()
        card.backgroundColor = ComponentColors.ProfileScreen.headerCardFill
        card.layer.cornerRadius = DeviceLayout.s(20)
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        let sectionTitle = UILabel()
        sectionTitle.text = "Legal"
        sectionTitle.font = .systemFont(ofSize: DeviceLayout.s(20), weight: .bold)
        sectionTitle.textColor = ComponentColors.ProfileScreen.userName
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(sectionTitle)

        let termsButton = makeLegalRowButton(title: "Terms of Service", action: #selector(openTermsOfService))
        let privacyButton = makeLegalRowButton(title: "Privacy Policy", action: #selector(openPrivacyPolicy))

        let divider = UIView()
        divider.backgroundColor = ComponentColors.ProfileScreen.statCardBorder
        divider.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [termsButton, divider, privacyButton])
        stack.axis = .vertical
        stack.spacing = DeviceLayout.s(0)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let previousView = contentView.subviews.last(where: { $0 != card })!

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: DeviceLayout.s(20)),
            card.leadingAnchor.constraint(equalTo: rightColumn.leadingAnchor, constant: DeviceLayout.s(20)),
            card.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor, constant: DeviceLayout.s(-20)),

            sectionTitle.topAnchor.constraint(equalTo: card.topAnchor, constant: DeviceLayout.s(20)),
            sectionTitle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DeviceLayout.s(20)),

            stack.topAnchor.constraint(equalTo: sectionTitle.bottomAnchor, constant: DeviceLayout.s(10)),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: DeviceLayout.s(-8)),

            termsButton.heightAnchor.constraint(equalToConstant: DeviceLayout.s(50)),
            privacyButton.heightAnchor.constraint(equalToConstant: DeviceLayout.s(50)),
            divider.heightAnchor.constraint(equalToConstant: DeviceLayout.s(0.5))
        ])

        if !GuestSessionManager.shared.isGuest() {
            if DeviceLayout.isPad {
                // the page is as tall as the taller column; this one doesn't stretch to fill
                card.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: DeviceLayout.s(-72)).isActive = true
                card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: DeviceLayout.s(-72))
                    .withPriority(.defaultLow).isActive = true
            } else {
                card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: DeviceLayout.s(-72)).isActive = true
            }
        }
    }

    private func makeLegalRowButton(title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = ComponentColors.ProfileScreen.userName
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = .systemFont(ofSize: DeviceLayout.s(16), weight: .medium)
            return attrs
        }
        let button = UIButton(configuration: config)
        button.contentHorizontalAlignment = .leading
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = ComponentColors.ProfileScreen.statLabel
        chevron.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(chevron)

        NSLayoutConstraint.activate([
            chevron.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: DeviceLayout.s(-20))
        ])

        return button
    }

    private func buildProfileMenu() -> UIMenu {
        let editName = UIAction(title: "Edit Name", image: UIImage(systemName: "person")) { [weak self] _ in
            self?.showNameEditor()
        }
        let editUsername = UIAction(title: "Edit Username", image: UIImage(systemName: "at")) { [weak self] _ in
            self?.showUsernameEditor()
        }
        let editPassword = UIAction(title: "Edit Password", image: UIImage(systemName: "key")) { [weak self] _ in
            self?.showPasswordEditor()
        }
        let changePhoto = UIAction(title: "Change Photo", image: UIImage(systemName: "camera")) { [weak self] _ in
            self?.changeAvatarTapped()
        }

        let editSection = UIMenu(
            title: "Edit Profile",
            options: .displayInline,
            children: [editName, editUsername, editPassword, changePhoto]
        )

        if GuestSessionManager.shared.isGuest() {
            let signInAction = UIAction(title: "Sign In", image: UIImage(systemName: "person.crop.circle.badge.plus")) { [weak self] _ in
                self?.presentAuthentication(mode: .logIn)
            }
            return UIMenu(title: "", children: [
                editSection,
                UIMenu(title: "Account", options: .displayInline, children: [signInAction])
            ])
        }

        let signOutAction = UIAction(title: "Sign Out", image: UIImage(systemName: "rectangle.portrait.and.arrow.right"), attributes: .destructive) { [weak self] _ in
            self?.signOutTapped()
        }
        let deleteAccountAction = UIAction(title: "Delete Account", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
            self?.deleteAccountTapped()
        }

        return UIMenu(title: "", children: [
            editSection,
            UIMenu(title: "Account", options: .displayInline, children: [signOutAction, deleteAccountAction])
        ])
    }

    private func updateSignInOutButton() {
        signOutButton.removeTarget(nil, action: nil, for: .touchUpInside)

        if GuestSessionManager.shared.isGuest() {
            signOutButton.setTitle("Sign In", for: .normal)
            signOutButton.setTitleColor(ComponentColors.AuthScreen.ctaText, for: .normal)
            signOutButton.backgroundColor = ComponentColors.AuthScreen.ctaFill
            signOutButton.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)
        } else {
            signOutButton.setTitle(nil, for: .normal)
            signOutButton.backgroundColor = .clear
        }
    }

    // MARK: - Saved snapshot
    //
    // What Settings showed last time for the signed-in account, so it opens instantly (no
    // skeleton, and offline too); the fetch below updates it.

    private struct Snapshot: Codable {
        var name: String?
        var username: String?
        var avatar: String?
        var goalMinutes: Int?
        var practiceText: String?
        var lessons: Int?
        var streak: Int?
        var weeklyText: String?
        var weeklyHours: [Double]?
    }

    private static let snapshotKey = "settings.snapshot"

    private func updateSnapshot(_ change: (inout Snapshot) -> Void) {
        guard !GuestSessionManager.shared.isGuest() else { return }
        var snapshot = AppDataCache.shared.value(Snapshot.self, for: Self.snapshotKey) ?? Snapshot()
        change(&snapshot)
        AppDataCache.shared.store(snapshot, for: Self.snapshotKey)
    }

    /// Shows the saved snapshot; false when there is none.
    @discardableResult
    private func showSavedSnapshot() -> Bool {
        guard !GuestSessionManager.shared.isGuest(),
              let s = AppDataCache.shared.value(Snapshot.self, for: Self.snapshotKey) else { return false }
        if let name = s.name { nameLabel.text = name }
        if let username = s.username { usernameLabel.text = username.isEmpty ? "" : "@\(username)" }
        if let avatar = s.avatar { updateAvatar(with: avatar) }
        if let goal = s.goalMinutes { goalBadgeLabel.text = goalBadgeText(for: goal) }
        if let text = s.practiceText { practiceLabel.text = text }
        if let lessons = s.lessons { lessonsLabel.text = "\(lessons)" }
        if let streak = s.streak { streakLabel.text = "\(streak)" }
        if let text = s.weeklyText { weeklyHoursLabel.text = text }
        if let hours = s.weeklyHours, let chart = contentView.viewWithTag(9901) as? PracticeChartView {
            chart.weeklyData = hours.map { CGFloat($0) }
            chart.setNeedsDisplay()
        }
        return true
    }

    // MARK: - Load Data
    private func loadData() {
        if showSavedSnapshot() { profileSkeleton.hide() }
        Task {
            await DailyGoalManager.shared.refreshFromSupabase()
            await loadProfile()
            await loadStats()
            // Hide skeleton once both profile + stats have resolved
            await MainActor.run { profileSkeleton.hide() }
        }
    }

    private func loadProfile() async {
        if GuestSessionManager.shared.isGuest() {
            await MainActor.run {
                self.nameLabel.text = GuestSessionManager.shared.guestDisplayName() ?? "Guest"
                if let guestUsername = GuestSessionManager.shared.guestUsername(), !guestUsername.isEmpty {
                    self.usernameLabel.text = "@\(guestUsername)"
                } else {
                    self.usernameLabel.text = "@guest"
                }
                self.updateAvatar(with: GuestSessionManager.shared.guestAvatarIdentifier())
                if let goalMins = GuestSessionManager.shared.guestPracticeGoalMinutes() {
                    self.goalBadgeLabel.text = self.goalBadgeText(for: goalMins)
                    DailyGoalManager.shared.dailyGoalMinutes = goalMins
                }
                self.navigationItem.rightBarButtonItem?.menu = self.buildProfileMenu()
                self.updateSignInOutButton()
            }
            return
        }

        guard let user = SupabaseManager.shared.client.auth.currentUser else {
            await MainActor.run { nameLabel.text = "Not logged in" }
            return
        }

        do {
            let profile: UserProfile = try await SupabaseManager.shared.client
                .from("profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .single()
                .execute()
                .value

            self.currentProfile = profile

            await MainActor.run {
                let name = profile.full_name?.isEmpty == false ? profile.full_name ?? "" : "No Name"
                nameLabel.text = name
                let username = profile.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                usernameLabel.text = username.isEmpty ? "" : "@\(username)"
                updateAvatar(with: profile.avatar_url)
                updateSnapshot { $0.name = name; $0.username = username; $0.avatar = profile.avatar_url }
            }
            
            // Fetch daily goal from user_onboarding (an account that skipped onboarding has no row)
            do {
                let rows: [OnboardingData] = try await SupabaseManager.shared.client
                    .from("user_onboarding")
                    .select("practice_mins")
                    .eq("id", value: user.id.uuidString)
                    .limit(1)
                    .execute()
                    .value
                guard let onboarding = rows.first else { return }

                await MainActor.run {
                    let goalMins = onboarding.practice_mins
                    goalBadgeLabel.text = self.goalBadgeText(for: goalMins)
                    DailyGoalManager.shared.dailyGoalMinutes = goalMins
                    updateSnapshot { $0.goalMinutes = goalMins }
                }
            } catch {
                debugLog("Error loading onboarding goal:", error)
            }
        } catch {
            debugLog("Error loading profile:", error)
            // offline or a failed refresh: the saved profile stays; "Error" only with nothing saved
            await MainActor.run {
                if AppDataCache.shared.value(Snapshot.self, for: Self.snapshotKey)?.name == nil {
                    nameLabel.text = "Error"
                }
            }
        }
    }

    private func loadStats() async {
        if GuestSessionManager.shared.isGuest() {
            DailyGoalManager.shared.checkAndResetIfNewDay()
            let guestEvents = SupabaseProgressManager.guestLessonEvents()
            let totalSecondsFromEvents = guestEvents.compactMap(\.durationSeconds).reduce(0, +)
            let lessonEvents = guestEvents.filter { $0.eventType == "lesson_completed" }
            let totalLessons = lessonEvents.count

            var weeklySeconds = [Double](repeating: 0, count: 7)
            let calendar = Calendar.current
            let now = Date()
            let weekday = calendar.component(.weekday, from: now)
            let daysSinceMonday = (weekday + 5) % 7
            guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: calendar.startOfDay(for: now)) else { return }

            for event in guestEvents {
                guard let date = practiceEventDate(from: event.occurredAt) else { continue }
                let dayStart = calendar.startOfDay(for: date)
                let diff = calendar.dateComponents([.day], from: monday, to: dayStart).day ?? -1
                if diff >= 0 && diff < 7 {
                    weeklySeconds[diff] += Double(event.durationSeconds ?? 0)
                }
            }

            let todayIndex = daysSinceMonday
            let todayTrackedSeconds = Int(weeklySeconds[todayIndex])
            let practiceSecondsToday = DailyGoalManager.shared.practiceTimeMinutesToday * 60
            let resolvedTodaySeconds = max(practiceSecondsToday, todayTrackedSeconds)
            weeklySeconds[todayIndex] = Double(resolvedTodaySeconds)

            let weeklyHours = weeklySeconds.map { $0 / 3600.0 }
            let thisWeekHours = weeklyHours.reduce(0, +)
            let practicedDays = Set(guestEvents.compactMap { event -> Date? in
                guard let date = practiceEventDate(from: event.occurredAt) else { return nil }
                return calendar.startOfDay(for: date)
            }).union(resolvedTodaySeconds > 0 ? [calendar.startOfDay(for: now)] : [])

            var streak = 0
            var checkDate = calendar.startOfDay(for: now)
            while practicedDays.contains(checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            }

            await MainActor.run {
                let adjustedTotalSeconds = max(totalSecondsFromEvents - todayTrackedSeconds + resolvedTodaySeconds, 0)
                self.practiceLabel.text = self.practiceHoursText(from: adjustedTotalSeconds)
                self.lessonsLabel.text = "\(totalLessons)"
                self.streakLabel.text = "\(streak)"
                self.weeklyHoursLabel.text = self.practiceHoursText(from: Int(thisWeekHours * 3600))

                if let chart = self.contentView.viewWithTag(9901) as? PracticeChartView {
                    chart.weeklyData = weeklyHours.map { CGFloat($0) }
                    chart.setNeedsDisplay()
                }
            }
            return
        }

        guard let user = SupabaseManager.shared.client.auth.currentUser else { return }

        do {
            DailyGoalManager.shared.checkAndResetIfNewDay()

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
            let totalSecondsFromEvents = events.compactMap { $0.duration_seconds }.reduce(0, +)
            let totalLessons = events.filter { $0.event_type == "lesson_completed" }.count

            // Weekly data (last 7 days Mon–Sun)
            var weeklySeconds = [Double](repeating: 0, count: 7)
            let calendar = Calendar.current
            let now = Date()

            // Find the most recent Monday
            let weekday = calendar.component(.weekday, from: now) // 1=Sun, 2=Mon...
            let daysSinceMonday = (weekday + 5) % 7
            guard let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: calendar.startOfDay(for: now)) else { return }

            for event in events {
                guard let seconds = event.duration_seconds,
                      let date = practiceEventDate(from: event.occurred_at) else { continue }
                let dayStart = calendar.startOfDay(for: date)
                let diff = calendar.dateComponents([.day], from: monday, to: dayStart).day ?? -1
                if diff >= 0 && diff < 7 {
                    weeklySeconds[diff] += Double(seconds)
                }
            }

            let today = DailyGoalManager.dayString(for: now)
            let profilePracticeMinutesToday = currentProfile?.last_practice_date == today
                ? (currentProfile?.practice_mins_today ?? 0)
                : 0
            let freshPracticeMinutesToday = max(
                profilePracticeMinutesToday,
                DailyGoalManager.shared.practiceTimeMinutesToday
            )
            let practiceSecondsToday = freshPracticeMinutesToday * 60
            let todayIndex = daysSinceMonday
            let todayTrackedSeconds = Int(weeklySeconds[todayIndex])
            let storedTotalSeconds = currentProfile?.total_study_seconds ?? 0
            let pendingTodaySeconds = currentProfile?.last_practice_date == today && todayTrackedSeconds == 0
                ? max(storedTotalSeconds - totalSecondsFromEvents, 0)
                : 0
            let resolvedTodaySeconds = max(
                practiceSecondsToday,
                max(todayTrackedSeconds, pendingTodaySeconds)
            )
            weeklySeconds[todayIndex] = Double(resolvedTodaySeconds)

            let weeklyHours = weeklySeconds.map { $0 / 3600.0 }
            let thisWeekHours = weeklyHours.reduce(0, +)

            // Streak: consecutive days with practice up to today
            var streak = 0
            var checkDate = calendar.startOfDay(for: now)
            let practicedDays = Set(events.compactMap { event -> Date? in
                guard let date = practiceEventDate(from: event.occurred_at) else { return nil }
                return calendar.startOfDay(for: date)
            }).union(resolvedTodaySeconds > 0 ? [calendar.startOfDay(for: now)] : [])

            while practicedDays.contains(checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            }

            await MainActor.run {
                // Practice hours label
                let adjustedTotalSeconds = max(
                    storedTotalSeconds,
                    max(totalSecondsFromEvents - todayTrackedSeconds + resolvedTodaySeconds, 0)
                )
                practiceLabel.text = practiceHoursText(from: adjustedTotalSeconds)

                lessonsLabel.text = "\(totalLessons)"
                streakLabel.text = "\(streak)"

                weeklyHoursLabel.text = practiceHoursText(from: Int(thisWeekHours * 3600))

                // Update chart
                if let chart = contentView.viewWithTag(9901) as? PracticeChartView {
                    chart.weeklyData = weeklyHours.map { CGFloat($0) }
                    chart.setNeedsDisplay()
                }
                updateSnapshot {
                    $0.practiceText = practiceLabel.text
                    $0.lessons = totalLessons
                    $0.streak = streak
                    $0.weeklyText = weeklyHoursLabel.text
                    $0.weeklyHours = weeklyHours
                }
            }
        } catch {
            debugLog("Error loading stats:", error)
        }
    }

    // MARK: - Actions

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

    @objc private func deleteAccountTapped() {
        showDeleteAccountPasswordPrompt()
    }

    @objc private func signInTapped() {
        presentAuthentication(mode: .logIn)
    }

    private func performSignOut() {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.signOut()
                await MainActor.run {
                    GuestSessionManager.shared.clearGuestState()
                    if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
                        sceneDelegate.showLoginScreen()
                    }
                }
            } catch {
                await MainActor.run {
                    showAlert(title: "Error", message: "Failed to sign out: \(error.localizedDescription)")
                }
            }
        }
    }

    private func showDeleteAccountPasswordPrompt() {
        guard let email = SupabaseManager.shared.client.auth.currentUser?.email, !email.isEmpty else {
            showAlert(title: "Error", message: "We could not load your account email for re-authentication.")
            return
        }

        let alert = UIAlertController(
            title: "Re-authenticate",
            message: "Enter the password for \(email) to continue.",
            preferredStyle: .alert
        )
        alert.addTextField {
            $0.placeholder = "Current password"
            $0.isSecureTextEntry = true
            $0.textContentType = .password
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self, weak alert] _ in
            let password = InputValidator.limit(
                alert?.textFields?.first?.text ?? "",
                maxLength: InputValidator.singleLineMaxLength
            )
            self?.reauthenticateBeforeDeletion(currentPassword: password)
        })
        present(alert, animated: true)
    }

    private func reauthenticateBeforeDeletion(currentPassword: String) {
        let password = InputValidator.trimOnSubmit(currentPassword)

        guard !password.isEmpty else {
            showAlert(title: "Password Required", message: "Enter your current password to delete your account.")
            return
        }

        if let passwordError = InputValidator.validatePassword(password) {
            showAlert(title: "Invalid Password", message: passwordError)
            return
        }

        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser,
                  let email = user.email else {
                await MainActor.run {
                    self.showAlert(title: "Error", message: "No active account session was found.")
                }
                return
            }

            do {
                let tempClient = SupabaseManager.shared.makeEphemeralClient()
                _ = try await tempClient.auth.signIn(email: email, password: password)
                let reauthenticatedSession = try await tempClient.auth.session
                await MainActor.run {
                    self.pendingDeleteAccountBearerToken = reauthenticatedSession.accessToken
                    self.showPermanentDeleteConfirmation()
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "Delete Account Failed", message: "We couldn't verify your password. Please try again.")
                }
            }
        }
    }

    private func showPermanentDeleteConfirmation() {
        let alert = UIAlertController(
            title: "Delete Account",
            message: "This will permanently delete your account and all your data. This cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete Permanently", style: .destructive) { [weak self] _ in
            self?.performPermanentAccountDeletion()
        })
        present(alert, animated: true)
    }

    private func performPermanentAccountDeletion() {
        Task {
            do {
                guard let bearerToken = pendingDeleteAccountBearerToken else {
                    await MainActor.run {
                        self.showAlert(title: "Delete Account Failed", message: "Re-authentication expired. Please try again.")
                    }
                    return
                }
                try await SupabaseManager.shared.client.functions.invoke(
                    "delete-account",
                    options: FunctionInvokeOptions(
                        headers: ["Authorization": "Bearer \(bearerToken)"]
                    )
                )

                await MainActor.run {
                    self.pendingDeleteAccountBearerToken = nil
                    // uploads are stored on this device, not in Supabase: remove them too
                    LocalSheetLibrary.shared.deleteAllUploadsOfCurrentAccount()
                    self.showDeletionSuccessAndSignOut()
                }
            } catch {
                await MainActor.run {
                    self.pendingDeleteAccountBearerToken = nil
                    self.showAlert(title: "Delete Account Failed", message: "We couldn't delete your account right now. Please try again.")
                }
            }
        }
    }

    private func showDeletionSuccessAndSignOut() {
        let alert = UIAlertController(
            title: "Account Deleted",
            message: "Your account was permanently deleted.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.completeDeletionSignOut()
        })
        present(alert, animated: true)
    }

    private func completeDeletionSignOut() {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.signOut()
            } catch {
                debugLog("Local sign-out after deletion failed: \(error.localizedDescription)")
            }

            await MainActor.run {
                if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
                    sceneDelegate.showSplashAndRoute()
                }
            }
        }
    }

    @objc private func openTermsOfService() {
        presentLegalScreen(preselectPrivacy: false)
    }

    @objc private func openPrivacyPolicy() {
        presentLegalScreen(preselectPrivacy: true)
    }

    private func presentLegalScreen(preselectPrivacy: Bool) {
        let initialTab: LegalTab = preselectPrivacy ? .privacy : .terms
        let legalVC = UIHostingController(rootView: LegalScreenView(initialTab: initialTab))
        legalVC.modalPresentationStyle = .fullScreen
        present(legalVC, animated: true)
    }

    // MARK: - Edit Profile

    private func showNameEditor() {
        let currentName = GuestSessionManager.shared.isGuest()
            ? GuestSessionManager.shared.guestDisplayName()
            : currentProfile?.full_name
        let alert = UIAlertController(title: "Edit Name", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Full Name"
            field.text = currentName
            field.textContentType = .name
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let name = InputValidator.limit(
                InputValidator.trimOnSubmit(alert.textFields?.first?.text ?? ""),
                maxLength: InputValidator.nameMaxLength
            )
            guard InputValidator.validateRequired(name, message: "Name cannot be blank.") == nil else {
                self.showAlert(title: "Error", message: "Name cannot be blank.")
                return
            }
            self.updateProfileName(name)
        })
        present(alert, animated: true)
    }

    private func showUsernameEditor() {
        let currentUsername = GuestSessionManager.shared.isGuest()
            ? GuestSessionManager.shared.guestUsername()
            : currentProfile?.username
        let alert = UIAlertController(title: "Edit Username", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Username"
            field.text = currentUsername
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let username = InputValidator.limit(
                InputValidator.trimOnSubmit(alert.textFields?.first?.text ?? "").replacingOccurrences(of: " ", with: ""),
                maxLength: InputValidator.singleLineMaxLength
            )
            guard InputValidator.validateRequired(username, message: "Username cannot be blank.") == nil else {
                self.showAlert(title: "Error", message: "Username cannot be blank.")
                return
            }
            self.updateProfileUsername(username)
        })
        present(alert, animated: true)
    }

    private func showPasswordEditor() {
        guard !GuestSessionManager.shared.isGuest() else {
            presentAuthentication(mode: .logIn)
            return
        }

        let alert = UIAlertController(title: "Edit Password", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "New Password"; $0.isSecureTextEntry = true }
        alert.addTextField { $0.placeholder = "Confirm Password"; $0.isSecureTextEntry = true }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let pw = InputValidator.limit(alert.textFields?[0].text ?? "", maxLength: InputValidator.singleLineMaxLength)
            let pw2 = InputValidator.limit(alert.textFields?[1].text ?? "", maxLength: InputValidator.singleLineMaxLength)
            if pw.isEmpty { self.showAlert(title: "Error", message: "Password cannot be empty") }
            else if pw != pw2 { self.showAlert(title: "Error", message: "Passwords don't match") }
            else if let passwordError = InputValidator.validatePassword(pw) { self.showAlert(title: "Error", message: passwordError) }
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
        if GuestSessionManager.shared.isGuest() {
            var onboardingData = GuestSessionManager.shared.loadGuestOnboardingData() ?? [:]
            onboardingData["practice_mins"] = minutes
            GuestSessionManager.shared.saveGuestOnboardingData(onboardingData)
            goalBadgeLabel.text = goalBadgeText(for: minutes)
            DailyGoalManager.shared.dailyGoalMinutes = minutes
            showAlert(title: "Success", message: "Daily goal updated!")
            return
        }

        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            do {
                _ = try await SupabaseManager.shared.client
                    .from("user_onboarding")
                    .update(["practice_mins": minutes])
                    .eq("id", value: user.id.uuidString)
                    .select()
                    .execute()
                
                await MainActor.run {
                    self.goalBadgeLabel.text = self.goalBadgeText(for: minutes)
                    DailyGoalManager.shared.dailyGoalMinutes = minutes
                    self.showAlert(title: "Success", message: "Daily goal updated!")
                }
            } catch {
                await MainActor.run { showAlert(title: "Error", message: "We couldn't update your daily goal right now. Please try again.") }
            }
        }
    }

    @objc private func openAppearancePicker() {
        let currentTheme = AppThemeManager.shared.currentTheme
        let alert = UIAlertController(title: "Theme", message: nil, preferredStyle: .actionSheet)

        let themes: [AppTheme] = [.system, .light, .dark]
        for theme in themes {
            let title = theme == currentTheme ? "\(theme.displayName) ✓" : theme.displayName
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                AppThemeManager.shared.setTheme(theme, window: self?.view.window)
                self?.updateAppearanceValueLabel()
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            let sourceView = appearanceValueLabel.superview ?? view
            popover.sourceView = sourceView
            popover.sourceRect = sourceView?.bounds ?? .zero
        }

        present(alert, animated: true)
    }

    func updateProfileName(_ fullName: String) {
        if GuestSessionManager.shared.isGuest() {
            let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            GuestSessionManager.shared.saveGuestDisplayName(trimmedName)
            nameLabel.text = trimmedName.isEmpty ? "Guest" : trimmedName
            NotificationCenter.default.post(name: NavigationBarHelper.profileDidUpdateNotification, object: nil)
            return
        }

        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            do {
                _ = try await SupabaseManager.shared.client
                    .from("profiles").update(["full_name": fullName])
                    .eq("id", value: user.id.uuidString)
                    .select()
                    .execute()
                await MainActor.run {
                    nameLabel.text = fullName.isEmpty ? "No Name" : fullName
                    self.currentProfile?.full_name = fullName
                    NotificationCenter.default.post(name: NavigationBarHelper.profileDidUpdateNotification, object: nil)
                }
            } catch {
                await MainActor.run { showAlert(title: "Error", message: "We couldn't update your name right now. Please try again.") }
            }
        }
    }

    func updateProfileUsername(_ username: String) {
        if GuestSessionManager.shared.isGuest() {
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            GuestSessionManager.shared.saveGuestUsername(trimmedUsername)
            usernameLabel.text = trimmedUsername.isEmpty ? "@guest" : "@\(trimmedUsername)"
            return
        }

        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            do {
                _ = try await SupabaseManager.shared.client
                    .from("profiles").update(["username": username])
                    .eq("id", value: user.id.uuidString)
                    .select()
                    .execute()
                await MainActor.run {
                    self.usernameLabel.text = username.isEmpty ? "@username" : "@\(username)"
                    self.currentProfile?.username = username
                    NotificationCenter.default.post(name: NavigationBarHelper.profileDidUpdateNotification, object: nil)
                }
            } catch {
                await MainActor.run { showAlert(title: "Error", message: "We couldn't update your username right now. Please try again.") }
            }
        }
    }

    func updatePassword(newPassword: String) {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.update(user: .init(password: newPassword))
                await MainActor.run { showAlert(title: "Success", message: "Password updated!") }
            } catch {
                await MainActor.run { showAlert(title: "Error", message: "We couldn't update your password right now. Please try again.") }
            }
        }
    }
}

// MARK: - Avatar
extension UserProfileViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @objc func changeAvatarTapped() {
        guard !GuestSessionManager.shared.isGuest() else {
            presentAuthentication(mode: .signUp)
            return
        }

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
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            showAlert(title: "Photo Library Unavailable", message: "Photo Library is not available on this device right now.")
            return
        }

        switch PhotoLibraryAccess.status {
        case .authorized, .limited:
            presentProfilePhotoLibraryPicker()
        case .notDetermined:
            let alert = UIAlertController(
                title: "Use Photo Library for Profile Photo",
                message: "Re-Hearse only accesses your photo library when you choose Photo Library so you can select a profile picture.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
                PhotoLibraryAccess.request { status in
                    DispatchQueue.main.async {
                        switch status {
                        case .authorized, .limited:
                            self?.presentProfilePhotoLibraryPicker()
                        case .denied, .restricted:
                            self?.showPhotoLibrarySettingsAlert()
                        case .notDetermined:
                            break
                        @unknown default:
                            self?.showPhotoLibrarySettingsAlert()
                        }
                    }
                }
            })
            present(alert, animated: true)
        case .denied, .restricted:
            showPhotoLibrarySettingsAlert()
        @unknown default:
            showPhotoLibrarySettingsAlert()
        }
    }

    private func presentProfilePhotoLibraryPicker() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = false
        picker.delegate = self
        activeImagePicker = picker
        present(picker, animated: true)
    }

    private func openCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentProfileCameraPicker()
        case .notDetermined:
            let alert = UIAlertController(
                title: "Use Camera for Profile Photo",
                message: "Re-Hearse only uses the camera when you choose Camera so you can take a profile photo.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        granted ? self?.presentProfileCameraPicker() : self?.showCameraSettingsAlert()
                    }
                }
            })
            present(alert, animated: true)
        case .denied, .restricted:
            showCameraSettingsAlert()
        @unknown default:
            showCameraSettingsAlert()
        }
    }

    private func presentProfileCameraPicker() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = false
        picker.delegate = self
        activeImagePicker = picker
        present(picker, animated: true)
    }

    private func showCameraSettingsAlert() {
        let alert = UIAlertController(
            title: "Camera Access Needed",
            message: "Turn on camera access in Settings to take a profile photo.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsURL)
        })
        present(alert, animated: true)
    }

    private func showPhotoLibrarySettingsAlert() {
        let alert = UIAlertController(
            title: "Photo Library Access Needed",
            message: "Turn on Photo Library access in Settings to choose a profile photo.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsURL)
        })
        present(alert, animated: true)
    }

    private func dismissImagePicker(_ picker: UIImagePickerController, completion: (() -> Void)? = nil) {
        activeImagePicker = nil
        picker.delegate = nil
        guard picker.presentingViewController != nil else {
            completion?()
            return
        }
        picker.dismiss(animated: true, completion: completion)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let selectedImage = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        dismissImagePicker(picker) { [weak self] in
            guard let self, let image = selectedImage else { return }
            switch self.prepareUserSelectedImage(image) {
            case .success(let preparedImage):
                self.profileImageView.image = preparedImage
                self.profileImageView.contentMode = .scaleAspectFill
                self.uploadAvatarImage(preparedImage)
            case .failure(let error):
                self.showAlert(title: "Upload Error", message: error.userMessage)
            }
        }
    }

    private func prepareUserSelectedImage(_ image: UIImage) -> Result<UIImage, ImageValidationError> {
        guard let sourceData = image.normalizedImageData(jpegQuality: 1.0) else {
            return .failure(.processingFailed)
        }

        switch ImageValidator.validateAndPrepareImageData(sourceData, typeIdentifier: nil) {
        case .success(let prepared):
            guard let preparedImage = UIImage(data: prepared.data) else {
                return .failure(.processingFailed)
            }
            return .success(preparedImage)
        case .failure(let error):
            return .failure(error)
        }
    }

    func uploadAvatarImage(_ image: UIImage) {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser,
                  let sourceData = image.normalizedImageData(jpegQuality: 1.0) else { return }

            let prepared: PreparedImage
            switch ImageValidator.validateAndPrepareImageData(sourceData, typeIdentifier: nil) {
            case .success(let result):
                prepared = result
            case .failure(let error):
                await MainActor.run { showAlert(title: "Upload Error", message: error.userMessage) }
                return
            }

            let client = SupabaseManager.shared.client
            let fileName = "avatar_\(user.id.uuidString)_\(Int(Date().timeIntervalSince1970)).\(prepared.fileExtension)"
            do {
                try await client.storage.from("useprofile").upload(fileName, data: prepared.data)
                let signedURL = try await client.storage.from("useprofile")
                    .createSignedURL(path: fileName, expiresIn: 3600)
                _ = try await client.from("profiles")
                    .update(["avatar_url": fileName])
                    .eq("id", value: user.id.uuidString)
                    .execute()
                // Earlier avatars are never shown again; remove them so storage doesn't grow with every change.
                if let previous = try? await client.storage.from("useprofile")
                    .list(options: SearchOptions(search: "avatar_\(user.id.uuidString)")) {
                    let stale = previous.map(\.name).filter { $0 != fileName && $0.hasPrefix("avatar_") }
                    if !stale.isEmpty { _ = try? await client.storage.from("useprofile").remove(paths: stale) }
                }
                self.currentProfile = UserProfile(
                    id: self.currentProfile?.id ?? user.id,
                    avatar_url: signedURL.absoluteString,
                    full_name: self.currentProfile?.full_name,
                    username: self.currentProfile?.username,
                    bio: self.currentProfile?.bio,
                    total_study_seconds: self.currentProfile?.total_study_seconds,
                    daily_goal_minutes: self.currentProfile?.daily_goal_minutes,
                    practice_mins_today: self.currentProfile?.practice_mins_today,
                    last_practice_date: self.currentProfile?.last_practice_date,
                    current_chapter: self.currentProfile?.current_chapter
                )
                await MainActor.run {
                    NotificationCenter.default.post(name: NavigationBarHelper.profileDidUpdateNotification, object: nil)
                    showAlert(title: "Success", message: "Photo updated!")
                }
            } catch {
                debugLog("Profile upload error: \(error)")
                let message = AppUserFacingError.message(
                    for: "upload that photo",
                    error: error,
                    fallback: "We couldn't upload that photo right now. Please try again."
                )
                await MainActor.run {
                    showAlert(title: AppUserFacingError.title(for: error), message: message)
                }
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismissImagePicker(picker)
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
            guard let finalURL = await NavigationBarHelper.signedProfileURLString(from: urlString),
                  let url = URL(string: finalURL) else { return }
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
    func updateAppearanceValueLabel() {
        appearanceValueLabel.text = AppThemeManager.shared.currentTheme.displayName
    }

    func goalBadgeText(for minutes: Int) -> String {
        if minutes < 60 {
            return "Goal: \(minutes)m"
        }
        let goalHours = Double(minutes) / 60.0
        return goalHours == goalHours.rounded()
            ? "Goal: \(Int(goalHours))h"
            : String(format: "Goal: %.1fh", goalHours)
    }

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
            .font: UIFont.systemFont(ofSize: DeviceLayout.s(11), weight: .medium),
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





extension UserProfileViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        syncNavBarAlpha()
    }
}

/// iPad: wide, in two columns, like the Library.
extension UserProfileViewController: IPadContentWidth {
    var iPadContentWidth: CGFloat { 1180 }
}
