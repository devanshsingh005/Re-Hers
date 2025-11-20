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
    
    // MARK: - Playlist Data
    private let playlists = [
        Playlist(title: "Silent Waves", tags: "Lo-fi Ambient Acoustic Chill", trackCount: 12, imageName: "playlist1"),
        Playlist(title: "Beast Mode Beats", tags: "Blaze Surge Rush Fuel", trackCount: 9, imageName: "playlist2"),
        Playlist(title: "Midnight Flow", tags: "Ambient Chillwave Jazzy Groovy", trackCount: 14, imageName: "playlist3"),
        Playlist(title: "Beast Mode Beats", tags: "Blaze Surge Rush Fuel", trackCount: 9, imageName: "playlist4"),
        Playlist(title: "Beast Mode Beats", tags: "Blaze Surge Rush Fuel", trackCount: 9, imageName: "playlist5")
    ]
    
    // MARK: - Grey Shades Configuration
    private let greyShades = [
        UIColor(red: 0.235, green: 0.235, blue: 0.235, alpha: 1.0), // #3C3C3C
        UIColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1.0),    // #737373
        UIColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1.0),    // #A6A6A6
        UIColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1.0),    // #CCCCCC
        UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)     // #E6E6E6
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
          
          // 🔥 SHOW CHORD ICON
          navBar.isChordIconVisible = true
          
          // ---- IMPORTANT: use push so the chord VC becomes part of the nav stack.
          // This keeps the bottom tab bar visible and lets back button behavior be natural.
          navBar.chordAction = { [weak self] in
              guard let self = self else { return }
              let vc = ChordRecognitionViewController()
              // prefer push (so TabBar + Nav stack remain correct)
              if let nav = self.navigationController {
                  nav.pushViewController(vc, animated: true)
              } else {
                  // fallback: if caller isn't embedded in a UINavigationController,
                  // present modally so feature still works.
                  vc.modalPresentationStyle = .fullScreen
                  self.present(vc, animated: true)
              }
          }


        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
        
        navBar.layer.shadowColor = UIColor.black.cgColor
        navBar.layer.shadowOpacity = 0.1
        navBar.layer.shadowOffset = CGSize(width: 0, height: 2)
        navBar.layer.shadowRadius = 4
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
        let bgColor = greyShades[indexPath.row % greyShades.count]
        cell.configure(with: playlist, backgroundColor: bgColor)
        return cell
    }
    
    // MARK: - TableView Delegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        print("Selected playlist: \(playlists[indexPath.row].title)")
    }
}

// MARK: - Playlist Table View Cell
class PlaylistTableViewCell: UITableViewCell {
    
    private let containerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 20
        view.layer.masksToBounds = true
        return view
    }()
    
    private let playlistImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 16
        imageView.layer.masksToBounds = true
        imageView.backgroundColor = .darkGray
        return imageView
    }()
    
    private let textStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 6
        stackView.alignment = .leading
        return stackView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        return label
    }()
    
    private let tracksLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(white: 0.8, alpha: 1.0)
        label.text = "Tracks"
        return label
    }()
    
    private let tagsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor(white: 0.7, alpha: 1.0)
        label.numberOfLines = 1
        return label
    }()
    
    private let trackCountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(white: 0.9, alpha: 1.0)
        return label
    }()
    
    // MARK: - Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        containerView.addSubview(playlistImageView)
        containerView.addSubview(textStackView)
        
        textStackView.addArrangedSubview(titleLabel)
        textStackView.addArrangedSubview(tracksLabel)
        textStackView.addArrangedSubview(tagsLabel)
        textStackView.addArrangedSubview(trackCountLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        playlistImageView.translatesAutoresizingMaskIntoConstraints = false
        textStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            
            playlistImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            playlistImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            playlistImageView.widthAnchor.constraint(equalToConstant: 85),
            playlistImageView.heightAnchor.constraint(equalToConstant: 85),
            
            textStackView.leadingAnchor.constraint(equalTo: playlistImageView.trailingAnchor, constant: 20),
            textStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            textStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    
    func configure(with playlist: Playlist, backgroundColor: UIColor) {
        titleLabel.text = playlist.title
        tagsLabel.text = playlist.tags
        trackCountLabel.text = "\(playlist.trackCount)"
        playlistImageView.image = UIImage(systemName: "music.note.list")
        playlistImageView.tintColor = .white
        playlistImageView.backgroundColor = .systemGray
        containerView.backgroundColor = backgroundColor
    }
}

