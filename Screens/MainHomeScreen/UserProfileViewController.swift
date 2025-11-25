//
//  UserProfileViewController.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 25/11/25.
//

import UIKit

// MARK: - Constants

private enum Constants {
    enum Colors {
        static let gradientStart = UIColor(red: 1.0, green: 0.6549, blue: 0.1490, alpha: 1.0)
        static let gradientEnd = UIColor.white
        static let darkCard = UIColor(red: 0.290, green: 0.290, blue: 0.290, alpha: 1.0)
        static let progressGreen = UIColor(red: 0.494, green: 0.812, blue: 0.541, alpha: 1.0)
        static let lightGrayRemainder = UIColor(white: 0.85, alpha: 1.0)
        static let white = UIColor.white
        static let orange = UIColor(red: 1.0, green: 0.6549, blue: 0.1490, alpha: 1.0)
        static let dailyGoalBackground = UIColor.black.withAlphaComponent(0.8)
        static let progressTrack = UIColor.white.withAlphaComponent(0.2)
    }
    
    enum Metrics {
        static let cardCornerRadius: CGFloat = 28
        static let cardHorizontalPadding: CGFloat = 24
        static let dailyGoalCardHeight: CGFloat = 48
        static let practiceGraphCardHeight: CGFloat = 300
        static let avatarSize: CGFloat = 64
        static let barWidth: CGFloat = 18
        static let barSpacing: CGFloat = 12
        static let barChartHeightValues: [CGFloat] = [55, 100, 150, 120, 100, 135, 150]
        static let barLabelHeight: CGFloat = 16
        static let metricsEmojiSize: CGFloat = 32
        static let metricsNumberFontSize: CGFloat = 40
        static let metricsCaptionFontSize: CGFloat = 14
        static let mostPlayedImageSize: CGFloat = 68
        static let mostPlayedCornerRadius: CGFloat = 18
        static let sectionTitleFontSize: CGFloat = 22
        static let greetingFontSize: CGFloat = 30
        static let greetingWeight: UIFont.Weight = .bold
        static let dailyGoalTitleFontSize: CGFloat = 14
        static let dailyGoalTimeFontSize: CGFloat = 12
        static let practiceGraphTitleFontSize: CGFloat = 20
        static let practiceSegmentedControlHeight: CGFloat = 28
        static let dailyGoalCornerRadius: CGFloat = 20
        static let progressWidth: CGFloat = 180
        static let dailyGoalPadding: CGFloat = 14
    }
}

// MARK: - UserProfileViewController

final class UserProfileViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var scrollView = makeScrollView()
    private lazy var contentStack = makeContentStack()
    private lazy var headerContainer = UIView()
    private lazy var greetingLabel = makeGreetingLabel()
    private lazy var avatarView = makeAvatarView()
    private lazy var dailyGoalCard = makeDailyGoalCard()
    private lazy var practiceGraphCard = makeCard()
    private lazy var practiceGraphHeaderContainer = UIView()
    private lazy var practiceGraphTitleLabel = makePracticeGraphTitleLabel()
    private lazy var practiceSegmentedControl = makePracticeSegmentedControl()
    private lazy var barChartContainer = makeBarChartContainer()
    private lazy var barsStackView = makeBarsStackView()
    private lazy var dayLabelsStackView = makeDayLabelsStackView()
    private lazy var metricsRowStack = makeMetricsRowStack()
    private lazy var streakMetricStack = makeMetricStack()
    private lazy var hoursMetricStack = makeMetricStack()
    private lazy var streakImageView = makeMetricImageView(systemName: "flame.fill")
    private lazy var streakNumberLabel = makeMetricNumberLabel("5")
    private lazy var streakCaptionLabel = makeMetricCaptionLabel("Days Streak")
    private lazy var hoursImageView = makeMetricImageView(systemName: "timer")
    private lazy var hoursNumberLabel = makeMetricNumberLabel("24")
    private lazy var hoursCaptionLabel = makeMetricCaptionLabel("Hours Spent")
    private lazy var mostPlayedSectionTitleLabel = makeMostPlayedSectionTitleLabel()
    private lazy var mostPlayedListStack = makeMostPlayedListStack()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureGradientBackground()
        configureBarChart()
        configureMostPlayed()
        updateSegmentedControlStyle()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        setupStacks()
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        setupHeader()
        setupPracticeGraphCard()
        setupMetrics()
        setupConstraints()
    }
    
    private func setupStacks() {
        [streakMetricStack, hoursMetricStack].forEach {
            $0.axis = .vertical
            $0.alignment = .center
            $0.spacing = 6
        }
        
        mostPlayedListStack.axis = .vertical
        mostPlayedListStack.spacing = 16
    }
    
    private func setupHeader() {
        headerContainer.addSubviews(greetingLabel, avatarView)
        contentStack.addArrangedSubviews(
            headerContainer, dailyGoalCard, practiceGraphCard,
            metricsRowStack, mostPlayedSectionTitleLabel, mostPlayedListStack
        )
    }
    
    private func setupPracticeGraphCard() {
        practiceGraphHeaderContainer.addSubviews(practiceGraphTitleLabel, practiceSegmentedControl)
        barChartContainer.addSubviews(barsStackView, dayLabelsStackView)
        practiceGraphCard.addSubviews(practiceGraphHeaderContainer, barChartContainer)
    }
    
    private func setupMetrics() {
        metricsRowStack.addArrangedSubviews(streakMetricStack, hoursMetricStack)
        streakMetricStack.addArrangedSubviews(streakImageView, streakNumberLabel, streakCaptionLabel)
        hoursMetricStack.addArrangedSubviews(hoursImageView, hoursNumberLabel, hoursCaptionLabel)
    }
    
    // MARK: - UI Factory Methods
    
    private func makeScrollView() -> UIScrollView {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.contentInsetAdjustmentBehavior = .always
        sv.alwaysBounceVertical = true
        sv.showsVerticalScrollIndicator = true
        return sv
    }
    
    private func makeContentStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }
    
    private func makeGreetingLabel() -> UILabel {
        let label = UILabel()
        label.text = "Good Afternoon"
        label.font = .systemFont(ofSize: Constants.Metrics.greetingFontSize, weight: Constants.Metrics.greetingWeight)
        label.textColor = Constants.Colors.white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func makeAvatarView() -> UIView {
        let view = UIView()
        view.backgroundColor = Constants.Colors.orange
        view.layer.cornerRadius = Constants.Metrics.avatarSize / 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    
    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = Constants.Colors.darkCard
        card.layer.cornerRadius = Constants.Metrics.cardCornerRadius
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }
    
    private func makeDailyGoalCard() -> UIView {
        let container = UIView()
        container.backgroundColor = Constants.Colors.dailyGoalBackground
        container.layer.cornerRadius = Constants.Metrics.dailyGoalCornerRadius
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Enable tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(openPianoPage))
        container.addGestureRecognizer(tap)
        container.isUserInteractionEnabled = true
        
        let label = UILabel()
        label.text = "Daily goal"
        label.font = .systemFont(ofSize: Constants.Metrics.dailyGoalTitleFontSize, weight: .regular)
        label.textColor = Constants.Colors.white
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let progress = UIProgressView()
        progress.progress = 0.7
        progress.progressTintColor = .systemGreen
        progress.trackTintColor = Constants.Colors.progressTrack
        progress.translatesAutoresizingMaskIntoConstraints = false
        
        let time = UILabel()
        time.text = "20 mins"
        time.font = .systemFont(ofSize: Constants.Metrics.dailyGoalTimeFontSize)
        time.textColor = Constants.Colors.white
        time.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(label)
        container.addSubview(progress)
        container.addSubview(time)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: Constants.Metrics.dailyGoalCardHeight),
            
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Constants.Metrics.dailyGoalPadding),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            progress.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            progress.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            progress.widthAnchor.constraint(equalToConstant: Constants.Metrics.progressWidth),
            
            time.leadingAnchor.constraint(equalTo: progress.trailingAnchor, constant: 8),
            time.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return container
    }
    
    private func makePracticeGraphTitleLabel() -> UILabel {
        let label = UILabel()
        label.text = "Practice Graph"
        label.font = .systemFont(ofSize: Constants.Metrics.practiceGraphTitleFontSize, weight: .semibold)
        label.textColor = Constants.Colors.white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func makePracticeSegmentedControl() -> UISegmentedControl {
        let sc = UISegmentedControl(items: ["7 Days", "1 Month"])
        sc.selectedSegmentIndex = 0
        sc.selectedSegmentTintColor = Constants.Colors.white
        sc.setTitleTextAttributes([.foregroundColor: Constants.Colors.white], for: .normal)
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }
    
    private func makeBarChartContainer() -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    
    private func makeBarsStackView() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .bottom
        stack.spacing = Constants.Metrics.barSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }
    
    private func makeDayLabelsStackView() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Constants.Metrics.barSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }
    
    private func makeMetricsRowStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 48
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }
    
    private func makeMetricStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        return stack
    }
    
    private func makeMetricImageView(systemName: String) -> UIImageView {
        let iv = UIImageView()
        iv.image = UIImage(systemName: systemName)
        iv.tintColor = Constants.Colors.orange
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }
    
    private func makeMetricNumberLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: Constants.Metrics.metricsNumberFontSize, weight: .bold)
        label.textColor = Constants.Colors.white
        return label
    }
    
    private func makeMetricCaptionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: Constants.Metrics.metricsCaptionFontSize)
        label.textColor = Constants.Colors.white.withAlphaComponent(0.7)
        return label
    }
    
    private func makeMostPlayedSectionTitleLabel() -> UILabel {
        let label = UILabel()
        label.text = "Most Played"
        label.font = .systemFont(ofSize: Constants.Metrics.sectionTitleFontSize, weight: .semibold)
        label.textColor = Constants.Colors.white
        return label
    }
    
    private func makeMostPlayedListStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }
    
    // MARK: - Actions
    
    @objc private func openPianoPage() {
        print("Daily goal tapped - open piano page")
    }
    
    // MARK: - Configuration
    
    private func updateSegmentedControlStyle() {
        let backgroundColor = UIColor(white: 1.0, alpha: 0.12)
        practiceSegmentedControl.backgroundColor = backgroundColor
        practiceSegmentedControl.layer.cornerRadius = Constants.Metrics.practiceSegmentedControlHeight / 2
        practiceSegmentedControl.clipsToBounds = true
        // We keep original simple white text; no .font key (to avoid the width: error)
    }
    
    private func configureBarChart() {
        let days = ["mon", "tues", "wed", "thurs", "fri", "sat", "sun"]
        
        barsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        dayLabelsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for (i, height) in Constants.Metrics.barChartHeightValues.enumerated() {
            let bar = UIView()
            bar.backgroundColor = i < 2 ? Constants.Colors.white : Constants.Colors.orange
            bar.layer.cornerRadius = Constants.Metrics.barWidth / 2
            if #available(iOS 13.0, *) {
                bar.layer.cornerCurve = .continuous
            }
            bar.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                bar.heightAnchor.constraint(equalToConstant: height),
                bar.widthAnchor.constraint(equalToConstant: Constants.Metrics.barWidth)
            ])
            
            barsStackView.addArrangedSubview(bar)
            
            let label = UILabel()
            label.text = days[i]
            label.font = .systemFont(ofSize: 12)
            label.textColor = Constants.Colors.white.withAlphaComponent(0.7)
            label.textAlignment = .center
            dayLabelsStackView.addArrangedSubview(label)
        }
    }
    
    private func configureMostPlayed() {
        mostPlayedListStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let mostPlayedItems = [
            ("Shallow", "Lady Gaga & Bradley Cooper", 23, UIColor.systemPink),
            ("Blinding Lights", "The Weeknd", 16, UIColor.systemTeal)
        ]
        
        mostPlayedItems.forEach { title, subtitle, count, color in
            mostPlayedListStack.addArrangedSubview(
                MostPlayedCellView(title: title, subtitle: subtitle, count: count, color: color)
            )
        }
    }
    
    private func configureGradientBackground() {
        let gradient = CAGradientLayer()
        gradient.colors = [Constants.Colors.gradientStart.cgColor, Constants.Colors.gradientEnd.cgColor]
        gradient.frame = view.bounds
        view.layer.insertSublayer(gradient, at: 0)
    }
    
    // MARK: - Constraints
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll View
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content Stack
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 32),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            // Header
            headerContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: Constants.Metrics.avatarSize),
            greetingLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: Constants.Metrics.cardHorizontalPadding),
            greetingLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            avatarView.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -Constants.Metrics.cardHorizontalPadding),
            avatarView.widthAnchor.constraint(equalToConstant: Constants.Metrics.avatarSize),
            avatarView.heightAnchor.constraint(equalToConstant: Constants.Metrics.avatarSize),
            
            // Daily Goal Card
            dailyGoalCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.Metrics.cardHorizontalPadding),
            dailyGoalCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.Metrics.cardHorizontalPadding),
            
            // Practice Graph Card
            practiceGraphCard.heightAnchor.constraint(equalToConstant: Constants.Metrics.practiceGraphCardHeight),
            practiceGraphCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.Metrics.cardHorizontalPadding),
            practiceGraphCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.Metrics.cardHorizontalPadding),
            
            // Graph Header
            practiceGraphHeaderContainer.topAnchor.constraint(equalTo: practiceGraphCard.topAnchor, constant: 16),
            practiceGraphHeaderContainer.leadingAnchor.constraint(equalTo: practiceGraphCard.leadingAnchor, constant: 20),
            practiceGraphHeaderContainer.trailingAnchor.constraint(equalTo: practiceGraphCard.trailingAnchor, constant: -20),
            practiceGraphHeaderContainer.heightAnchor.constraint(equalToConstant: Constants.Metrics.practiceSegmentedControlHeight),
            
            practiceGraphTitleLabel.centerYAnchor.constraint(equalTo: practiceGraphHeaderContainer.centerYAnchor),
            practiceGraphTitleLabel.leadingAnchor.constraint(equalTo: practiceGraphHeaderContainer.leadingAnchor),
            
            practiceSegmentedControl.centerYAnchor.constraint(equalTo: practiceGraphHeaderContainer.centerYAnchor),
            practiceSegmentedControl.trailingAnchor.constraint(equalTo: practiceGraphHeaderContainer.trailingAnchor),
            practiceSegmentedControl.widthAnchor.constraint(equalToConstant: 140),
            
            // Graph Body
            barChartContainer.topAnchor.constraint(equalTo: practiceGraphHeaderContainer.bottomAnchor, constant: 20),
            barChartContainer.leadingAnchor.constraint(equalTo: practiceGraphCard.leadingAnchor, constant: 20),
            barChartContainer.trailingAnchor.constraint(equalTo: practiceGraphCard.trailingAnchor, constant: -20),
            barChartContainer.bottomAnchor.constraint(equalTo: practiceGraphCard.bottomAnchor, constant: -20),
            
            barsStackView.leadingAnchor.constraint(equalTo: barChartContainer.leadingAnchor),
            barsStackView.trailingAnchor.constraint(equalTo: barChartContainer.trailingAnchor),
            barsStackView.bottomAnchor.constraint(equalTo: dayLabelsStackView.topAnchor, constant: -8),
            barsStackView.heightAnchor.constraint(equalToConstant: 160),
            
            dayLabelsStackView.leadingAnchor.constraint(equalTo: barsStackView.leadingAnchor),
            dayLabelsStackView.trailingAnchor.constraint(equalTo: barsStackView.trailingAnchor),
            dayLabelsStackView.bottomAnchor.constraint(equalTo: barChartContainer.bottomAnchor),
            dayLabelsStackView.heightAnchor.constraint(equalToConstant: Constants.Metrics.barLabelHeight),
            
            // Metrics row leading/trailing (kept from your original)
            metricsRowStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Constants.Metrics.cardHorizontalPadding),
            metricsRowStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Constants.Metrics.cardHorizontalPadding)
        ])
        
        NSLayoutConstraint.activate([
            streakImageView.widthAnchor.constraint(equalToConstant: Constants.Metrics.metricsEmojiSize),
            streakImageView.heightAnchor.constraint(equalToConstant: Constants.Metrics.metricsEmojiSize),
            hoursImageView.widthAnchor.constraint(equalToConstant: Constants.Metrics.metricsEmojiSize),
            hoursImageView.heightAnchor.constraint(equalToConstant: Constants.Metrics.metricsEmojiSize)
        ])
    }
}

// MARK: - MostPlayedCellView

final class MostPlayedCellView: UIView {
    
    private let albumView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let countLabel = UILabel()
    private let infoStack = UIStackView()
    
    init(title: String, subtitle: String, count: Int, color: UIColor) {
        super.init(frame: .zero)
        setupView(title: title, subtitle: subtitle, count: count, color: color)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupView(title: String, subtitle: String, count: Int, color: UIColor) {
        translatesAutoresizingMaskIntoConstraints = false
        
        albumView.backgroundColor = color
        albumView.layer.cornerRadius = Constants.Metrics.mostPlayedCornerRadius
        albumView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = Constants.Colors.white
        
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = Constants.Colors.white.withAlphaComponent(0.7)
        
        countLabel.text = "\(count)\nTimes"
        countLabel.font = .systemFont(ofSize: 16, weight: .medium)
        countLabel.textAlignment = .right
        countLabel.textColor = Constants.Colors.orange
        countLabel.numberOfLines = 2
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        
        infoStack.axis = .vertical
        infoStack.spacing = 4
        infoStack.addArrangedSubview(titleLabel)
        infoStack.addArrangedSubview(subtitleLabel)
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(albumView)
        addSubview(infoStack)
        addSubview(countLabel)
        
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 88),
            
            albumView.leadingAnchor.constraint(equalTo: leadingAnchor),
            albumView.centerYAnchor.constraint(equalTo: centerYAnchor),
            albumView.widthAnchor.constraint(equalToConstant: Constants.Metrics.mostPlayedImageSize),
            albumView.heightAnchor.constraint(equalToConstant: Constants.Metrics.mostPlayedImageSize),
            
            infoStack.leadingAnchor.constraint(equalTo: albumView.trailingAnchor, constant: 16),
            infoStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            countLabel.widthAnchor.constraint(equalToConstant: 64)
        ])
    }
}

// MARK: - Extensions

extension UIView {
    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }
}

extension UIStackView {
    func addArrangedSubviews(_ views: UIView...) {
        views.forEach { addArrangedSubview($0) }
    }
}
