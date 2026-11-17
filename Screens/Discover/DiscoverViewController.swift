// DiscoverViewController.swift
// Re-Hearse
//
// Discover screen — Supabase songs, Level/Skill dropdown filters,
// active-chip dismissal, search. Optimised for iPhone + iPad.
// Primary color: #EF9408

import UIKit
import Supabase
import Auth
internal import PostgREST

// MARK: - DiscoverViewController

// MARK: - DiscoverViewController

final class DiscoverViewController: UIViewController {

    // MARK: State

    private var allSongs:      [Song] = []
    private var filteredSongs: [Song] = []
    private let blockedUserStore = BlockedUserStore.shared
    private var selectedLevel: Int?    { didSet { refreshFilters() } }
    private var selectedSkill: String? { didSet { refreshFilters() } }

    private var tableHeightConstraint: NSLayoutConstraint?
    private var chipsHeightConstraint: NSLayoutConstraint?

    private var levelOptions: [(label: String, value: Int?)] = [("All Levels", nil)]
    private var skillOptions: [(label: String, value: String?)] = [("All Skills", nil)]

    // MARK: UI

    private let navBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let navShadowLayer = UIView()
    private let notificationsButton = NotificationBellButton()
    private let largeSubtitleLabel = UILabel()
    private var inlineSubtitleLabel: UILabel?

    private lazy var searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder     = "Search songs, composers..."
        sb.searchBarStyle  = .minimal
        sb.backgroundImage = UIImage()
        sb.delegate        = self
        sb.translatesAutoresizingMaskIntoConstraints = false
        (sb.value(forKey: "searchField") as? UITextField).map {
            $0.backgroundColor    = ComponentColors.DiscoverScreen.chipBackgroundDefault
            $0.layer.cornerRadius = DeviceLayout.s(12)
            $0.clipsToBounds      = true
        }
        return sb
    }()

    private lazy var levelButton = makeFilterButton(icon: "decrease.indent", title: "Level")
    private lazy var skillButton = makeFilterButton(icon: "pianokeys",        title: "Skill")

    private lazy var filterRow: UIStackView = {
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let sv = UIStackView(arrangedSubviews: [levelButton, skillButton, spacer])
        sv.spacing = DeviceLayout.s(12)
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var chipsScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        sv.alpha = 0   // hidden until a filter is active
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var chipsStack: UIStackView = {
        let sv = UIStackView()
        sv.spacing = DeviceLayout.s(8)
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var songsTitleLabel = styledLabel(
        "Songs", font: .systemFont(ofSize: DeviceLayout.s(22), weight: .bold),
        color: ComponentColors.DiscoverScreen.sectionHeader)

    private lazy var emptyLabel: UILabel = {
        let l = styledLabel("No songs found.", font: .systemFont(ofSize: DeviceLayout.s(16)),
                            color: ComponentColors.DiscoverScreen.emptyStateText)
        l.textAlignment = .center
        l.isHidden = true
        return l
    }()

    // isScrollEnabled = false → table renders all rows and derives height from content.
    // We then keep a manual height constraint in sync via updateTableHeight().
    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.register(SongCell.self, forCellReuseIdentifier: SongCell.reuseID)
        tv.register(PadSongPairCell.self, forCellReuseIdentifier: PadSongPairCell.reuseID)
        if DeviceLayout.isPad {
            tv.allowsSelection = false   // the cards take the taps
            // a fixed height (card 116 + 16 between rows), so the table's full height is known
            // up front and the last row is never cut off
            tv.rowHeight = PadSongPairCell.rowHeight
        }
        tv.dataSource         = self
        tv.delegate           = self
        tv.separatorStyle     = .none
        tv.backgroundColor    = .clear
        if !DeviceLayout.isPad { tv.rowHeight = UITableView.automaticDimension }
        tv.estimatedRowHeight = DeviceLayout.isPad ? PadSongPairCell.rowHeight : 86
        tv.isScrollEnabled    = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let discoverSkeleton = DiscoverSkeletonView()

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.delegate = self
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var dismissKeyboardTapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        gesture.cancelsTouchesInView = false
        return gesture
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.DiscoverScreen.background
        setupNavBar()
        navigationItem.titleView?.alpha = 0
        syncNavBarAlpha()
        setupLayout()
        setupKeyboardDismissal()
        setupNavBackground()
        buildFilterMenus()
        setupRefresh()
        fetchSongs()
    }

    /// Pull to refresh, and a fresh fetch when the connection comes back.
    private func setupRefresh() {
        let refresh = UIRefreshControl()
        refresh.addAction(UIAction { [weak self] _ in self?.fetchSongs(force: true) }, for: .valueChanged)
        scrollView.refreshControl = refresh
        NotificationCenter.default.addObserver(forName: Connectivity.didChangeNotification, object: nil,
                                               queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if Connectivity.shared.isOnline { self?.fetchSongs(force: true) }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.titleView?.alpha = 0
        syncNavBarAlpha()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncNavBarAlpha()
        AppTour.showIfNeeded(.library, in: self) { [weak self] in
            guard self != nil else { return [] }
            return [
                TourStep(target: { [weak self] in self?.searchBar },
                         title: "Find a song",
                         message: "Search by title or composer."),
                TourStep(target: { [weak self] in self?.filterRow },
                         title: "Filter by level and skill",
                         message: "Narrow the list to songs that suit where you are."),
                TourStep(target: { [weak self] in self?.tableView.visibleCells.first },
                         title: "Open a song",
                         message: "See the sheet, then play along or watch it played."),
            ]
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateScrollInsets()
    }


    // MARK: NavBar

    private func setupNavBar() {
        inlineSubtitleLabel = NavigationBarHelper.configureInlineNavigationBar(
            for: self,
            title: "Library",
            subtitle: "Songs to learn and play"
        )
        navigationItem.rightBarButtonItems = nil
    }

    private func setupNavBackground() {
        NavigationBarHelper.updateNavigationBackgroundAppearance(
            navBackgroundView,
            shadowView: navShadowLayer,
            traitCollection: traitCollection
        )
        NavigationBarHelper.installNavigationBackground(
            navBackgroundView,
            shadowView: navShadowLayer,
            in: view
        )
    }

    private func setupCustomLargeHeader() -> UIView {
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let labelStack = UIStackView()
        labelStack.axis = .vertical
        labelStack.spacing = DeviceLayout.s(-2)
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Library"
        titleLabel.font = .systemFont(ofSize: DeviceLayout.s(34), weight: .heavy)
        titleLabel.textColor = ComponentColors.NavBar.title
        
        largeSubtitleLabel.text = "Songs to learn and play"
        largeSubtitleLabel.font = .systemFont(ofSize: DeviceLayout.s(16), weight: .regular)
        largeSubtitleLabel.textColor = ComponentColors.NavBar.title.withAlphaComponent(0.6)
        
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(largeSubtitleLabel)
        headerContainer.addSubview(labelStack)
        
        notificationsButton.translatesAutoresizingMaskIntoConstraints = false
        
        headerContainer.addSubview(notificationsButton)
        
        NSLayoutConstraint.activate([
            headerContainer.heightAnchor.constraint(equalToConstant: DeviceLayout.s(80)),
            
            labelStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: DeviceLayout.s(20)),
            labelStack.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            
            notificationsButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: DeviceLayout.s(-20)),
            notificationsButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            notificationsButton.widthAnchor.constraint(equalToConstant: DeviceLayout.s(44)),
            notificationsButton.heightAnchor.constraint(equalToConstant: DeviceLayout.s(44))
        ])
        return headerContainer
    }
    
    // MARK: Layout

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.keyboardDismissMode = .interactive
        scrollView.addSubview(contentView)
        chipsScrollView.addSubview(chipsStack)

        let headerContainer = setupCustomLargeHeader()
        contentView.addSubview(headerContainer)

        [searchBar, filterRow, chipsScrollView,
         songsTitleLabel, tableView, emptyLabel]
            .forEach { contentView.addSubview($0) }

        // Install a starting table height constraint (updated after each reload)
        let initialHeight = tableView.heightAnchor.constraint(equalToConstant: DeviceLayout.s(0))
        initialHeight.isActive = true
        tableHeightConstraint = initialHeight

        let c = contentView
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: DeviceLayout.s(96)),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // header container
            headerContainer.topAnchor.constraint(equalTo: c.topAnchor, constant: DeviceLayout.s(0)),
            headerContainer.leadingAnchor.constraint(equalTo: c.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: c.trailingAnchor),
            
            // Search bar
            searchBar.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: DeviceLayout.s(16)),
            searchBar.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: DeviceLayout.s(12)),
            searchBar.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: DeviceLayout.s(-12)),
            searchBar.heightAnchor.constraint(equalToConstant: DeviceLayout.s(48)),

            // Filter row
            filterRow.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: DeviceLayout.s(12)),
            filterRow.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: DeviceLayout.s(20)),
            filterRow.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: DeviceLayout.s(-20)),
            filterRow.heightAnchor.constraint(equalToConstant: DeviceLayout.s(44)),

            // Chips
            chipsScrollView.topAnchor.constraint(equalTo: filterRow.bottomAnchor, constant: DeviceLayout.s(10)),
            chipsScrollView.leadingAnchor.constraint(equalTo: c.leadingAnchor),
            chipsScrollView.trailingAnchor.constraint(equalTo: c.trailingAnchor),

            chipsStack.topAnchor.constraint(equalTo: chipsScrollView.topAnchor),
            chipsStack.leadingAnchor.constraint(equalTo: chipsScrollView.leadingAnchor),
            chipsStack.trailingAnchor.constraint(equalTo: chipsScrollView.trailingAnchor),
            chipsStack.bottomAnchor.constraint(equalTo: chipsScrollView.bottomAnchor),
            chipsStack.heightAnchor.constraint(equalTo: chipsScrollView.heightAnchor),

            // Songs header
            songsTitleLabel.topAnchor.constraint(equalTo: chipsScrollView.bottomAnchor, constant: DeviceLayout.s(10)),
            songsTitleLabel.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: DeviceLayout.s(20)),

            // Table — height driven by tableHeightConstraint, bottom closes contentView
            tableView.topAnchor.constraint(equalTo: songsTitleLabel.bottomAnchor, constant: DeviceLayout.s(12)),
            tableView.leadingAnchor.constraint(equalTo: c.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: c.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: DeviceLayout.s(-20)),

            // Overlays
            emptyLabel.centerXAnchor.constraint(equalTo: c.centerXAnchor),
            emptyLabel.topAnchor.constraint(equalTo: tableView.topAnchor, constant: DeviceLayout.s(60)),
        ])

        chipsHeightConstraint = chipsScrollView.heightAnchor.constraint(equalToConstant: DeviceLayout.s(0))
        chipsHeightConstraint?.isActive = true

        updateScrollInsets()
    }

    private func setupKeyboardDismissal() {
        view.addGestureRecognizer(dismissKeyboardTapGesture)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: Table Height

    /// Call after every reload so the outer scroll view knows the correct content size.
    private func updateTableHeight() {
        tableView.layoutIfNeeded()
        // iPad rows are a fixed height, so the full height is known without laying them all out
        let h = DeviceLayout.isPad
            ? CGFloat(tableView.numberOfRows(inSection: 0)) * PadSongPairCell.rowHeight
            : tableView.contentSize.height
        tableHeightConstraint?.constant = max(h, 1)   // never zero — layout engine needs > 0
        scrollView.layoutIfNeeded()
    }

    private func updateScrollInsets() {
        let bottomInset = DiscoverLayoutMetrics.scrollBottomInset(
            safeAreaBottom: view.safeAreaInsets.bottom
        )
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    // MARK: Filter Menus

    private func buildFilterMenus() {
        levelButton.menu = UIMenu(title: "Filter by Level", children: levelOptions.map { opt in
            UIAction(title: opt.label, state: selectedLevel == opt.value ? .on : .off) { [weak self] _ in
                self?.selectedLevel = opt.value   // didSet → refreshFilters()
                self?.buildFilterMenus()
            }
        })
        levelButton.showsMenuAsPrimaryAction = true

        skillButton.menu = UIMenu(title: "Filter by Skill", children: skillOptions.map { opt in
            UIAction(title: opt.label, state: selectedSkill == opt.value ? .on : .off) { [weak self] _ in
                self?.selectedSkill = opt.value
                self?.buildFilterMenus()
            }
        })
        skillButton.showsMenuAsPrimaryAction = true
    }

    // MARK: Refresh (driven by didSet observers)

    private func refreshFilters() {
        let orange = ComponentColors.HomeScreen.actionButtonFill

        func updateBtn(_ btn: UIButton, active: Bool, label: String) {
            btn.configuration?.title = "\(label)  ▾"
            btn.configuration?.background.backgroundColor = active
                ? orange.withAlphaComponent(0.15)
                : ComponentColors.DiscoverScreen.chipBackgroundDefault
            btn.configuration?.baseForegroundColor = active ? orange : ComponentColors.DiscoverScreen.chipTextDefault
        }

        updateBtn(levelButton,
                  active: selectedLevel != nil,
                  label: levelOptions.first { $0.value == selectedLevel }?.label ?? levelOptions[0].label)
        updateBtn(skillButton,
                  active: selectedSkill != nil,
                  label: skillOptions.first { $0.value == selectedSkill }?.label ?? skillOptions[0].label)
        buildFilterMenus()
        rebuildChips()
        applyFilters()
    }

    private func rebuildChips() {
        chipsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let lv = selectedLevel, let m = levelOptions.first(where: { $0.value == lv }) {
            chipsStack.addArrangedSubview(makeChip(m.label) { [weak self] in self?.selectedLevel = nil })
        }
        if let sk = selectedSkill, let m = skillOptions.first(where: { $0.value == sk }) {
            chipsStack.addArrangedSubview(makeChip(m.label) { [weak self] in self?.selectedSkill = nil })
        }

        let hasChips = !chipsStack.arrangedSubviews.isEmpty
        UIView.animate(withDuration: 0.2) {
            self.chipsHeightConstraint?.constant = hasChips ? 34 : 0
            self.chipsScrollView.alpha = hasChips ? 1 : 0
            self.scrollView.layoutIfNeeded()
        }
    }

    // MARK: Data & Filtering

    /// Shows the saved songs at once (no skeleton) and refreshes them in the background;
    /// the skeleton only shows when nothing has ever been fetched. `force` skips the
    /// session's 5-minute copy (pull to refresh).
    private func fetchSongs(force: Bool = false) {
        if allSongs.isEmpty, let saved = SongService.shared.savedSongs, !saved.isEmpty {
            show(saved)
        }
        if allSongs.isEmpty {
            discoverSkeleton.show(in: view)
            tableView.isHidden = true
            emptyLabel.isHidden = true
        }

        Task {
            defer { self.scrollView.refreshControl?.endRefreshing() }
            do {
                let songs = try await SongService.shared.fetchSongs(forceRefresh: force)
                self.show(songs)
            } catch {
                self.discoverSkeleton.hide()
                // with songs on screen, a failed refresh (offline) keeps them quietly
                guard self.allSongs.isEmpty else { return }
                self.showError(AppUserFacingError.message(
                    for: "load songs",
                    error: error,
                    fallback: "We couldn't load songs right now. Please try again."
                ))
            }
        }
    }

    private func show(_ songs: [Song]) {
        allSongs = songs
        updateDynamicFilters(from: songs)
        applyFilters()
        discoverSkeleton.hide()
        tableView.isHidden = filteredSongs.isEmpty
    }

    private func applyFilters() {
        filteredSongs = DiscoverSongFilter.visibleSongs(
            from: allSongs,
            blockedUserIDs: blockedUserStore.blockedUserIDs(),
            selectedLevel: selectedLevel,
            selectedSkill: selectedSkill,
            query: searchBar.text
        )

        tableView.reloadData()
        emptyLabel.isHidden = !filteredSongs.isEmpty
        tableView.isHidden  = filteredSongs.isEmpty

        // Must update height AFTER reloadData so contentSize is fresh
        updateTableHeight()
    }

    private func updateDynamicFilters(from songs: [Song]) {
        // Levels: unique integers
        let levels = Set(songs.map { $0.level }).sorted()
        levelOptions = [("All Levels", nil)] + levels.map { ("Lv \($0)", $0) }

        // Skills: unique strings from the skillTags array
        let skills = Set(songs.flatMap { $0.skillTags }).sorted()
        skillOptions = [("All Skills", nil)] + skills.map { ($0.capitalized, $0) }
        
        // Rebuild menus with new options
        buildFilterMenus()
    }

    // MARK: Helpers

    private func makeFilterButton(icon: String, title: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: icon)
        config.title = "\(title)  ▾"
        config.imagePadding = 8
        config.baseForegroundColor = ComponentColors.DiscoverScreen.chipTextDefault
        config.background.backgroundColor = ComponentColors.DiscoverScreen.chipBackgroundDefault
        config.background.cornerRadius = DeviceLayout.s(14)
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 18)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = .systemFont(ofSize: DeviceLayout.s(15), weight: .semibold)
            return attrs
        }
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    private func makeChip(_ label: String, onRemove: @escaping () -> Void) -> UIView {
        let orange = ComponentColors.HomeScreen.actionButtonFill
        let chip   = UIView()
        chip.backgroundColor    = orange.withAlphaComponent(0.18)
        chip.layer.cornerRadius = DeviceLayout.s(14)
        chip.translatesAutoresizingMaskIntoConstraints = false

        let lbl  = styledLabel(label, font: .systemFont(ofSize: DeviceLayout.s(13), weight: .bold), color: orange)
        let xBtn = UIButton(type: .system)
        xBtn.setImage(UIImage(systemName: "xmark",
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: DeviceLayout.s(11), weight: .bold)),
                      for: .normal)
        xBtn.tintColor = orange
        xBtn.translatesAutoresizingMaskIntoConstraints = false
        xBtn.addAction(UIAction { _ in onRemove() }, for: .touchUpInside)

        [lbl, xBtn].forEach { chip.addSubview($0) }
        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: DeviceLayout.s(12)),
            lbl.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
            xBtn.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: DeviceLayout.s(6)),
            xBtn.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: DeviceLayout.s(-10)),
            xBtn.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
            xBtn.widthAnchor.constraint(equalToConstant: DeviceLayout.s(16)),
            chip.heightAnchor.constraint(equalToConstant: DeviceLayout.s(30)),
        ])
        return chip
    }

    private func styledLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text      = text
        l.font      = font
        l.textColor = color
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func push(_ vc: UIViewController) {
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showError(_ msg: String) {
        let a = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    private func syncNavBarAlpha() {
        NavigationBarHelper.syncNavigationBarAlpha(
            scrollView: scrollView,
            navigationItem: navigationItem,
            navBackgroundView: navBackgroundView
        )
    }
}

// MARK: - UISearchBarDelegate

extension DiscoverViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange _: String) {
        let limited = InputValidator.limit(searchBar.text ?? "", maxLength: InputValidator.searchMaxLength)
        if limited != searchBar.text {
            searchBar.text = limited
        }
        applyFilters()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = InputValidator.trimOnSubmit(searchBar.text ?? "")
        searchBar.resignFirstResponder()
        applyFilters()
    }
}

// MARK: - Table DataSource + Delegate

extension DiscoverViewController: UITableViewDataSource, UITableViewDelegate {

    // iPad: two songs to a row, as cards
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        DeviceLayout.isPad ? (filteredSongs.count + 1) / 2 : filteredSongs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if DeviceLayout.isPad {
            let cell = tableView.dequeueReusableCell(withIdentifier: PadSongPairCell.reuseID,
                                                     for: indexPath) as! PadSongPairCell
            let first = indexPath.row * 2
            cell.configure(left: filteredSongs[first],
                           right: first + 1 < filteredSongs.count ? filteredSongs[first + 1] : nil)
            cell.onTap = { [weak self, weak cell] side in
                guard let self, first + side < self.filteredSongs.count else { return }
                self.openSong(at: first + side, art: cell?.rows[side].currentArtImage)
            }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: SongCell.reuseID, for: indexPath) as! SongCell
        cell.configure(with: filteredSongs[indexPath.row])
        return cell
    }
    

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Grab the art image from the visible cell (optional, for a smooth transition)
        let cell = tableView.cellForRow(at: indexPath) as? SongCell
        openSong(at: indexPath.row, art: cell?.currentArtImage)
    }

    private func openSong(at index: Int, art: UIImage?) {
        dismissKeyboard()
        let song = filteredSongs[index]
        let detailVC        = DiscoverSongDetailViewController()
        detailVC.song       = song
        detailVC.passedImage = art
        detailVC.onUserBlocked = { [weak self] blockedUserID in
            self?.blockedUserStore.block(blockedUserID)
            self?.applyFilters()
        }
        push(detailVC)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === self.scrollView {
            syncNavBarAlpha()
        }
    }

}

enum DiscoverLayoutMetrics {
    static func scrollBottomInset(safeAreaBottom: CGFloat) -> CGFloat {
        safeAreaBottom + 24
    }
}

protocol BlockedUserKeyValueStore {
    func stringArray(forKey defaultName: String) -> [String]?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: BlockedUserKeyValueStore {}

final class BlockedUserStore {
    static let shared = BlockedUserStore()

    private let defaults: BlockedUserKeyValueStore
    private let storageKey: String

    init(defaults: BlockedUserKeyValueStore = UserDefaults.standard, storageKey: String = "discover.blocked-user-ids") {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func blockedUserIDs() -> Set<UUID> {
        let rawValues = defaults.stringArray(forKey: storageKey) ?? []
        return Set(rawValues.compactMap(UUID.init(uuidString:)))
    }

    func block(_ userID: UUID) {
        var updated = blockedUserIDs()
        updated.insert(userID)
        defaults.set(updated.map(\.uuidString).sorted(), forKey: storageKey)
    }
}

enum DiscoverSongFilter {
    static func visibleSongs(
        from songs: [Song],
        blockedUserIDs: Set<UUID>,
        selectedLevel: Int?,
        selectedSkill: String?,
        query: String?
    ) -> [Song] {
        var result = songs.filter { song in
            guard let userID = song.userId else { return true }
            return !blockedUserIDs.contains(userID)
        }

        if let selectedLevel {
            result = result.filter { $0.level == selectedLevel }
        }

        if let selectedSkill {
            result = result.filter { $0.skillTags.contains(selectedSkill) }
        }

        if let query = query?.trimmingCharacters(in: .whitespacesAndNewlines),
           !query.isEmpty {
            let normalizedQuery = query.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(normalizedQuery)
                    || $0.composer.lowercased().contains(normalizedQuery)
            }
        }

        return result
    }
}

// MARK: - Song rows and cards

/// One song: cover, title, composer and tags (level, tempo, hands). A row in the phone's list
/// (`SongCell`) and, larger, a card in the iPad's two-column grid (`PadSongPairCell`).
final class SongRowView: UIView {
    private let orange = ComponentColors.HomeScreen.actionButtonFill
    private var coverImageTask: Task<Void, Never>?
    private let large: Bool

    // Pool of track images from Assets/track_images/
    static let trackImages: [UIImage] = (1...16).compactMap { UIImage(named: "trackimage_\($0)") }

    private let artImageView = UIImageView()
    private let titleLabel = UILabel()
    private let composerLabel = UILabel()
    private let tagsStack = UIStackView()

    var currentArtImage: UIImage? { artImageView.image }

    init(large: Bool) {
        self.large = large
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false

        artImageView.contentMode = .scaleAspectFill
        artImageView.clipsToBounds = true
        artImageView.layer.cornerRadius = large ? 12 : 8
        artImageView.layer.cornerCurve = .continuous
        artImageView.backgroundColor = ComponentColors.DiscoverySongCard.artPlaceholder
        artImageView.translatesAutoresizingMaskIntoConstraints = false

        style(titleLabel, size: large ? 19 : 17, weight: .semibold, color: ComponentColors.DiscoverySongCard.titleText)
        style(composerLabel, size: large ? 15 : 14, weight: .regular, color: SemanticColors.Text.secondary)
        tagsStack.spacing = 6

        let info = UIStackView(arrangedSubviews: [titleLabel, composerLabel, tagsStack])
        info.axis = .vertical
        info.spacing = large ? 5 : 4
        info.setCustomSpacing(large ? 10 : 4, after: composerLabel)
        info.translatesAutoresizingMaskIntoConstraints = false
        addSubview(artImageView)
        addSubview(info)

        let art: CGFloat = large ? 84 : 58
        NSLayoutConstraint.activate([
            artImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            artImageView.topAnchor.constraint(equalTo: topAnchor),
            artImageView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            artImageView.widthAnchor.constraint(equalToConstant: art),
            artImageView.heightAnchor.constraint(equalToConstant: art),
            info.leadingAnchor.constraint(equalTo: artImageView.trailingAnchor, constant: large ? 18 : 14),
            info.trailingAnchor.constraint(equalTo: trailingAnchor),
            info.centerYAnchor.constraint(equalTo: artImageView.centerYAnchor),
            info.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            info.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func prepareForReuse() {
        coverImageTask?.cancel()
        coverImageTask = nil
        artImageView.image = Self.trackImages.randomElement()
    }

    func configure(with song: Song) {
        let placeholder = Self.trackImages.randomElement()
        artImageView.image = placeholder

        coverImageTask?.cancel()
        coverImageTask = Task { [weak self] in
            guard let self else { return }
            if let url = try? await song.resolvedCoverImageURL() {
                ImageLoader.shared.loadImage(from: url.absoluteString) { [weak self] img in
                    if let img = img { self?.artImageView.image = img }
                }
                return
            }
            if let coverUrl = song.coverImageUrl, !coverUrl.isEmpty {
                await MainActor.run {
                    self.artImageView.image = UIImage(named: coverUrl) ?? placeholder
                }
            }
        }

        titleLabel.text    = song.title
        composerLabel.text = song.composer
        tagsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let tempo = song.tempo == "slow" ? "🐢 Slow" : song.tempo == "fast" ? "🐇 Fast" : "♩ Medium"
        let hands = song.hands == "right_only" ? "RH only" : song.hands == "left_only" ? "LH only" : "Both hands"
        [("Lv \(song.level)", orange), (tempo, UIColor.secondaryLabel), (hands, UIColor.secondaryLabel)]
            .map  { makeTag($0.0, color: $0.1) }
            .forEach { tagsStack.addArrangedSubview($0) }

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tagsStack.addArrangedSubview(spacer)
        accessibilityLabel = "\(song.title), \(song.composer)"
    }

    private func makeTag(_ text: String, color: UIColor) -> UIView {
        let lbl = UILabel()
        style(lbl, size: large ? 12 : 11, weight: .bold, color: color)
        lbl.text = text
        let v = UIView()
        v.backgroundColor    = color.withAlphaComponent(0.1)
        v.layer.cornerRadius = large ? 7 : 6
        v.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(lbl)
        let vertical: CGFloat = large ? 4 : 3
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: v.topAnchor, constant: vertical),
            lbl.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -vertical),
            lbl.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 8),
            lbl.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -8),
        ])
        return v
    }

    private func style(_ l: UILabel, size: CGFloat, weight: UIFont.Weight, color: UIColor) {
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color
        l.translatesAutoresizingMaskIntoConstraints = false
    }
}

// MARK: - SongCell (phone)

final class SongCell: UITableViewCell {
    static let reuseID = "SongCell"

    private let row = SongRowView(large: false)
    var currentArtImage: UIImage? { row.currentArtImage }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle  = .default
        accessoryType   = .disclosureIndicator
        let separator = UIView()
        separator.backgroundColor = ComponentColors.DiscoverySongCard.separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        contentView.addSubview(separator)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 92),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        row.prepareForReuse()
    }

    func configure(with song: Song) { row.configure(with: song) }
}

// MARK: - PadSongPairCell (iPad)

/// iPad: two songs side by side, each a card.
final class PadSongPairCell: UITableViewCell {
    static let reuseID = "PadSongPairCell"
    static let rowHeight: CGFloat = 132
    /// Called with 0 (left card) or 1 (right card).
    var onTap: ((Int) -> Void)?

    private let cards = [SongCard(), SongCard()]
    var rows: [SongRowView] { cards.map(\.row) }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        let pair = UIStackView(arrangedSubviews: cards)
        pair.axis = .horizontal
        pair.spacing = 16
        pair.distribution = .fillEqually
        pair.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pair)
        NSLayoutConstraint.activate([
            pair.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            pair.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            pair.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            pair.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
        for (i, card) in cards.enumerated() {
            card.addAction(UIAction { [weak self] _ in self?.onTap?(i) }, for: .touchUpInside)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        cards.forEach { $0.row.prepareForReuse() }
    }

    /// `right` is nil for the last row of an odd number of songs.
    func configure(left: Song, right: Song?) {
        cards[0].row.configure(with: left)
        cards[0].accessibilityLabel = cards[0].row.accessibilityLabel
        cards[1].alpha = right == nil ? 0 : 1
        cards[1].isUserInteractionEnabled = right != nil
        if let right {
            cards[1].row.configure(with: right)
            cards[1].accessibilityLabel = cards[1].row.accessibilityLabel
        }
    }

    /// A song card: rounded, slightly raised, with a chevron; dims while pressed.
    final class SongCard: UIControl {
        let row = SongRowView(large: true)

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = ComponentColors.HomeScreen.cardBackground
            layer.cornerRadius = 20
            layer.cornerCurve = .continuous
            isAccessibilityElement = true
            accessibilityTraits = .button
            let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
            chevron.tintColor = .tertiaryLabel
            chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            chevron.translatesAutoresizingMaskIntoConstraints = false
            addSubview(row)
            addSubview(chevron)
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                row.topAnchor.constraint(equalTo: topAnchor, constant: 16),
                row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
                row.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -12),
                chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
                chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
                chevron.widthAnchor.constraint(equalToConstant: 10),
            ])
        }

        required init?(coder: NSCoder) { fatalError() }

        override var isHighlighted: Bool {
            didSet { UIView.animate(withDuration: 0.15) { self.alpha = self.isHighlighted ? 0.6 : 1 } }
        }
    }
}

/// iPad: wide enough for two columns of song cards, centred beside the tab rail.
extension DiscoverViewController: IPadContentWidth {
    var iPadContentWidth: CGFloat { 1180 }
}
