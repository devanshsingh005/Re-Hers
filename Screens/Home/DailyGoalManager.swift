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
            // The goal is saved by whoever changes it, to user_onboarding.practice_mins (the source of truth).
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

    private struct RemoteDailyProgress: Decodable {
        let practice_mins_today: Int?
        let last_practice_date: String?
    }

    private struct RemoteGoal: Decodable {
        let practice_mins: Int
    }

    /// Goal from user_onboarding (chosen during onboarding), today's progress from profiles.
    func refreshFromSupabase() async {
        guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
        let client = SupabaseManager.shared.client
        let userId = user.id.uuidString

        async let goalRows: [RemoteGoal] = client
            .from("user_onboarding")
            .select("practice_mins")
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        async let progressRows: [RemoteDailyProgress] = client
            .from("profiles")
            .select("practice_mins_today, last_practice_date")
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value

        do {
            let goal = try await goalRows.first?.practice_mins
            let progress = try await progressRows.first

            await MainActor.run {
                if let goal, goal > 0 {
                    self._dailyGoal = goal
                    UserDefaults.standard.set(goal, forKey: self.dailyGoalKey)
                }

                let today = DailyGoalManager.dayString(for: Date())
                if progress?.last_practice_date == today {
                    let remotePracticeMins = progress?.practice_mins_today ?? 0
                    self._practiceMins = max(remotePracticeMins, self._practiceMins)
                } else if self.lastPracticeDateString != today {
                    self._practiceMins = 0
                    self.practiceRemainderSeconds = 0
                }

                if let remoteDate = progress?.last_practice_date {
                    self.lastPracticeDateString = max(remoteDate, self.lastPracticeDateString ?? "")
                }
                NotificationCenter.default.post(name: Self.dailyGoalUpdatedNotification, object: nil)
            }
        } catch {
            debugLog("DailyGoal sync error (Supabase): \(error)")
        }
    }

    /// Pushes today's progress only; the goal lives in user_onboarding.
    private func syncToSupabase() {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { return }
            let today = DailyGoalManager.dayString(for: Date())

            struct DailyProgressUpdate: Encodable {
                let practice_mins_today: Int
                let last_practice_date: String
            }

            let update = DailyProgressUpdate(
                practice_mins_today: min(practiceTimeMinutesToday, 1440),
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

