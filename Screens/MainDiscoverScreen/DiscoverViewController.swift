// DiscoverViewController.swift
// Re-Hearse
//
// Complete Discover screen — wired to Supabase songs table
// Primary color: #EF9408
// Supports dark + light mode via iOS semantic colors

import UIKit
import Supabase

// MARK: - Song Model
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

    enum CodingKeys: String, CodingKey {
        case id, title, composer, level, tempo, hands, initials
        case skillTags        = "skill_tags"
        case skillDescription = "skill_description"
        case sheetFileId      = "sheet_file_id"
        case isFree           = "is_free"
        case isActive         = "is_active"
        case sortOrder        = "sort_order"
    }
}

// MARK: - Song Service
class SongService {
    static let shared = SongService()

    func fetchSongs() async throws -> [Song] {
        let songs: [Song] = try await SupabaseManager.shared.client
            .from("songs")
            .select()
            .order("level", ascending: true)
            .order("sort_order", ascending: true)
            .execute()
            .value
        return songs
    }
}

// MARK: - DiscoverViewController
class DiscoverViewController: UIViewController {

    // MARK: Data
    private var allSongs: [Song] = []
    private var filteredSongs: [Song] = []
    private var selectedLevel: Int? = nil     // nil = All
    private var selectedSkill: String? = nil  // nil = All skills
    private var tableHeightConstraint: NSLayoutConstraint?

    // MARK: UI Components
    
    private let navBar = TopNavBar.make(title: "Discover")
    private let searchController = UISearchController(searchResultsController: nil)

    // Level filter chips scroll
    private lazy var levelScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var levelStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // Skills section title
    private lazy var skillsTitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Skills"
        lbl.font = .systemFont(ofSize: 22, weight: .bold)
        lbl.textColor = .label
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    // Skill tiles scroll
    private lazy var skillScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var skillStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 10
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // Songs section header
    private lazy var songsTitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Songs"
        lbl.font = .systemFont(ofSize: 22, weight: .bold)
        lbl.textColor = .label
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private lazy var sortButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "By level ↑"
        config.baseForegroundColor = UIColor(red: 239/255, green: 148/255, blue: 8/255, alpha: 1)
        config.image = UIImage(systemName: "chevron.down")
        config.imagePlacement = .trailing
        config.imagePadding = 4
        
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // Table view
    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.register(SongCell.self, forCellReuseIdentifier: SongCell.reuseID)
        tv.dataSource = self
        tv.delegate = self
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 100
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // Empty state
    private lazy var emptyLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "No songs found."
        lbl.font = .systemFont(ofSize: 16, weight: .regular)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .center
        lbl.isHidden = true
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    // Loading indicator
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // Main scroll view wrapping everything
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

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavBar()
        setupUI()
        setupLevelChips()
        setupSkillTiles()
        setupSortMenu()
        fetchSongs()
    }

    // MARK: Navigation Setup

    private func setupNavBar() {
        navigationController?.navigationBar.isHidden = true
        view.addSubview(navBar)
        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        navBar.isChordIconVisible = true
        
        // Wire up search controller
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search songs"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        
        navBar.chordAction = { [weak self] in
            let vc = ChordRecognitionViewController()
            self?.navigationController?.pushViewController(vc, animated: true)
        }
        navBar.profileAction = { [weak self] in
            self?.navigationController?.pushViewController(UserProfileViewController(), animated: true)
        }
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupNavigation() {}

    // MARK: UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Add scroll view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // Add all subviews to contentView
        contentView.addSubview(levelScrollView)
        levelScrollView.addSubview(levelStackView)
        contentView.addSubview(skillsTitleLabel)
        contentView.addSubview(skillScrollView)
        skillScrollView.addSubview(skillStackView)

        // Songs header row
        contentView.addSubview(songsTitleLabel)
        contentView.addSubview(sortButton)
        contentView.addSubview(tableView)
        contentView.addSubview(emptyLabel)
        contentView.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            // ScrollView fills view
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // ContentView fills scrollView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Level chips
            levelScrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            levelScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            levelScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            levelScrollView.heightAnchor.constraint(equalToConstant: 38),

            levelStackView.topAnchor.constraint(equalTo: levelScrollView.topAnchor),
            levelStackView.leadingAnchor.constraint(equalTo: levelScrollView.leadingAnchor),
            levelStackView.trailingAnchor.constraint(equalTo: levelScrollView.trailingAnchor),
            levelStackView.bottomAnchor.constraint(equalTo: levelScrollView.bottomAnchor),
            levelStackView.heightAnchor.constraint(equalTo: levelScrollView.heightAnchor),

            // Skills title
            skillsTitleLabel.topAnchor.constraint(equalTo: levelScrollView.bottomAnchor, constant: 24),
            skillsTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // Skill tiles
            skillScrollView.topAnchor.constraint(equalTo: skillsTitleLabel.bottomAnchor, constant: 12),
            skillScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            skillScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            skillScrollView.heightAnchor.constraint(equalToConstant: 100),

            skillStackView.topAnchor.constraint(equalTo: skillScrollView.topAnchor),
            skillStackView.leadingAnchor.constraint(equalTo: skillScrollView.leadingAnchor),
            skillStackView.trailingAnchor.constraint(equalTo: skillScrollView.trailingAnchor),
            skillStackView.bottomAnchor.constraint(equalTo: skillScrollView.bottomAnchor),
            skillStackView.heightAnchor.constraint(equalTo: skillScrollView.heightAnchor),

            // Songs title
            songsTitleLabel.topAnchor.constraint(equalTo: skillScrollView.bottomAnchor, constant: 24),
            songsTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            sortButton.centerYAnchor.constraint(equalTo: songsTitleLabel.centerYAnchor),
            sortButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),

            // Table view
            tableView.topAnchor.constraint(equalTo: songsTitleLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 500),

            // Empty state
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 60),

            // Loading
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 60),
        ])
    }

    // MARK: - Sort Logic
    private func setupSortMenu() {
        let levelAsc = UIAction(title: "Level: Low to High", image: UIImage(systemName: "arrow.up.circle")) { [weak self] _ in
            self?.sortSongs(by: .levelAsc)
        }
        let levelDesc = UIAction(title: "Level: High to Low", image: UIImage(systemName: "arrow.down.circle")) { [weak self] _ in
            self?.sortSongs(by: .levelDesc)
        }
        let titleAsc = UIAction(title: "Title: A-Z", image: UIImage(systemName: "textformat")) { [weak self] _ in
            self?.sortSongs(by: .titleAsc)
        }
        
        sortButton.menu = UIMenu(title: "Sort Songs", children: [levelAsc, levelDesc, titleAsc])
        sortButton.showsMenuAsPrimaryAction = true
    }

    enum SortOption {
        case levelAsc, levelDesc, titleAsc
    }

    private func sortSongs(by option: SortOption) {
        switch option {
        case .levelAsc:
            filteredSongs.sort { $0.level < $1.level }
            sortButton.setTitle("By level ↑", for: .normal)
        case .levelDesc:
            filteredSongs.sort { $0.level > $1.level }
            sortButton.setTitle("By level ↓", for: .normal)
        case .titleAsc:
            filteredSongs.sort { $0.title.lowercased() < $1.title.lowercased() }
            sortButton.setTitle("By title A-Z", for: .normal)
        }
        tableView.reloadData()
    }

    // MARK: Level Chips

    private func setupLevelChips() {
        let levels = ["All", "Lv 1", "Lv 2", "Lv 3", "Lv 4"]
        for (index, title) in levels.enumerated() {
            let chip = makeLevelChip(title: title, tag: index)
            levelStackView.addArrangedSubview(chip)
        }
        // Select "All" by default
        updateChipSelection(selectedTag: 0)
    }

    private func makeLevelChip(title: String, tag: Int) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 18)
        config.cornerStyle = .capsule
        let btn = UIButton(configuration: config)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        btn.tag = tag
        btn.addTarget(self, action: #selector(levelChipTapped(_:)), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    private func updateChipSelection(selectedTag: Int) {
        let primary = UIColor(red: 239/255, green: 148/255, blue: 8/255, alpha: 1)
        for view in levelStackView.arrangedSubviews {
            guard let btn = view as? UIButton else { continue }
            if btn.tag == selectedTag {
                btn.backgroundColor = primary
                btn.setTitleColor(.white, for: .normal)
            } else {
                btn.backgroundColor = .secondarySystemBackground
                btn.setTitleColor(.secondaryLabel, for: .normal)
            }
        }
    }

    @objc private func levelChipTapped(_ sender: UIButton) {
        selectedLevel = sender.tag == 0 ? nil : sender.tag
        updateChipSelection(selectedTag: sender.tag)
        applyFilters()
    }

    // MARK: Skill Tiles

    private func setupSkillTiles() {
        let skills: [(icon: String, name: String, tag: String)] = [
            ("keyboard",            "Chords",    "chords"),
            ("music.quarternote.3", "Scales",    "scales"),
            ("music.note",          "Melody",    "melody"),
            ("music.note.list",     "Arpeggios", "arpeggios"),
        ]
        for skill in skills {
            let tile = makeSkillTile(icon: skill.icon, name: skill.name, tag: skill.tag)
            skillStackView.addArrangedSubview(tile)
        }
    }

    private func makeSkillTile(icon: String, name: String, tag: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.backgroundColor = .systemBackground
        btn.layer.cornerRadius = 18
        
        // Shadow
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.05
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 8

        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 92).isActive = true

        // Icon
        let iconIV = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        iconIV.image = UIImage(systemName: icon, withConfiguration: config)
        iconIV.tintColor = .label
        iconIV.contentMode = .scaleAspectFit
        iconIV.translatesAutoresizingMaskIntoConstraints = false

        // Name label
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = .secondaryLabel
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        btn.addSubview(iconIV)
        btn.addSubview(nameLabel)
        NSLayoutConstraint.activate([
            iconIV.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            iconIV.topAnchor.constraint(equalTo: btn.topAnchor, constant: 18),
            iconIV.heightAnchor.constraint(equalToConstant: 30),
            
            nameLabel.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: btn.bottomAnchor, constant: -14)
        ])

        // Store tag as accessibility identifier
        btn.accessibilityIdentifier = tag
        btn.addTarget(self, action: #selector(skillTileTapped(_:)), for: .touchUpInside)
        return btn
    }

    @objc private func skillTileTapped(_ sender: UIButton) {
        guard let skill = sender.accessibilityIdentifier else { return }
        if selectedSkill == skill {
            selectedSkill = nil
            sender.layer.borderColor = nil
            sender.layer.borderWidth = 0
            sender.backgroundColor = .systemBackground
        } else {
            for view in skillStackView.arrangedSubviews {
                view.layer.borderWidth = 0
                view.backgroundColor = .systemBackground
            }
            selectedSkill = skill
            let primary = UIColor(red: 239/255, green: 148/255, blue: 8/255, alpha: 1)
            sender.layer.borderColor = primary.cgColor
            sender.layer.borderWidth = 2
            sender.backgroundColor = primary.withAlphaComponent(0.05)
        }
        applyFilters()
    }

    // MARK: Data Fetching

    private func fetchSongs() {
        loadingIndicator.startAnimating()
        tableView.isHidden = true
        emptyLabel.isHidden = true

        Task {
            do {
                let songs = try await SongService.shared.fetchSongs()
                await MainActor.run {
                    self.allSongs = songs
                    self.applyFilters()
                    self.loadingIndicator.stopAnimating()
                    self.tableView.isHidden = false
                }
            } catch {
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: Filtering

    private func applyFilters() {
        var result = allSongs

        // Level filter
        if let level = selectedLevel {
            result = result.filter { $0.level == level }
        }

        // Skill filter
        if let skill = selectedSkill {
            result = result.filter { $0.skillTags.contains(skill) }
        }
        
        // Search filter
        if let query = searchController.searchBar.text, !query.isEmpty {
            result = result.filter { 
                $0.title.lowercased().contains(query.lowercased()) || 
                $0.composer.lowercased().contains(query.lowercased())
            }
        }

        filteredSongs = result
        tableView.reloadData()

        // Empty state
        emptyLabel.isHidden = !filteredSongs.isEmpty
        tableView.isHidden = filteredSongs.isEmpty
        
        // Adjust content view height
        contentView.layoutIfNeeded()
        let tableHeight = tableView.contentSize.height
        if let existing = tableHeightConstraint {
            existing.constant = max(400, tableHeight)
        } else {
            tableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: max(400, tableHeight))
            tableHeightConstraint?.isActive = true
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UISearchResultsUpdating
extension DiscoverViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        applyFilters()
    }
}

// MARK: - UITableViewDataSource
extension DiscoverViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredSongs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SongCell.reuseID, for: indexPath) as! SongCell
        cell.configure(with: filteredSongs[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate
extension DiscoverViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let song = filteredSongs[indexPath.row]
        let detailVC = DiscoverSongDetailViewController()
        detailVC.song = song
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - SongCell
class SongCell: UITableViewCell {
    static let reuseID = "SongCell"

    private let orangeColor = UIColor(red: 239/255, green: 148/255, blue: 8/255, alpha: 1)

    // Art view — initials in grey square
    private lazy var artView: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 14
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var initialsLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 17, weight: .bold)
        lbl.textColor = .tertiaryLabel
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private lazy var titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 17, weight: .bold)
        lbl.textColor = .label
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private lazy var composerLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 14, weight: .regular)
        lbl.textColor = .secondaryLabel
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private lazy var tagsStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 6
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var chevron: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let iv = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: config))
        iv.tintColor = .tertiaryLabel
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var separatorLine: UIView = {
        let v = UIView()
        v.backgroundColor = .separator.withAlphaComponent(0.5)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var infoStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 4
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .default

        artView.addSubview(initialsLabel)
        contentView.addSubview(artView)
        contentView.addSubview(infoStack)
        contentView.addSubview(chevron)
        contentView.addSubview(separatorLine)

        infoStack.addArrangedSubview(titleLabel)
        infoStack.addArrangedSubview(composerLabel)
        infoStack.addArrangedSubview(tagsStackView)

        NSLayoutConstraint.activate([
            // Art
            artView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            artView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            artView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            artView.widthAnchor.constraint(equalToConstant: 58),
            artView.heightAnchor.constraint(equalToConstant: 58),

            initialsLabel.centerXAnchor.constraint(equalTo: artView.centerXAnchor),
            initialsLabel.centerYAnchor.constraint(equalTo: artView.centerYAnchor),

            // Info stack
            infoStack.leadingAnchor.constraint(equalTo: artView.trailingAnchor, constant: 14),
            infoStack.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            infoStack.centerYAnchor.constraint(equalTo: artView.centerYAnchor),

            // Chevron
            chevron.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            chevron.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            // Separator
            separatorLine.leadingAnchor.constraint(equalTo: infoStack.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separatorLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    func configure(with song: Song) {
        initialsLabel.text = song.initials
        titleLabel.text = song.title
        composerLabel.text = "\(song.composer) · \(song.skillDescription)"

        // Clear previous tags
        tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Level tag — orange
        tagsStackView.addArrangedSubview(makeTag("Lv \(song.level)", color: orangeColor))

        // Tempo tag
        let tempoText = song.tempo == "slow" ? "🐢 Slow" : song.tempo == "fast" ? "🐇 Fast" : "♩ Medium"
        tagsStackView.addArrangedSubview(makeTag(tempoText, color: .secondaryLabel))

        // Hands tag
        let handsText = song.hands == "right_only" ? "RH only" : song.hands == "left_only" ? "LH only" : "Both hands"
        tagsStackView.addArrangedSubview(makeTag(handsText, color: .secondaryLabel))

        // Spacer
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tagsStackView.addArrangedSubview(spacer)
    }

    private func makeTag(_ text: String, color: UIColor) -> UIView {
        let container = UIView()
        container.layer.cornerRadius = 6
        container.backgroundColor = color.withAlphaComponent(0.1)

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -3),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
        ])
        return container
    }
}
