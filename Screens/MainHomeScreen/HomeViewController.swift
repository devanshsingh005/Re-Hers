//
//  HomeViewController.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase

class HomeViewController: UIViewController, UIScrollViewDelegate {

    // MARK: - Native Nav Bar Architecture
    let navBackgroundView = UIVisualEffectView(effect: nil)
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
    var topCardContainer:      UIView?
    
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProfileUpdate),
            name: NavigationBarHelper.profileDidUpdateNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNavBackgroundAppearance()
        syncNavBarAlpha()
        startPracticeTimer()
        fetchPlaylists()
        fetchRecents()
        fetchTopSong()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncNavBarAlpha()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPracticeTimer()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        updateNavBackgroundAppearance()
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
        
        let card = addTopPracticeCardView()
        self.topCardContainer = card
        mainStackView.addArrangedSubview(card)

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
                debugLog("Error fetching playlists: \(error)")
            }
        }
    }
    
    private func fetchTopSong() {
        Task {
            do {
                // 1. Try from recents first!
                let recents = try await RecentPlayService.shared.fetchRecents(limit: 1)
                if let mostRecent = recents.first {
                    await MainActor.run {
                        self.topCardContainer?.isHidden = false
                        self.updateHeroCard(with: mostRecent.songs)
                    }
                    return
                }
                
                // 2. NEW USER Logic: Try levels from onboarding
                if let user = SupabaseManager.shared.client.auth.currentUser {
                    struct Onboarding: Decodable { let level: Int }
                    let onboarding: Onboarding? = try? await SupabaseManager.shared.client
                        .from("user_onboarding")
                        .select("level")
                        .eq("id", value: user.id)
                        .single()
                        .execute()
                        .value
                    
                    if let onboarding = onboarding {
                        // Query songs WHERE level = onboarding.level AND is_active = true
                        let recommendedSongs: [Song] = try await SupabaseManager.shared.client
                            .from("songs")
                            .select()
                            .eq("level", value: onboarding.level)
                            .eq("is_active", value: true)
                            .limit(1)
                            .execute()
                            .value
                        
                        if let song = recommendedSongs.first {
                            await MainActor.run {
                                self.topCardContainer?.isHidden = false
                                self.updateHeroCard(with: song)
                            }
                            return
                        }
                    }
                }
                
                // 3. Fallback to discover songs (fetched by SongService)
                let songs = try await SongService.shared.fetchSongs()
                if let song = songs.first {
                    await MainActor.run {
                        self.topCardContainer?.isHidden = false
                        self.updateHeroCard(with: song)
                    }
                } else {
                    // If absolutely nothing, hide the card
                    await MainActor.run {
                        self.topCardContainer?.isHidden = true
                    }
                }
            } catch {
                debugLog("Error fetching top song: \(error)")
                // Keep previous state if any
            }
        }
    }

    private func updateHeroCard(with song: Song) {
        self.topSong = song
        self.topCardTitleLabel?.text = song.title

        // ── Cover Image ─────────────────────────────────────────────
        if let coverImageView = view.viewWithTag(9910) as? UIImageView {
            let placeholder = UIImage(named: "trackimage_1")
            coverImageView.image = placeholder
            if let coverUrl = song.coverImageUrl, !coverUrl.isEmpty {
                if coverUrl.hasPrefix("http") {
                    ImageLoader.shared.loadImage(from: coverUrl) { [weak coverImageView] img in
                        if let img = img { coverImageView?.image = img }
                    }
                } else {
                    coverImageView.image = UIImage(named: coverUrl) ?? placeholder
                }
            }
        }

        // ── Tags ─────────────────────────────────────────────────────
        if let stack = self.topCardTagsStack {
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            let tags = ["LEVEL \(song.level)", song.hands.uppercased()]
            for text in tags {
                stack.addArrangedSubview(makePillTag(text: text))
            }
        }
        
        // ── Details ──────────────────────────────────────────────────
        if let stack = self.topCardDetailsStack {
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            let levelText = song.level <= 3 ? "Beginner" : (song.level <= 6 ? "Intermediate" : "Advanced")
            stack.addArrangedSubview(self.makeDetailItem(icon: "gauge.with.needle", text: levelText))
            stack.addArrangedSubview(self.makeDetailItem(icon: "person.fill", text: song.composer))
            stack.addArrangedSubview(self.makeDetailItem(icon: "metronome", text: song.tempo))
        }

        // ── Gradient Background ──────────────────────────────────────
        if let wrapper = view.viewWithTag(991) as? PracticeCardBackgroundView {
            let theme = PracticeCardTheme.theme(for: song.title)
            wrapper.updateColors(start: theme.start, end: theme.end)
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

        if playlists.isEmpty {
            stack.addArrangedSubview(createEmptyPlaylistCard())
            return
        }

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
                debugLog("Error fetching recents: \(error)")
            }
        }
    }

    private func populateRecents(_ recents: [RecentPlay]) {
        guard let stack = recentsStackView else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if recents.count <= 1 {
            stack.addArrangedSubview(createEmptyRecentsView())
            return
        }
        
        for recent in recents.dropFirst(1) {
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
