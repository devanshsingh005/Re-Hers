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
    /// Christmas theme only: snowy hills with a gift at the bottom of Browse (hidden while searching).
    private let snowLandscape = ChristmasArtView("xmas-snow-gift")

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
    /// iPad: a search field that stays under the title (a search controller's bar moves to the
    /// top of the screen while it's active).
    private let padSearchBar = UISearchBar()
    private var activeSearchBar: UISearchBar { DeviceLayout.isPad ? padSearchBar : searchController.searchBar }
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // iPad: the search field lines up with the cards below it (the minimal bar draws its
        // field 8 pt inside its frame)
        guard DeviceLayout.isPad, let top = tableView.tableHeaderView else { return }
        let inset = tableView.layoutMargins.left - 8
        let frame = CGRect(x: inset, y: TabRootHeaderView.height + 6,
                           width: top.bounds.width - 2 * inset, height: 52)
        if padSearchBar.frame != frame { padSearchBar.frame = frame }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.HomeScreen.background
        _ = NavigationBarHelper.configureInlineNavigationBar(
            for: self, title: "Search", subtitle: "Uploads, songs, playlists and lessons"
        )
        navigationItem.titleView?.alpha = 0

        tableView.backgroundColor = .clear
        // iPad: rows and their text a size up, in proportion with the larger header
        if DeviceLayout.isPad { tableView.traitOverrides.preferredContentSizeCategory = .extraExtraLarge }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(PadCardPairCell.self, forCellReuseIdentifier: PadCardPairCell.reuseID)
        if DeviceLayout.isPad {
            tableView.allowsSelection = false   // the cards take the taps
            tableView.separatorStyle = .none
        }
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
        installChristmasDecorations()
        header.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: TabRootHeaderView.height)
        header.translatesAutoresizingMaskIntoConstraints = true
        header.autoresizingMask = [.flexibleWidth]
        if DeviceLayout.isPad {
            // iPad (no tab bar to hold it): the search field sits under the title, at the
            // page's width, instead of in the corner of the navigation bar
            let barHeight: CGFloat = 64
            let top = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width,
                                           height: TabRootHeaderView.height + barHeight))
            let bar = padSearchBar
            bar.placeholder = "Uploads, songs, playlists, lessons, settings"
            bar.delegate = self
            bar.searchBarStyle = .minimal
            bar.searchTextField.font = .systemFont(ofSize: 19)
            bar.frame = CGRect(x: 8, y: TabRootHeaderView.height + 6, width: view.bounds.width - 44, height: 52)
            bar.autoresizingMask = [.flexibleWidth]
            top.addSubview(header)
            top.addSubview(bar)
            tableView.tableHeaderView = top
        } else {
            tableView.tableHeaderView = header
        }
        setContentScrollView(tableView)

        NavigationBarHelper.updateNavigationBackgroundAppearance(
            navBackgroundView, shadowView: navShadowLayer, traitCollection: traitCollection
        )
        NavigationBarHelper.installNavigationBackground(navBackgroundView, shadowView: navShadowLayer, in: view)

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Uploads, songs, playlists, lessons, settings"
        if DeviceLayout.isPad {
            searchController.hidesNavigationBarDuringPresentation = false
        } else {
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
        }
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

    /// Christmas theme: the pine branch with an ornament in the header, and the snowy landscape
    /// behind the list at the bottom of the screen (the cards scroll over it). Hidden otherwise.
    private func installChristmasDecorations() {
        let branch = ChristmasDecor.addHeaderBranch(to: header)
        let ornament = ChristmasArtView("xmas-ornament").sized(24, 56)
        header.insertSubview(ornament, aboveSubview: branch)
        NSLayoutConstraint.activate([
            ornament.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: DeviceLayout.s(-46)),
            ornament.topAnchor.constraint(equalTo: branch.topAnchor, constant: DeviceLayout.s(10)),
        ])

        snowLandscape.contentMode = .scaleAspectFill
        snowLandscape.clipsToBounds = true
        view.insertSubview(snowLandscape, belowSubview: tableView)
        NSLayoutConstraint.activate([
            snowLandscape.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            snowLandscape.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            snowLandscape.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            snowLandscape.heightAnchor.constraint(equalTo: snowLandscape.widthAnchor, multiplier: 104.0 / 400.0),
        ])
    }

    // MARK: - Searching

    private var query: String {
        activeSearchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    @objc private func refresh() {
        let q = query
        snowLandscape.alpha = q.isEmpty ? 1 : 0
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
        let count = sections[section].results.count
        return DeviceLayout.isPad ? (count + 1) / 2 : count
    }

    private func content(for result: Result) -> UIListContentConfiguration {
        var content = UIListContentConfiguration.subtitleCell()
        content.secondaryTextProperties.color = .secondaryLabel
        content.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        content.imageProperties.tintColor = BrandColors.brand
        switch result {
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
        return content
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let results = sections[indexPath.section].results
        if DeviceLayout.isPad {
            // two results to a row, as cards (like the Library)
            let cell = tableView.dequeueReusableCell(withIdentifier: PadCardPairCell.reuseID,
                                                     for: indexPath) as! PadCardPairCell
            let first = indexPath.row * 2
            let second = first + 1 < results.count ? results[first + 1] : nil
            cell.configure(left: content(for: results[first]), right: second.map { content(for: $0) })
            cell.onTap = { [weak self] side in
                guard let self, first + side < results.count else { return }
                self.activeSearchBar.resignFirstResponder()
                self.open(results[first + side])
            }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.contentConfiguration = content(for: results[indexPath.row])
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = ComponentColors.HomeScreen.cardBackground
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        activeSearchBar.resignFirstResponder()
        open(sections[indexPath.section].results[indexPath.row])
    }

    private func open(_ result: Result) {
        switch result {
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

extension AppSearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchBar.setShowsCancelButton(!searchText.isEmpty, animated: true)
        refresh()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.setShowsCancelButton(false, animated: true)
        searchBar.resignFirstResponder()
        refresh()
    }
}

/// iPad: wide, with results in two columns, like the Library.
extension AppSearchViewController: IPadContentWidth {
    var iPadContentWidth: CGFloat { 1180 }
}
