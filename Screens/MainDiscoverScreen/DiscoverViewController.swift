// DiscoverViewController.swift
// Re-Hearse
//
// Discover screen — Supabase songs, Level/Skill dropdown filters,
// active-chip dismissal, search. Optimised for iPhone + iPad.
// Primary color: #EF9408

import UIKit
import Supabase

// MARK: - Model

struct Song: Codable, Identifiable {
    let id: UUID
    let title: String
    let composer: String
    let level: Int
    let tempo: String
    let hands: String
    let skillTags: [String]
    let skillDescription: String
    let initials: String
    let sheetFileId: UUID?
    let isFree: Bool
    let isActive: Bool
    let sortOrder: Int
    let sheetUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, title, composer, level, tempo, hands, initials
        case skillTags        = "skill_tags"
        case skillDescription = "skill_description"
        case sheetFileId      = "sheet_file_id"
        case isFree           = "is_free"
        case isActive         = "is_active"
        case sortOrder        = "sort_order"
        case sheetUrl         = "sheet_url"
    }
}

// MARK: - Service

final class SongService {
    static let shared = SongService()
    private init() {}

    func fetchSongs() async throws -> [Song] {
        try await SupabaseManager.shared.client
            .from("songs").select()
            .order("level", ascending: true)
            .order("sort_order", ascending: true)
            .execute().value
    }
}

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

    private let navBar = TopNavBar.make(title: "Discover")

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
        setupLayout()
        buildFilterMenus()
        fetchSongs()
    }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in self.applyAdaptiveWidth(for: size.width) })
    }

    // MARK: NavBar

    private func setupNavBar() {
        navigationController?.navigationBar.isHidden = true
        view.addSubview(navBar)
        navBar.isStreakVisible     = false
        navBar.isWelcomeTextHidden = true
        navBar.isChordIconVisible  = true
        navBar.chordAction   = { [weak self] in self?.push(ChordRecognitionViewController()) }
        navBar.profileAction = { [weak self] in self?.push(UserProfileViewController()) }
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: Layout

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        chipsScrollView.addSubview(chipsStack)

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
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Search bar
            searchBar.topAnchor.constraint(equalTo: c.topAnchor, constant: 8),
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
            var title = AttributedString("\(label)  ▾")
            title.font = .systemFont(ofSize: 15, weight: .semibold)
            btn.configuration?.attributedTitle     = title
            btn.configuration?.baseBackgroundColor = active
                ? orange.withAlphaComponent(0.15)
                : ComponentColors.DiscoverScreen.chipBackgroundDefault
            btn.configuration?.baseForegroundColor = active
                ? orange
                : ComponentColors.DiscoverScreen.chipTextDefault
        }

        updateBtn(levelButton,
                  active: selectedLevel != nil,
                  label: levelOptions.first { $0.value == selectedLevel }?.label ?? "Level")
        updateBtn(skillButton,
                  active: selectedSkill != nil,
                  label: skillOptions.first { $0.value == selectedSkill }?.label ?? "Skill")
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
                    self.showError(error.localizedDescription)
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
        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = ComponentColors.DiscoverScreen.chipBackgroundDefault
        cfg.baseForegroundColor = ComponentColors.DiscoverScreen.chipTextDefault
        cfg.image               = UIImage(systemName: icon)
        cfg.imagePlacement      = .leading
        cfg.imagePadding        = 8
        cfg.contentInsets       = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 14)
        cfg.cornerStyle         = .medium
        var attrTitle = AttributedString("\(title)  ▾")
        attrTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        cfg.attributedTitle = attrTitle
        let btn = UIButton(configuration: cfg)
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
        present(a, animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension DiscoverViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange _: String) { applyFilters() }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
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
     
        let previewVC         = DiscoverSongPreviewViewController()
        previewVC.song        = song
        previewVC.songImage   = cell?.currentArtImage   // see note below
        push(previewVC)
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
        // Pick a random track image; fall back to a plain coloured view if assets missing
        artImageView.image = SongCell.trackImages.randomElement()

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

