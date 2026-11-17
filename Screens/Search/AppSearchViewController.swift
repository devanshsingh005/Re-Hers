//
//  AppSearchViewController.swift
//  Re-Hearse_v1
//
//  The Search tab: one search across your uploads, the Library's songs, your playlists,
//  the practice lessons and settings. With no query it offers places to browse.
//

import UIKit

final class AppSearchViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let header = TabRootHeaderView(title: "Search", subtitle: "Uploads, songs, playlists and lessons")
    private let navBackgroundView = UIVisualEffectView(effect: nil)
    private let navShadowLayer = UIView()

    private enum Result {
        case upload(LocalSheetLibrary.Upload)
        case song(Song)
        case playlist(Playlist)
        case chapter(MusicChapter)
        case setting(Shortcut)
    }

    /// Places and settings that search can jump to.
    struct Shortcut {
        let title: String
        let subtitle: String
        let symbolName: String
        let keywords: [String]
        let action: Action

        enum Action {
            case scan, library, playlists, notifications, settings
            case settingsItem(UserProfileViewController.SettingsShortcut)
        }
    }

    private struct Section {
        let title: String
        let results: [Result]
    }

    private let searchController = UISearchController(searchResultsController: nil)
    private var sections: [Section] = []
    private var songs: [Song] = []
    private var playlists: [Playlist] = []
    private var loadTask: Task<Void, Never>?

    private static let browse: [Shortcut] = [
        Shortcut(title: "Scan Sheet Music", subtitle: "Turn a page into music", symbolName: "camera.viewfinder",
                 keywords: ["scan", "camera", "upload", "sheet"], action: .scan),
        Shortcut(title: "Library", subtitle: "Songs to learn", symbolName: "music.note.list",
                 keywords: ["library", "songs", "discover"], action: .library),
        Shortcut(title: "Playlists", subtitle: "Your collections", symbolName: "rectangle.stack",
                 keywords: ["playlist", "playlists", "collection"], action: .playlists),
        Shortcut(title: "Practice Lessons", subtitle: "Interactive lessons", symbolName: "map",
                 keywords: ["practice", "lessons", "learn", "chapters", "theory"],
                 action: .settingsItem(.practice)),
        Shortcut(title: "Notifications", subtitle: "Uploads, goals and new songs", symbolName: "bell",
                 keywords: ["notifications", "alerts", "activity"], action: .notifications),
        Shortcut(title: "Settings", subtitle: "Profile, theme and more", symbolName: "gearshape",
                 keywords: ["settings", "profile", "account", "preferences"], action: .settings),
    ]

    private static let settingsItems: [Shortcut] = [
        Shortcut(title: "Theme", subtitle: "Settings › Appearance", symbolName: "circle.lefthalf.filled",
                 keywords: ["theme", "appearance", "dark mode", "light mode"], action: .settingsItem(.appearance)),
        Shortcut(title: "Daily Goal", subtitle: "Settings › Practice", symbolName: "target",
                 keywords: ["daily goal", "goal", "minutes", "streak"], action: .settingsItem(.dailyGoal)),
        Shortcut(title: "Edit Profile", subtitle: "Settings › Account", symbolName: "person.crop.circle",
                 keywords: ["profile", "name", "username", "photo", "password", "account"],
                 action: .settingsItem(.editProfile)),
        Shortcut(title: "Terms of Service", subtitle: "Settings › Legal", symbolName: "doc.text",
                 keywords: ["terms", "legal"], action: .settingsItem(.terms)),
        Shortcut(title: "Privacy Policy", subtitle: "Settings › Legal", symbolName: "hand.raised",
                 keywords: ["privacy", "legal", "data"], action: .settingsItem(.privacy)),
    ]

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.HomeScreen.background
        _ = NavigationBarHelper.configureInlineNavigationBar(
            for: self, title: "Search", subtitle: "Uploads, songs, playlists and lessons"
        )
        navigationItem.titleView?.alpha = 0

        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.keyboardDismissMode = .onDrag
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.contentInset.top = TabRootHeaderView.topOffset
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        header.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: TabRootHeaderView.height)
        header.translatesAutoresizingMaskIntoConstraints = true
        header.autoresizingMask = [.flexibleWidth]
        tableView.tableHeaderView = header
        setContentScrollView(tableView)

        NavigationBarHelper.updateNavigationBackgroundAppearance(
            navBackgroundView, shadowView: navShadowLayer, traitCollection: traitCollection
        )
        NavigationBarHelper.installNavigationBackground(navBackgroundView, shadowView: navShadowLayer, in: view)

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Uploads, songs, playlists, lessons, settings"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: LocalSheetLibrary.didChangeNotification, object: nil)
        loadRemoteData()
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncNavBarAlpha()
        loadRemoteData()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        tableView.contentInset.bottom = view.safeAreaInsets.bottom
        tableView.verticalScrollIndicatorInsets.bottom = view.safeAreaInsets.bottom
    }

    private func syncNavBarAlpha() {
        NavigationBarHelper.syncNavigationBarAlpha(
            scrollView: tableView, navigationItem: navigationItem, navBackgroundView: navBackgroundView
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        loadTask?.cancel()
    }

    private func loadRemoteData() {
        // what was fetched before, at once; the fetch below replaces it
        if songs.isEmpty, let saved = SongService.shared.savedSongs { songs = saved.filter(\.isActive) }
        if playlists.isEmpty, let saved = PlaylistService.shared.savedPlaylists { playlists = saved }
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            async let songs = try? SongService.shared.fetchSongs()
            async let playlists = try? PlaylistService.shared.fetchPlaylists()
            let (s, p) = await (songs, playlists)
            guard let self, !Task.isCancelled else { return }
            if let s { self.songs = s.filter(\.isActive) }
            if let p { self.playlists = p }
            self.refresh()
        }
    }

    // MARK: - Searching

    private var query: String {
        searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    @objc private func refresh() {
        let q = query
        if q.isEmpty {
            sections = [Section(title: "Browse", results: Self.browse.map { .setting($0) })]
            contentUnavailableConfiguration = nil
            tableView.reloadData()
            return
        }

        func matches(_ fields: [String?]) -> Bool {
            fields.contains { field in
                guard let field else { return false }
                return field.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }

        let uploads = LocalSheetLibrary.shared.uploads().filter { matches([$0.title, $0.originalFilename]) }
        let songResults = songs.filter { matches([$0.title, $0.composer] + $0.skillTags) }
        let playlistResults = playlists.filter { matches([$0.name, $0.description]) }
        let chapters = allChapters.filter { matches([$0.title, $0.subtitle, $0.lesson.title, $0.lesson.noteName]) }
        let settings = (Self.browse + Self.settingsItems).filter { matches([$0.title] + $0.keywords) }

        sections = [
            Section(title: "Your Uploads", results: uploads.map { .upload($0) }),
            Section(title: "Library", results: songResults.map { .song($0) }),
            Section(title: "Playlists", results: playlistResults.map { .playlist($0) }),
            Section(title: "Practice Lessons", results: chapters.map { .chapter($0) }),
            Section(title: "Settings & Shortcuts", results: settings.map { .setting($0) }),
        ].filter { !$0.results.isEmpty }

        contentUnavailableConfiguration = sections.isEmpty ? UIContentUnavailableConfiguration.search() : nil
        tableView.reloadData()
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        content.secondaryTextProperties.color = .secondaryLabel
        content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        content.imageProperties.tintColor = BrandColors.brand
        switch sections[indexPath.section].results[indexPath.row] {
        case .upload(let upload):
            content.image = UIImage(systemName: "doc.text")
            content.text = upload.title
            switch upload.status {
            case .processing: content.secondaryText = "Upload · Converting on device…"
            case .failed:     content.secondaryText = "Upload · Conversion failed"
            case .completed:  content.secondaryText = "Upload · " + DateFormatter.localizedString(
                from: upload.uploadedAt, dateStyle: .medium, timeStyle: .none)
            }
        case .song(let song):
            content.image = UIImage(systemName: "music.note")
            content.text = song.title
            content.secondaryText = "\(song.composer) · \(LastPlayedStore.detail(for: song))"
        case .playlist(let playlist):
            content.image = UIImage(systemName: "rectangle.stack")
            content.text = playlist.name
            content.secondaryText = playlist.description ?? "Playlist"
        case .chapter(let chapter):
            content.image = UIImage(systemName: "graduationcap")
            content.text = chapter.title
            content.secondaryText = "Chapter \(chapter.chapterIndex) · \(chapter.subtitle)"
        case .setting(let shortcut):
            content.image = UIImage(systemName: shortcut.symbolName)
            content.text = shortcut.title
            content.secondaryText = shortcut.subtitle
        }
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = ComponentColors.HomeScreen.cardBackground
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        searchController.searchBar.resignFirstResponder()
        switch sections[indexPath.section].results[indexPath.row] {
        case .upload(let upload):
            if upload.status == .failed { LocalSheetLibrary.shared.retry(id: upload.id) }
            let vc = UploadPageNextViewController()
            vc.jobId = upload.id
            navigationController?.pushViewController(vc, animated: true)
        case .song(let song):
            let vc = DiscoverSongDetailViewController()
            vc.song = song
            navigationController?.pushViewController(vc, animated: true)
        case .playlist(let playlist):
            let vc = PlaylistDetailViewController()
            vc.passedTitle    = playlist.name
            vc.passedArtist   = playlist.description ?? "Custom Playlist"
            vc.playlistId     = playlist.id
            vc.passedCoverUrl = playlist.coverImageURL
            navigationController?.pushViewController(vc, animated: true)
        case .chapter:
            // Lessons unlock in order, so open the lesson map rather than the lesson itself.
            navigationController?.pushViewController(LessonMapViewController(), animated: true)
        case .setting(let shortcut):
            perform(shortcut.action)
        }
    }

    private func perform(_ action: Shortcut.Action) {
        switch action {
        case .scan:
            let nav = mainTabBarController?.select(.home)
            (nav?.viewControllers.first?.screen as? HomeViewController)?.startUploadFlow()
        case .library:
            mainTabBarController?.select(.library)
        case .playlists:
            PlaylistsManager.shared.prewarmPlaylistCacheIfNeeded()
            navigationController?.pushViewController(PlaylistViewController(), animated: true)
        case .notifications:
            navigationController?.pushViewController(NotificationsViewController(), animated: true)
        case .settings:
            mainTabBarController?.select(.settings)
        case .settingsItem(.practice):
            navigationController?.pushViewController(LessonMapViewController(), animated: true)
        case .settingsItem(let item):
            let nav = mainTabBarController?.select(.settings)
            (nav?.viewControllers.first?.screen as? UserProfileViewController)?.perform(item)
        }
    }
}

extension AppSearchViewController: UITableViewDataSource, UITableViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        syncNavBarAlpha()
    }
}

extension AppSearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        refresh()
    }
}
