//
//  MainPlayListScreen.swift
//  Re-Hearse_v1
//
//  Created by Devvvv on 07/11/25.
//

import UIKit

// MARK: - Playlist Data Model
struct Playlist {
    let title: String
    let tags: String
    let trackCount: Int
    let imageName: String
}

// MARK: - Playlist Screen
class PlaylistViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - UI Components
    private let navBar = TopNavBar.make(
        title: "PlayList"
    )
    
    private let tableView = UITableView()
    
    // MARK: - Playlist Data (UPDATED)
    private let playlists = [
        Playlist(title: "Silent Waves", tags: "Lo-fi Ambient Acoustic Chill", trackCount: 12, imageName: "cl_2"),
        Playlist(title: "Beast Mode Beats", tags: "Blaze Surge Rush Fuel", trackCount: 9, imageName: "cl_3"),
        Playlist(title: "Midnight Flow", tags: "Ambient Chillwave Jazzy Groovy", trackCount: 14, imageName: "cl_4"),
        Playlist(title: "Focus Mode", tags: "Study Chill Relax", trackCount: 10, imageName: "cl_5"),
        Playlist(title: "Deep Travel", tags: "Soul Indie Acoustic", trackCount: 8, imageName: "cl_1"),
    ]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .white
        navigationController?.navigationBar.isHidden = true
        
        setupNavBar()
        setupTableView()
    }
    
    // MARK: - Navbar Setup
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        
        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        navBar.isChordIconVisible = true
        
        navBar.chordAction = { [weak self] in
            guard let self = self else { return }
            let vc = ChordRecognitionViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            navBar.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PlaylistTableViewCell.self, forCellReuseIdentifier: "PlaylistCell")
        
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.rowHeight = 130
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 18),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - TableView DataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlists.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistCell", for: indexPath) as! PlaylistTableViewCell
        let playlist = playlists[indexPath.row]
        
        cell.configure(with: playlist)
        return cell
    }
    
    // MARK: - TableView Tap Navigation
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let playlist = playlists[indexPath.row]
        print("Selected playlist: \(playlist.title)")
        
        let vc = PlaylistDetailViewController()
        // You can pass playlist info if needed later
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Playlist Table View Cell
class PlaylistTableViewCell: UITableViewCell {
    
    private let containerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 20
        view.layer.masksToBounds = true
        view.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        return view
    }()
    
    private let playlistImageView = UIImageView()
    
    private let titleLabel = UILabel()
    private let tagsLabel = UILabel()
    private let trackCountLabel = UILabel()
    
    // MARK: - Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    // MARK: - Setup UI
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        playlistImageView.contentMode = .scaleAspectFill
        playlistImageView.layer.cornerRadius = 16
        playlistImageView.clipsToBounds = true
        
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.textColor = .white
        
        tagsLabel.font = .systemFont(ofSize: 13)
        tagsLabel.textColor = .lightGray
        
        trackCountLabel.font = .systemFont(ofSize: 13)
        trackCountLabel.textColor = .white
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, tagsLabel, trackCountLabel])
        stack.axis = .vertical
        stack.spacing = 3
        
        contentView.addSubview(containerView)
        containerView.addSubview(playlistImageView)
        containerView.addSubview(stack)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        playlistImageView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            
            playlistImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            playlistImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            playlistImageView.widthAnchor.constraint(equalToConstant: 70),
            playlistImageView.heightAnchor.constraint(equalToConstant: 70),
            
            stack.leadingAnchor.constraint(equalTo: playlistImageView.trailingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    
    func configure(with playlist: Playlist) {
        titleLabel.text = playlist.title
        tagsLabel.text = playlist.tags
        trackCountLabel.text = "Tracks - \(playlist.trackCount)"
        playlistImageView.image = UIImage(named: playlist.imageName)
    }
}
