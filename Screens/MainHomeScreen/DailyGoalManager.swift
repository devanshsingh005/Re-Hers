//
//  DailyGoalManager.swift
//  Re-Hearse_v1
//

import UIKit

// MARK: - Daily Goal Manager (Shared Singleton)

class DailyGoalManager {
    static let shared = DailyGoalManager()

    private let dailyGoalKey         = "dailyGoalMinutes"
    private let practiceTimeKey      = "practiceTimeToday"
    private let practiceStartDateKey = "practiceStartDate"

    static let dailyGoalUpdatedNotification = NSNotification.Name("DailyGoalUpdated")

    var dailyGoalMinutes: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: dailyGoalKey)
            return stored > 0 ? stored : 60
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dailyGoalKey)
            NotificationCenter.default.post(name: Self.dailyGoalUpdatedNotification, object: nil)
        }
    }

    var practiceTimeMinutesToday: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: practiceTimeKey)
            return stored >= 0 ? stored : 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: practiceTimeKey)
            NotificationCenter.default.post(name: Self.dailyGoalUpdatedNotification, object: nil)
        }
    }

    var lastPracticeDateString: String? {
        get { UserDefaults.standard.string(forKey: practiceStartDateKey) }
        set { if let v = newValue { UserDefaults.standard.set(v, forKey: practiceStartDateKey) } }
    }

    func checkAndResetIfNewDay() {
        let today = DateFormatter().string(from: Date(), format: "yyyy-MM-dd")
        if let lastDate = lastPracticeDateString, lastDate != today {
            practiceTimeMinutesToday = 0
        }
        if lastPracticeDateString == nil || lastPracticeDateString != today {
            lastPracticeDateString = today
        }
    }

    func getProgressRatio() -> Float {
        min(Float(practiceTimeMinutesToday) / Float(dailyGoalMinutes), 1.0)
    }
}

extension DateFormatter {
    func string(from date: Date, format: String) -> String {
        self.dateFormat = format
        return self.string(from: date)
    }
}

// MARK: - HomeViewController Daily Goal Bar

extension HomeViewController {

    public func addDailyGoal() {
        DailyGoalManager.shared.checkAndResetIfNewDay()

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // ── Cream pill card, full stadium radius ──
        let cardHeight: CGFloat = 44
        let card = UIView()
        card.backgroundColor  = ComponentColors.App.screenBackground
        card.layer.cornerRadius  = cardHeight / 2   // full pill
        card.layer.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        // "Daily goal" — deep orange text
        let label = UILabel()
        label.text      = "Daily goal"
        label.font      = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = ComponentColors.HomeScreen.actionButtonFill
        label.translatesAutoresizingMaskIntoConstraints = false

        // Progress bar — orange fill, sand track
        let progress = UIProgressView()
        progress.progressTintColor = ComponentColors.HomeScreen.actionButtonFill
        progress.trackTintColor    = ComponentColors.QuizScreen.progressTrack
        progress.layer.cornerRadius = 3
        progress.clipsToBounds      = true
        progress.transform = CGAffineTransform(scaleX: 1.0, y: 1.8)
        progress.translatesAutoresizingMaskIntoConstraints = false
        dailyGoalProgressView = progress

        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dailyGoalTapped)))
        card.isUserInteractionEnabled = true

        // Time label — deep orange, right-aligned
        let time = UILabel()
        time.font          = .systemFont(ofSize: 12, weight: .semibold)
        time.textColor     = ComponentColors.HomeScreen.actionButtonFill
        time.textAlignment = .right
        time.translatesAutoresizingMaskIntoConstraints = false
        dailyGoalTimeLabel = time

        card.addSubview(label)
        card.addSubview(progress)
        card.addSubview(time)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            card.heightAnchor.constraint(equalToConstant: cardHeight),

            // Leading padded to match pill curve
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 70),

            progress.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            progress.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            progress.trailingAnchor.constraint(equalTo: time.leadingAnchor, constant: -10),

            time.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            time.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            time.widthAnchor.constraint(equalToConstant: 64),
        ])

        dailyGoalContainer = container
        contentView.addArrangedSubview(container)

        updateDailyGoalUI()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateDailyGoalUI),
            name: DailyGoalManager.dailyGoalUpdatedNotification,
            object: nil
        )
    }

    @objc func updateDailyGoalUI() {
        let mins = DailyGoalManager.shared.practiceTimeMinutesToday
        let goal = DailyGoalManager.shared.dailyGoalMinutes
        dailyGoalProgressView?.progress = DailyGoalManager.shared.getProgressRatio()
        dailyGoalTimeLabel?.text = "\(mins)/\(goal) min"
    }

    @objc private func dailyGoalTapped() {
        tabBarController?.selectedIndex = 2
    }
}
