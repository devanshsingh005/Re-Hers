//
//  DailyGoalManager.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase
import Auth
internal import PostgREST

// MARK: - Daily Goal Manager (Shared Singleton)

class DailyGoalManager {
    static let shared = DailyGoalManager()

    private let dailyGoalKey         = "dailyGoalMinutes"
    private let practiceTimeKey      = "practiceTimeToday"
    private let practiceStartDateKey = "practiceStartDate"

    static let dailyGoalUpdatedNotification = NSNotification.Name("DailyGoalUpdated")

    // The in-memory source of truth, updated from sync
    private var _dailyGoal: Int   = 60
    private var _practiceMins: Int = 0

    var dailyGoalMinutes: Int {
        get { return _dailyGoal }
        set {
            _dailyGoal = newValue
            UserDefaults.standard.set(newValue, forKey: dailyGoalKey)
            NotificationCenter.default.post(name: Self.dailyGoalUpdatedNotification, object: nil)
            syncToSupabase()
        }
    }

    var practiceTimeMinutesToday: Int {
        get { return _practiceMins }
        set {
            _practiceMins = newValue
            UserDefaults.standard.set(newValue, forKey: practiceTimeKey)
            NotificationCenter.default.post(name: Self.dailyGoalUpdatedNotification, object: nil)
            syncToSupabase()
        }
    }

    var lastPracticeDateString: String? {
        get { UserDefaults.standard.string(forKey: practiceStartDateKey) }
        set { if let v = newValue { UserDefaults.standard.set(v, forKey: practiceStartDateKey) } }
    }

    private init() {
        // Load initial values from Disk (immediate)
        let storedGoal = UserDefaults.standard.integer(forKey: dailyGoalKey)
        _dailyGoal = storedGoal > 0 ? storedGoal : 60
        _practiceMins = UserDefaults.standard.integer(forKey: practiceTimeKey)
        
        // Start background sync from Supabase
        fetchFromSupabase()
    }

    func checkAndResetIfNewDay() {
        let today = DateFormatter().string(from: Date(), format: "yyyy-MM-dd")
        if let lastDate = lastPracticeDateString, lastDate != today {
            practiceTimeMinutesToday = 0
            _practiceMins = 0
        }
        if lastPracticeDateString == nil || lastPracticeDateString != today {
            lastPracticeDateString = today
        }
    }

    func getProgressRatio() -> Float {
        guard dailyGoalMinutes > 0 else { return 0 }
        return min(Float(practiceTimeMinutesToday) / Float(dailyGoalMinutes), 1.0)
    }

    // MARK: - Supabase Sync

    private func fetchFromSupabase() {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            do {
                let profile: UserProfile = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select("daily_goal_minutes, practice_mins_today, last_practice_date")
                    .eq("id", value: user.id)
                    .single()
                    .execute()
                    .value
                
                await MainActor.run {
                    self._dailyGoal = profile.daily_goal_minutes ?? self._dailyGoal
                    
                    // Only sync practice mins if it's the same day
                    let today = DateFormatter().string(from: Date(), format: "yyyy-MM-dd")
                    if profile.last_practice_date == today {
                        self._practiceMins = profile.practice_mins_today ?? self._practiceMins
                    } else {
                        // It's a new day on the server side
                        self._practiceMins = 0
                    }
                    
                    NotificationCenter.default.post(name: Self.dailyGoalUpdatedNotification, object: nil)
                }
            } catch {
                debugLog("DailyGoal sync error (Supabase): \(error)")
            }
        }
    }

    private func syncToSupabase() {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            let today = DateFormatter().string(from: Date(), format: "yyyy-MM-dd")
            
            let update: [String: String] = [
                "daily_goal_minutes": String(dailyGoalMinutes),
                "practice_mins_today": String(practiceTimeMinutesToday),
                "last_practice_date": today
            ]
            
            do {
                try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(update)
                    .eq("id", value: user.id)
                    .execute()
            } catch {
                debugLog("DailyGoal push error: \(error)")
            }
        }
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
        mainStackView.addArrangedSubview(container)

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
        navigationController?.pushViewController(LessonMapViewController(), animated: true)
    }
}
