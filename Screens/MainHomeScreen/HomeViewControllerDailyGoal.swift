//
//  HomeViewControllerDailyGoal.swift
//  Re-Hearse_v1
//

import UIKit

// MARK: - Daily Goal Manager (Shared Singleton)
class DailyGoalManager {
    static let shared = DailyGoalManager()
    
    private let dailyGoalKey = "dailyGoalMinutes"
    private let practiceTimeKey = "practiceTimeToday"
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
        let progress = Float(practiceTimeMinutesToday) / Float(dailyGoalMinutes)
        return min(progress, 1.0)
    }
}

extension DateFormatter {
    func string(from date: Date, format: String) -> String {
        self.dateFormat = format
        return self.string(from: date)
    }
}

extension HomeViewController {
    
    // MARK: - Daily Goal Bar (compact pill, matches design)
    public func addDailyGoal() {
        DailyGoalManager.shared.checkAndResetIfNewDay()

        let container = UIView()

        // Pill card: dark charcoal to match design
        let card = UIView()
        card.backgroundColor = UIColor(red: 0.15, green: 0.14, blue: 0.13, alpha: 1.0)
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.12
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        card.layer.shadowRadius = 8
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        // "Day 5" badge on the right (matching navbar area in design)
        // The daily goal bar itself shows "Daily goal" + progress + time
        let label = UILabel()
        label.text = "Daily goal"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false

        let progress = UIProgressView()
        progress.progressTintColor = UIColor(red: 0.28, green: 0.78, blue: 0.44, alpha: 1.0) // green
        progress.trackTintColor = UIColor.white.withAlphaComponent(0.15)
        progress.layer.cornerRadius = 3
        progress.clipsToBounds = true
        progress.transform = CGAffineTransform(scaleX: 1.0, y: 2.0)
        progress.translatesAutoresizingMaskIntoConstraints = false
        dailyGoalProgressView = progress

        let tapCard = UITapGestureRecognizer(target: self, action: #selector(dailyGoalTapped))
        card.addGestureRecognizer(tapCard)
        card.isUserInteractionEnabled = true

        let time = UILabel()
        time.font = .systemFont(ofSize: 13, weight: .semibold)
        time.textColor = UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1.0)
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
            card.heightAnchor.constraint(equalToConstant: 52),

            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 80),

            progress.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            progress.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            progress.trailingAnchor.constraint(equalTo: time.leadingAnchor, constant: -12),

            time.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            time.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            time.widthAnchor.constraint(equalToConstant: 80)
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
        let practiceTime = DailyGoalManager.shared.practiceTimeMinutesToday
        let dailyGoal = DailyGoalManager.shared.dailyGoalMinutes
        dailyGoalProgressView?.progress = DailyGoalManager.shared.getProgressRatio()
        dailyGoalTimeLabel?.text = "\(practiceTime)/\(dailyGoal) min"
    }

    @objc private func dailyGoalTapped() {
        let vc = LessonMapViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
}
