//
//  HomeViewController.swift
//  Re-Hearse_v1
//

import UIKit
import Supabase

class HomeViewController: UIViewController {

    let scrollView  = UIScrollView()
    let contentView = UIStackView()
    var fixedFooter: UIView!
    
    var largeSubtitleLabel = UILabel()
    var inlineSubtitleLabel: UILabel?
    private let navBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let navShadowLayer = UIView()

    var dailyGoalProgressView: UIProgressView?
    var dailyGoalTimeLabel:    UILabel?
    var dailyGoalContainer:    UIView?
    var playlistStackView:     UIStackView?
    var recentsStackView:      UIStackView?
    var topCardTitleLabel:     UILabel?
    var topCardTagLabel:       UILabel?
    var topCardImageView:      UIImageView?

    private var practiceTimer: Timer?
    let largeProfileButton = UIButton(type: .custom)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startPracticeTimer()
        
        navigationItem.titleView?.alpha = 0 // Extra protection against flicker
        
        fetchPlaylists()
        fetchTopSong()
        fetchRecents()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startPracticeTimer()
        
        // Hard-reset alpha immediately to prevent that "one second flicker" during transition
        navigationItem.titleView?.alpha = 0
        syncNavBarAlpha()
        
        fetchProfileData()
        syncNavBarAlpha()
        
        fetchRecents()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncNavBarAlpha()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPracticeTimer()
        navigationItem.titleView?.alpha = 0
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopPracticeTimer()
    }

    private func setupUI() {
        view.backgroundColor = ComponentColors.HomeScreen.background
        scrollView.delegate = self
        setupNavBar()
        syncNavBarAlpha() // Initial state
        setupScrollView()
        
        setupNavBackground()
        setupCustomLargeHeader()
        addDailyGoal()
        addCarouselSection()
        addContinueLearningSection()
        addUploadSection()
        addPlaylistSection()
        addRecentsSection()
        
        NotificationCenter.default.addObserver(self, selector: #selector(onProfileUpdated), name: TopNavBar.profileDidUpdateNotification, object: nil)
    }
    
    private func setupCustomLargeHeader() {
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let labelStack = UIStackView()
        labelStack.axis = .vertical
        labelStack.spacing = -2 // Tighten the vertical gap!
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Home"
        titleLabel.font = .systemFont(ofSize: 34, weight: .heavy) // Extra punchy weight
        titleLabel.textColor = ComponentColors.NavBar.title
        
        largeSubtitleLabel.text = "Welcome"
        largeSubtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        largeSubtitleLabel.textColor = ComponentColors.NavBar.title.withAlphaComponent(0.6)
        
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(largeSubtitleLabel)
        headerContainer.addSubview(labelStack)
        
        largeProfileButton.backgroundColor    = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.12)
        largeProfileButton.layer.cornerRadius = 20
        largeProfileButton.layer.masksToBounds = true
        largeProfileButton.clipsToBounds      = true
        largeProfileButton.layer.borderWidth    = 1.0
        largeProfileButton.layer.borderColor    = (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black).cgColor
        largeProfileButton.imageView?.contentMode = .scaleAspectFill
        
        // Default placeholder
        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
        largeProfileButton.tintColor = .secondaryLabel
        
        largeProfileButton.translatesAutoresizingMaskIntoConstraints = false
        largeProfileButton.addTarget(self, action: #selector(handleProfileTap), for: .touchUpInside)
        
        largeProfileButton.removeFromSuperview()
        headerContainer.addSubview(largeProfileButton)
        
        NSLayoutConstraint.activate([
            headerContainer.heightAnchor.constraint(equalToConstant: 80),
            
            labelStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            labelStack.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            
            largeProfileButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            largeProfileButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            largeProfileButton.widthAnchor.constraint(equalToConstant: 40),
            largeProfileButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        contentView.insertArrangedSubview(headerContainer, at: 0)
    }
    
    @objc private func handleProfileTap() {
        navigationController?.pushViewController(UserProfileViewController(), animated: true)
    }
    
    @objc private func onProfileUpdated() {
        fetchProfileData()
    }

    func syncNavBarAlpha() {
        let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let alpha = NavigationBarHelper.calculateNavBarAlpha(offset: offset)
        
        navigationItem.titleView?.alpha = alpha
        navigationItem.titleView?.isHidden = (alpha == 0)
        navBackgroundView.alpha = alpha
    }

    private func setupNavBackground() {
        navBackgroundView.alpha = 0
        navBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        navBackgroundView.isUserInteractionEnabled = false // Allow touches to pass through to header
        navBackgroundView.contentView.isUserInteractionEnabled = false
        view.addSubview(navBackgroundView)
        
        navShadowLayer.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        navShadowLayer.translatesAutoresizingMaskIntoConstraints = false
        navShadowLayer.isUserInteractionEnabled = false
        navBackgroundView.contentView.addSubview(navShadowLayer)
        
        let window = view.window?.windowScene?.keyWindow ?? UIApplication.shared.windows.first
        let topPadding = window?.safeAreaInsets.top ?? 0
        let navHeight: CGFloat = 44 + topPadding
        
        NSLayoutConstraint.activate([
            navBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            navBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBackgroundView.heightAnchor.constraint(equalToConstant: navHeight),
            
            navShadowLayer.leadingAnchor.constraint(equalTo: navBackgroundView.leadingAnchor),
            navShadowLayer.trailingAnchor.constraint(equalTo: navBackgroundView.trailingAnchor),
            navShadowLayer.bottomAnchor.constraint(equalTo: navBackgroundView.bottomAnchor),
            navShadowLayer.heightAnchor.constraint(equalToConstant: 0.33)
        ])
        
        applyLiquidGlass(to: navBackgroundView)
    }

    private func applyLiquidGlass(to blurView: UIVisualEffectView) {
        blurView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        blurView.layer.borderWidth = 0.5
    }

    private func fetchProfileData() {
        Task {
            guard let user = SupabaseManager.shared.client.auth.currentUser else { 
                await MainActor.run {
                    largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    largeProfileButton.tintColor = .secondaryLabel
                }
                return 
            }
            
            do {
                let profile: Profile = try await SupabaseManager.shared.client
                    .from("profiles")
                    .select()
                    .eq("id", value: user.id)
                    .single()
                    .execute()
                    .value
                
                let firstName = profile.full_name?.split(separator: " ").first.map(String.init)
                let welcomeText = firstName != nil ? "Welcome \(firstName!)" : "Welcome back"
                
                await MainActor.run {
                    self.largeSubtitleLabel.text = welcomeText
                    self.inlineSubtitleLabel?.text = welcomeText
                }
                
                if let avatarUrl = profile.avatar_url, !avatarUrl.isEmpty {
                    await loadAndSetProfileImage(from: avatarUrl)
                } else {
                    await MainActor.run {
                        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                        largeProfileButton.tintColor = .secondaryLabel
                    }
                }
            } catch {
                print("Error fetching profile: \(error)")
                await MainActor.run {
                    largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    largeProfileButton.tintColor = .secondaryLabel
                }
            }
        }
    }
    
    private func loadAndSetProfileImage(from urlString: String) async {
        // Support named icon assets (e.g. icon_1, icon_2 ...)
        if urlString.starts(with: "icon_") {
            await MainActor.run {
                if let img = UIImage(named: urlString) {
                    largeProfileButton.setImage(img, for: .normal)
                    largeProfileButton.tintColor = .clear
                }
            }
            return
        }
        
        // Fix Supabase storage URL that may be missing /public/
        var finalURL = urlString
        if urlString.contains("supabase.co/storage/v1/object/useprofile/") && !urlString.contains("/public/") {
            finalURL = urlString.replacingOccurrences(of: "/object/useprofile/", with: "/object/public/useprofile/")
        }
        
        guard let url = URL(string: finalURL) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 30))
            if let img = UIImage(data: data) {
                await MainActor.run {
                    self.largeProfileButton.setImage(img, for: .normal)
                    self.largeProfileButton.tintColor = .clear
                    self.largeProfileButton.imageView?.contentMode = .scaleAspectFill
                }
            } else {
                await MainActor.run {
                    self.largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    self.largeProfileButton.tintColor = .secondaryLabel
                }
            }
        } catch {
            await MainActor.run {
                self.largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                self.largeProfileButton.tintColor = .secondaryLabel
            }
        }
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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            largeProfileButton.layer.borderColor = (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black).cgColor
        }
    }
}
