//
//  HomeViewController.swift
//  Re-Hearse_v1
//

import UIKit

class HomeViewController: UIViewController {

    let navBar      = TopNavBar.make(title: "Home")
    let scrollView  = UIScrollView()
    let contentView = UIStackView()
    var fixedFooter: UIView!

    var dailyGoalProgressView: UIProgressView?
    var dailyGoalTimeLabel:    UILabel?
    var dailyGoalContainer:    UIView?
    var playlistStackView:     UIStackView?
    var recentsStackView:      UIStackView?
    var topCardTitleLabel:     UILabel?
    var topCardTagLabel:       UILabel?
    var topCardImageView:      UIImageView?

    private var practiceTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startPracticeTimer()
        fetchPlaylists()
        fetchTopSong()
        fetchRecents()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startPracticeTimer()
        fetchRecents()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPracticeTimer()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopPracticeTimer()
    }

    private func setupUI() {
        // Background and navigation bar — tokens handle light/dark automatically
        view.backgroundColor = ComponentColors.HomeScreen.background
        navigationController?.navigationBar.isHidden = true
        setupNavBar()
        setupScrollView()
        addTopPracticeCard()
        addUploadSection()
        addPlaylistSection()
        addRecentsSection()
    }

    private func startPracticeTimer() {
        stopPracticeTimer()
        practiceTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard self != nil else { return }
            DailyGoalManager.shared.checkAndResetIfNewDay()
            DailyGoalManager.shared.practiceTimeMinutesToday += 1
        }
    }

    private func stopPracticeTimer() {
        practiceTimer?.invalidate()
        practiceTimer = nil
    }

    private func fetchPlaylists() {
        Task {
            do {
                let list = try await PlaylistService.shared.fetchPlaylists()
                await MainActor.run {
                    self.populatePlaylists(list)
                }
            } catch {
                print("Error fetching playlists: \(error)")
            }
        }
    }
    
    private func fetchTopSong() {
        Task {
            do {
                let songs = try await SongService.shared.fetchSongs()
                if let song = songs.first {
                    await MainActor.run {
                        self.topCardTitleLabel?.text = song.title
                        let tempoStr = song.tempo.uppercased()
                        let handStr = song.hands == "right_only" ? "RH ONLY" : song.hands == "left_only" ? "LH ONLY" : "BOTH HANDS"
                        self.topCardTagLabel?.text = "\(tempoStr) | \(handStr)"
                        self.topCardImageView?.image = UIImage(named: "trackimage_\(Int.random(in: 1...16))")
                        self.topCardTitleLabel?.superview?.layoutIfNeeded()
                    }
                }
            } catch {
                print("Error fetching top song: \(error)")
            }
        }
    }

    private func populatePlaylists(_ playlists: [Playlist]) {
        guard let stack = playlistStackView else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let images = ["trackimage_1", "trackimage_2", "trackimage_3"]
        for (i, p) in playlists.enumerated() {
            stack.addArrangedSubview(createPlaylistCard(playlist: p, imageName: images[i % images.count]))
        }
    }

    private func fetchRecents() {
        Task {
            do {
                let recents = try await RecentPlayService.shared.fetchRecents(limit: 4)
                await MainActor.run {
                    self.populateRecents(recents)
                }
            } catch {
                print("Error fetching recents: \(error)")
            }
        }
    }

    private func populateRecents(_ recents: [RecentPlay]) {
        guard let stack = recentsStackView else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for recent in recents {
            let randomImg = "trackimage_\(Int.random(in: 1...16))"
            let timeAgo = Self.timeAgoString(from: recent.lastPlayedAt)
            stack.addArrangedSubview(createRecentRow(song: recent.songs, timeAgo: timeAgo, imageName: randomImg))
        }
    }

    private static func timeAgoString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}
