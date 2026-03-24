//
//  HomeViewController.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase

class HomeViewController: UIViewController, UIScrollViewDelegate {

    // MARK: - Native Nav Bar Architecture
    let navBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    let navShadowLayer = UIView()
    let largeSubtitleLabel = UILabel()
    var inlineSubtitleLabel: UILabel?
    
    // Header specific elements
    let largeProfileButton = UIButton(type: .custom)

    let scrollView   = UIScrollView()
    let contentView  = UIView()
    let mainStackView = UIStackView()
    var fixedFooter: UIView!

    var dailyGoalProgressView: UIProgressView?
    var dailyGoalTimeLabel:    UILabel?
    var dailyGoalContainer:    UIView?
    var playlistStackView:     UIStackView?
    var recentsStackView:      UIStackView?
    var topCardTitleLabel:     UILabel?
    var topCardTagLabel:       UILabel?
    var topCardTagsStack:      UIStackView?
    var topCardDetailsStack:   UIStackView?
    var topCardImageView:      UIImageView?
    
    // Store the top song for navigation
    var topSong: Song?

    private var practiceTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.delegate = self
        setupUI()
        startPracticeTimer()
        fetchPlaylists()
        fetchTopSong()
        fetchRecents()
        fetchProfileData()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleProfileUpdate), name: NSNotification.Name("TopNavBarProfileDidUpdate"), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startPracticeTimer()
        fetchRecents()
        fetchTopSong()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPracticeTimer()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopPracticeTimer()
    }
    
    @objc private func handleProfileUpdate() {
        fetchProfileData()
    }

    private func setupUI() {
        // Background and navigation bar — tokens handle light/dark automatically
        view.backgroundColor = ComponentColors.HomeScreen.background
        
        // Ensure nav bar title is clear
        navigationController?.navigationBar.largeTitleTextAttributes = [.foregroundColor: ComponentColors.NavBar.title]
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: ComponentColors.NavBar.title]
        
        setupNavBar()
        syncNavBarAlpha()
        setupScrollView()
        setupNavBackground()
        
        mainStackView.addArrangedSubview(addTopPracticeCardView())
        mainStackView.addArrangedSubview(addUploadSectionView())
        mainStackView.addArrangedSubview(addPlaylistSectionView())
        mainStackView.addArrangedSubview(addRecentsSectionView())
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        syncNavBarAlpha()
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
                // Try from recents first!
                let recents = try await RecentPlayService.shared.fetchRecents(limit: 1)
                if let mostRecent = recents.first {
                    await MainActor.run { self.updateHeroCard(with: mostRecent.songs) }
                    return
                }
                
                // Fallback to highest level song
                let songs = try await SongService.shared.fetchSongs()
                if let song = songs.first {
                    await MainActor.run { self.updateHeroCard(with: song) }
                }
            } catch {
                print("Error fetching top song: \(error)")
            }
        }
    }

    private func updateHeroCard(with song: Song) {
        self.topSong = song
        self.topCardTitleLabel?.text = song.title
        
        // Dynamic Theme Logic
        let theme = PracticeCardTheme.theme(for: song.title)
        
        if let wrapper = view.viewWithTag(991) as? PracticeCardBackgroundView {
            wrapper.updateColors(start: theme.start, end: theme.end)
        }
        if let shadowContainer = view.viewWithTag(992) {
            UIView.animate(withDuration: 0.4) {
                shadowContainer.layer.shadowColor = theme.shadow.cgColor
            }
        }
        
        UIView.animate(withDuration: 0.4) {
            self.view.backgroundColor = UIColor.adaptive(light: theme.bgLight, dark: theme.bgDark)
        }
        
        // Update tags
        if let stack = self.topCardTagsStack {
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            let tags = ["LEVEL \(song.level)", song.hands.uppercased()]
            for text in tags {
                let tag = self.makePillTag(text: text)
                stack.addArrangedSubview(tag)
            }
        }
        
        // Update details
        if let stack = self.topCardDetailsStack {
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            stack.addArrangedSubview(makeDetailItem(icon: "gauge.with.needle", text: "Level \(song.level)"))
            stack.addArrangedSubview(makeDetailItem(icon: "person.fill", text: song.composer))
            stack.addArrangedSubview(makeDetailItem(icon: "metronome", text: song.tempo))
        }
        
        self.topCardTitleLabel?.superview?.layoutIfNeeded()
    }

    func makeDetailItem(icon: String, text: String) -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal; stack.spacing = 6
        let img = UIImageView(image: UIImage(systemName: icon))
        img.tintColor = .white.withAlphaComponent(0.6)
        img.contentMode = .scaleAspectFit
        img.widthAnchor.constraint(equalToConstant: 14).isActive = true
        img.heightAnchor.constraint(equalToConstant: 14).isActive = true
        
        let lbl = UILabel()
        lbl.text = text
        lbl.font = .systemFont(ofSize: 13, weight: .medium)
        lbl.textColor = .white.withAlphaComponent(0.9)
        
        stack.addArrangedSubview(img)
        stack.addArrangedSubview(lbl)
        return stack
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
        
        if recents.isEmpty {
            let placeholder = UILabel()
            placeholder.text = "Play a song to see your recents here!"
            placeholder.font = .systemFont(ofSize: 14, weight: .medium)
            placeholder.textColor = ComponentColors.SongCard.metadataText
            placeholder.textAlignment = .center
            placeholder.tag = 999
            stack.addArrangedSubview(placeholder)
            return
        }
        
        for recent in recents {
            // Stable image from title hash so it doesn't flicker on refresh
            let hash = abs(recent.songs.title.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
            let imgName = "trackimage_\((hash % 16) + 1)"
            let timeAgo = Self.timeAgoString(from: recent.lastPlayedAt)
            stack.addArrangedSubview(createRecentRow(song: recent.songs, timeAgo: timeAgo, imageName: imgName))
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
