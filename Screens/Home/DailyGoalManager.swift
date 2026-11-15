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
    private let practiceRemainderSecondsKey = "practiceRemainderSeconds"

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

    private var practiceRemainderSeconds: Int {
        get { UserDefaults.standard.integer(forKey: practiceRemainderSecondsKey) }
        set { UserDefaults.standard.set(newValue, forKey: practiceRemainderSecondsKey) }
    }

    private init() {
        // Load initial values from Disk (immediate)
        let storedGoal = UserDefaults.standard.integer(forKey: dailyGoalKey)
        _dailyGoal = storedGoal > 0 ? storedGoal : 60
        _practiceMins = UserDefaults.standard.integer(forKey: practiceTimeKey)
        
        // Start background sync from Supabase
        Task {
            await refreshFromSupabase()
        }
    }

    func checkAndResetIfNewDay() {
        let today = DailyGoalManager.dayString(for: Date())
        if let lastDate = lastPracticeDateString, lastDate != today {
            practiceTimeMinutesToday = 0
            _practiceMins = 0
            practiceRemainderSeconds = 0
        }
        if lastPracticeDateString == nil || lastPracticeDateString != today {
            lastPracticeDateString = today
        }
    }

    func addPracticeDuration(seconds: Int) {
        let normalizedSeconds = max(seconds, 0)
        guard normalizedSeconds > 0 else { return }

        checkAndResetIfNewDay()

        let totalSeconds = practiceRemainderSeconds + normalizedSeconds
        let fullMinutes = totalSeconds / 60
        practiceRemainderSeconds = totalSeconds % 60

        if fullMinutes > 0 {
            practiceTimeMinutesToday += fullMinutes
        }
    }

    // MARK: - Supabase Sync

    func refreshFromSupabase() async {
        guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
        do {
            let profile: UserProfile = try await SupabaseManager.shared.client
                .from("profiles")
                .select("daily_goal_minutes, practice_mins_today, last_practice_date")
                .eq("id", value: user.id.uuidString)
                .single()
                .execute()
                .value

            await MainActor.run {
                self._dailyGoal = profile.daily_goal_minutes ?? self._dailyGoal

                let today = DailyGoalManager.dayString(for: Date())
                if profile.last_practice_date == today {
                    let remotePracticeMins = profile.practice_mins_today ?? 0
                    self._practiceMins = max(remotePracticeMins, self._practiceMins)
                } else {
                    self._practiceMins = 0
                    self.practiceRemainderSeconds = 0
                }

                self.lastPracticeDateString = profile.last_practice_date
                NotificationCenter.default.post(name: Self.dailyGoalUpdatedNotification, object: nil)
            }
        } catch {
            debugLog("DailyGoal sync error (Supabase): \(error)")
        }
    }

    private func syncToSupabase() {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            let today = DailyGoalManager.dayString(for: Date())

            struct DailyGoalProfileUpdate: Encodable {
                let daily_goal_minutes: Int
                let practice_mins_today: Int
                let last_practice_date: String
            }

            let update = DailyGoalProfileUpdate(
                daily_goal_minutes: dailyGoalMinutes,
                practice_mins_today: practiceTimeMinutesToday,
                last_practice_date: today
            )

            do {
                try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(update)
                    .eq("id", value: user.id.uuidString)
                    .execute()
            } catch {
                debugLog("DailyGoal push error: \(error)")
            }
        }
    }
}

extension DailyGoalManager {
    /// "2026-11-16" for `date`, in the user's calendar; one shared formatter.
    static func dayString(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

