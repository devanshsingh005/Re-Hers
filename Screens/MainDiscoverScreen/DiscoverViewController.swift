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
    private var selectedLevel: Int?    { didSet { refreshFilters() } }
    private var selectedSkill: String? { didSet { refreshFilters() } }

    // Dynamic height constraint for the non-scrolling table
    private var tableHeightConstraint: NSLayoutConstraint?
    // Collapses chips row when no filters are active
    private var chipsHeightConstraint: NSLayoutConstraint?

    // MARK: Filter Options

    private let levelOptions: [(label: String, value: Int?)] = [
        ("All Levels", nil), ("Lv 1", 1), ("Lv 2", 2), ("Lv 3", 3), ("Lv 4", 4)
    ]
    private let skillOptions: [(label: String, value: String?)] = [
        ("All Skills", nil), ("Melody", "melody"), ("Chords", "chords"),
        ("Scales", "scales"), ("Arpeggios", "arpeggios")
    ]

    // MARK: UI

    private let navBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let navShadowLayer = UIView()
    private let largeProfileButton = UIButton(type: .custom)
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
            $0.layer.cornerRadius = 12
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
        sv.spacing = 12
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
        sv.spacing = 8
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var songsTitleLabel = styledLabel(
        "Songs", font: .systemFont(ofSize: 22, weight: .bold),
        color: ComponentColors.DiscoverScreen.sectionHeader)

    private lazy var emptyLabel: UILabel = {
        let l = styledLabel("No songs found.", font: .systemFont(ofSize: 16),
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
        tv.dataSource         = self
        tv.delegate           = self
        tv.separatorStyle     = .none
        tv.backgroundColor    = .clear
        tv.rowHeight          = UITableView.automaticDimension
        tv.estimatedRowHeight = 86
        tv.isScrollEnabled    = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private lazy var spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

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

    // iPad adaptive width — swapped on rotation
    private var iPadWidthConstraints: [NSLayoutConstraint] = []

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ComponentColors.DiscoverScreen.background
        setupNavBar()
        navigationItem.titleView?.alpha = 0
        syncNavBarAlpha()
        setupLayout()
        setupNavBackground()
        buildFilterMenus()
        fetchSongs()
        fetchProfileData()
        
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
                self.updateProfileButtonBorder()
            }
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProfileUpdate),
            name: NavigationBarHelper.profileDidUpdateNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.titleView?.alpha = 0
        syncNavBarAlpha()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncNavBarAlpha()
    }

    @objc private func handleProfileUpdate() {
        fetchProfileData()
    }

    @available(iOS, deprecated: 17.0)
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateProfileButtonBorder()
        }
    }

    private func updateProfileButtonBorder() {
        largeProfileButton.layer.borderColor = (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black).cgColor
    }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in self.applyAdaptiveWidth(for: size.width) })
    }

    // MARK: NavBar

    private func setupNavBar() {
        inlineSubtitleLabel = NavigationBarHelper.configureInlineNavigationBar(
            for: self,
            title: "Discover",
            subtitle: "Find new music"
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
        labelStack.spacing = -2
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Discover"
        titleLabel.font = .systemFont(ofSize: 34, weight: .heavy)
        titleLabel.textColor = ComponentColors.NavBar.title
        
        largeSubtitleLabel.text = "Find new music"
        largeSubtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        largeSubtitleLabel.textColor = ComponentColors.NavBar.title.withAlphaComponent(0.6)
        
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(largeSubtitleLabel)
        headerContainer.addSubview(labelStack)
        
        largeProfileButton.backgroundColor = ComponentColors.HomeScreen.actionButtonFill.withAlphaComponent(0.12)
        largeProfileButton.layer.cornerRadius = 20
        largeProfileButton.layer.masksToBounds = true
        largeProfileButton.clipsToBounds = true
        largeProfileButton.layer.borderWidth = 1.0
        largeProfileButton.layer.borderColor = (traitCollection.userInterfaceStyle == .dark ? UIColor.white : UIColor.black).cgColor
        largeProfileButton.imageView?.contentMode = .scaleAspectFill
        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
        largeProfileButton.tintColor = .secondaryLabel
        largeProfileButton.translatesAutoresizingMaskIntoConstraints = false
        largeProfileButton.addTarget(self, action: #selector(handleProfileTap), for: .touchUpInside)
        
        headerContainer.addSubview(largeProfileButton)
        
        NSLayoutConstraint.activate([
            headerContainer.heightAnchor.constraint(equalToConstant: 80),
            
            labelStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 20),
            labelStack.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            
            largeProfileButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -20),
            largeProfileButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            largeProfileButton.widthAnchor.constraint(equalToConstant: 40),
            largeProfileButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        return headerContainer
    }
    
    @objc private func handleProfileTap() {
        push(UserProfileViewController())
    }

    // MARK: Layout

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.addSubview(contentView)
        chipsScrollView.addSubview(chipsStack)

        let headerContainer = setupCustomLargeHeader()
        contentView.addSubview(headerContainer)

        [searchBar, filterRow, chipsScrollView,
         songsTitleLabel, tableView, emptyLabel, spinner]
            .forEach { contentView.addSubview($0) }

        // Install a starting table height constraint (updated after each reload)
        let initialHeight = tableView.heightAnchor.constraint(equalToConstant: 0)
        initialHeight.isActive = true
        tableHeightConstraint = initialHeight

        let c = contentView
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 90),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // header container
            headerContainer.topAnchor.constraint(equalTo: c.topAnchor, constant: 0),
            headerContainer.leadingAnchor.constraint(equalTo: c.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: c.trailingAnchor),
            
            // Search bar
            searchBar.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 16),
            searchBar.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 12),
            searchBar.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -12),
            searchBar.heightAnchor.constraint(equalToConstant: 48),

            // Filter row
            filterRow.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 12),
            filterRow.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 20),
            filterRow.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -20),
            filterRow.heightAnchor.constraint(equalToConstant: 44),

            // Chips
            chipsScrollView.topAnchor.constraint(equalTo: filterRow.bottomAnchor, constant: 10),
            chipsScrollView.leadingAnchor.constraint(equalTo: c.leadingAnchor),
            chipsScrollView.trailingAnchor.constraint(equalTo: c.trailingAnchor),

            chipsStack.topAnchor.constraint(equalTo: chipsScrollView.topAnchor),
            chipsStack.leadingAnchor.constraint(equalTo: chipsScrollView.leadingAnchor),
            chipsStack.trailingAnchor.constraint(equalTo: chipsScrollView.trailingAnchor),
            chipsStack.bottomAnchor.constraint(equalTo: chipsScrollView.bottomAnchor),
            chipsStack.heightAnchor.constraint(equalTo: chipsScrollView.heightAnchor),

            // Songs header
            songsTitleLabel.topAnchor.constraint(equalTo: chipsScrollView.bottomAnchor, constant: 10),
            songsTitleLabel.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 20),

            // Table — height driven by tableHeightConstraint, bottom closes contentView
            tableView.topAnchor.constraint(equalTo: songsTitleLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: c.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: c.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -20),

            // Overlays
            emptyLabel.centerXAnchor.constraint(equalTo: c.centerXAnchor),
            emptyLabel.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 60),
            spinner.centerXAnchor.constraint(equalTo: c.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 60),
        ])

        chipsHeightConstraint = chipsScrollView.heightAnchor.constraint(equalToConstant: 0)
        chipsHeightConstraint?.isActive = true

        applyAdaptiveWidth(for: view.bounds.width)
    }

    // MARK: Table Height

    /// Call after every reload so the outer scroll view knows the correct content size.
    private func updateTableHeight() {
        tableView.layoutIfNeeded()
        let h = tableView.contentSize.height
        tableHeightConstraint?.constant = max(h, 1)   // never zero — layout engine needs > 0
        scrollView.layoutIfNeeded()
    }

    // MARK: iPad Adaptive Width

    private func applyAdaptiveWidth(for viewWidth: CGFloat) {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        NSLayoutConstraint.deactivate(iPadWidthConstraints)

        let maxW = min(viewWidth * 0.74, 800)
        iPadWidthConstraints = [
            contentView.widthAnchor.constraint(equalToConstant: maxW),
            contentView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
        ]
        // Deactivate the phone leading-pin so centering works cleanly
        scrollView.constraints
            .first { $0.firstItem === contentView && $0.firstAttribute == .leading }
            .map { $0.isActive = false }

        NSLayoutConstraint.activate(iPadWidthConstraints)
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
            btn.setTitle("\(label)  ▾", for: .normal)
            btn.backgroundColor = active
                ? orange.withAlphaComponent(0.15)
                : ComponentColors.DiscoverScreen.chipBackgroundDefault
            btn.setTitleColor(active ? orange : ComponentColors.DiscoverScreen.chipTextDefault, for: .normal)
            btn.tintColor = active ? orange : ComponentColors.DiscoverScreen.chipTextDefault
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

    private func fetchSongs() {
        spinner.startAnimating()
        tableView.isHidden = true
        emptyLabel.isHidden = true

        Task {
            do {
                let songs = try await SongService.shared.fetchSongs()
                await MainActor.run {
                    self.allSongs = songs
                    self.applyFilters()
                    self.spinner.stopAnimating()
                    self.tableView.isHidden = false
                }
            } catch {
                await MainActor.run {
                    self.spinner.stopAnimating()
                    self.showError("We couldn't load songs right now. Please try again.")
                }
            }
        }
    }

    private func applyFilters() {
        var result = allSongs
        if let lv = selectedLevel         { result = result.filter { $0.level == lv } }
        if let sk = selectedSkill         { result = result.filter { $0.skillTags.contains(sk) } }
        if let q = searchBar.text, !q.isEmpty {
            let lq = q.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(lq) || $0.composer.lowercased().contains(lq)
            }
        }
        filteredSongs   = result

        tableView.reloadData()
        emptyLabel.isHidden = !result.isEmpty
        tableView.isHidden  = result.isEmpty

        // Must update height AFTER reloadData so contentSize is fresh
        updateTableHeight()
    }

    // MARK: Helpers

    private func makeFilterButton(icon: String, title: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: icon), for: .normal)
        btn.setTitle("\(title)  ▾", for: .normal)
        btn.setTitleColor(ComponentColors.DiscoverScreen.chipTextDefault, for: .normal)
        btn.tintColor = ComponentColors.DiscoverScreen.chipTextDefault
        btn.backgroundColor = ComponentColors.DiscoverScreen.chipBackgroundDefault
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        btn.layer.cornerRadius = 14
        btn.clipsToBounds = true
        btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 14)
        btn.semanticContentAttribute = .forceLeftToRight
        btn.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        btn.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    private func makeChip(_ label: String, onRemove: @escaping () -> Void) -> UIView {
        let orange = ComponentColors.HomeScreen.actionButtonFill
        let chip   = UIView()
        chip.backgroundColor    = orange.withAlphaComponent(0.18)
        chip.layer.cornerRadius = 14
        chip.translatesAutoresizingMaskIntoConstraints = false

        let lbl  = styledLabel(label, font: .systemFont(ofSize: 13, weight: .bold), color: orange)
        let xBtn = UIButton(type: .system)
        xBtn.setImage(UIImage(systemName: "xmark",
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)),
                      for: .normal)
        xBtn.tintColor = orange
        xBtn.translatesAutoresizingMaskIntoConstraints = false
        xBtn.addAction(UIAction { _ in onRemove() }, for: .touchUpInside)

        [lbl, xBtn].forEach { chip.addSubview($0) }
        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: 12),
            lbl.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
            xBtn.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 6),
            xBtn.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -10),
            xBtn.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
            xBtn.widthAnchor.constraint(equalToConstant: 16),
            chip.heightAnchor.constraint(equalToConstant: 30),
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
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
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
                
                if let avatarUrl = profile.avatar_url, !avatarUrl.isEmpty {
                    await loadAndSetProfileImage(from: avatarUrl)
                } else {
                    await MainActor.run {
                        largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                        largeProfileButton.tintColor = .secondaryLabel
                    }
                }
            } catch {
                debugLog("Error fetching profile: \(error)")
                await MainActor.run {
                    largeProfileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
                    largeProfileButton.tintColor = .secondaryLabel
                }
            }
        }
    }

    private func loadAndSetProfileImage(from urlString: String) async {
        if urlString.starts(with: "icon_") {
            await MainActor.run {
                if let img = UIImage(named: urlString) {
                    largeProfileButton.setImage(img, for: .normal)
                    largeProfileButton.tintColor = .clear
                }
            }
            return
        }
        
        guard let finalURL = await NavigationBarHelper.signedProfileURLString(from: urlString),
              URL(string: finalURL) != nil else { return }

        ImageLoader.shared.loadImage(from: finalURL) { [weak self] img in
            guard let self = self, let img = img else { return }
            DispatchQueue.main.async {
                self.largeProfileButton.setImage(img, for: .normal)
                self.largeProfileButton.tintColor = .clear
            }
        }
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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredSongs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SongCell.reuseID, for: indexPath) as! SongCell
        cell.configure(with: filteredSongs[indexPath.row])
        return cell
    }
    

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
     
        let song = filteredSongs[indexPath.row]
     
        // Grab the art image from the visible cell (optional, for a smooth transition)
        let cell = tableView.cellForRow(at: indexPath) as? SongCell
     
        let detailVC        = DiscoverSongDetailViewController()
        detailVC.song       = song
        detailVC.passedImage = cell?.currentArtImage
        push(detailVC)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === self.scrollView {
            syncNavBarAlpha()
        }
    }

}

// MARK: - SongCell

final class SongCell: UITableViewCell {
    static let reuseID = "SongCell"

    private let orange = ComponentColors.HomeScreen.actionButtonFill

    // Pool of track images from Assets/track_images/
    private static let trackImages: [UIImage] = (1...16).compactMap {
        UIImage(named: "trackimage_\($0)")
    }

    private lazy var artImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode        = .scaleAspectFill
        iv.clipsToBounds      = true
        iv.layer.cornerRadius = 8
        iv.backgroundColor    = ComponentColors.DiscoverySongCard.artPlaceholder
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    

    // Expose the current art image for transition/preview purposes
    var currentArtImage: UIImage? { artImageView.image }

    private lazy var titleLabel    = cellLabel(17, .semibold, ComponentColors.DiscoverySongCard.titleText)
    private lazy var composerLabel = cellLabel(14, .regular,  SemanticColors.Text.secondary)

    private lazy var tagsStack: UIStackView = {
        let sv = UIStackView()
        sv.spacing = 6
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var separator: UIView = {
        let v = UIView()
        v.backgroundColor = ComponentColors.DiscoverySongCard.separator
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var infoStack: UIStackView = {
        let sv = UIStackView(arrangedSubviews: [titleLabel, composerLabel, tagsStack])
        sv.axis    = .vertical
        sv.spacing = 4
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle  = .default
        accessoryType   = .disclosureIndicator
        [artImageView, infoStack, separator].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            artImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            artImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            artImageView.widthAnchor.constraint(equalToConstant: 58),
            artImageView.heightAnchor.constraint(equalToConstant: 58),
            artImageView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -14),

            infoStack.leadingAnchor.constraint(equalTo: artImageView.trailingAnchor, constant: 14),
            infoStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            infoStack.centerYAnchor.constraint(equalTo: artImageView.centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: infoStack.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with song: Song) {
        let placeholder = SongCell.trackImages.randomElement()
        artImageView.image = placeholder
        
        if let coverUrl = song.coverImageUrl, !coverUrl.isEmpty {
            if coverUrl.hasPrefix("http") {
                ImageLoader.shared.loadImage(from: coverUrl) { [weak self] img in
                    if let img = img { self?.artImageView.image = img }
                }
            } else {
                artImageView.image = UIImage(named: coverUrl) ?? placeholder
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
    }

    private func makeTag(_ text: String, color: UIColor) -> UIView {
        let lbl = cellLabel(11, .bold, color)
        lbl.text = text
        let v = UIView()
        v.backgroundColor    = color.withAlphaComponent(0.1)
        v.layer.cornerRadius = 6
        v.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: v.topAnchor, constant: 3),
            lbl.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -3),
            lbl.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 8),
            lbl.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -8),
        ])
        return v
    }

    private func cellLabel(_ size: CGFloat, _ weight: UIFont.Weight,
                           _ color: UIColor, _ align: NSTextAlignment = .left) -> UILabel {
        let l = UILabel()
        l.font          = .systemFont(ofSize: size, weight: weight)
        l.textColor     = color
        l.textAlignment = align
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }
}
