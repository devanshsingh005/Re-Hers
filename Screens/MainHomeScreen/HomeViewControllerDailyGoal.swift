//
//  HomeViewControllerDailyGoal.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/12/25.
//

import Foundation
//
//  HomeViewController+DailyGoal.swift
//  Re-Hearse_v1
//

import UIKit

// MARK: - Daily Goal Manager (Shared Singleton)
class DailyGoalManager {
    static let shared = DailyGoalManager()
    
    private let dailyGoalKey = "dailyGoalMinutes"
    private let practiceTimeKey = "practiceTimeToday"
    private let practiceStartDateKey = "practiceStartDate"
    
    // Notification name for updates
    static let dailyGoalUpdatedNotification = NSNotification.Name("DailyGoalUpdated")
    
    // Default daily goal is 60 minutes
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
        get {
            return UserDefaults.standard.string(forKey: practiceStartDateKey)
        }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: practiceStartDateKey)
            }
        }
    }
    
    // Reset daily practice time if it's a new day
    func checkAndResetIfNewDay() {
        let today = DateFormatter().string(from: Date(), format: "yyyy-MM-dd")
        
        if let lastDate = lastPracticeDateString, lastDate != today {
            // It's a new day, reset practice time
            practiceTimeMinutesToday = 0
        }
        
        // Update to today if not set
        if lastPracticeDateString == nil || lastPracticeDateString != today {
            lastPracticeDateString = today
        }
    }
    
    // Get progress as a decimal (0.0 to 1.0)
    func getProgressRatio() -> Float {
        let progress = Float(practiceTimeMinutesToday) / Float(dailyGoalMinutes)
        return min(progress, 1.0)
    }
}

// Helper extension for DateFormatter
extension DateFormatter {
    func string(from date: Date, format: String) -> String {
        self.dateFormat = format
        return self.string(from: date)
    }
}

extension HomeViewController {
    
    // MARK: - Daily Goal
    public func addDailyGoal() {
        // Reset daily practice time if it's a new day
        DailyGoalManager.shared.checkAndResetIfNewDay()
        
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
        
        let progress = UIProgressView()
        progress.progressTintColor = UIColor(red: 0.3, green: 0.75, blue: 0.45, alpha: 1.0) // Fresh green
        progress.trackTintColor = UIColor.white.withAlphaComponent(0.15)
        progress.layer.cornerRadius = 4
        progress.clipsToBounds = true
        progress.translatesAutoresizingMaskIntoConstraints = false
        
        // Make progress bar thicker
        progress.transform = CGAffineTransform(scaleX: 1.0, y: 2.0)
        
        dailyGoalProgressView = progress
        
        // Add tap to edit
        let tapCard = UITapGestureRecognizer(target: self, action: #selector(dailyGoalTapped))
        card.addGestureRecognizer(tapCard)
        card.isUserInteractionEnabled = true
        
        let time = UILabel()
        time.font = .systemFont(ofSize: 14, weight: .semibold)
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
            card.heightAnchor.constraint(equalToConstant: 56),
            
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            
            progress.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 16),
            progress.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            progress.trailingAnchor.constraint(equalTo: time.leadingAnchor, constant: -16),
            
            time.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            time.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            time.widthAnchor.constraint(equalToConstant: 80)
        ])

        dailyGoalContainer = container
        contentView.addArrangedSubview(container)
        
        // Update UI with current values
        updateDailyGoalUI()
        
        // Listen for daily goal updates from profile
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateDailyGoalUI),
            name: DailyGoalManager.dailyGoalUpdatedNotification,
            object: nil
        )
    }
    
    
    // MARK: - Update Daily Goal UI
    @objc func updateDailyGoalUI() {
        let practiceTime = DailyGoalManager.shared.practiceTimeMinutesToday
        let dailyGoal = DailyGoalManager.shared.dailyGoalMinutes
        let progress = DailyGoalManager.shared.getProgressRatio()
        
        dailyGoalProgressView?.progress = progress
        dailyGoalTimeLabel?.text = "\(practiceTime) / \(dailyGoal) mins"
    }
    
    // MARK: - Daily Goal Tap Handler
    @objc private func dailyGoalTapped() {
        let vc = UserProfileViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
}

